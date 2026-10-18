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

#include "rd_waveform_scanner.hpp"

#include <vlc_aout.h>
#include <vlc_block.h>
#include <vlc_codec.h>
#include <vlc_demux.h>
#include <vlc_es_out.h>
#include <vlc_stream.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <new>
#include <vector>

namespace {

// sampled scan: the audio measured in each slice, and a bound on the packets demuxed to
// reach it (a video packet comes between audio packets; a broken file must not read forever)
constexpr double kSampleSeconds = 0.25;
constexpr int kSampleMaxPackets = 4000;
// sampled scan: audio this far before the slice comes from a seek that landed early (MP4 aligns
// every track to the video keyframe before the time, about 4 s on average with x264's default
// keyframe interval) and is skipped; audio further away has timestamps that do not follow the
// duration (MPEG-TS) and is taken as it comes
constexpr double kMaxPrerollSeconds = 30.0;
// sampled scan: the audio decoded before a stretch so the decoder's output is settled when the
// stretch starts (AAC overlap and priming, the MP3 bit reservoir, Opus pre-roll); an audio packet
// that ends earlier than this before the stretch is dropped before the packetizer, undecoded
constexpr double kWarmupSeconds = 0.2;
// sampled scan: a stretch whose audio ends at most this far past the next stretch's start was
// measured where it lies, so the next stretch is read on from there instead of seeked to
constexpr double kOnTimeSeconds = 0.05;
// sampled scan: how long an audio packet without a length may be, for the drop above
constexpr double kUnknownLengthSeconds = 1.0;
// a file that has shown no audio track after this many packets has none (a video-only file
// is not read to its end for nothing)
constexpr int kNoAudioPackets = 2000;
// the AVI demuxer's "avi-index" choice "Never fix" (0 asks the user)
constexpr int64_t kAviIndexNeverFix = 2;

struct Track
{
    es_format_t fmt;
    decoder_t* packetizer = nullptr;
    decoder_t* decoder = nullptr;
};

} // namespace

struct RdWaveformScanner::Scan
{
    explicit Scan(const RdWaveformScanner& scanner);

    QByteArray execute();
    // false: it stopped for the sampled scan (a video track in a file over kFullScanMaxBytes)
    bool scanFull(demux_t* demux, bool smallFile);
    void scanSampled(demux_t* demux);

    // sampled scan
    double stretchStart(int bin) const;
    void beginStretch(int bin, bool readOnTo);
    bool readOn() const;
    bool keepPacket(block_t* block);

    // es_out
    es_out_id_t* addTrack(const es_format_t* fmt);
    void sendBlock(Track* track, block_t* block);
    void deleteTrack(Track* track);
    int control(int query, va_list args);

    // decoders of the audio track
    bool openDecoders(Track* track);
    void closeDecoders(Track* track);
    decoder_t* loadDecoder(bool packetizer, const es_format_t* fmt);
    void process(Track* track, block_t* block);
    void flush(Track* track);

    // decoded audio
    void consume(const audio_format_t& fmt, const block_t* frame);
    void accumulate(int bin, const audio_format_t& fmt, const uint8_t* data, size_t frames);
    QByteArray result() const;

    // the scan ends: a failure, a cancel, or the time budget spent
    bool stopped()
    {
        if (!failed && !overBudget && vlc_tick_now() >= deadline)
            overBudget = true;
        return failed || overBudget || scanner.cancelled();
    }

    const RdWaveformScanner& scanner;
    vlc_object_t* obj = nullptr;
    // the end of the time budget (RdWaveformScanner::kTimeBudgetSeconds), and whether it came
    vlc_tick_t deadline = VLC_TICK_MAX;
    bool overBudget = false;

    std::vector<Track*> tracks;
    // the measured track: the first audio track whose decoder could be loaded
    Track* audio = nullptr;
    // a decoder could not be (re)loaded or gave an unusable format: the scan gives up
    bool failed = false;
    // the levels are made: the demuxer's closing deletes its tracks without a drain
    bool finished = false;
    // the file has a video track (a cover picture does not count): a full scan would read it
    bool hasVideo = false;

    double lengthSeconds = 0;
    std::vector<double> sumSquares;
    std::vector<double> counts;

    // full scan: the time of the next decoded sample (seconds)
    bool positionKnown = false;
    double position = 0;

    // how the file was read, for the log
    const char* mode = "not opened";

