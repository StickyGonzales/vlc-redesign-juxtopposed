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

#include "rd_up_next.hpp"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QEvent>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QRegularExpression>
#include <QSettings>

#include <cmath>
#include <memory>

#include <vlc_common.h>
#include <vlc_block.h>
#include <vlc_configuration.h>
#include <vlc_media_library.h>
#include <vlc_picture.h>
#include <vlc_player.h>
#include <vlc_preparser.h>
#include <vlc_url.h>
#include <vlc_variables.h>

#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlhelper.hpp"
#include "player/input_models.hpp"
#include "player/player_controller.hpp"
#include "player/rd_effects.hpp"
#include "playlist/playlist_controller.hpp"
#include "playlist/playlist_item.hpp"

using vlc::playlist::Media;
using vlc::playlist::PlaylistController;
using vlc::playlist::vlc_playlist_locker;

namespace {

// the prompt: this long into the first episode of a show, then this long on screen
constexpr int kPromptDelayMs = 10000;
constexpr int kPromptShownMs = 20000;
// the next episode's picture: at this part of the file, this wide
constexpr double kThumbnailPosition = 0.15;
constexpr int kThumbnailWidth = 320;
// "Still watching?" after this many episodes in a row without the user
constexpr int kStillWatchingAfter = 3;

QString storePath()
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return {};
    const QString path = QString::fromUtf8(dir) + QStringLiteral("/rd-shows.json");
    free(dir);
    return path;
}

QString thumbnailDir()
{
    char* dir = config_GetUserDir(VLC_CACHE_DIR);
    if (!dir)
        return {};
    const QString path = QString::fromUtf8(dir) + QStringLiteral("/up-next");
    free(dir);
    return path;
}

// Windows paths do not tell case apart
QString normalizedPath(const QString& path)
{
    const QString clean = QDir::cleanPath(QDir::fromNativeSeparators(path));
#ifdef _WIN32
    return clean.toLower();
#else
    return clean;
#endif
}

// the MRL VLC and the media library give a local file (vlc_path2uri encodes the sub-delims
// "( ) ' ! & , ; =" that QUrl leaves as they are), so the library finds the episode
QString episodeMrl(const QString& path)
{
    char* uri = vlc_path2uri(qtu(QDir::toNativeSeparators(path)), "file");
    if (!uri)
        return {};
    const QString mrl = QString::fromUtf8(uri);
    free(uri);
    return mrl;
}

QString localPath(const QUrl& url)
{
    if (!url.isLocalFile())
        return {};
    return QDir::cleanPath(url.toLocalFile());
}

// a chapter that starts the end credits ("Credits", "End Credits", "Ending", "ED", "Outro")
bool isCreditsChapter(const QString& name)
{
    static const QRegularExpression credits(
        QStringLiteral("^\\s*(?:end\\s*credits|credits|ending|outro|ed)\\s*$"),
        QRegularExpression::CaseInsensitiveOption);
    return credits.match(name).hasMatch();
}

// the language of the track selected in a category, empty when none
QString selectedLanguage(vlc_player_t* player, es_format_category_e cat, bool* selected)
{
    vlc_player_locker lock{ player };
    const vlc_player_track* track = vlc_player_GetSelectedTrack(player, cat);
    if (selected)
        *selected = track != nullptr;
    if (!track || !track->fmt.psz_language)
        return {};
    return QString::fromUtf8(track->fmt.psz_language);
}

} // namespace

