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

#include "rd_subtitle_timeline.hpp"

#include <QFile>
#include <QList>
#include <QMetaObject>
#include <QRegularExpression>
#include <QRunnable>
#include <QString>
#include <QThread>

#include <algorithm>

#include <vlc_url.h>

#include "player/input_models.hpp"
#include "player/player_controller.hpp"

namespace {

constexpr int kRetryIntervalMs = 400;
constexpr int kMaxRetries = 8;

// "1,5" / "1.500" after the seconds: a fraction of a second
qint64 fractionMs(const QStringView digits)
{
    if (digits.isEmpty())
        return 0;
    qint64 value = digits.left(3).toLongLong();
    for (qsizetype i = digits.left(3).size(); i < 3; ++i)
        value *= 10;
    return value;
}

// "H:MM:SS.cc" (SSA / ASS): -1 when it is not a time
qint64 assTimeMs(QStringView text)
{
    static const QRegularExpression time(QStringLiteral("^\\s*(\\d+):(\\d{1,2}):(\\d{1,2})(?:[.,](\\d{1,3}))?\\s*$"));
    const QRegularExpressionMatch match = time.matchView(text);
    if (!match.hasMatch())
        return -1;
    return ((match.capturedView(1).toLongLong() * 60 + match.capturedView(2).toLongLong()) * 60
            + match.capturedView(3).toLongLong()) * 1000
           + fractionMs(match.capturedView(4));
}

// the file as UTF-8 text: UTF-16 files (with their byte order mark) are converted, the times
// are plain digits in every other encoding VLC reads
QString decode(const QByteArray& data)
{
    if (data.startsWith("\xff\xfe") || data.startsWith("\xfe\xff"))
    {
        const bool little = data.startsWith("\xff\xfe");
        QList<char16_t> units;
        units.reserve(data.size() / 2);
        for (qsizetype i = 2; i + 1 < data.size(); i += 2)
        {
            const auto lo = static_cast<uchar>(data[little ? i : i + 1]);
            const auto hi = static_cast<uchar>(data[little ? i + 1 : i]);
            units.append(static_cast<char16_t>(lo | (hi << 8)));
        }
        return QString(reinterpret_cast<const QChar*>(units.constData()), units.size());
    }
    return QString::fromUtf8(data);
}

} // namespace

/**
 * One read of the selected subtitle file, on the worker thread.
 */
class RdSubtitleTimelineJob : public QRunnable
{
public:
    RdSubtitleTimelineJob(RdSubtitleTimeline* owner, int generation, const QString& path)
        : m_owner(owner)
        , m_generation(generation)
        , m_path(path)
    {
    }

    void run() override
    {
        std::vector<RdSubtitleTimeline::Cue> cues;
        QFile file(m_path);
        if (file.size() <= RdSubtitleTimeline::kMaxFileSize && file.open(QIODevice::ReadOnly))
            cues = RdSubtitleTimeline::parse(file.readAll());

        // the owner waits for this job before it goes (~RdSubtitleTimeline)
        RdSubtitleTimeline* owner = m_owner;
        const int generation = m_generation;
        QMetaObject::invokeMethod(owner, [owner, generation, cues = std::move(cues)]() mutable {
            owner->onParsed(generation, std::move(cues));
        }, Qt::QueuedConnection);
    }

private:
    RdSubtitleTimeline* m_owner;
    int m_generation;
    QString m_path;
};

