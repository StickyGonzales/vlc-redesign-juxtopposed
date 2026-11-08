/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "rd_sync_scanner.hpp"

#include <vlc_aout.h>
#include <vlc_block.h>
#include <vlc_codec.h>
#include <vlc_demux.h>
#include <vlc_es_out.h>
#include <vlc_stream.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <memory>
#include <new>

namespace {

// the AVI demuxer's "avi-index" choice "Never fix" (0 asks the user)
constexpr int64_t kAviIndexNeverFix = 2;
// the audio's timestamps move it to another frame only when they are this far from the samples
// counted (a gap in the audio, a broken file); smaller differences are the decoder's rounding
constexpr double kJumpSeconds = 0.5;
// how often the read looks at the clock, the cancel flag and its position (demux calls)
constexpr int kCheckEvery = 64;

struct Track
{
    es_format_t fmt;
    decoder_t* packetizer = nullptr;
    decoder_t* decoder = nullptr;
    // an embedded text subtitle track whose packets' times are kept
    bool text = false;
};

bool isTextSubtitle(vlc_fourcc_t codec)
{
    switch (codec)
    {
    case VLC_CODEC_SUBT:
    case VLC_CODEC_SSA:
    case VLC_CODEC_TX3G:
    case VLC_CODEC_WEBVTT:
    case VLC_CODEC_TTML:
        return true;
    default:
        return false;
    }
}

// a packet that clears the screen instead of showing a line: MP4 fills the gaps between lines
// with empty samples (tx3g: a text length of 0; WebVTT: a lone "vtte" box), and some muxers
// send an empty SubRip line
bool isEmptyLine(vlc_fourcc_t codec, const block_t* block)
{
    if (block->i_buffer == 0)
        return true;
    switch (codec)
    {
    case VLC_CODEC_TX3G:
        return block->i_buffer < 2 || GetWBE(block->p_buffer) == 0;
    case VLC_CODEC_WEBVTT:
        return block->i_buffer >= 8 && block->i_buffer == GetDWBE(block->p_buffer)
               && std::memcmp(block->p_buffer + 4, "vtte", 4) == 0;
    case VLC_CODEC_SUBT:
        return block->p_buffer[0] == '\0';
    default:
        return false;
    }
}

bool supportedFormat(vlc_fourcc_t format)
{
    switch (format)
    {
    case VLC_CODEC_FL32:
    case VLC_CODEC_FL64:
    case VLC_CODEC_S16N:
    case VLC_CODEC_S32N:
    case VLC_CODEC_U8:
        return true;
    default:
        return false;
    }
}

template<typename T>
float sampleAt(const uint8_t* data, size_t index, double scale, double offset)
{
    T value;
    memcpy(&value, data + index * sizeof(T), sizeof(T));
    return static_cast<float>((static_cast<double>(value) - offset) * scale);
}

} // namespace

struct RdSyncScanner::Scan
{
    explicit Scan(RdSyncScanner& scanner) : scanner(scanner) {}

    es_out_id_t* addTrack(const es_format_t* fmt);
    void sendBlock(Track* track, block_t* block);
    void deleteTrack(Track* track);
    int control(int query, va_list args);

    decoder_t* loadDecoder(bool packetizer, const es_format_t* fmt);
    bool openDecoders(Track* track);
    void closeDecoders(Track* track);
    void process(Track* track, block_t* block);
    void consume(const audio_format_t& fmt, const block_t* frame);
    void keepCue(Track* track, const block_t* block);

    bool stopped() const { return scanner.cancelled() || overBudget || failed; }

    RdSyncScanner& scanner;
    vlc_object_t* obj = nullptr;
    vlc_tick_t deadline = VLC_TICK_INVALID;
    std::vector<Track*> tracks;
    Track* audio = nullptr;
    std::unique_ptr<rdsync::FeatureExtractor> features;
    unsigned featureRate = 0;
    // where the next decoded sample lies (seconds), once the first audio has shown its time
    bool positionKnown = false;
    double position = 0;
    std::vector<float> mono;
    std::map<int, std::vector<rdsync::Cue>> cues;
    // the time the demuxer calls the media's start (MPEG-TS: its first clock reference); VLC
    // shows and shifts external subtitles from it (src/input/es_out.c), so every time is counted
    // from it
    vlc_tick_t normalTime = VLC_TICK_0;
    bool overBudget = false;
    bool failed = false;
};

