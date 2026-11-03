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

#include "rd_sub_sync.hpp"

#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QRunnable>

#include <vlc_player.h>
#include <vlc_url.h>

#include <cmath>
#include <cstring>

#include "player/input_models.hpp"
#include "player/player_controller.hpp"
#include "player/rd_subtitle_timeline.hpp"
#include "player/rd_sync_math.hpp"
#include "player/rd_sync_scanner.hpp"

namespace {

// an external file's track id starts with the MD5 of its URI: "<32 hex digits>/spu/0"
// (src/input/es_out.c, EsOutCreateStrId; player/input_models.cpp)
constexpr int kSlaveIdLength = 32;
// how often the progress is shown while the file is read
constexpr int kProgressIntervalMs = 200;
// a downloaded file's track is listed a moment after it is added: looked for this often, this
// many times
constexpr int kDownloadLookupMs = 250;
constexpr int kDownloadLookups = 20;
// a move smaller than this is no move
constexpr int kAlreadyInSyncMs = 60;
// the reference built from another track is laid out this far past its last line
constexpr int64_t kReferenceTailMs = 60 * 1000;

bool isExternalId(const char* strId)
{
    const char* slash = strId ? std::strchr(strId, '/') : nullptr;
    return slash && slash - strId == kSlaveIdLength;
}

// the demuxer's track id at the end of "spu/3" or "audio/1"
int demuxIdOf(const char* strId)
{
    const char* slash = strId ? std::strrchr(strId, '/') : nullptr;
    if (!slash || !slash[1])
        return -1;
    char* end = nullptr;
    const long id = std::strtol(slash + 1, &end, 10);
    return end && *end == '\0' ? static_cast<int>(id) : -1;
}

QString signedSeconds(int ms)
{
    const QString number = QString::number(std::abs(ms) / 1000.0, 'f', 1);
    return (ms < 0 ? QStringLiteral("-") : QStringLiteral("+")) + number;
}

// the frame rates a factor stands for: lines timed for `from` fps on a `to` fps video are
// stretched by from / to (rdsync::frameRateScales)
bool frameRatePair(double scale, double* from, double* to)
{
    const double ntsc = 24000.0 / 1001.0;
    const double pairs[][2] = { { 25, ntsc }, { ntsc, 25 }, { 24, ntsc }, { ntsc, 24 }, { 25, 24 }, { 24, 25 } };
    for (const auto& pair : pairs)
        if (std::abs(pair[0] / pair[1] - scale) < 1e-4)
        {
            *from = pair[0];
            *to = pair[1];
            return true;
        }
    return false;
}

QString fpsText(double fps)
{
    // 23.976, 25, 24
    QString text = QString::number(fps, 'f', 3);
    while (text.endsWith(QChar('0')))
        text.chop(1);
    if (text.endsWith(QChar('.')))
        text.chop(1);
    return text;
}

std::vector<rdsync::Cue> readSubtitleFile(const QByteArray& uri, bool* readable)
{
    *readable = false;
    std::vector<rdsync::Cue> cues;
    char* psz = vlc_uri2path(uri.constData());
    if (!psz)
        return cues;
    QFile file(QString::fromUtf8(psz));
    free(psz);
    if (file.size() > RdSubtitleTimeline::kMaxFileSize || !file.open(QIODevice::ReadOnly))
        return cues;
    *readable = true;
    for (const RdSubtitleTimeline::Cue& cue : RdSubtitleTimeline::parse(file.readAll()))
        cues.push_back({ cue.start, cue.end });
    return cues;
}

} // namespace

struct RdSubSync::Request
{
    QByteArray mediaUri;
    TrackRef track;
    // the reference: another track, or (not valid) the speech
    TrackRef reference;
    int audioId = -1;
    bool tryScales = false;
};

struct RdSubSync::Outcome
{
    bool ok = false;
    QString error;
    rdsync::Match match;
    bool automatic = false;
    QByteArray mediaUri;
    QByteArray trackStrId;
    double videoFps = 0;
};