RdUpNext::RdUpNext(qt_intf_t* intf, MainCtx* ctx, RdEffects* effects, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_ctx(ctx)
    , m_player(intf->p_mainPlayerController)
    , m_playlist(intf->p_mainPlaylistController)
{
    m_scanPool.setMaxThreadCount(1);
    m_storePool.setMaxThreadCount(1);

    m_creditsTimer.setInterval(1000);
    connect(&m_creditsTimer, &QTimer::timeout, this, [this]() {
        if (m_secondsLeft <= 1)
        {
            m_creditsTimer.stop();
            playNow();
            return;
        }
        setSecondsLeft(m_secondsLeft - 1);
    });

    m_promptTimer.setSingleShot(true);
    connect(&m_promptTimer, &QTimer::timeout, this, [this]() {
        // no answer: asked again with the next episode of the show
        setPromptVisible(false);
    });

    readSettings();
    connect(effects, &RdEffects::changed, this, &RdUpNext::reloadSettings);

    connect(m_player, &PlayerController::inputChanged, this, &RdUpNext::onInputChanged);
    connect(m_player, &PlayerController::timeChanged, this, &RdUpNext::updateCard);
    connect(m_player, &PlayerController::lengthChanged, this, &RdUpNext::evaluate);
    connect(m_player, &PlayerController::rateChanged, this, &RdUpNext::updateCard);
    connect(m_player, &PlayerController::playingStateChanged, this, [this]() {
        if (m_creditsRunning)
        {
            if (m_player->getPlayingState() == PlayerController::PLAYING_STATE_PLAYING)
                m_creditsTimer.start();
            else
                m_creditsTimer.stop();
        }
        if (m_player->getPlayingState() == PlayerController::PLAYING_STATE_STOPPED)
        {
            setCard(false, CardNext);
            // between two episodes the player stops for a moment too: only a stop that lasts counts
            QTimer::singleShot(300, this, &RdUpNext::onStopped);
        }
        // the episode loaded paused under "Still watching?" plays (Space, the play button)
        if (m_stillOnPaused && m_player->getPlayingState() == PlayerController::PLAYING_STATE_PLAYING)
            leaveStillWatching();
        updateCard();
    });
    connect(m_player, &PlayerController::ABLoopStateChanged, this, &RdUpNext::evaluate);

    // a subtitle track switched on or off (the track model changes its selection role)
    const auto updateSubtitles = [this]() {
        bool selected = false;
        selectedLanguage(m_player->getPlayer(), SPU_ES, &selected);
        if (selected == m_subtitlesOn)
            return;
        m_subtitlesOn = selected;
        emit subtitlesChanged();
    };
    TrackListModel* subtitles = m_player->getSubtitleTracks();
    connect(subtitles, &QAbstractItemModel::dataChanged, this, updateSubtitles);
    connect(subtitles, &QAbstractItemModel::modelReset, this, updateSubtitles);
    connect(subtitles, &QAbstractItemModel::rowsInserted, this, updateSubtitles);
    connect(subtitles, &QAbstractItemModel::rowsRemoved, this, updateSubtitles);
    connect(m_player, &PlayerController::playbackRestoreQueried, this, &RdUpNext::updateCard);

    connect(m_playlist, &PlaylistController::randomChanged, this, &RdUpNext::evaluate);
    connect(m_playlist, &PlaylistController::repeatModeChanged, this, &RdUpNext::evaluate);
    connect(m_playlist, &PlaylistController::mediaStopActionChanged, this, &RdUpNext::evaluate);
    connect(m_playlist, &PlaylistController::itemsAdded, this, &RdUpNext::onItemsAdded);
    connect(m_playlist, &PlaylistController::itemsRemoved, this, &RdUpNext::onItemsRemoved);
    connect(m_playlist, &PlaylistController::itemsMoved, this, &RdUpNext::onItemsMovedOrReset);
    connect(m_playlist, &PlaylistController::itemsReset, this, &RdUpNext::onItemsMovedOrReset);

    // a key, a click or the wheel: the user is there ("Still watching?" counts from here)
    qApp->installEventFilter(this);

    // the remembered answers, read in the background
    auto data = std::make_shared<QJsonObject>();
    QPointer<RdUpNext> self(this);
    m_storePool.start([self, data]() {
        QFile file(storePath());
        if (file.open(QIODevice::ReadOnly))
            *data = QJsonDocument::fromJson(file.readAll()).object();
        QMetaObject::invokeMethod(self.data(), [self, data]() {
            if (self)
                self->loadStore(*data);
        }, Qt::QueuedConnection);
    });

    // a media already playing when the interface starts
    if (m_player->hasInput())
        onInputChanged(true);
}

RdUpNext::~RdUpNext()
{
    qApp->removeEventFilter(this);
    m_scanPool.waitForDone();
    m_storePool.waitForDone();
    // ends the thumbnailer thread; the callback of a request in flight runs before this
    // returns, and its result (queued to this object) is dropped with it
    if (m_preparser)
        vlc_preparser_Delete(m_preparser);
    if (m_thumbReq)
        vlc_preparser_req_Release(m_thumbReq);
}

// ------------------------------------------------------------------------------- settings

bool RdUpNext::readSettings()
{
    const int mode = int(config_GetInt("qt-autoplay-next"));
    const int countdown = int(config_GetInt("qt-autoplay-countdown"));
    const int cardPoint = int(config_GetInt("qt-autoplay-card-point"));
    const bool still = config_GetInt("qt-autoplay-still-watching") != 0;
    const int clampedCountdown = (countdown == 5 || countdown == 15) ? countdown : 10;
    if (mode == m_mode && clampedCountdown == m_countdown && cardPoint == m_cardPoint && still == m_stillWatching)
        return false;
    m_mode = std::clamp(mode, int(ModeOff), int(ModeAlways));
    m_countdown = clampedCountdown;
    m_cardPoint = cardPoint;
    m_stillWatching = still;
    emit settingsChanged();
    return true;
}

void RdUpNext::reloadSettings()
{
    // RdEffects::changed comes with every effect applied (a slider drag): only a change of
    // these options does something
    const int mode = m_mode;
    if (!readSettings())
        return;
    if (mode != m_mode)
        startDetection();
    else
        evaluate();
}

// ------------------------------------------------------------------------------ properties

bool RdUpNext::showActive() const
{
    return m_mode != ModeOff && m_showKnown && m_show.isShow;
}

QString RdUpNext::showName() const
{
    return showActive() ? m_show.name : QString();
}

bool RdUpNext::showEnabled() const
{
    if (!showActive())
        return false;
    const auto it = m_answers.constFind(showKey());
    if (it != m_answers.cend())
        return it->yes;
    // Always: on, once the stored answers are known (a stored "no" wins)
    return m_mode == ModeAlways && m_storeLoaded;
}

QString RdUpNext::nextCode() const
{
    if (m_nextIndex < 0)
        return {};
    const rdepisode::Episode& next = m_show.episodes.at(m_nextIndex);
    // the parser's words are English: translated here
    if (next.part)
        return qtr("Part %1").arg(next.episode);
    if (next.seasonDefaulted || next.season < 0)
        return qtr("Episode %1").arg(next.episode);
    return rdepisode::code(next);
}

QString RdUpNext::nextTitle() const
{
    if (m_nextIndex < 0)
        return {};
    return m_show.episodes.at(m_nextIndex).title;
}

QString RdUpNext::nextLine() const
{
    if (m_nextIndex < 0)
        return {};
    const QString title = nextTitle();
    return title.isEmpty() ? nextCode() : nextCode() + QStringLiteral(" · ") + title;
}

QUrl RdUpNext::nextUrl() const
{
    if (m_nextIndex < 0)
        return {};
    return QUrl(episodeMrl(m_show.episodes.at(m_nextIndex).path));
}

QString RdUpNext::cardLine() const
{
    return (m_cardVisible && m_cardMode == CardStillWatching && !m_stillLine.isEmpty()) ? m_stillLine : nextLine();
}

bool RdUpNext::nextIsNewSeason() const
{
    return m_nextIndex >= 0 && m_show.nextIsNewSeason();
}

int RdUpNext::nextSeason() const
{
    return m_nextIndex >= 0 ? m_show.episodes.at(m_nextIndex).season : -1;
}

double RdUpNext::countdownProgress() const
{
    return m_countdown > 0 ? std::clamp(double(m_secondsLeft) / m_countdown, 0.0, 1.0) : 0.0;
}

int RdUpNext::rememberedYes() const
{
    int n = 0;
    for (const Answer& a : m_answers)
        n += a.yes ? 1 : 0;
    return n;
}

int RdUpNext::rememberedNo() const
{
    return int(m_answers.size()) - rememberedYes();
}

// ------------------------------------------------------------------------------ the media

void RdUpNext::onInputChanged(bool hasInput)
{
    const PlaylistItem current = m_playlist->getCurrentItem();
    input_item_t* input = current ? current.inputItem() : nullptr;

    const bool fromAutoplay = input && input == m_queuedInput;
    if (fromAutoplay)
    {
        // the queue moved on to the autoplay item: it is the episode playing now
        m_currentIsAutoplay = true;
        ++m_autoStreak;
        clearQueued();
    }
    else
    {
        m_currentIsAutoplay = false;
        // a file the user opened on its own (added alone and played at once): a fresh queue
        if (input && input == m_lastSingleAdd.get())
            m_userQueue = false;
        m_autoStreak = 0;
        m_stillPending = false;
    }
    m_lastSingleAdd = SharedInputItem();
    m_cancelled = false;
    m_promptDone = false;
    setPromptVisible(false);
    m_creditsTimer.stop();
    m_creditsRunning = false;
    m_creditsStartMs = -1;

    // "Still watching?" stays on the next episode, which starts paused under it
    m_stillOnPaused = m_stillPending && fromAutoplay;
    if (m_stillOnPaused)
        setCard(true, CardStillWatching);
    else
        setCard(false, CardNext);
    m_stillPending = false;

    m_url = hasInput ? m_player->getUrl() : QUrl();
    m_path = localPath(m_url);
    startDetection();
}

void RdUpNext::startDetection()
{
    ++m_generation;
    m_showKnown = false;
    m_show = rdepisode::Show();
    m_nextIndex = -1;
    emit stateChanged();
    emit nextChanged();

    if (m_mode == ModeOff || m_path.isEmpty())
    {
        evaluate();
        return;
    }

    rdepisode::Options options;
    const QStringList musicMrls = m_intf->mainSettings
            ? m_intf->mainSettings->value(QStringLiteral("RdLibrary/musicFolders")).toStringList()
            : QStringList();
    for (const QString& mrl : musicMrls)
    {
        const QString path = localPath(QUrl(mrl));
        if (!path.isEmpty())
            options.musicRoots.append(path);
    }

    const int generation = m_generation;
    const QString path = m_path;
    QPointer<RdUpNext> self(this);
    m_scanPool.start([self, generation, path, options]() {
        const rdepisode::Show show = rdepisode::detect(path, options);
        QMetaObject::invokeMethod(self.data(), [self, generation, show]() {
            if (self)
                self->onDetected(generation, show);
        }, Qt::QueuedConnection);
    });
}

void RdUpNext::onDetected(int generation, const rdepisode::Show& show)
{
    if (generation != m_generation)
        return;
    m_show = show;
    m_showKnown = true;
    if (!m_show.isShow)
        msg_Dbg(m_intf, "up next: not a show (%s)", qtu(m_show.reason));
    evaluate();
}

// --------------------------------------------------------------------------------- guards

// the rules of UP_NEXT_PLAN.md section 8 that keep autoplay away; empty when none applies
QString RdUpNext::guardReason() const
{
    if (m_playlist->isRandom())
        return qtr("Shuffle is on");
    if (m_playlist->getRepeatMode() == PlaylistController::PLAYBACK_REPEAT_CURRENT)
        return qtr("Repeat one is on");
    switch (m_playlist->getMediaStopAction())
    {
    case PlaylistController::MEDIA_STOPPED_STOP:
        if (var_InheritBool(m_intf, "play-and-stop"))
            return qtr("Stop after each item is on");
        return qtr("Playback stops after this file");
    case PlaylistController::MEDIA_STOPPED_EXIT:
        return qtr("Quit at the end of the queue is on");
    default:
        break;
    }
    if (var_InheritBool(m_intf, "play-and-pause"))
        return qtr("Pause on the last frame is on");
    if (var_InheritBool(m_intf, "start-paused") || var_InheritInteger(m_intf, "input-repeat") > 0
            || var_InheritFloat(m_intf, "start-time") > 0 || var_InheritFloat(m_intf, "stop-time") > 0
            || var_InheritFloat(m_intf, "run-time") > 0)
        return qtr("A command line option is set");
    if (m_player->getABloopState() != PlayerController::ABLOOP_STATE_NONE)
        return qtr("An A-B loop is set");
    if (!queueIsCones())
        return qtr("You built the queue");
    return {};
}

// only a queue Cone made is ever filled: nothing the user added after the episode playing
bool RdUpNext::queueIsCones() const
{
    if (m_userQueue)
        return false;
    vlc_playlist_t* playlist = m_playlist->getPlaylist().m_playlist;
    vlc_playlist_locker lock{ playlist };
    const ssize_t current = vlc_playlist_GetCurrentIndex(playlist);
    if (current < 0)
        return false;
    const size_t count = vlc_playlist_Count(playlist);
    for (size_t i = size_t(current) + 1; i < count; ++i)
    {
        // Cone's items only (the waiting one, or one queued before and gone back to with Previous)
        if (!isOwn(vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i))))
            return false;
    }
    return true;
}