namespace {

// the es_out the demuxer writes to; C layout, so the demuxer's es_out_t* leads back to the scan
struct ScanEsOut
{
    es_out_t out;
    RdSyncScanner::Scan* scan;
};

RdSyncScanner::Scan* scanOf(es_out_t* out)
{
    return reinterpret_cast<ScanEsOut*>(out)->scan;
}

Track* trackOf(es_out_id_t* id)
{
    return reinterpret_cast<Track*>(id);
}

es_out_id_t* EsOutAdd(es_out_t* out, input_source_t*, const es_format_t* fmt)
{
    return scanOf(out)->addTrack(fmt);
}

int EsOutSend(es_out_t* out, es_out_id_t* id, block_t* block)
{
    scanOf(out)->sendBlock(trackOf(id), block);
    return VLC_SUCCESS;
}

void EsOutDel(es_out_t* out, es_out_id_t* id)
{
    scanOf(out)->deleteTrack(trackOf(id));
}

int EsOutControl(es_out_t* out, input_source_t*, int query, va_list args)
{
    return scanOf(out)->control(query, args);
}

void EsOutDestroy(es_out_t*)
{
    // owned by the scan
}

es_out_callbacks makeEsOutCallbacks()
{
    es_out_callbacks cbs {};
    cbs.add = EsOutAdd;
    cbs.send = EsOutSend;
    cbs.del = EsOutDel;
    cbs.control = EsOutControl;
    cbs.destroy = EsOutDestroy;
    return cbs;
}

const es_out_callbacks kEsOutCallbacks = makeEsOutCallbacks();

// a decoder or packetizer of the scan; C layout, decoder_t first (vlc_object_create)
struct DecoderOwner
{
    decoder_t dec;
    es_format_t fmtIn;
    RdSyncScanner::Scan* scan;
};

DecoderOwner* ownerOf(decoder_t* dec)
{
    return reinterpret_cast<DecoderOwner*>(dec);
}

// as for an audio output, without one: a passthrough decoder (S/PDIF) is refused, so VLC loads
// the next decoder, one that outputs samples
int DecoderFormatUpdate(decoder_t* dec)
{
    audio_format_t& audio = dec->fmt_out.audio;
    audio.i_format = dec->fmt_out.i_codec;
    if (!supportedFormat(audio.i_format) || audio.i_rate == 0)
        return -1;
    if (audio.i_physical_channels == 0 && audio.i_channels > 0
        && audio.i_channels < ARRAY_SIZE(vlc_chan_maps))
        audio.i_physical_channels = vlc_chan_maps[audio.i_channels];
    aout_FormatPrepare(&audio);
    if (audio.i_channels == 0 || audio.i_bytes_per_frame == 0 || audio.i_frame_length == 0)
        return -1;
    return 0;
}

void DecoderQueueAudio(decoder_t* dec, vlc_frame_t* frame)
{
    ownerOf(dec)->scan->consume(dec->fmt_out.audio, frame);
    block_Release(frame);
}

decoder_owner_callbacks makeDecoderCallbacks()
{
    decoder_owner_callbacks cbs {};
    cbs.audio.format_update = DecoderFormatUpdate;
    cbs.audio.queue = DecoderQueueAudio;
    cbs.get_attachments = nullptr;
    return cbs;
}

const decoder_owner_callbacks kDecoderCallbacks = makeDecoderCallbacks();

void destroyDecoder(decoder_t* dec)
{
    if (!dec)
        return;
    decoder_Clean(dec);
    es_format_Clean(&ownerOf(dec)->fmtIn);
    vlc_object_delete(dec);
}

} // namespace

es_out_id_t* RdSyncScanner::Scan::addTrack(const es_format_t* fmt)
{
    auto* track = new (std::nothrow) Track;
    if (!track)
        return nullptr;
    es_format_Copy(&track->fmt, fmt);
    tracks.push_back(track);

    if (fmt->i_cat == SPU_ES && isTextSubtitle(fmt->i_codec))
        track->text = true;
    // the audio asked for, else the first one
    if (scanner.m_wantAudio && !audio && fmt->i_cat == AUDIO_ES
        && (scanner.m_audioId < 0 || fmt->i_id == scanner.m_audioId) && openDecoders(track))
        audio = track;
    return reinterpret_cast<es_out_id_t*>(track);
}

void RdSyncScanner::Scan::sendBlock(Track* track, block_t* block)
{
    if (stopped())
    {
        block_Release(block);
        return;
    }
    if (track->text)
    {
        keepCue(track, block);
        block_Release(block);
    }
    else if (track == audio)
        process(track, block);
    else
        block_Release(block);
}

