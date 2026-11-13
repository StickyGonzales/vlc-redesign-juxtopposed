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

#include "rd_credits_scanner.hpp"

#include <QString>

#include <vlc_aout.h>
#include <vlc_block.h>
#include <vlc_codec.h>
#include <vlc_demux.h>
#include <vlc_es_out.h>
#include <vlc_picture.h>
#include <vlc_stream.h>

#include <algorithm>
#include <cstring>
#include <new>

#include "player/rd_credits_audio.hpp"

namespace {

// the AVI demuxer's "avi-index" choice "Never fix" (0 asks the user)
constexpr int64_t kAviIndexNeverFix = 2;
// the avcodec decoder's "avcodec-skip-frame" / "avcodec-skiploopfilter" values (video.c)
constexpr int64_t kSkipNonKey = 3;
constexpr int64_t kSkipAll = 4;
// the picture is sampled this often, on a grid this coarse (a few small samples a second)
constexpr qint64 kFrameStepMs = 250;
constexpr int kGridColumns = 48;
constexpr int kGridRows = 27;
// a sample this dark (8-bit luma, limited range black is 16) is black
constexpr int kDarkLuma = 40;
// the read stops this far past the end of the stretch (the decoders' last frames are out)
constexpr qint64 kPastEndMs = 1000;
// a file with no audio track the scan can decode after this many packets is given up
constexpr int kNoAudioPackets = 500;

struct Track
{
    es_format_t fmt;
    decoder_t* packetizer = nullptr;
    decoder_t* decoder = nullptr;
    bool text = false;
};

bool isTextSubtitle(vlc_fourcc_t codec)
{
    return codec == VLC_CODEC_SUBT || codec == VLC_CODEC_SSA || codec == VLC_CODEC_TX3G;
}

bool isPicture(vlc_fourcc_t codec)
{
    switch (codec)
    {
    case VLC_CODEC_JPEG:
    case VLC_CODEC_PNG:
    case VLC_CODEC_BMP:
    case VLC_CODEC_GIF:
    case VLC_CODEC_WEBP:
        return true;
    default:
        return false;
    }
}

bool supportedAudio(vlc_fourcc_t format)
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
    return float((double(value) - offset) * scale);
}

} // namespace

struct RdCreditsScanner::Scan
{
    explicit Scan(RdCreditsScanner& scanner) : scanner(scanner) {}

    es_out_id_t* addTrack(const es_format_t* fmt);
    void sendBlock(Track* track, block_t* block);
    void deleteTrack(Track* track);
    int control(int query, va_list args);

    decoder_t* loadDecoder(bool packetizer, const es_format_t* fmt);
    bool openDecoders(Track* track);
    void closeDecoders(Track* track);
    void process(Track* track, block_t* block);
    void chooseTracks();
    void consumeAudio(const audio_format_t& fmt, const block_t* frame);
    void consumePicture(picture_t* picture);
    void keepLine(const block_t* block);
    // a decoder could not be (re)loaded or failed: without video the scan goes on (no black
    // frames), without audio it stops
    void trackFailed(Track* track);

    bool stopped() const { return scanner.cancelled() || overBudget || failed; }
    qint64 msOf(vlc_tick_t tick) const { return MS_FROM_VLC_TICK(tick - normalTime); }

    RdCreditsScanner& scanner;
    vlc_object_t* obj = nullptr;
    std::vector<Track*> tracks;
    Track* audio = nullptr;
    Track* video = nullptr;
    Track* text = nullptr;
    bool planned = false;
    Plan plan;
    vlc_tick_t normalTime = VLC_TICK_0;

    std::unique_ptr<rdcredits::AudioPrinter> printer;
    std::vector<float> mono;
    qint64 audioNextMs = -1;
    qint64 nextFrameMs = -1;
    // the latest time the demuxer reached (any track), to know when the stretch is read
    qint64 reachedMs = -1;

    QVector<rdcredits::FrameSample> frames;
    QVector<rdcredits::Line> lines;
    bool overBudget = false;
    bool failed = false;
    bool videoFailed = false;
    unsigned printerRate = 0;
    int packets = 0;
};