// ------------------------------------------------------------------------------- decision

void RdUpNext::evaluate()
{
    const QString oldReason = m_blockedReason;
    const int oldNext = m_nextIndex;

    bool active = showActive();
    // a short clip or a weak pattern on a short file is not an episode (plan 3.3)
    if (active && m_show.minDurationSec > 0)
    {
        const VLCDuration length = m_player->getLength();
        if (length.valid() && length.toSeconds() < m_show.minDurationSec)
            active = false;
    }

    // Always remembers "yes" for a new show, once the stored answers are known (a stored "no" wins)
    if (active && m_mode == ModeAlways && m_storeLoaded && !hasAnswer())
        setAnswer(true);

    const bool enabled = active && showEnabled();
    m_blockedReason = enabled ? guardReason() : QString();

    const int next = (active && enabled) ? m_show.next() : -1;
    m_nextIndex = next;

    const bool wantItem = next >= 0 && m_blockedReason.isEmpty() && !m_cancelled;
    if (wantItem)
    {
        const QUrl url = nextUrl();
        if (!queuedPresent() || m_queuedUrl != url)
        {
            removeQueued();
            queueNext(false);
        }
    }
    else
    {
        removeQueued();
    }

    // the prompt: an unanswered show in "Ask for each show"
    if (!(active && m_mode == ModeAsk && !hasAnswer()))
        setPromptVisible(false);

    if (oldReason != m_blockedReason || oldNext != m_nextIndex)
        emit nextChanged();
    emit stateChanged();
    if (oldNext != m_nextIndex)
        requestThumbnail();
    updateCard();
}