    // sampled scan: the slice length and the stretch measured in each slice (seconds)
    bool sampled = false;
    double slice = 0;
    double sampleSeconds = 0;
    // the slice being sampled (-1 or kBins: none), where its stretch starts (seconds), the audio
    // still wanted for it, whether the audio decoded now is measured for it (false: the scan
    // seeks to it first) and whether part of it was taken as it came (not where it lies)
    int targetBin = -1;
    double sampleStart = 0;
    double sampleLeft = 0;
    bool armed = false;
    bool stretchAsItComes = false;
    // the packets before the packetizer: the last timestamped one was dropped (the ones without
    // a timestamp after it follow it), some were dropped since the last one decoded
    bool dropping = false;
    bool dropped = false;
    // where the demuxer's audio is (the end of its last timestamped packet, seconds)
    bool readKnown = false;
    double readEnd = 0;
    // how far before its target the audio starts after a seek, on average (seconds)
    bool leadPending = false;
    double leadSum = 0;
    int leadCount = 0;
    // for the log
    int seeks = 0;
    int audioPackets = 0;
    int droppedPackets = 0;
};

namespace {

// the es_out the demuxer writes to; C layout, so the demuxer's es_out_t* leads back to the scan
struct ScanEsOut
{
    es_out_t out;
    RdWaveformScanner::Scan* scan;
};

RdWaveformScanner::Scan* scanOf(es_out_t* out)
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
    RdWaveformScanner::Scan* scan;
};

DecoderOwner* ownerOf(decoder_t* dec)
{
    return reinterpret_cast<DecoderOwner*>(dec);
}

// the formats the loudness is read from (what VLC's audio decoders output)
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

// a still picture shown as a video track (cover art, chapter images of an audio file)
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

// what the core does for an audio output, without one: a passthrough decoder (S/PDIF) is
// refused, so VLC loads the next decoder, one that outputs samples
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

// the sum of the squared samples of `frames` interleaved frames
template<typename T>
double sumOfSquares(const uint8_t* data, size_t samples, double scale, double offset)
{
    T value;
    double sum = 0;
    for (size_t i = 0; i < samples; ++i)
    {
        memcpy(&value, data + i * sizeof(T), sizeof(T));
        const double v = (static_cast<double>(value) - offset) * scale;
        sum += v * v;
    }
    return sum;
}

} // namespace

RdWaveformScanner::Scan::Scan(const RdWaveformScanner& scanner)
    : scanner(scanner)
{
}

es_out_id_t* RdWaveformScanner::Scan::addTrack(const es_format_t* fmt)
{
    auto* track = new (std::nothrow) Track;
    if (!track)
        return nullptr;
    es_format_Copy(&track->fmt, fmt);
    tracks.push_back(track);

    if (fmt->i_cat == VIDEO_ES && !isPicture(fmt->i_codec))
        hasVideo = true;
    if (!audio && fmt->i_cat == AUDIO_ES && openDecoders(track))
        audio = track;
    return reinterpret_cast<es_out_id_t*>(track);
}

void RdWaveformScanner::Scan::sendBlock(Track* track, block_t* block)
{
    // a packet the sampled scan does not decode never reaches the packetizer, so it is still
    // ours to release
    if (track == audio && !stopped() && (!sampled || keepPacket(block)))
        process(track, block);
    else
        block_Release(block);
}

void RdWaveformScanner::Scan::deleteTrack(Track* track)
{
    const auto it = std::find(tracks.begin(), tracks.end(), track);
    if (it == tracks.end())
        return;
    tracks.erase(it);
    if (track == audio)
    {
        // the rest of its audio was demuxed: let the decoder give out what it holds
        if (!finished && !stopped())
            process(track, nullptr);
        audio = nullptr;
    }
    closeDecoders(track);
    es_format_Clean(&track->fmt);
    delete track;
}