void RdSyncScanner::Scan::deleteTrack(Track* track)
{
    const auto it = std::find(tracks.begin(), tracks.end(), track);
    if (it == tracks.end())
        return;
    tracks.erase(it);
    if (track == audio)
    {
        if (!stopped())
            process(track, nullptr);
        audio = nullptr;
    }
    closeDecoders(track);
    es_format_Clean(&track->fmt);
    delete track;
}

int RdSyncScanner::Scan::control(int query, va_list args)
{
    switch (query)
    {
    case ES_OUT_GET_ES_STATE:
    {
        // the measured audio and the text subtitles are selected: demuxers skip the others
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        bool* selected = va_arg(args, bool*);
        *selected = track && (track == audio || track->text);
        return VLC_SUCCESS;
    }
    case ES_OUT_IS_EMPTY:
        *va_arg(args, bool*) = true;
        return VLC_SUCCESS;
    case ES_OUT_RESTART_ES:
    {
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        if (track == audio)
        {
            closeDecoders(track);
            if (!openDecoders(track))
                failed = true;
        }
        return VLC_SUCCESS;
    }
    case ES_OUT_SET_ES_FMT:
    {
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        const es_format_t* fmt = va_arg(args, es_format_t*);
        es_format_Clean(&track->fmt);
        es_format_Copy(&track->fmt, fmt);
        if (track == audio)
        {
            closeDecoders(track);
            if (!openDecoders(track))
                failed = true;
        }
        return VLC_SUCCESS;
    }
    case ES_OUT_SET_ES:
    case ES_OUT_SET_ES_DEFAULT:
    case ES_OUT_SET_ES_STATE:
    case ES_OUT_SET_ES_CAT_POLICY:
    case ES_OUT_SET_GROUP:
    case ES_OUT_SET_PCR:
    case ES_OUT_SET_GROUP_PCR:
    case ES_OUT_RESET_PCR:
    case ES_OUT_SET_NEXT_DISPLAY_TIME:
    case ES_OUT_SET_GROUP_META:
    case ES_OUT_SET_GROUP_EPG:
    case ES_OUT_SET_GROUP_EPG_EVENT:
    case ES_OUT_SET_EPG_TIME:
    case ES_OUT_DEL_GROUP:
    case ES_OUT_SET_ES_SCRAMBLED_STATE:
    case ES_OUT_DRAIN:
    case ES_OUT_SET_META:
        return VLC_SUCCESS;
    default:
        return VLC_EGENERIC;
    }
}

decoder_t* RdSyncScanner::Scan::loadDecoder(bool packetizer, const es_format_t* fmt)
{
    auto* owner = static_cast<DecoderOwner*>(vlc_object_create(obj, sizeof(DecoderOwner)));
    if (!owner)
        return nullptr;
    owner->scan = this;

    decoder_t* dec = &owner->dec;
    decoder_Init(dec, &owner->fmtIn, fmt);
    dec->cbs = &kDecoderCallbacks;
    dec->b_frame_drop_allowed = false;

    decoder_LoadModule(dec, packetizer, false);
    if (!dec->p_module)
    {
        destroyDecoder(dec);
        return nullptr;
    }
    return dec;
}

bool RdSyncScanner::Scan::openDecoders(Track* track)
{
    track->packetizer = loadDecoder(true, &track->fmt);
    if (!track->packetizer)
        return false;
    track->decoder = loadDecoder(false, &track->packetizer->fmt_out);
    if (!track->decoder)
    {
        destroyDecoder(track->packetizer);
        track->packetizer = nullptr;
        return false;
    }
    return true;
}

void RdSyncScanner::Scan::closeDecoders(Track* track)
{
    destroyDecoder(track->decoder);
    destroyDecoder(track->packetizer);
    track->decoder = nullptr;
    track->packetizer = nullptr;
}