// ---------------------------------------------------------------------------------- card

void RdUpNext::updateCard()
{
    const bool started = m_player->isStarted();

    // the prompt, early in the first episode of an unanswered show and after the resume toast
    if (showActive() && m_mode == ModeAsk && !hasAnswer() && !m_promptDone && !m_promptVisible && started)
    {
        const VLCTime time = m_player->getTime();
        if (time.valid() && time.toMilliseconds() >= kPromptDelayMs && !m_player->canRestorePlayback())
        {
            m_promptDone = true;
            setPromptVisible(true);
            m_promptTimer.start(kPromptShownMs);
        }
    }

    if (m_cardMode == CardStillWatching && m_cardVisible)
    {
        // over the paused episode it waits for an answer (or for playback, above)
        if (m_stillOnPaused)
            return;
        // in the episode before it: a seek back out of the end means the user is there
        const VLCDuration length = m_player->getLength();
        const VLCTime time = m_player->getTime();
        const qint64 limit = (m_cardPoint == 1 && m_creditsStartMs > 0)
                ? m_creditsStartMs : (length.valid() ? length.toMilliseconds() - qint64(m_countdown) * 1000 : 0);
        if (time.valid() && time.toMilliseconds() < limit - 1000)
            leaveStillWatching();
        return;
    }

    const bool armed = m_nextIndex >= 0 && m_blockedReason.isEmpty() && !m_cancelled && queuedPresent();
    if (!armed || !started)
    {
        if (!m_stillPending)
            setCard(false, CardNext);
        m_creditsTimer.stop();
        m_creditsRunning = false;
        return;
    }

    const VLCDuration length = m_player->getLength();
    const VLCTime time = m_player->getTime();
    if (!length.valid() || !time.valid())
        return;
    const qint64 lengthMs = length.toMilliseconds();
    const qint64 timeMs = time.toMilliseconds();
    const double rate = std::max(0.01f, m_player->getRate());

    // the credits chapter: the card from its start, a wall-clock countdown, then Play now
    if (m_cardPoint == 1)
    {
        if (m_creditsStartMs < 0)
        {
            ChapterListModel* chapters = m_player->getChapters();
            for (int i = 0; chapters && i < chapters->rowCount(); ++i)
            {
                const QModelIndex index = chapters->index(i);
                if (!isCreditsChapter(chapters->data(index, Qt::DisplayRole).toString()))
                    continue;
                const VLCTime start = chapters->data(index, ChapterListModel::TimeRole).value<VLCTime>();
                if (start.valid() && start.toMilliseconds() > 0 && start.toMilliseconds() < lengthMs)
                {
                    m_creditsStartMs = start.toMilliseconds();
                    break;
                }
            }
            if (m_creditsStartMs < 0)
                m_creditsStartMs = 0; // none: the end of the episode, below
        }
        if (m_creditsStartMs > 0)
        {
            if (timeMs >= m_creditsStartMs)
            {
                if (!m_creditsRunning)
                {
                    m_creditsRunning = true;
                    setSecondsLeft(m_countdown);
                    if (m_player->getPlayingState() == PlayerController::PLAYING_STATE_PLAYING)
                        m_creditsTimer.start();
                }
                if (m_autoStreak >= kStillWatchingAfter && m_stillWatching)
                {
                    m_creditsTimer.stop();
                    m_creditsRunning = false;
                    removeQueued();
                    queueNext(true);
                    m_stillPending = true;
                    setCard(true, CardStillWatching);
                    return;
                }
                setCard(true, CardNext);
            }
            else
            {
                // sought back before the credits
                m_creditsTimer.stop();
                m_creditsRunning = false;
                setCard(false, CardNext);
            }
            return;
        }
    }

    // the end of the episode: the last `countdown` seconds, in real seconds at any speed
    const qint64 remainingMs = lengthMs - timeMs;
    const int seconds = int(std::ceil(double(remainingMs) / 1000.0 / rate));
    if (remainingMs > 0 && seconds <= m_countdown)
    {
        if (m_autoStreak >= kStillWatchingAfter && m_stillWatching)
        {
            if (!m_queuedPaused)
            {
                removeQueued();
                queueNext(true);
            }
            m_stillPending = true;
            setCard(true, CardStillWatching);
            return;
        }
        setSecondsLeft(std::max(1, seconds));
        setCard(true, CardNext);
    }
    else if (!m_stillPending)
    {
        setCard(false, CardNext);
    }
}