namespace {

struct ScanEsOut
{
    es_out_t out;
    RdCreditsScanner::Scan* scan;
};

RdCreditsScanner::Scan* scanOf(es_out_t* out)
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

struct DecoderOwner
{
    decoder_t dec;
    es_format_t fmtIn;
    RdCreditsScanner::Scan* scan;
};

DecoderOwner* ownerOf(decoder_t* dec)
{
    return reinterpret_cast<DecoderOwner*>(dec);
}

int AudioFormatUpdate(decoder_t* dec)
{
    audio_format_t& audio = dec->fmt_out.audio;
    audio.i_format = dec->fmt_out.i_codec;
    if (!supportedAudio(audio.i_format) || audio.i_rate == 0)
        return -1;
    if (audio.i_physical_channels == 0 && audio.i_channels > 0 && audio.i_channels < ARRAY_SIZE(vlc_chan_maps))
        audio.i_physical_channels = vlc_chan_maps[audio.i_channels];
    aout_FormatPrepare(&audio);
    if (audio.i_channels == 0 || audio.i_bytes_per_frame == 0 || audio.i_frame_length == 0)
        return -1;
    return 0;
}

void AudioQueue(decoder_t* dec, vlc_frame_t* frame)
{
    ownerOf(dec)->scan->consumeAudio(dec->fmt_out.audio, frame);
    block_Release(frame);
}

vlc_decoder_device* VideoGetDevice(decoder_t*)
{
    // no hardware decoding: the scan decodes in software, apart from playback
    return nullptr;
}

int VideoFormatUpdate(decoder_t* dec, vlc_video_context*)
{
    // the pictures stay in the decoder's own format; only their luma is read
    dec->fmt_out.video.i_chroma = dec->fmt_out.i_codec;
    return 0;
}

picture_t* VideoBufferNew(decoder_t* dec)
{
    return picture_NewFromFormat(&dec->fmt_out.video);
}

void VideoQueue(decoder_t* dec, picture_t* picture)
{
    ownerOf(dec)->scan->consumePicture(picture);
    picture_Release(picture);
}

decoder_owner_callbacks makeDecoderCallbacks(bool video)
{
    decoder_owner_callbacks cbs {};
    if (video)
    {
        cbs.video.get_device = VideoGetDevice;
        cbs.video.format_update = VideoFormatUpdate;
        cbs.video.buffer_new = VideoBufferNew;
        cbs.video.queue = VideoQueue;
    }
    else
    {
        cbs.audio.format_update = AudioFormatUpdate;
        cbs.audio.queue = AudioQueue;
    }
    cbs.get_attachments = nullptr;
    return cbs;
}

const decoder_owner_callbacks kAudioCallbacks = makeDecoderCallbacks(false);
const decoder_owner_callbacks kVideoCallbacks = makeDecoderCallbacks(true);

void destroyDecoder(decoder_t* dec)
{
    if (!dec)
        return;
    decoder_Clean(dec);
    es_format_Clean(&ownerOf(dec)->fmtIn);
    vlc_object_delete(dec);
}

} // namespace

es_out_id_t* RdCreditsScanner::Scan::addTrack(const es_format_t* fmt)
{
    auto* track = new (std::nothrow) Track;
    if (!track)
        return nullptr;
    es_format_Copy(&track->fmt, fmt);
    tracks.push_back(track);
    if (planned)
        chooseTracks();
    return reinterpret_cast<es_out_id_t*>(track);
}

// the first audio track, the first video track (not a cover picture) when the picture is
// sampled, the first text subtitle track when the subtitles are read
void RdCreditsScanner::Scan::chooseTracks()
{
    for (Track* track : tracks)
    {
        const es_format_t& fmt = track->fmt;
        if (!audio && fmt.i_cat == AUDIO_ES && openDecoders(track))
            audio = track;
        else if (plan.frames && !video && fmt.i_cat == VIDEO_ES && !isPicture(fmt.i_codec) && openDecoders(track))
            video = track;
        else if (plan.subtitles && !text && fmt.i_cat == SPU_ES && isTextSubtitle(fmt.i_codec))
        {
            track->text = true;
            text = track;
        }
    }
}