// the input core's decoder loop without the clock: packetize, reload the decoder on a format
// change, decode (`block` null: drain). As in the waveform scanner (rd_waveform_scanner.cpp),
// the packetizer owns `block` from here, whatever it returns.
void RdSyncScanner::Scan::process(Track* track, block_t* block)
{
    decoder_t* packetizer = track->packetizer;
    if (!packetizer || !track->decoder)
    {
        if (block)
            block_Release(block);
        return;
    }

    const bool draining = !block;
    block_t** blockRef = draining ? nullptr : &block;
    block_t* packets;
    while ((packets = packetizer->pf_packetize(packetizer, blockRef)) != nullptr)
    {
        if (stopped())
        {
            block_ChainRelease(packets);
            continue;
        }

        if (!es_format_IsSimilar(track->decoder->fmt_in, &packetizer->fmt_out))
        {
            track->decoder->pf_decode(track->decoder, nullptr);
            destroyDecoder(track->decoder);
            track->decoder = loadDecoder(false, &packetizer->fmt_out);
            if (!track->decoder)
            {
                failed = true;
                block_ChainRelease(packets);
                continue;
            }
        }

        while (packets)
        {
            block_t* next = packets->p_next;
            packets->p_next = nullptr;
            if (track->decoder->pf_decode(track->decoder, packets) == VLCDEC_ECRITICAL)
            {
                failed = true;
                block_ChainRelease(next);
                break;
            }
            packets = next;
        }
    }
    if (draining && track->decoder && !stopped())
        track->decoder->pf_decode(track->decoder, nullptr);
}

void RdSyncScanner::Scan::consume(const audio_format_t& fmt, const block_t* frame)
{
    if (stopped() || fmt.i_rate == 0 || fmt.i_bytes_per_frame == 0 || fmt.i_frame_length == 0
        || fmt.i_channels == 0)
        return;
    const size_t bytesPerFrame = fmt.i_bytes_per_frame / fmt.i_frame_length;
    if (bytesPerFrame == 0)
        return;
    const size_t frames = std::min<size_t>(frame->i_nb_samples, frame->i_buffer / bytesPerFrame);
    if (frames == 0)
        return;

    // the frames are counted at the first rate the decoder gives (a rate change mid-file is rare
    // and moves the times by a fraction only)
    if (!features)
    {
        featureRate = fmt.i_rate;
        features = std::make_unique<rdsync::FeatureExtractor>(featureRate);
    }

    // the audio's own time places it: at the start (audio that begins after the video) and
    // after a gap; within kJumpSeconds the samples counted are followed
    if (frame->i_pts != VLC_TICK_INVALID)
    {
        const double time = std::max(0.0, secf_from_vlc_tick(frame->i_pts - normalTime));
        if (!positionKnown || time - position > kJumpSeconds)
        {
            position = std::max(position, time);
            features->skipTo(static_cast<size_t>(position * 1000.0 / rdsync::kFrameMs));
        }
        positionKnown = true;
    }

    // down to one channel, as floats
    const unsigned channels = fmt.i_channels;
    mono.resize(frames);
    const uint8_t* data = frame->p_buffer;
    for (size_t i = 0; i < frames; ++i)
    {
        double sum = 0;
        for (unsigned c = 0; c < channels; ++c)
        {
            const size_t index = i * channels + c;
            switch (fmt.i_format)
            {
            case VLC_CODEC_FL32: sum += sampleAt<float>(data, index, 1.0, 0); break;
            case VLC_CODEC_FL64: sum += sampleAt<double>(data, index, 1.0, 0); break;
            case VLC_CODEC_S16N: sum += sampleAt<int16_t>(data, index, 1.0 / 32768.0, 0); break;
            case VLC_CODEC_S32N: sum += sampleAt<int32_t>(data, index, 1.0 / 2147483648.0, 0); break;
            case VLC_CODEC_U8: sum += sampleAt<uint8_t>(data, index, 1.0 / 128.0, 128.0); break;
            default: return;
            }
        }
        mono[i] = static_cast<float>(sum / channels);
    }
    features->push(mono.data(), frames);
    position += static_cast<double>(frames) / featureRate;
}

void RdSyncScanner::Scan::keepCue(Track* track, const block_t* block)
{
    const vlc_tick_t pts = block->i_pts != VLC_TICK_INVALID ? block->i_pts : block->i_dts;
    if (pts == VLC_TICK_INVALID || isEmptyLine(track->fmt.i_codec, block))
        return;
    rdsync::Cue cue;
    cue.startMs = MS_FROM_VLC_TICK(pts - normalTime);
    // a line without a length (some MP4 and Matroska muxers) shows until the next one, at most
    // a few seconds: closed when the next line comes
    cue.endMs = block->i_length > 0 ? cue.startMs + MS_FROM_VLC_TICK(block->i_length) : cue.startMs;
    std::vector<rdsync::Cue>& list = cues[track->fmt.i_id];
    if (!list.empty() && list.back().endMs <= list.back().startMs)
        list.back().endMs = std::min(cue.startMs, list.back().startMs + 4000);
    list.push_back(cue);
}