// the languages may have changed since the item was queued: queue it again with the current ones
void RdUpNext::refreshQueued()
{
    if (!queuedPresent() || itemOptions(m_queuedPaused) == m_queuedOptions)
        return;
    const bool paused = m_queuedPaused;
    removeQueued();
    queueNext(paused);
}

void RdUpNext::setCard(bool visible, int mode)
{
    if (visible && !m_cardVisible)
        refreshQueued();
    if (visible == m_cardVisible && mode == m_cardMode)
        return;
    // "Still watching?" keeps naming the episode it holds back, also once that one is loaded
    if (visible && mode == CardStillWatching && !(m_cardVisible && m_cardMode == CardStillWatching))
        m_stillLine = nextLine();
    if (!visible || mode != CardStillWatching)
    {
        m_stillLine.clear();
        m_stillOnPaused = false;
    }
    m_cardVisible = visible;
    m_cardMode = mode;
    emit cardChanged();
    emit nextChanged();
}

void RdUpNext::leaveStillWatching()
{
    m_autoStreak = 0;
    m_stillPending = false;
    m_stillOnPaused = false;
    setCard(false, CardNext);
    if (m_queuedPaused)
    {
        removeQueued();
        queueNext(false);
    }
    evaluate();
}

void RdUpNext::setSecondsLeft(int seconds)
{
    if (seconds == m_secondsLeft)
        return;
    m_secondsLeft = seconds;
    emit countdownChanged();
}

void RdUpNext::setPromptVisible(bool visible)
{
    if (visible == m_promptVisible)
        return;
    m_promptVisible = visible;
    if (!visible)
        m_promptTimer.stop();
    emit promptChanged();
}

// ------------------------------------------------------------------------------- actions

void RdUpNext::playNow()
{
    if (!queuedPresent())
        return;
    // the rest of the episode is skipped: it counts as watched
    markWatched(m_url);
    m_creditsTimer.stop();
    m_creditsRunning = false;
    setCard(false, CardNext);
    m_playlist->next();
}

void RdUpNext::cancel()
{
    m_cancelled = true;
    m_creditsTimer.stop();
    m_creditsRunning = false;
    m_stillPending = false;
    setCard(false, CardNext);
    removeQueued();
    emit nextChanged();
}

void RdUpNext::keepWatching()
{
    const bool onPaused = m_stillOnPaused;
    leaveStillWatching();
    if (onPaused && m_player->getPlayingState() == PlayerController::PLAYING_STATE_PAUSED)
        m_playlist->togglePlayPause();
}

void RdUpNext::stopWatching()
{
    m_stillPending = false;
    setCard(false, CardNext);
    removeQueued();
    m_playlist->stop();
}

void RdUpNext::answer(bool yes)
{
    setPromptVisible(false);
    setAnswer(yes);
    evaluate();
}

void RdUpNext::dismissPrompt()
{
    setPromptVisible(false);
}