class RdSubSync::Job : public QRunnable
{
public:
    Job(RdSubSync* owner, int generation, Request request, std::shared_ptr<RdSyncScanner> scanner,
        std::shared_ptr<Outcome> outcome)
        : m_owner(owner)
        , m_generation(generation)
        , m_request(std::move(request))
        , m_scanner(std::move(scanner))
        , m_outcome(std::move(outcome))
    {
        setAutoDelete(true);
    }

    void run() override
    {
        compute();
        QMetaObject::invokeMethod(m_owner, [owner = m_owner, generation = m_generation, outcome = m_outcome]() {
            owner->finish(generation, outcome);
        }, Qt::QueuedConnection);
    }

private:
    void compute()
    {
        Outcome& out = *m_outcome;
        const bool speech = !m_request.reference.valid;

        // the file is read only for what the subtitle files do not give: the speech, and the
        // lines of embedded tracks
        RdSyncScanner::Result scan;
        if (m_scanner)
        {
            scan = m_scanner->run();
            if (!scan.ok)
            {
                out.error = m_scanner->cancelled() ? QString() : qtr("The file could not be read.");
                return;
            }
        }

        const auto cuesOf = [&scan](const TrackRef& ref, bool* readable) {
            if (ref.external)
                return readSubtitleFile(ref.uri, readable);
            *readable = true;
            const auto it = scan.cues.find(ref.demuxId);
            return it != scan.cues.end() ? it->second : std::vector<rdsync::Cue>();
        };

        bool readable = false;
        const std::vector<rdsync::Cue> cues = cuesOf(m_request.track, &readable);
        if (cues.empty())
        {
            out.error = readable ? qtr("Auto-sync needs a text subtitle track (SRT, ASS, WebVTT).")
                                 : qtr("The subtitle file could not be read.");
            return;
        }

        std::vector<float> reference;
        if (speech)
        {
            reference = std::move(scan.speech);
            if (reference.empty())
            {
                out.error = qtr("This file has no audio to sync to.");
                return;
            }
        }
        else
        {
            const std::vector<rdsync::Cue> refCues = cuesOf(m_request.reference, &readable);
            if (refCues.empty())
            {
                out.error = qtr("The other subtitle track has no lines to sync to.");
                return;
            }
            const int64_t end = refCues.back().endMs + kReferenceTailMs;
            reference = rdsync::cueSignal(refCues, static_cast<size_t>(end / rdsync::kFrameMs));
        }

        out.match = rdsync::align(reference, cues, m_request.tryScales);
        out.ok = true;
    }

    RdSubSync* m_owner;
    int m_generation;
    Request m_request;
    std::shared_ptr<RdSyncScanner> m_scanner;
    std::shared_ptr<Outcome> m_outcome;
};

RdSubSync::RdSubSync(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
    , m_pool(std::make_unique<QThreadPool>())
{
    // one read at a time, below playback
    m_pool->setMaxThreadCount(1);
    m_pool->setThreadPriority(QThread::LowPriority);

    m_progressTimer.setInterval(kProgressIntervalMs);
    connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
        const qreal value = m_scanner ? m_scanner->progress() : 0;
        if (!qFuzzyCompare(value + 1, m_progress + 1))
        {
            m_progress = value;
            emit progressChanged();
        }
    });

    m_downloadRetry.setSingleShot(true);
    m_downloadRetry.setInterval(kDownloadLookupMs);
    connect(&m_downloadRetry, &QTimer::timeout, this, [this]() { syncDownloaded(m_downloadUri); });

    TrackListModel* tracks = m_player->getSubtitleTracks();
    const auto changed = [this]() { QTimer::singleShot(0, this, &RdSubSync::updateTracks); };
    connect(tracks, &QAbstractItemModel::rowsInserted, this, changed);
    connect(tracks, &QAbstractItemModel::rowsRemoved, this, changed);
    connect(tracks, &QAbstractItemModel::modelReset, this, changed);
    connect(tracks, &QAbstractItemModel::dataChanged, this, changed);
    connect(m_player, &PlayerController::inputChanged, this, &RdSubSync::clearForNewMedia);
    connect(m_player, &PlayerController::nameChanged, this, &RdSubSync::clearForNewMedia);
    updateTracks();
}

RdSubSync::~RdSubSync()
{
    if (m_scanner)
        m_scanner->cancel();
    // the job's result is dropped: it refers to this object
    m_pool->waitForDone();
}

