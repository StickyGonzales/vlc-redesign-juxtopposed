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

#include "rd_credits_subtitles.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStringDecoder>

#include <vlc_block.h>
#include <vlc_demux.h>
#include <vlc_es_out.h>
#include <vlc_stream.h>

#include <algorithm>
#include <new>

namespace {

// a subtitle file larger than this is not a subtitle file
constexpr qint64 kMaxFileBytes = 16 * 1024 * 1024;
// the demuxer seeks a little before the window: a line that starts there may end inside it
constexpr qint64 kSeekMarginMs = 10 * 1000;

bool isTextCodec(vlc_fourcc_t codec)
{
    return codec == VLC_CODEC_SUBT || codec == VLC_CODEC_SSA || codec == VLC_CODEC_TX3G;
}

QString decodeText(const QByteArray& data)
{
    // a BOM tells UTF-16 / UTF-32; anything else is read as UTF-8 (the timings are ASCII)
    const std::optional<QStringConverter::Encoding> bom = QStringConverter::encodingForData(data);
    QStringDecoder decoder(bom.value_or(QStringConverter::Utf8));
    return decoder.decode(data);
}

// the scan of the embedded track: what the demuxer writes goes here
struct EmbeddedScan
{
    es_out_t out;
    // the first text track and its codec
    es_out_id_t* text = nullptr;
    vlc_fourcc_t codec = 0;
    // the tracks the demuxer announced (their ids are these counters' addresses)
    std::vector<int*> ids;
    QVector<rdcredits::Line> lines;
    qint64 lengthMs = 0;
    // the window's lines are read: the demuxer may stop
    bool past = false;
};

EmbeddedScan* scanOf(es_out_t* out)
{
    return reinterpret_cast<EmbeddedScan*>(out);
}

es_out_id_t* EsOutAdd(es_out_t* out, input_source_t*, const es_format_t* fmt)
{
    EmbeddedScan* scan = scanOf(out);
    int* id = new (std::nothrow) int(0);
    if (!id)
        return nullptr;
    scan->ids.push_back(id);
    es_out_id_t* esId = reinterpret_cast<es_out_id_t*>(id);
    if (!scan->text && fmt->i_cat == SPU_ES && isTextCodec(fmt->i_codec))
    {
        scan->text = esId;
        scan->codec = fmt->i_codec;
    }
    return esId;
}

int EsOutSend(es_out_t* out, es_out_id_t* id, block_t* block)
{
    EmbeddedScan* scan = scanOf(out);
    if (id == scan->text && block->i_buffer > 0)
    {
        const vlc_tick_t pts = block->i_pts != VLC_TICK_INVALID ? block->i_pts : block->i_dts;
        if (pts != VLC_TICK_INVALID)
        {
            QByteArray data(reinterpret_cast<const char*>(block->p_buffer), int(block->i_buffer));
            if (scan->codec == VLC_CODEC_TX3G)
            {
                // a 16-bit big-endian length, then the text
                const int size = data.size() >= 2 ? (uchar(data[0]) << 8 | uchar(data[1])) : 0;
                data = data.mid(2, size);
            }
            const int nul = data.indexOf('\0');
            if (nul >= 0)
                data.truncate(nul);
            QString text = QString::fromUtf8(data);
            if (scan->codec == VLC_CODEC_SSA)
                text = rdcredits::assPacketText(text);
            rdcredits::Line line;
            line.startMs = MS_FROM_VLC_TICK(pts - VLC_TICK_0);
            line.endMs = line.startMs + (block->i_length > 0 ? MS_FROM_VLC_TICK(block->i_length) : 0);
            line.text = text;
            scan->lines.append(line);
            if (line.startMs >= scan->lengthMs)
                scan->past = true;
        }
    }
    block_Release(block);
    return VLC_SUCCESS;
}

void EsOutDel(es_out_t* out, es_out_id_t* id)
{
    EmbeddedScan* scan = scanOf(out);
    if (id == scan->text)
        scan->text = nullptr;
}

int EsOutControl(es_out_t* out, input_source_t*, int query, va_list args)
{
    EmbeddedScan* scan = scanOf(out);
    switch (query)
    {
    case ES_OUT_GET_ES_STATE:
    {
        // only the text track is selected: demuxers skip reading the others where they can
        es_out_id_t* id = va_arg(args, es_out_id_t*);
        bool* selected = va_arg(args, bool*);
        *selected = id == scan->text;
        return VLC_SUCCESS;
    }
    case ES_OUT_IS_EMPTY:
        *va_arg(args, bool*) = true;
        return VLC_SUCCESS;
    case ES_OUT_SET_ES:
    case ES_OUT_SET_ES_DEFAULT:
    case ES_OUT_SET_ES_STATE:
    case ES_OUT_SET_ES_CAT_POLICY:
    case ES_OUT_SET_ES_FMT:
    case ES_OUT_RESTART_ES:
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

bool isSubtitleFile(const QString& name)
{
    const QString ext = QFileInfo(name).suffix().toLower();
    return ext == QLatin1String("srt") || ext == QLatin1String("ass") || ext == QLatin1String("ssa")
           || ext == QLatin1String("vtt");
}

} // namespace

RdCreditsSubtitles::RdCreditsSubtitles(vlc_object_t* parent, const QString& path, const QByteArray& mrl,
                                       const QStringList& slaves, qint64 lengthMs)
    : m_parent(parent)
    , m_path(path)
    , m_mrl(mrl)
    , m_slaves(slaves)
    , m_lengthMs(lengthMs)
    , m_origin(QStringLiteral("none"))
{
}

QStringList RdCreditsSubtitles::externalFiles(const QString& path, const QStringList& slaves)
{
    QStringList files;
    for (const QString& slave : slaves)
    {
        if (isSubtitleFile(slave) && !files.contains(slave))
            files.append(slave);
    }
    // next to the episode, and in a Subs / Subtitles folder beside it, as VLC's autodetection
    const QFileInfo info(path);
    const QString base = info.completeBaseName();
    const QDir dir = info.dir();
    QStringList folders = { dir.absolutePath() };
    for (const QString& sub : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
    {
        if (sub.compare(QLatin1String("subs"), Qt::CaseInsensitive) == 0
                || sub.compare(QLatin1String("subtitles"), Qt::CaseInsensitive) == 0)
            folders.append(dir.absoluteFilePath(sub));
    }
    for (const QString& folder : folders)
    {
        QStringList names = QDir(folder).entryList(QDir::Files, QDir::Name);
        for (const QString& name : names)
        {
            if (!isSubtitleFile(name) || !name.startsWith(base, Qt::CaseInsensitive))
                continue;
            const QString file = QDir(folder).absoluteFilePath(name);
            if (!files.contains(file))
                files.append(file);
        }
    }
    return files;
}

QVector<rdcredits::Line> RdCreditsSubtitles::fromFiles()
{
    for (const QString& file : externalFiles(m_path, m_slaves))
    {
        if (cancelled())
            return {};
        QFile f(file);
        if (f.size() > kMaxFileBytes || !f.open(QIODevice::ReadOnly))
            continue;
        const QVector<rdcredits::Line> lines =
                rdcredits::parseSubtitleFile(decodeText(f.readAll()), QFileInfo(file).suffix());
        if (!lines.isEmpty())
        {
            m_origin = QStringLiteral("file %1").arg(QFileInfo(file).fileName());
            return lines;
        }
    }
    return {};
}

QVector<rdcredits::Line> RdCreditsSubtitles::fromEmbedded()
{
    if (m_mrl.isEmpty())
        return {};
    vlc_object_t* obj = static_cast<vlc_object_t*>(vlc_object_create(m_parent, sizeof(vlc_object_t)));
    if (!obj)
        return {};
    // a background scan never asks anything (an AVI index is never rebuilt)
    if (var_Create(obj, "avi-index", VLC_VAR_INTEGER) == VLC_SUCCESS)
        var_SetInteger(obj, "avi-index", 2);

    QVector<rdcredits::Line> lines;
    stream_t* stream = vlc_stream_NewURL(obj, m_mrl.constData());
    if (stream)
    {
        EmbeddedScan scan;
        scan.out.cbs = &kEsOutCallbacks;
        scan.lengthMs = m_lengthMs;
        demux_t* demux = demux_New(obj, "any", m_mrl.constData(), stream, &scan.out);
        if (!demux)
        {
            vlc_stream_Delete(stream);
        }
        else
        {
            // the tracks are announced while the demuxer opens: no text track, no read
            // and a file the demuxer cannot seek in is never read from its start
            bool canSeek = false;
            if (demux_Control(demux, DEMUX_CAN_SEEK, &canSeek) != VLC_SUCCESS)
                canSeek = false;
            const qint64 seekMs = std::max<qint64>(0, rdcredits::windowStart(m_lengthMs) - kSeekMarginMs);
            if (scan.text && canSeek
                    && demux_Control(demux, DEMUX_SET_TIME, VLC_TICK_FROM_MS(seekMs), false) == VLC_SUCCESS)
            {
                const vlc_tick_t deadline = vlc_tick_now() + VLC_TICK_FROM_SEC(kTimeBudgetSeconds);
                while (!cancelled() && !scan.past && vlc_tick_now() < deadline
                       && demux_Demux(demux) == VLC_DEMUXER_SUCCESS)
                {
                }
                if (!cancelled() && vlc_tick_now() < deadline)
                {
                    lines = scan.lines;
                    m_origin = QStringLiteral("embedded");
                }
            }
            // the demuxer deletes its tracks (es_out del) and the stream
            demux_Delete(demux);
        }
        for (int* id : scan.ids)
            delete id;
    }
    vlc_object_delete(obj);
    return lines;
}

QVector<rdcredits::Line> RdCreditsSubtitles::run()
{
    if (m_lengthMs <= 0 || cancelled())
        return {};
    QVector<rdcredits::Line> lines = fromFiles();
    if (lines.isEmpty() && !cancelled())
        lines = fromEmbedded();
    return cancelled() ? QVector<rdcredits::Line>() : lines;
}