int RdWaveformScanner::Scan::control(int query, va_list args)
{
    switch (query)
    {
    case ES_OUT_GET_ES_STATE:
    {
        // only the measured track is selected: demuxers skip reading the others where they can
        es_out_id_t* id = va_arg(args, es_out_id_t*);
        bool* selected = va_arg(args, bool*);
        *selected = audio && trackOf(id) == audio;
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

decoder_t* RdWaveformScanner::Scan::loadDecoder(bool packetizer, const es_format_t* fmt)
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

bool RdWaveformScanner::Scan::openDecoders(Track* track)
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

void RdWaveformScanner::Scan::closeDecoders(Track* track)
{
    destroyDecoder(track->decoder);
    destroyDecoder(track->packetizer);
    track->decoder = nullptr;
    track->packetizer = nullptr;
}

// the input core's decoder loop without the clock: packetize, reload the decoder on a format
// change, decode (`block` null: drain)
void RdWaveformScanner::Scan::process(Track* track, block_t* block)
{
    decoder_t* packetizer = track->packetizer;
    if (!packetizer || !track->decoder)
    {
        if (block)
            block_Release(block);
        return;
    }

    // the packetizer owns `block` from here, whatever it returns: a bytestream packetizer
    // (MPEG audio, AAC, FLAC ...) keeps it in its queue and leaves `*blockRef` pointing at it,
    // so it is never released here (as in the input core). The loop always runs until the
    // packetizer has nothing more for this block; once the scan stops, its packets are dropped
    // instead of decoded.
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

void RdWaveformScanner::Scan::flush(Track* track)
{
    if (track->packetizer && track->packetizer->pf_flush)
        track->packetizer->pf_flush(track->packetizer);
    if (track->decoder && track->decoder->pf_flush)
        track->decoder->pf_flush(track->decoder);
}

void RdWaveformScanner::Scan::consume(const audio_format_t& fmt, const block_t* frame)
{
    if (stopped() || fmt.i_rate == 0 || fmt.i_bytes_per_frame == 0 || fmt.i_frame_length == 0)
        return;

    const size_t bytesPerFrame = fmt.i_bytes_per_frame / fmt.i_frame_length;
    if (bytesPerFrame == 0)
        return;
    const size_t frames = std::min<size_t>(frame->i_nb_samples, frame->i_buffer / bytesPerFrame);
    const double rate = fmt.i_rate;

    if (sampled)
    {
        // the time of the frame's next sample; a frame without a timestamp is taken as it comes
        const bool timed = frame->i_pts != VLC_TICK_INVALID;
        double time = timed ? secf_from_vlc_tick(frame->i_pts - VLC_TICK_0) : 0;
        size_t done = 0;
        while (armed && done < frames)
        {
            // the audio before the stretch is not the slice's (a seek that landed on an earlier
            // keyframe, the decoder's warm-up): skipped, so neighbouring slices do not measure
            // the same audio
            if (!timed || sampleStart - time > kMaxPrerollSeconds)
                stretchAsItComes = true;
            else if (sampleStart > time)
            {
                const size_t skip = std::min(frames - done,
                                             static_cast<size_t>((sampleStart - time) * rate));
                done += skip;
                time += static_cast<double>(skip) / rate;
                if (done >= frames)
                    return;
            }

            const size_t used = std::min(frames - done,
                                         static_cast<size_t>(std::ceil(sampleLeft * rate)));
            accumulate(targetBin, fmt, frame->p_buffer + done * bytesPerFrame, used);
            sampleLeft -= static_cast<double>(used) / rate;
            done += used;
            time += static_cast<double>(used) / rate;
            if (sampleLeft > 0)
                return;

            // the stretch is complete. When it was measured where it lies and the next one
            // starts no earlier than where it ends and within kMaxPrerollSeconds of it (audio
            // further away would be taken as it comes: slices over 30 s, files over about 8 h),
            // the next one follows from the audio decoded from here on (the rest of this frame
            // included); else the scan seeks to it
            const int next = targetBin + 1;
            const double gap = stretchStart(next) - time;
            beginStretch(next, !stretchAsItComes && gap >= -kOnTimeSeconds
                                   && gap <= kMaxPrerollSeconds);
        }
        return;
    }

    // the first decoded audio starts where its timestamp says (audio that begins after the
    // video); from there the samples are counted, so timestamp gaps do not move the slices
    if (!positionKnown)
    {
        positionKnown = true;
        if (frame->i_pts != VLC_TICK_INVALID && frame->i_pts > VLC_TICK_0)
            position = std::min(secf_from_vlc_tick(frame->i_pts - VLC_TICK_0), lengthSeconds);
    }

    const double binsPerSecond = kBins / lengthSeconds;
    size_t done = 0;
    while (done < frames)
    {
        const int bin = static_cast<int>(std::min<double>(kBins - 1, position * binsPerSecond));
        size_t run = frames - done;
        if (bin < kBins - 1)
        {
            const double untilNext = (bin + 1) / binsPerSecond - position;
            run = std::min(run, std::max<size_t>(1, static_cast<size_t>(std::ceil(untilNext * rate))));
        }
        accumulate(bin, fmt, frame->p_buffer + done * bytesPerFrame, run);
        position += static_cast<double>(run) / rate;
        done += run;
    }
}

void RdWaveformScanner::Scan::accumulate(int bin, const audio_format_t& fmt, const uint8_t* data,
                                         size_t frames)
{
    const size_t samples = frames * fmt.i_channels;
    double sum = 0;
    switch (fmt.i_format)
    {
    case VLC_CODEC_FL32:
        sum = sumOfSquares<float>(data, samples, 1.0, 0);
        break;
    case VLC_CODEC_FL64:
        sum = sumOfSquares<double>(data, samples, 1.0, 0);
        break;
    case VLC_CODEC_S16N:
        sum = sumOfSquares<int16_t>(data, samples, 1.0 / 32768.0, 0);
        break;
    case VLC_CODEC_S32N:
        sum = sumOfSquares<int32_t>(data, samples, 1.0 / 2147483648.0, 0);
        break;
    case VLC_CODEC_U8:
        sum = sumOfSquares<uint8_t>(data, samples, 1.0 / 128.0, 128.0);
        break;
    default:
        return;
    }
    sumSquares[bin] += sum;
    counts[bin] += static_cast<double>(samples);
}

QByteArray RdWaveformScanner::Scan::result() const
{
    std::vector<double> rms(kBins, -1.0);
    double loudest = 0;
    bool any = false;
    for (int i = 0; i < kBins; ++i)
    {
        if (counts[i] <= 0)
            continue;
        rms[i] = std::sqrt(sumSquares[i] / counts[i]);
        loudest = std::max(loudest, rms[i]);
        any = true;
    }
    if (!any)
        return {};

    // slices no audio reached (a sample that failed, a duration longer than the audio) take
    // the nearest measured slice before them, or after them at the start
    double last = -1.0;
    for (int i = 0; i < kBins; ++i)
    {
        if (rms[i] >= 0)
            last = rms[i];
        else if (last >= 0)
            rms[i] = last;
    }
    for (int i = kBins - 1; i >= 0; --i)
    {
        if (rms[i] >= 0)
            last = rms[i];
        else
            rms[i] = last;
    }

    QByteArray levels(kBins, '\0');
    for (int i = 0; i < kBins; ++i)
    {
        const long value = loudest > 0 ? std::lround(rms[i] / loudest * 255.0) : 0;
        levels[i] = static_cast<char>(std::clamp(value, 0L, 255L));
    }
    return levels;
}

bool RdWaveformScanner::Scan::scanFull(demux_t* demux, bool smallFile)
{
    for (int packet = 0; !stopped() && demux_Demux(demux) == VLC_DEMUXER_SUCCESS; ++packet)
    {
        if (!audio && packet >= kNoAudioPackets)
            break;
        // a demuxer that announces its tracks while reading (MPEG-PS) showed video in a file
        // too large to read through
        if (hasVideo && !smallFile)
            return false;
    }
    if (audio && !stopped())
        process(audio, nullptr);
    return true;
}

// a stretch centered in its slice
double RdWaveformScanner::Scan::stretchStart(int bin) const
{
    return std::max(0.0, (bin + 0.5) * slice - sampleSeconds / 2);
}

// `readOnTo`: the audio decoded from here on is measured for `bin` (its stretch follows the one
// just measured); false: the scan seeks to it first, and the audio until then is dropped
void RdWaveformScanner::Scan::beginStretch(int bin, bool readOnTo)
{
    targetBin = bin;
    armed = readOnTo && bin < kBins;
    sampleStart = stretchStart(bin);
    sampleLeft = sampleSeconds;
    stretchAsItComes = false;
}

// whether the next stretch is reached by reading on rather than by a seek: the demuxer's audio
// is no further before it than a seek would land before it (about half a keyframe interval for
// MP4, as far as the audio read last for MKV without audio cues), or than the warm-up
bool RdWaveformScanner::Scan::readOn() const
{
    if (!armed || !readKnown)
        return false;
    const double lead = leadCount > 0 ? leadSum / leadCount : 0.0;
    return sampleStart - readEnd <= std::max(kWarmupSeconds, lead);
}

// sampled scan: whether an audio packet goes to the packetizer. Dropped undecoded: a packet
// that ends more than kWarmupSeconds before the stretch (the audio from the keyframe an MP4 seek
// lands on, or between two stretches read on), and every packet while the scan is about to seek.
// Audio further before the stretch than kMaxPrerollSeconds is decoded and taken as it comes, as
// consume() does.
bool RdWaveformScanner::Scan::keepPacket(block_t* block)
{
    ++audioPackets;
    const vlc_tick_t ts = block->i_pts != VLC_TICK_INVALID ? block->i_pts : block->i_dts;
    if (ts != VLC_TICK_INVALID)
    {
        const double begin = secf_from_vlc_tick(ts - VLC_TICK_0);
        const double early = sampleStart - begin;
        // a packet without a length (MKV SimpleBlock, PES, AVI chunk) may be long: it is
        // dropped only when it starts kUnknownLengthSeconds earlier
        const double end = begin + (block->i_length > 0 ? secf_from_vlc_tick(block->i_length)
                                                        : kUnknownLengthSeconds);
        readEnd = begin + secf_from_vlc_tick(std::max<vlc_tick_t>(block->i_length, 0));
        readKnown = true;
        if (leadPending)
        {
            leadPending = false;
            if (early <= kMaxPrerollSeconds)
            {
                leadSum += std::max(0.0, early);
                ++leadCount;
            }
        }
        dropping = early <= kMaxPrerollSeconds && end < sampleStart - kWarmupSeconds;
    }
    if (!armed || dropping)
    {
        dropped = true;
        ++droppedPackets;
        return false;
    }
    // the packetizer and the decoder start over after the gap, as after a seek (the block is
    // still ours here: it reaches the packetizer only after this)
    if (dropped)
    {
        flush(audio);
        dropped = false;
    }
    return true;
}

void RdWaveformScanner::Scan::scanSampled(demux_t* demux)
{
    // never more audio per slice than the slice holds: a short file of a high bitrate (a 30 s
    // 4K clip) decodes at most its own audio, not 0.25 s per 1/1000 of it
    slice = lengthSeconds / kBins;
    sampleSeconds = std::min(kSampleSeconds, slice);
    // the stretches are measured in order; consume() moves on to the next one when a stretch
    // is complete, and the loop seeks only when reading on would cost more (readOn()). A file
    // up to kBins * kSampleSeconds long (stretches that touch) is read once from its start.
    beginStretch(0, false);
    while (targetBin < kBins && !stopped())
    {
        const int bin = targetBin;
        if (!readOn())
        {
            // by time, else by position (demuxers without an index, such as an MPEG-TS
            // recording, seek better by position)
            if (demux_SetTime(demux, vlc_tick_from_sec(sampleStart), false) != VLC_SUCCESS
                && demux_SetPosition(demux, sampleStart / lengthSeconds, false) != VLC_SUCCESS)
            {
                beginStretch(bin + 1, false);
                continue;
            }
            ++seeks;
            if (audio)
                flush(audio);
            // the stretch is measured from the seek on, whatever audio came before it
            beginStretch(bin, true);
            dropping = false;
            dropped = false;
            readKnown = false;
            leadPending = true;
        }
        for (int packet = 0; packet < kSampleMaxPackets && targetBin == bin && !stopped(); ++packet)
        {
            if (demux_Demux(demux) != VLC_DEMUXER_SUCCESS)
                break;
            if (!audio && packet >= kNoAudioPackets)
                break;
        }
        if (!audio)
            break;
        // the stretch was not reached (end of the file, a read error, the packet bound)
        if (targetBin == bin)
            beginStretch(bin + 1, false);
    }
    targetBin = -1;
    armed = false;
}

QByteArray RdWaveformScanner::Scan::execute()
{
    stream_t* stream = vlc_stream_NewURL(obj, scanner.m_url.constData());
    if (!stream)
        return {};

    uint64_t size = 0;
    const bool sizeKnown = vlc_stream_GetSize(stream, &size) == VLC_SUCCESS;

    ScanEsOut esOut { { &kEsOutCallbacks }, this };
    demux_t* demux = demux_New(obj, "any", scanner.m_url.constData(), stream, &esOut.out);
    if (!demux)
    {
        vlc_stream_Delete(stream);
        return {};
    }

    vlc_tick_t length = 0;
    if (demux_Control(demux, DEMUX_GET_LENGTH, &length) != VLC_SUCCESS || length <= 0)
        length = scanner.m_lengthHint;
    bool canSeek = false;
    if (demux_Control(demux, DEMUX_CAN_SEEK, &canSeek) != VLC_SUCCESS)
        canSeek = false;

    QByteArray levels;
    mode = "no duration";
    if (length > 0)
    {
        lengthSeconds = secf_from_vlc_tick(length);
        sumSquares.assign(kBins, 0.0);
        counts.assign(kBins, 0.0);
        // full or sampled (WAVEFORM_NOTES section 2): a full scan reads the whole file, video
        // included, so it is only for small files and for files without video (music) up to
        // kAudioFullScanMaxBytes; the tracks the demuxer announced while opening tell which
        const bool smallFile = !sizeKnown || size <= kFullScanMaxBytes;
        bool full = smallFile || (size <= kAudioFullScanMaxBytes && !hasVideo);
        bool videoFound = false;
        mode = "full";
        if (full && !scanFull(demux, smallFile))
        {
            // the demuxer announced a video track while reading: start again, sampled
            full = false;
            videoFound = true;
            sumSquares.assign(kBins, 0.0);
            counts.assign(kBins, 0.0);
            positionKnown = false;
            position = 0;
        }
        if (!full)
        {
            // a file to sample that the demuxer cannot seek in is never read from start to
            // end: no waveform
            sampled = canSeek;
            if (videoFound)
                mode = sampled ? "sampled, video found while reading"
                               : "not seekable, video found while reading";
            else
                mode = sampled ? "sampled" : "large, not seekable";
            if (sampled)
                scanSampled(demux);
        }

        if (!stopped())
            levels = result();
    }
    finished = true;

    // the demuxer deletes its tracks (es_out del) and the stream
    demux_Delete(demux);
    for (Track* track : tracks)
    {
        closeDecoders(track);
        es_format_Clean(&track->fmt);
        delete track;
    }
    tracks.clear();
    audio = nullptr;
    return levels;
}

RdWaveformScanner::RdWaveformScanner(vlc_object_t* parent, const QByteArray& url,
                                     vlc_tick_t lengthHint)
    : m_parent(parent)
    , m_url(url)
    , m_lengthHint(lengthHint)
    , m_interrupt(vlc_interrupt_create())
{
}

RdWaveformScanner::~RdWaveformScanner()
{
    if (m_interrupt)
        vlc_interrupt_destroy(m_interrupt);
}

void RdWaveformScanner::cancel()
{
    m_cancelled.store(true, std::memory_order_relaxed);
    if (m_interrupt)
        vlc_interrupt_kill(m_interrupt);
}

QByteArray RdWaveformScanner::run()
{
    if (cancelled())
        return {};

    vlc_interrupt_t* previous = m_interrupt ? vlc_interrupt_set(m_interrupt) : nullptr;

    // the scan's own object: the demuxer and decoders hang from it, apart from the interface
    QByteArray levels;
    if (vlc_object_t* obj = static_cast<vlc_object_t*>(vlc_object_create(m_parent, sizeof(vlc_object_t))))
    {
        // a background scan never asks the user anything: an AVI file with a broken index is
        // read as is (VLC would ask whether to build the index, which reads the whole file)
        if (var_Create(obj, "avi-index", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avi-index", kAviIndexNeverFix);

        const vlc_tick_t start = vlc_tick_now();
        Scan scan(*this);
        scan.obj = obj;
        scan.deadline = start + VLC_TICK_FROM_SEC(kTimeBudgetSeconds);
        levels = scan.execute();
        vlc_object_delete(obj);

        // the measurements of the PC tests read this line (WAVEFORM_NOTES section 8)
        msg_Dbg(m_parent, "waveform scan (%s): %s in %lld ms", scan.mode,
                cancelled() ? "cancelled"
                : scan.overBudget ? "no waveform, over the time budget"
                : levels.isEmpty() ? "no waveform" : "levels",
                static_cast<long long>(MS_FROM_VLC_TICK(vlc_tick_now() - start)));
        if (scan.sampled)
            msg_Dbg(m_parent, "waveform sampling: seeks %d, audio packets dropped before the "
                    "decoder %d of %d", scan.seeks, scan.droppedPackets, scan.audioPackets);
    }

    if (m_interrupt)
        vlc_interrupt_set(previous);
    return cancelled() ? QByteArray() : levels;
}