void RdUpNext::setShowEnabled(bool enabled)
{
    if (!showActive())
        return;
    if (enabled)
        m_cancelled = false;
    setAnswer(enabled);
    evaluate();
}

void RdUpNext::forgetAll()
{
    if (m_answers.isEmpty())
        return;
    m_answers.clear();
    saveStore();
    emit storeChanged();
    evaluate();
}

// ------------------------------------------------------------------------- autoplay item

QStringList RdUpNext::itemOptions(bool startPaused) const
{
    QStringList options;
    // the next episode resumes at its saved spot without the prompt; "Never" is kept
    if (config_GetInt("restore-playback-pos") != 0)
        options << QStringLiteral(":restore-playback-pos=2");
    // the languages picked in the episode carry over (a show preset can still change them)
    vlc_player_t* player = m_player->getPlayer();
    const QString audio = selectedLanguage(player, AUDIO_ES, nullptr);
    if (!audio.isEmpty())
        options << QStringLiteral(":audio-language=") + audio;
    bool subSelected = false;
    const QString sub = selectedLanguage(player, SPU_ES, &subSelected);
    if (!sub.isEmpty())
        options << QStringLiteral(":sub-language=") + sub;
    // subtitles turned off in an episode that has some: the next one starts without them
    else if (!subSelected && m_player->getSubtitleTracks()->getCount() > 0)
        options << QStringLiteral(":sub-language=none");
    if (startPaused)
        options << QStringLiteral(":start-paused");
    return options;
}

void RdUpNext::queueNext(bool startPaused)
{
    if (m_nextIndex < 0)
        return;
    const rdepisode::Episode& next = m_show.episodes.at(m_nextIndex);
    const QString mrl = episodeMrl(next.path);
    if (mrl.isEmpty())
        return;
    const QByteArray mrl8 = mrl.toUtf8();

    vlc_playlist_t* playlist = m_playlist->getPlaylist().m_playlist;
    ssize_t current;
    {
        vlc_playlist_locker lock{ playlist };
        current = vlc_playlist_GetCurrentIndex(playlist);
        if (current < 0)
            return;
        // Previous inside an autoplay run: the episode Cone queued before is still next, it is
        // taken again instead of a second row
        if (!startPaused && size_t(current) + 1 < vlc_playlist_Count(playlist))
        {
            input_item_t* after = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, size_t(current) + 1));
            if (isOwn(after) && after->psz_uri && mrl8 == after->psz_uri)
            {
                m_queued = SharedInputItem(after);
                m_queuedInput = after;
                m_queuedUrl = QUrl(mrl);
                m_queuedPaused = false;
                m_queuedOptions.clear();
                emit queuedChanged();
                return;
            }
        }
    }

    m_queuedOptions = itemOptions(startPaused);
    Media media;
    try
    {
        media = Media(mrl, next.fileName, m_queuedOptions);
    }
    catch (const std::bad_alloc&)
    {
        return;
    }
    m_queued = SharedInputItem(media.raw());
    m_queuedInput = media.raw();
    m_queuedUrl = QUrl(mrl);
    m_queuedPaused = startPaused;
    m_ownItems.append(m_queued);
    emit queuedChanged();

    try
    {
        m_playlist->insert(size_t(current) + 1, QVector<Media>{ media }, false);
    }
    catch (const std::bad_alloc&)
    {
        m_ownItems.removeLast();
        clearQueued();
    }
}

// forgets the inserted items that left the queue
void RdUpNext::pruneOwnItems()
{
    if (m_ownItems.isEmpty())
        return;
    QVector<input_item_t*> present;
    {
        vlc_playlist_t* playlist = m_playlist->getPlaylist().m_playlist;
        vlc_playlist_locker lock{ playlist };
        const size_t count = vlc_playlist_Count(playlist);
        for (size_t i = 0; i < count; ++i)
            present.append(vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i)));
    }
    m_ownItems.erase(std::remove_if(m_ownItems.begin(), m_ownItems.end(), [&present](const SharedInputItem& item) {
        return !present.contains(item.get());
    }), m_ownItems.end());
}

bool RdUpNext::isOwn(input_item_t* input) const
{
    if (!input)
        return false;
    for (const SharedInputItem& item : m_ownItems)
        if (item.get() == input)
            return true;
    return false;
}

void RdUpNext::clearQueued()
{
    const bool had = !m_queuedUrl.isEmpty();
    m_queued = SharedInputItem();
    m_queuedInput = nullptr;
    m_queuedUrl.clear();
    m_queuedPaused = false;
    if (had)
        emit queuedChanged();
}

bool RdUpNext::queuedPresent() const
{
    if (!m_queuedInput)
        return false;
    vlc_playlist_t* playlist = m_playlist->getPlaylist().m_playlist;
    vlc_playlist_locker lock{ playlist };
    const size_t count = vlc_playlist_Count(playlist);
    for (size_t i = 0; i < count; ++i)
        if (vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i)) == m_queuedInput)
            return true;
    return false;
}