std::vector<RdSubSync::TrackRef> RdSubSync::subtitleTracks() const
{
    std::vector<TrackRef> list;
    vlc_player_t* player = m_player->getPlayer();
    vlc_player_locker lock{ player };
    input_item_t* item = vlc_player_GetCurrentMedia(player);
    const size_t count = vlc_player_GetTrackCount(player, SPU_ES);
    for (size_t i = 0; i < count; ++i)
    {
        const vlc_player_track* track = vlc_player_GetTrackAt(player, SPU_ES, i);
        const char* strId = track ? vlc_es_id_GetStrId(track->es_id) : nullptr;
        if (!strId)
            continue;
        TrackRef ref;
        ref.valid = true;
        ref.strId = strId;
        ref.name = qfu(track->name);
        ref.external = isExternalId(strId);
        if (ref.external)
        {
            if (item)
            {
                const QByteArray hash(strId, kSlaveIdLength);
                vlc_mutex_locker itemLock{ &item->lock };
                for (int s = 0; s < item->i_slaves; ++s)
                {
                    const QByteArray uri(item->pp_slaves[s]->psz_uri);
                    if (QCryptographicHash::hash(uri, QCryptographicHash::Md5).toHex() == hash)
                    {
                        ref.uri = uri;
                        break;
                    }
                }
            }
            if (!ref.uri.isEmpty())
            {
                char* path = vlc_uri2path(ref.uri.constData());
                if (path)
                {
                    ref.name = QFileInfo(QString::fromUtf8(path)).fileName();
                    free(path);
                }
            }
        }
        else
            ref.demuxId = demuxIdOf(strId);
        // the selected track first, as the one to sync
        if (track->selected)
            list.insert(list.begin(), ref);
        else
            list.push_back(ref);
    }
    return list;
}

RdSubSync::TrackRef RdSubSync::selectedSubtitle() const
{
    vlc_player_t* player = m_player->getPlayer();
    {
        vlc_player_locker lock{ player };
        const vlc_player_track* track = vlc_player_GetSelectedTrack(player, SPU_ES);
        if (!track)
            return {};
    }
    const std::vector<TrackRef> list = subtitleTracks();
    return list.empty() ? TrackRef() : list.front();
}

void RdSubSync::updateTracks()
{
    QByteArray mediaUri;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        if (input_item_t* item = vlc_player_GetCurrentMedia(player))
            mediaUri = item->psz_uri;
    }
    if (mediaUri != m_mediaUri)
        clearForNewMedia();

    const TrackRef selected = selectedSubtitle();
    const bool available = selected.valid && mediaUri.startsWith("file://")
                           && (!selected.external || !selected.uri.isEmpty());
    if (available != m_available)
    {
        m_available = available;
        emit availableChanged();
    }

    // "Sync to": every other track; the choice follows its track when the list changes
    const QByteArray chosen = m_reference > 0 && m_reference <= static_cast<int>(m_referenceTracks.size())
                                  ? m_referenceTracks[static_cast<size_t>(m_reference - 1)].strId
                                  : QByteArray();
    std::vector<TrackRef> others;
    for (const TrackRef& ref : subtitleTracks())
        if (!selected.valid || ref.strId != selected.strId)
            if (!ref.external || !ref.uri.isEmpty())
                others.push_back(ref);
    int index = 0;
    for (size_t i = 0; i < others.size(); ++i)
        if (!chosen.isEmpty() && others[i].strId == chosen)
            index = static_cast<int>(i) + 1;

    bool listChanged = others.size() != m_referenceTracks.size();
    for (size_t i = 0; !listChanged && i < others.size(); ++i)
        listChanged = others[i].strId != m_referenceTracks[i].strId || others[i].name != m_referenceTracks[i].name;
    if (listChanged || index != m_reference)
    {
        m_referenceTracks = std::move(others);
        m_reference = index;
        emit referencesChanged();
    }
}

QStringList RdSubSync::references() const
{
    QStringList list { qtr("Speech in the audio") };
    for (const TrackRef& ref : m_referenceTracks)
        list.append(ref.name.isEmpty() ? QString::fromUtf8(ref.strId) : ref.name);
    return list;
}