void RdCreditsScanner::Scan::sendBlock(Track* track, block_t* block)
{
    const vlc_tick_t time = block->i_pts != VLC_TICK_INVALID ? block->i_pts : block->i_dts;
    if (time != VLC_TICK_INVALID)
        reachedMs = std::max(reachedMs, msOf(time));
    ++packets;
    if (stopped() || !planned)
    {
        block_Release(block);
        return;
    }
    if (track == text)
    {
        keepLine(block);
        block_Release(block);
    }
    else if (track == audio || track == video)
        process(track, block);
    else
        block_Release(block);
}

void RdCreditsScanner::Scan::deleteTrack(Track* track)
{
    const auto it = std::find(tracks.begin(), tracks.end(), track);
    if (it == tracks.end())
        return;
    tracks.erase(it);
    if (track == audio || track == video)
    {
        if (!stopped())
            process(track, nullptr);
    }
    if (track == audio)
        audio = nullptr;
    if (track == video)
        video = nullptr;
    if (track == text)
        text = nullptr;
    closeDecoders(track);
    es_format_Clean(&track->fmt);
    delete track;
}

int RdCreditsScanner::Scan::control(int query, va_list args)
{
    switch (query)
    {
    case ES_OUT_GET_ES_STATE:
    {
        // only what is read is selected: demuxers skip the rest where they can
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        bool* selected = va_arg(args, bool*);
        *selected = track && (track == audio || track == video || track == text);
        return VLC_SUCCESS;
    }
    case ES_OUT_IS_EMPTY:
        *va_arg(args, bool*) = true;
        return VLC_SUCCESS;
    case ES_OUT_RESTART_ES:
    {
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        if (track && (track == audio || track == video))
        {
            closeDecoders(track);
            if (!openDecoders(track))
                trackFailed(track);
        }
        return VLC_SUCCESS;
    }
    case ES_OUT_SET_ES_FMT:
    {
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        const es_format_t* fmt = va_arg(args, es_format_t*);
        if (!track || !fmt)
            return VLC_EGENERIC;
        es_format_Clean(&track->fmt);
        es_format_Copy(&track->fmt, fmt);
        if (track == audio || track == video)
        {
            closeDecoders(track);
            if (!openDecoders(track))
                trackFailed(track);
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

decoder_t* RdCreditsScanner::Scan::loadDecoder(bool packetizer, const es_format_t* fmt)
{
    auto* owner = static_cast<DecoderOwner*>(vlc_object_create(obj, sizeof(DecoderOwner)));
    if (!owner)
        return nullptr;
    owner->scan = this;
    decoder_t* dec = &owner->dec;
    decoder_Init(dec, &owner->fmtIn, fmt);
    dec->cbs = fmt->i_cat == VIDEO_ES ? &kVideoCallbacks : &kAudioCallbacks;
    dec->b_frame_drop_allowed = false;
    decoder_LoadModule(dec, packetizer, false);
    if (!dec->p_module)
    {
        destroyDecoder(dec);
        return nullptr;
    }
    return dec;
}

bool RdCreditsScanner::Scan::openDecoders(Track* track)
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

void RdCreditsScanner::Scan::closeDecoders(Track* track)
{
    destroyDecoder(track->decoder);
    destroyDecoder(track->packetizer);
    track->decoder = nullptr;
    track->packetizer = nullptr;
}

// the input core's decoder loop without the clock, as in rd_waveform_scanner.cpp: packetize,
// reload the decoder on a format change, decode (`block` null: drain); the packetizer owns the
// block from here
void RdCreditsScanner::Scan::process(Track* track, block_t* block)
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
        if (stopped() || !track->decoder)
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
                block_ChainRelease(packets);
                trackFailed(track);
                continue;
            }
        }
        while (packets)
        {
            block_t* next = packets->p_next;
            packets->p_next = nullptr;
            if (track->decoder->pf_decode(track->decoder, packets) == VLCDEC_ECRITICAL)
            {
                block_ChainRelease(next);
                trackFailed(track);
                break;
            }
            packets = next;
        }
    }
    if (draining && track->decoder && !stopped())
        track->decoder->pf_decode(track->decoder, nullptr);
}