void RdUpNext::removeQueued()
{
    if (!m_queuedInput)
        return;
    vlc_playlist_t* playlist = m_playlist->getPlaylist().m_playlist;
    QVector<PlaylistItem> items;
    ssize_t index = -1;
    {
        vlc_playlist_locker lock{ playlist };
        const size_t count = vlc_playlist_Count(playlist);
        for (size_t i = 0; i < count; ++i)
        {
            vlc_playlist_item_t* item = vlc_playlist_Get(playlist, i);
            if (vlc_playlist_item_GetMedia(item) == m_queuedInput)
            {
                items.append(PlaylistItem(item));
                index = ssize_t(i);
            }
        }
    }
    clearQueued();
    if (items.isEmpty())
        return;
    ++m_ownRemovals;
    try
    {
        m_playlist->remove(items, index);
    }
    catch (const std::bad_alloc&)
    {
        --m_ownRemovals;
    }
}

// the Stop button, or the end of the queue: the waiting autoplay item goes like with Cancel
void RdUpNext::onStopped()
{
    if (m_player->getPlayingState() != PlayerController::PLAYING_STATE_STOPPED)
        return;
    m_stillPending = false;
    setCard(false, CardNext);
    if (!queuedPresent())
        return;
    const PlaylistItem current = m_playlist->getCurrentItem();
    if (current && current.inputItem() == m_queuedInput)
        return;
    m_cancelled = true;
    removeQueued();
    emit nextChanged();
}

// ------------------------------------------------------------------------- queue changes

void RdUpNext::onItemsAdded(size_t, const QVector<PlaylistItem>& items)
{
    QVector<input_item_t*> foreign;
    for (const PlaylistItem& item : items)
        if (!isOwn(item.inputItem()))
            foreign.append(item.inputItem());
    if (foreign.isEmpty())
        return;
    // several at once (a folder, several files, a playlist): the user's queue
    if (foreign.size() > 1)
        m_userQueue = true;
    else
        m_lastSingleAdd = SharedInputItem(foreign.first());
    evaluate();
}

void RdUpNext::onItemsRemoved(size_t, size_t)
{
    pruneOwnItems();
    if (m_ownRemovals > 0)
    {
        --m_ownRemovals;
        return;
    }
    // the autoplay row taken out by the user is a Cancel; any other remove makes it theirs
    if (m_queuedInput && !queuedPresent())
    {
        clearQueued();
        m_cancelled = true;
        setCard(false, CardNext);
    }
    else if (!m_playlist->isEmpty())
    {
        m_userQueue = true;
    }
    evaluate();
}

void RdUpNext::onItemsMovedOrReset()
{
    if (m_playlist->isEmpty())
    {
        // the queue was cleared: a new start
        m_userQueue = false;
        m_ownItems.clear();
        clearQueued();
        return;
    }
    // a move, a sort, a shuffle, or the queue Cone found when it started with several items
    if (m_playlist->count() > 1)
        m_userQueue = true;
    evaluate();
}

// ------------------------------------------------------------------------------ library

void RdUpNext::markWatched(const QUrl& url)
{
    MediaLib* mediaLib = m_ctx ? m_ctx->getMediaLibrary() : nullptr;
    if (!mediaLib || url.isEmpty())
        return;
    const QByteArray mrl = url.toString(QUrl::FullyEncoded).toUtf8();
    mediaLib->runOnMLThread(this, [mrl](vlc_medialibrary_t* ml) {
        ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media_by_mrl(ml, mrl.constData()));
        if (media)
            vlc_ml_media_set_played(ml, media->i_id, true);
    });
}