void RdSubSync::setReference(int index)
{
    if (index < 0 || index > static_cast<int>(m_referenceTracks.size()) || index == m_reference)
        return;
    m_reference = index;
    emit referencesChanged();
}

void RdSubSync::sync()
{
    const TrackRef track = selectedSubtitle();
    if (!track.valid)
        return;
    const QByteArray reference = m_reference > 0 && m_reference <= static_cast<int>(m_referenceTracks.size())
                                     ? m_referenceTracks[static_cast<size_t>(m_reference - 1)].strId
                                     : QByteArray();
    start(track, reference, false);
}

void RdSubSync::syncDownloaded(const QByteArray& uri)
{
    // the downloaded file's track, once VLC lists and selects it
    if (uri != m_downloadUri)
    {
        m_downloadUri = uri;
        m_downloadLookups = 0;
    }
    const QByteArray hash = QCryptographicHash::hash(uri, QCryptographicHash::Md5).toHex();
    const TrackRef selected = selectedSubtitle();
    if (selected.valid && selected.strId.startsWith(hash))
    {
        m_downloadUri.clear();
        start(selected, QByteArray(), true);
        return;
    }
    if (++m_downloadLookups < kDownloadLookups)
        m_downloadRetry.start();
    else
        m_downloadUri.clear();
}

void RdSubSync::start(const TrackRef& track, const QByteArray& referenceStrId, bool automatic)
{
    if (m_busy)
        cancel();

    Request request;
    request.track = track;
    for (const TrackRef& ref : m_referenceTracks)
        if (!referenceStrId.isEmpty() && ref.strId == referenceStrId)
            request.reference = ref;

    double videoFps = 0;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        input_item_t* item = vlc_player_GetCurrentMedia(player);
        if (!item)
            return;
        request.mediaUri = item->psz_uri;
        if (const vlc_player_track* audio = vlc_player_GetSelectedTrack(player, AUDIO_ES))
        {
            const char* strId = vlc_es_id_GetStrId(audio->es_id);
            if (!isExternalId(strId))
                request.audioId = demuxIdOf(strId);
        }
        if (const vlc_player_track* video = vlc_player_GetSelectedTrack(player, VIDEO_ES))
            if (video->fmt.video.i_frame_rate_base > 0)
                videoFps = static_cast<double>(video->fmt.video.i_frame_rate) / video->fmt.video.i_frame_rate_base;
    }
    if (!request.mediaUri.startsWith("file://"))
        return;
    // VLC rescales external subtitle files only (the subtitle speed), and needs the video's rate
    request.tryScales = track.external && videoFps > 1;

    const bool speech = !request.reference.valid;
    const bool needRead = speech || !track.external || !request.reference.external;
    std::shared_ptr<RdSyncScanner> scanner;
    if (needRead)
        scanner = std::make_shared<RdSyncScanner>(VLC_OBJECT(vlc_object_instance(m_intf)), request.mediaUri,
                                                  request.audioId, speech);
    m_scanner = scanner;

    auto outcome = std::make_shared<Outcome>();
    outcome->automatic = automatic;
    outcome->mediaUri = request.mediaUri;
    outcome->trackStrId = track.strId;
    outcome->videoFps = videoFps;

    setResult(QString(), false);
    m_progress = 0;
    emit progressChanged();
    setBusy(true);
    m_pool->start(new Job(this, ++m_generation, std::move(request), scanner, outcome));
}