RdSubtitleTimeline::RdSubtitleTimeline(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
    , m_pool(std::make_unique<QThreadPool>())
{
    m_pool->setMaxThreadCount(1);
    m_pool->setThreadPriority(QThread::LowPriority);

    m_retry.setSingleShot(true);
    m_retry.setInterval(kRetryIntervalMs);
    connect(&m_retry, &QTimer::timeout, this, &RdSubtitleTimeline::updateTrack);

    TrackListModel* tracks = m_player->getSubtitleTracks();
    connect(tracks, &QAbstractItemModel::dataChanged, this, &RdSubtitleTimeline::scheduleUpdate);
    connect(tracks, &QAbstractItemModel::rowsInserted, this, &RdSubtitleTimeline::scheduleUpdate);
    connect(tracks, &QAbstractItemModel::rowsRemoved, this, &RdSubtitleTimeline::scheduleUpdate);
    connect(tracks, &QAbstractItemModel::modelReset, this, &RdSubtitleTimeline::scheduleUpdate);
    connect(m_player, &PlayerController::inputChanged, this, [this]() {
        m_retries = 0;
        scheduleUpdate();
    });
    connect(m_player, &PlayerController::lengthChanged, this, &RdSubtitleTimeline::updateLength);
    updateLength();
}

RdSubtitleTimeline::~RdSubtitleTimeline()
{
    ++m_generation;
    m_pool->clear();
    m_pool->waitForDone();
}

void RdSubtitleTimeline::updateLength()
{
    const VLCDuration length = m_player->getLength();
    const qreal lengthMs = length.valid() ? std::max<qreal>(0, length.toMilliseconds()) : 0;
    if (lengthMs == m_lengthMs)
        return;
    m_lengthMs = lengthMs;
    emit lengthMsChanged();
}

void RdSubtitleTimeline::acquire()
{
    if (++m_users == 1)
        scheduleUpdate();
}

void RdSubtitleTimeline::release()
{
    if (m_users <= 0)
        return;
    --m_users;
}

void RdSubtitleTimeline::scheduleUpdate()
{
    // one look at the tracks for a burst of model signals
    if (m_updatePending)
        return;
    m_updatePending = true;
    QMetaObject::invokeMethod(this, [this]() {
        m_updatePending = false;
        updateTrack();
    }, Qt::QueuedConnection);
}

void RdSubtitleTimeline::updateTrack()
{
    // the first selected subtitle track, if it comes from an external file
    QByteArray uri;
    bool listedLater = false;
    const TrackListModel* tracks = m_player->getSubtitleTracks();
    for (int row = 0; row < tracks->rowCount(); ++row)
    {
        const QModelIndex index = tracks->index(row);
        if (!tracks->data(index, Qt::CheckStateRole).toBool())
            continue;
        if (tracks->data(index, TrackListModel::ExternalRole).toBool())
        {
            uri = tracks->data(index, TrackListModel::ExternalUriRole).toString().toUtf8();
            listedLater = uri.isEmpty();
        }
        break;
    }

    if (listedLater && m_retries < kMaxRetries)
    {
        ++m_retries;
        m_retry.start();
    }
    else if (!listedLater)
        m_retries = 0;

    if (uri != m_uri)
    {
        m_uri = uri;
        if (m_uri != m_parsedUri)
        {
            // the cues shown belong to another file
            ++m_generation;
            m_parsedUri.clear();
            setCues({});
        }
    }
    startParse();
}

void RdSubtitleTimeline::startParse()
{
    if (m_users == 0 || m_uri.isEmpty() || m_uri == m_parsedUri || !m_uri.startsWith("file://"))
        return;

    char* psz = vlc_uri2path(m_uri.constData());
    if (!psz)
        return;
    const QString path = QString::fromUtf8(psz);
    free(psz);

    m_parsedUri = m_uri;
    m_pool->start(new RdSubtitleTimelineJob(this, ++m_generation, path));
}

void RdSubtitleTimeline::onParsed(int generation, std::vector<Cue> cues)
{
    if (generation != m_generation)
        return;
    msg_Dbg(m_intf, "subtitle timeline: %zu cues in the selected subtitle file", cues.size());
    setCues(std::move(cues));
}

void RdSubtitleTimeline::setCues(std::vector<Cue> cues)
{
    if (cues.empty() && m_cues.empty())
        return;
    m_cues = std::move(cues);
    emit cuesChanged();
}

std::vector<RdSubtitleTimeline::Cue> RdSubtitleTimeline::parse(const QByteArray& data)
{
    std::vector<Cue> cues;
    const QString text = decode(data);

    // SubRip and WebVTT: "00:01:02,345 --> 00:01:04,000" (WebVTT may leave out the hours);
    // anything after the second time (positions, cue settings) is ignored
    static const QRegularExpression arrow(QStringLiteral(
        "^\\s*(?:(\\d+):)?(\\d{1,2}):(\\d{1,2})(?:[,.](\\d{1,3}))?\\s*-->\\s*"
        "(?:(\\d+):)?(\\d{1,2}):(\\d{1,2})(?:[,.](\\d{1,3}))?"));

    // SSA / ASS: the [Events] "Format:" line names the fields of the "Dialogue:" lines
    int startField = 1;
    int endField = 2;

    for (QStringView line : QStringView(text).split(QLatin1Char('\n')))
    {
        if (line.endsWith(QLatin1Char('\r')))
            line.chop(1);

        if (line.contains(QLatin1String("-->")))
        {
            const QRegularExpressionMatch match = arrow.matchView(line);
            if (!match.hasMatch())
                continue;
            const auto timeMs = [&match](int first) {
                return ((match.capturedView(first).toLongLong() * 60
                         + match.capturedView(first + 1).toLongLong()) * 60
                        + match.capturedView(first + 2).toLongLong()) * 1000
                       + fractionMs(match.capturedView(first + 3));
            };
            const qint64 start = timeMs(1);
            const qint64 end = timeMs(5);
            if (end > start)
                cues.push_back({ start, end });
            continue;
        }

        const QStringView trimmed = line.trimmed();
        if (trimmed.startsWith(QLatin1String("Format:"), Qt::CaseInsensitive))
        {
            const QList<QStringView> fields = trimmed.mid(7).split(QLatin1Char(','));
            for (qsizetype i = 0; i < fields.size(); ++i)
            {
                const QStringView name = fields[i].trimmed();
                if (name.compare(QLatin1String("Start"), Qt::CaseInsensitive) == 0)
                    startField = static_cast<int>(i);
                else if (name.compare(QLatin1String("End"), Qt::CaseInsensitive) == 0)
                    endField = static_cast<int>(i);
            }
        }
        else if (trimmed.startsWith(QLatin1String("Dialogue:"), Qt::CaseInsensitive))
        {
            // the text, the last field, may hold commas: only the fields before it are split
            const QList<QStringView> fields = trimmed.mid(9).split(QLatin1Char(','));
            const int needed = std::max(startField, endField);
            if (fields.size() <= needed)
                continue;
            const qint64 start = assTimeMs(fields[startField]);
            const qint64 end = assTimeMs(fields[endField]);
            if (start >= 0 && end > start)
                cues.push_back({ start, end });
        }
    }

    std::stable_sort(cues.begin(), cues.end(), [](const Cue& a, const Cue& b) {
        return a.start < b.start;
    });
    return cues;
}