RdSyncScanner::RdSyncScanner(vlc_object_t* parent, const QByteArray& url, int audioId, bool wantAudio)
    : m_parent(parent)
    , m_url(url)
    , m_audioId(audioId)
    , m_wantAudio(wantAudio)
    , m_interrupt(vlc_interrupt_create())
{
}

RdSyncScanner::~RdSyncScanner()
{
    if (m_interrupt)
        vlc_interrupt_destroy(m_interrupt);
}

void RdSyncScanner::cancel()
{
    m_cancelled.store(true, std::memory_order_relaxed);
    if (m_interrupt)
        vlc_interrupt_kill(m_interrupt);
}

RdSyncScanner::Result RdSyncScanner::run()
{
    Result result;
    if (cancelled())
    {
        result.reason = "cancelled";
        return result;
    }

    vlc_interrupt_t* previous = m_interrupt ? vlc_interrupt_set(m_interrupt) : nullptr;
    const vlc_tick_t start = vlc_tick_now();

    if (vlc_object_t* obj = static_cast<vlc_object_t*>(vlc_object_create(m_parent, sizeof(vlc_object_t))))
    {
        // a background read never asks the user anything (an AVI index is never rebuilt)
        if (var_Create(obj, "avi-index", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avi-index", kAviIndexNeverFix);

        Scan scan(*this);
        scan.obj = obj;
        scan.deadline = start + VLC_TICK_FROM_SEC(kTimeBudgetSeconds);

        ScanEsOut out;
        out.out.cbs = &kEsOutCallbacks;
        out.scan = &scan;

        stream_t* stream = vlc_stream_NewURL(obj, m_url.constData());
        demux_t* demux = stream ? demux_New(obj, "any", m_url.constData(), stream, &out.out) : nullptr;
        if (!demux)
        {
            if (stream)
                vlc_stream_Delete(stream);
            result.reason = "cannot open the file";
        }
        else
        {
            vlc_tick_t normalTime;
            if (demux_Control(demux, DEMUX_GET_NORMAL_TIME, &normalTime) == VLC_SUCCESS)
                scan.normalTime = normalTime;
            int calls = 0;
            while (!scan.stopped())
            {
                const int status = demux_Demux(demux);
                if (status != VLC_DEMUXER_SUCCESS)
                    break;
                if (++calls % kCheckEvery == 0)
                {
                    if (vlc_tick_now() > scan.deadline)
                        scan.overBudget = true;
                    double position = 0;
                    if (demux_Control(demux, DEMUX_GET_POSITION, &position) == VLC_SUCCESS)
                        m_progress.store(static_cast<float>(std::clamp(position, 0.0, 1.0)),
                                         std::memory_order_relaxed);
                }
            }
            // the demuxer deletes its tracks (es_out del, which drains the audio) and the stream
            demux_Delete(demux);
            for (Track* track : scan.tracks)
            {
                scan.closeDecoders(track);
                es_format_Clean(&track->fmt);
                delete track;
            }
            scan.tracks.clear();

            if (cancelled())
                result.reason = "cancelled";
            else if (scan.overBudget)
                result.reason = "over the time budget";
            else if (scan.failed)
                result.reason = "the audio could not be decoded";
            else
            {
                result.ok = true;
                if (scan.features)
                {
                    scan.features->finish();
                    result.speech = rdsync::detectSpeech(scan.features->bandDb(), scan.features->totalDb());
                }
                for (auto& [id, list] : scan.cues)
                {
                    std::sort(list.begin(), list.end(),
                              [](const rdsync::Cue& a, const rdsync::Cue& b) { return a.startMs < b.startMs; });
                    if (!list.empty() && list.back().endMs <= list.back().startMs)
                        list.back().endMs = list.back().startMs + 2000;
                }
                result.cues = std::move(scan.cues);
            }
        }

        msg_Dbg(m_parent, "subtitle sync read: %s in %lld ms, speech frames %zu, text tracks %zu",
                result.ok ? "done" : result.reason,
                static_cast<long long>(MS_FROM_VLC_TICK(vlc_tick_now() - start)),
                result.speech.size(), result.cues.size());
        vlc_object_delete(obj);
    }
    else
        result.reason = "out of memory";

    if (m_interrupt)
        vlc_interrupt_set(previous);
    m_progress.store(1.f, std::memory_order_relaxed);
    return result;
}