void RdCreditsScanner::Scan::trackFailed(Track* track)
{
    if (track == audio)
    {
        failed = true;
        return;
    }
    // the decoder goes once the packetizer loop is done with it (process() checks it); the
    // samples taken so far are dropped: black frames need the whole stretch
    videoFailed = true;
    frames.clear();
    if (track->decoder)
    {
        destroyDecoder(track->decoder);
        track->decoder = nullptr;
    }
}

void RdCreditsScanner::Scan::consumeAudio(const audio_format_t& fmt, const block_t* frame)
{
    if (stopped() || frame->i_pts == VLC_TICK_INVALID || fmt.i_rate == 0 || fmt.i_bytes_per_frame == 0
        || fmt.i_frame_length == 0 || fmt.i_channels == 0)
        return;
    const size_t bytesPerFrame = fmt.i_bytes_per_frame / fmt.i_frame_length;
    if (bytesPerFrame == 0)
        return;
    const size_t count = std::min<size_t>(frame->i_nb_samples, frame->i_buffer / bytesPerFrame);
    const qint64 startMs = msOf(frame->i_pts);
    const qint64 endMs = startMs + qint64(count) * 1000 / fmt.i_rate;
    if (endMs <= plan.fromMs || startMs >= plan.toMs)
        return;

    if (!printer)
    {
        printer = std::make_unique<rdcredits::AudioPrinter>(fmt.i_rate);
        printerRate = fmt.i_rate;
        audioNextMs = plan.fromMs;
    }
    // a rate change on the way (a decoder reload) would shift the fingerprint's times
    if (fmt.i_rate != printerRate)
        return;
    // the samples before the stretch are left out; a gap in the audio is filled with silence
    size_t skip = 0;
    if (startMs < plan.fromMs)
        skip = size_t((plan.fromMs - startMs) * fmt.i_rate / 1000);
    if (startMs > audioNextMs + 500)
        printer->skipTo(double(startMs - plan.fromMs) / 1000.0);
    if (skip >= count)
        return;

    const unsigned channels = fmt.i_channels;
    mono.resize(count - skip);
    const uint8_t* data = frame->p_buffer;
    for (size_t i = skip; i < count; ++i)
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
        mono[i - skip] = float(sum / channels);
    }
    printer->push(mono.data(), mono.size());
    audioNextMs = endMs;
}

void RdCreditsScanner::Scan::consumePicture(picture_t* picture)
{
    if (stopped() || videoFailed || picture->date == VLC_TICK_INVALID || picture->i_planes < 1)
        return;
    const qint64 timeMs = msOf(picture->date);
    if (timeMs < plan.fromMs || timeMs >= plan.toMs || (nextFrameMs >= 0 && timeMs < nextFrameMs))
        return;
    nextFrameMs = timeMs + kFrameStepMs;

    // the luma plane of the planar YUV formats VLC's decoders give (8 or 16 bits a sample)
    const plane_t& plane = picture->p[0];
    const int pixel = plane.i_pixel_pitch;
    if ((pixel != 1 && pixel != 2) || plane.i_visible_lines <= 0 || plane.i_visible_pitch <= 0
        || !vlc_fourcc_IsYUV(picture->format.i_chroma))
        return;
    const int width = plane.i_visible_pitch / pixel;
    const int height = plane.i_visible_lines;
    // a 16-bit sample holds 10 bits in VLC's high-depth formats
    const int threshold = pixel == 1 ? kDarkLuma : kDarkLuma << 2;
    int dark = 0;
    for (int row = 0; row < kGridRows; ++row)
    {
        const uint8_t* line = plane.p_pixels + size_t(((2 * row + 1) * height) / (2 * kGridRows)) * size_t(plane.i_pitch);
        for (int column = 0; column < kGridColumns; ++column)
        {
            const int x = ((2 * column + 1) * width) / (2 * kGridColumns);
            int value;
            if (pixel == 1)
                value = line[x];
            else
            {
                uint16_t v;
                memcpy(&v, line + 2 * x, 2);
                value = v;
            }
            dark += value < threshold ? 1 : 0;
        }
    }
    frames.append({ timeMs, float(dark) / float(kGridRows * kGridColumns) });
}