void RdSubSync::finish(int generation, std::shared_ptr<Outcome> outcome)
{
    if (generation != m_generation)
        return;
    m_scanner.reset();
    setBusy(false);

    // the media or the track changed meanwhile: the result is for something else
    const TrackRef selected = selectedSubtitle();
    if (outcome->mediaUri != m_mediaUri || !selected.valid || selected.strId != outcome->trackStrId)
        return;

    if (!outcome->ok)
    {
        setResult(outcome->error, false);
        if (outcome->automatic && !outcome->error.isEmpty())
            emit notice(qtr("Auto-sync: %1").arg(outcome->error));
        return;
    }

    const rdsync::Match& match = outcome->match;
    msg_Dbg(m_intf, "subtitle sync: %s, delay %lld ms, scale %.5f, score %.3f, confidence %.1f",
            match.found ? "match" : "no match", static_cast<long long>(match.offsetMs), match.scale,
            match.score, match.confidence);
    if (!match.found)
    {
        setResult(qtr("No match found. The subtitles were not changed."), false);
        if (outcome->automatic)
            emit notice(qtr("Auto-sync found no match for the downloaded subtitles"));
        return;
    }

    const int oldDelay = m_player->getSubtitleDelayMS();
    const float oldFps = m_player->getSubtitleFPS();
    const int newDelay = static_cast<int>(match.offsetMs);
    const bool scaled = !rdsync::isUnitScale(match.scale);
    // the subtitle speed is the frame rate the file was timed for: the video's rate / factor
    // (src/input/input.c, RequestSubRate). The lines were measured at the file's own timing, so
    // a speed set before is taken back when no factor is needed.
    float newFps = oldFps;
    if (scaled)
        newFps = static_cast<float>(outcome->videoFps / match.scale);
    else if (selected.external && oldFps > 1.f)
        newFps = 0.f;
    const bool fpsChange = std::abs(newFps - oldFps) > 0.0005f;

    if (std::abs(newDelay - oldDelay) < kAlreadyInSyncMs && !fpsChange)
    {
        setResult(qtr("Already in sync"), false);
        if (outcome->automatic)
            emit notice(qtr("Downloaded subtitles are in sync"));
        return;
    }

    // Undo goes back to before the first sync of this file, also after a second one
    if (!m_undo.valid)
    {
        m_undo.valid = true;
        m_undo.mediaUri = m_mediaUri;
        m_undo.delayMs = oldDelay;
        m_undo.fps = oldFps;
        m_undo.fpsChanged = false;
    }
    m_undo.fpsChanged = m_undo.fpsChanged || fpsChange;
    m_undo.appliedFps = newFps;

    if (fpsChange)
        m_player->setSubtitleFPS(newFps);
    m_player->setSubtitleDelayMS(newDelay);

    QString text = qtr("Moved %1 s").arg(signedSeconds(newDelay - oldDelay));
    double from = 0, to = 0;
    if (scaled && frameRatePair(match.scale, &from, &to))
        text = qtr("Moved %1 s, frame rate %2 to %3 fps").arg(signedSeconds(newDelay - oldDelay),
                                                              fpsText(from), fpsText(to));
    setResult(text, true);
    if (outcome->automatic)
        emit notice(qtr("Subtitles auto-synced: %1").arg(text));
}

void RdSubSync::undo()
{
    if (!m_undo.valid)
        return;
    if (m_undo.mediaUri == m_mediaUri)
    {
        if (m_undo.fpsChanged)
            m_player->setSubtitleFPS(m_undo.fps);
        m_player->setSubtitleDelayMS(m_undo.delayMs);
    }
    m_undo = Undo();
    setResult(QString(), false);
}

void RdSubSync::cancel()
{
    ++m_generation;
    if (m_scanner)
        m_scanner->cancel();
    m_scanner.reset();
    setBusy(false);
}

void RdSubSync::setResult(const QString& text, bool moved)
{
    if (text == m_resultText && moved == m_moved)
    {
        emit stateChanged();
        return;
    }
    m_resultText = text;
    m_moved = moved;
    emit stateChanged();
}

void RdSubSync::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    if (busy)
        m_progressTimer.start();
    else
        m_progressTimer.stop();
    emit stateChanged();
}

void RdSubSync::clearForNewMedia()
{
    QByteArray mediaUri;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        if (input_item_t* item = vlc_player_GetCurrentMedia(player))
            mediaUri = item->psz_uri;
    }
    if (mediaUri == m_mediaUri)
        return;

    // a frame-rate fix belongs to the file it was found for: VLC keeps the subtitle speed for
    // the next file, so it is taken back (unless the user changed it since)
    if (m_undo.valid && m_undo.fpsChanged
        && std::abs(m_player->getSubtitleFPS() - m_undo.appliedFps) < 0.0005f)
        m_player->setSubtitleFPS(m_undo.fps);

    m_mediaUri = mediaUri;
    if (m_busy)
        cancel();
    m_undo = Undo();
    m_downloadUri.clear();
    m_downloadRetry.stop();
    setResult(QString(), false);
}