// the next episode's picture: one thumbnailer request at 15 %, saved as a PNG in the cache
void RdUpNext::requestThumbnail()
{
    ++m_thumbGeneration;
    if (m_thumbReq)
    {
        vlc_preparser_Cancel(m_preparser, m_thumbReq);
        vlc_preparser_req_Release(m_thumbReq);
        m_thumbReq = nullptr;
    }
    if (!m_thumbnail.isEmpty())
    {
        m_thumbnail.clear();
        emit thumbnailChanged();
    }
    if (m_nextIndex < 0)
        return;

    const QFileInfo file(m_show.episodes.at(m_nextIndex).path);
    const QString dir = thumbnailDir();
    if (dir.isEmpty() || !QDir().mkpath(dir))
        return;
    const QByteArray key = QCryptographicHash::hash(
        (file.absoluteFilePath() + QString::number(file.lastModified().toMSecsSinceEpoch())).toUtf8(),
        QCryptographicHash::Sha1).toHex();
    const QString target = dir + QChar('/') + QString::fromLatin1(key) + QStringLiteral(".png");
    if (QFile::exists(target))
    {
        m_thumbnail = QUrl::fromLocalFile(target);
        emit thumbnailChanged();
        return;
    }

    if (!m_preparser)
    {
        struct vlc_preparser_cfg cfg{};
        cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
        cfg.max_parser_threads = 0;
        cfg.max_thumbnailer_threads = 1;
        cfg.timeout = VLC_TICK_FROM_SEC(10);
        cfg.external_process = false;
        m_preparser = vlc_preparser_New(VLC_OBJECT(vlc_object_instance(m_intf)), &cfg);
        if (!m_preparser)
            return;
    }

    const QByteArray mrl = episodeMrl(file.absoluteFilePath()).toUtf8();
    input_item_t* item = input_item_New(mrl.constData(), nullptr);
    if (!item)
        return;

    struct vlc_thumbnailer_arg arg{};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_POS;
    arg.seek.pos = kThumbnailPosition;
    arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    struct Job
    {
        QPointer<RdUpNext> self;
        vlc_object_t* obj;
        QString target;
        int generation;
    };
    static const struct vlc_thumbnailer_cbs cbs = {
        [](vlc_preparser_req*, int status, picture_t* picture, void* data) {
            std::unique_ptr<Job> job(static_cast<Job*>(data));
            QString saved;
            if (status == VLC_SUCCESS && picture)
            {
                block_t* block = nullptr;
                video_format_t fmt;
                video_format_Init(&fmt, 0);
                const int width = kThumbnailWidth;
                const int height = picture->format.i_visible_width > 0
                        ? int(double(width) * picture->format.i_visible_height / picture->format.i_visible_width) : width * 9 / 16;
                if (picture_Export(job->obj, &block, &fmt, picture, VLC_CODEC_PNG, width, height, false) == VLC_SUCCESS && block)
                {
                    QFile out(job->target);
                    if (out.open(QIODevice::WriteOnly) && out.write(reinterpret_cast<const char*>(block->p_buffer), qint64(block->i_buffer)) == qint64(block->i_buffer))
                        saved = job->target;
                    block_Release(block);
                }
                video_format_Clean(&fmt);
            }
            QPointer<RdUpNext> self = job->self;
            const int generation = job->generation;
            QMetaObject::invokeMethod(self.data(), [self, generation, saved]() {
                if (self)
                    self->onThumbnailDone(generation, saved);
            }, Qt::QueuedConnection);
        }
    };

    Job* job = new Job{ this, VLC_OBJECT(vlc_object_instance(m_intf)), target, m_thumbGeneration };
    vlc_preparser_req* req = vlc_preparser_req_NewThumbnail(m_preparser, item, &arg, &cbs, job);
    input_item_Release(item);
    if (!req)
    {
        delete job;
        return;
    }
    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        vlc_preparser_req_Release(req);
        delete job;
        return;
    }
    m_thumbReq = req;
}

void RdUpNext::onThumbnailDone(int generation, const QString& path)
{
    if (generation != m_thumbGeneration)
        return;
    if (m_thumbReq)
    {
        vlc_preparser_req_Release(m_thumbReq);
        m_thumbReq = nullptr;
    }
    if (path.isEmpty())
        return;
    m_thumbnail = QUrl::fromLocalFile(path);
    emit thumbnailChanged();
}

// ------------------------------------------------------------------------------ answers

QString RdUpNext::showKey() const
{
    return m_show.root.isEmpty() ? QString() : normalizedPath(m_show.root);
}

bool RdUpNext::hasAnswer() const
{
    return m_answers.contains(showKey());
}

void RdUpNext::setAnswer(bool yes)
{
    const QString key = showKey();
    if (key.isEmpty())
        return;
    Answer& answer = m_answers[key];
    answer.yes = yes;
    answer.name = m_show.name;
    answer.updated = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    saveStore();
    emit storeChanged();
    emit stateChanged();
}

void RdUpNext::loadStore(const QJsonObject& data)
{
    const QJsonObject shows = data.value(QStringLiteral("shows")).toObject();
    for (auto it = shows.begin(); it != shows.end(); ++it)
    {
        const QJsonObject entry = it.value().toObject();
        const QString choice = entry.value(QStringLiteral("choice")).toString();
        if (choice != QLatin1String("yes") && choice != QLatin1String("no"))
            continue;
        // an answer the user gave while the file was read wins
        if (m_answers.contains(it.key()))
            continue;
        Answer answer;
        answer.yes = choice == QLatin1String("yes");
        answer.name = entry.value(QStringLiteral("name")).toString();
        answer.updated = entry.value(QStringLiteral("updated")).toString();
        m_answers.insert(it.key(), answer);
    }
    m_storeLoaded = true;
    // answers given before the file was read are written now, with the stored ones
    if (m_storeDirty)
        saveStore();
    emit storeChanged();
    evaluate();
}

void RdUpNext::saveStore()
{
    // writing before the file is read would lose the other shows
    if (!m_storeLoaded)
    {
        m_storeDirty = true;
        return;
    }
    m_storeDirty = false;
    QJsonObject shows;
    for (auto it = m_answers.cbegin(); it != m_answers.cend(); ++it)
    {
        QJsonObject entry;
        entry.insert(QStringLiteral("choice"), it->yes ? QStringLiteral("yes") : QStringLiteral("no"));
        entry.insert(QStringLiteral("name"), it->name);
        entry.insert(QStringLiteral("updated"), it->updated);
        shows.insert(it.key(), entry);
    }
    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("shows"), shows);
    const QByteArray json = QJsonDocument(root).toJson(QJsonDocument::Indented);
    m_storePool.start([json]() {
        const QString path = storePath();
        if (path.isEmpty())
            return;
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            file.write(json);
    });
}

// --------------------------------------------------------------------------- user input

bool RdUpNext::eventFilter(QObject* watched, QEvent* event)
{
    switch (event->type())
    {
    case QEvent::KeyPress:
    case QEvent::MouseButtonPress:
    case QEvent::Wheel:
        m_autoStreak = 0;
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}