void RdCreditsScanner::Scan::keepLine(const block_t* block)
{
    const vlc_tick_t pts = block->i_pts != VLC_TICK_INVALID ? block->i_pts : block->i_dts;
    if (pts == VLC_TICK_INVALID || block->i_buffer == 0)
        return;
    QByteArray data(reinterpret_cast<const char*>(block->p_buffer), int(block->i_buffer));
    if (text->fmt.i_codec == VLC_CODEC_TX3G)
    {
        // a 16-bit big-endian length, then the text (0: a gap, no line)
        const int size = data.size() >= 2 ? (uchar(data[0]) << 8 | uchar(data[1])) : 0;
        if (size == 0)
            return;
        data = data.mid(2, size);
    }
    const int nul = data.indexOf('\0');
    if (nul >= 0)
        data.truncate(nul);
    QString line = QString::fromUtf8(data);
    if (text->fmt.i_codec == VLC_CODEC_SSA)
        line = rdcredits::assPacketText(line);
    if (rdcredits::plainText(line).isEmpty())
        return;
    rdcredits::Line entry;
    entry.startMs = msOf(pts);
    entry.endMs = entry.startMs + (block->i_length > 0 ? MS_FROM_VLC_TICK(block->i_length) : 0);
    entry.text = line;
    lines.append(entry);
}

RdCreditsScanner::RdCreditsScanner(vlc_object_t* parent, const QByteArray& mrl,
                                   std::shared_ptr<RdBackgroundQueue::Control> control)
    : m_parent(parent)
    , m_mrl(mrl)
    , m_control(std::move(control))
    , m_interrupt(vlc_interrupt_create())
{
}

RdCreditsScanner::~RdCreditsScanner()
{
    if (m_interrupt)
        vlc_interrupt_destroy(m_interrupt);
}

void RdCreditsScanner::cancel()
{
    m_cancelled.store(true, std::memory_order_relaxed);
    if (m_interrupt)
        vlc_interrupt_kill(m_interrupt);
}

RdCreditsScanner::Result RdCreditsScanner::run(const Planner& planner)
{
    Result result;
    if (cancelled())
    {
        result.reason = "cancelled";
        return result;
    }
    vlc_interrupt_t* previous = m_interrupt ? vlc_interrupt_set(m_interrupt) : nullptr;
    const vlc_tick_t start = vlc_tick_now();

    vlc_object_t* obj = static_cast<vlc_object_t*>(vlc_object_create(m_parent, sizeof(vlc_object_t)));
    if (!obj)
    {
        result.reason = "out of memory";
    }
    else
    {
        // a background read never asks anything and decodes in software on one thread; only the
        // key frames are decoded (a few samples a second at most, enough for a stretch of black
        // that lasts), without the loop filter
        if (var_Create(obj, "avi-index", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avi-index", kAviIndexNeverFix);
        if (var_Create(obj, "avcodec-threads", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avcodec-threads", 1);
        if (var_Create(obj, "avcodec-skip-frame", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avcodec-skip-frame", kSkipNonKey);
        if (var_Create(obj, "avcodec-skiploopfilter", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avcodec-skiploopfilter", kSkipAll);
        if (var_Create(obj, "avcodec-hw", VLC_VAR_STRING) == VLC_SUCCESS)
            var_SetString(obj, "avcodec-hw", "none");
        // AV1 goes to dav1d, which decodes every frame: one thread, beside playback
        if (var_Create(obj, "dav1d-thread-frames", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "dav1d-thread-frames", 1);
        if (var_Create(obj, "dav1d-thread-tiles", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "dav1d-thread-tiles", 1);

        Scan scan(*this);
        scan.obj = obj;
        ScanEsOut out;
        out.out.cbs = &kEsOutCallbacks;
        out.scan = &scan;

        stream_t* stream = vlc_stream_NewURL(obj, m_mrl.constData());
        demux_t* demux = stream ? demux_New(obj, "any", m_mrl.constData(), stream, &out.out) : nullptr;
        if (!demux)
        {
            if (stream)
                vlc_stream_Delete(stream);
            result.reason = "cannot open the file";
        }
        else
        {
            vlc_tick_t length = 0;
            if (demux_Control(demux, DEMUX_GET_LENGTH, &length) != VLC_SUCCESS || length <= 0)
                length = 0;
            vlc_tick_t normalTime;
            if (demux_Control(demux, DEMUX_GET_NORMAL_TIME, &normalTime) == VLC_SUCCESS)
                scan.normalTime = normalTime;
            bool canSeek = false;
            if (demux_Control(demux, DEMUX_CAN_SEEK, &canSeek) != VLC_SUCCESS)
                canSeek = false;
            result.lengthMs = MS_FROM_VLC_TICK(length);
            scan.plan = result.lengthMs > 0 && canSeek ? planner(result.lengthMs) : Plan();
            scan.plan.toMs = std::min(scan.plan.toMs, result.lengthMs);
            result.plan = scan.plan;

            if (!scan.plan.read || scan.plan.toMs <= scan.plan.fromMs)
                result.reason = result.lengthMs <= 0 ? "no length" : !canSeek ? "not seekable" : "nothing to read";
            else
            {
                scan.planned = true;
                scan.chooseTracks();
                // the time paused (the seek bar in use) is not counted
                vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(scan.plan.budgetSeconds);
                const vlc_tick_t seekTo = VLC_TICK_0 + VLC_TICK_FROM_MS(scan.plan.fromMs);
                bool seeked = scan.plan.fromMs <= 0
                              || demux_Control(demux, DEMUX_SET_TIME, seekTo, false) == VLC_SUCCESS;
                // a demuxer without a time index may still seek by position
                if (!seeked)
                    seeked = demux_Control(demux, DEMUX_SET_POSITION,
                                           double(scan.plan.fromMs) / double(result.lengthMs), false) == VLC_SUCCESS;
                bool noAudio = false;
                while (seeked && !scan.stopped())
                {
                    // the background queue is paused (the user seeks, a more urgent job): the
                    // read waits, so seek previews stay fast; the time waited is not counted
                    if (m_control && m_control->paused())
                    {
                        const vlc_tick_t pausedAt = vlc_tick_now();
                        m_control->waitWhilePaused([this]() { return cancelled(); });
                        deadline += vlc_tick_now() - pausedAt;
                    }
                    if (cancelled())
                        break;
                    if (vlc_tick_now() > deadline)
                    {
                        scan.overBudget = true;
                        break;
                    }
                    if (demux_Demux(demux) != VLC_DEMUXER_SUCCESS)
                        break;
                    if (scan.reachedMs >= scan.plan.toMs + kPastEndMs)
                        break;
                    if (!scan.audio && scan.packets >= kNoAudioPackets)
                    {
                        noAudio = true;
                        break;
                    }
                }
                if (!seeked)
                    result.reason = "cannot seek";
                else if (noAudio || !scan.audio)
                    result.reason = "no audio";
            }
            // the demuxer deletes its tracks (es_out del, which drains the decoders)
            demux_Delete(demux);
            for (Track* track : scan.tracks)
            {
                scan.closeDecoders(track);
                es_format_Clean(&track->fmt);
                delete track;
            }
            scan.tracks.clear();

            // a cancel, the time budget or a failing decoder may not happen next time: the
            // manager does not keep these
            if (cancelled())
            {
                result.reason = "cancelled";
                result.transient = true;
            }
            else if (scan.overBudget)
            {
                result.reason = "over the time budget";
                result.transient = true;
            }
            else if (scan.failed)
            {
                result.reason = "the audio decoder failed";
                result.transient = true;
            }
            else if (scan.planned && scan.printer && *result.reason == '\0')
            {
                result.ok = true;
                result.prints = scan.printer->prints();
                result.frames = std::move(scan.frames);
                result.lines = std::move(scan.lines);
            }
        }
        msg_Dbg(m_parent, "up next: credits scan of %lld..%lld ms: %s in %lld ms (%zu prints, %lld frames, %lld lines)",
                static_cast<long long>(result.plan.fromMs), static_cast<long long>(result.plan.toMs),
                result.ok ? "done" : result.reason, static_cast<long long>(MS_FROM_VLC_TICK(vlc_tick_now() - start)),
                result.prints.size(), static_cast<long long>(result.frames.size()),
                static_cast<long long>(result.lines.size()));
        vlc_object_delete(obj);
    }
    if (m_interrupt)
        vlc_interrupt_set(previous);
    return result;
}
