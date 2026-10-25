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

#ifndef RD_UP_NEXT_HPP
#define RD_UP_NEXT_HPP

#include <QHash>
#include <QObject>
#include <QString>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>

#include "qt.hpp"
#include "player/rd_episode_parser.hpp"
#include "playlist/media.hpp"
#include "util/shared_input_item.hpp"

class MainCtx;
class PlayerController;
class RdEffects;
namespace vlc { namespace playlist { class PlaylistController; } }
class PlaylistItem;
struct vlc_preparser_t;
struct vlc_preparser_req;

/**
 * Cone extra (Decision 71, redesign/UP_NEXT_PLAN.md): "Autoplay next episode", a QML singleton
 * ("RdUpNext").
 *
 * When the file playing is an episode of a show folder (rd_episode_parser, strict), the next
 * episode is put in the queue right after it as the "autoplay item", so Next, the queue and the
 * mini queue show it; near the end an Up Next card counts down, and the queue moves on to it by
 * itself (or at once with Play now). Only a queue Cone made is ever filled: the single file the
 * user opened plus autoplay items. Anything the user adds, removes or reorders makes the queue
 * theirs and autoplay steps back (UP_NEXT_PLAN.md 4.2). The guards of the conflict matrix
 * (shuffle, repeat one, a stop or quit at the end, pause on the last frame, an A-B loop, the
 * command-line flow options) take the autoplay item out and keep the card away.
 *
 * Settings (qt.cpp): qt-autoplay-next (0 Off, 1 Ask for each show, 2 Always), qt-autoplay-countdown
 * (5 / 10 / 15 s), qt-autoplay-card-point (0 end of the episode, 1 credits chapter) and
 * qt-autoplay-still-watching. The answer per show (yes / no) is kept per show root folder in
 * rd-shows.json in VLC's user data folder, read and written on a worker thread.
 *
 * Nothing runs while the setting is Off: no scan, no card, no item.
 */
class RdUpNext : public QObject
{
    Q_OBJECT

    // the setting: 0 Off, 1 Ask for each show, 2 Always
    Q_PROPERTY(int mode READ mode NOTIFY settingsChanged FINAL)
    Q_PROPERTY(int countdown READ countdown NOTIFY settingsChanged FINAL)

    // a show is playing (the sidebar row shows), its name and whether autoplay is on for it
    Q_PROPERTY(bool showActive READ showActive NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString showName READ showName NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool showEnabled READ showEnabled NOTIFY stateChanged FINAL)
    // why autoplay waits although it is on for the show ("Shuffle is on"), empty when it does not
    Q_PROPERTY(QString blockedReason READ blockedReason NOTIFY stateChanged FINAL)

    // the next episode (set while autoplay is on for the show and nothing blocks it)
    Q_PROPERTY(bool hasNext READ hasNext NOTIFY nextChanged FINAL)
    Q_PROPERTY(QString nextCode READ nextCode NOTIFY nextChanged FINAL)
    Q_PROPERTY(QString nextTitle READ nextTitle NOTIFY nextChanged FINAL)
    Q_PROPERTY(QString nextLine READ nextLine NOTIFY nextChanged FINAL)
    // the episode the card names: the next one, or with "Still watching?" the one waiting paused
    Q_PROPERTY(QString cardLine READ cardLine NOTIFY nextChanged FINAL)
    Q_PROPERTY(QUrl nextUrl READ nextUrl NOTIFY nextChanged FINAL)
    Q_PROPERTY(bool nextIsNewSeason READ nextIsNewSeason NOTIFY nextChanged FINAL)
    Q_PROPERTY(int nextSeason READ nextSeason NOTIFY nextChanged FINAL)
    Q_PROPERTY(QUrl nextThumbnail READ nextThumbnail NOTIFY thumbnailChanged FINAL)
    // the autoplay item waiting in the queue (its row's "Autoplay" label, the library's "Up
    // next" tag), empty when none
    Q_PROPERTY(QUrl queuedUrl READ queuedUrl NOTIFY queuedChanged FINAL)

    // the Up Next card: shown, its kind (0 next, 1 still watching) and the countdown
    Q_PROPERTY(bool cardVisible READ cardVisible NOTIFY cardChanged FINAL)
    Q_PROPERTY(int cardMode READ cardMode NOTIFY cardChanged FINAL)
    Q_PROPERTY(int secondsLeft READ secondsLeft NOTIFY countdownChanged FINAL)
    Q_PROPERTY(double countdownProgress READ countdownProgress NOTIFY countdownChanged FINAL)

    // the one-time "Looks like a show" prompt
    Q_PROPERTY(bool promptVisible READ promptVisible NOTIFY promptChanged FINAL)

    // a subtitle track is on: the card and the prompt sit above the subtitle band (plan 7.1)
    Q_PROPERTY(bool subtitlesOn READ subtitlesOn NOTIFY subtitlesChanged FINAL)

    // remembered answers (Settings > Playback > Episodes)
    Q_PROPERTY(int rememberedYes READ rememberedYes NOTIFY storeChanged FINAL)
    Q_PROPERTY(int rememberedNo READ rememberedNo NOTIFY storeChanged FINAL)

public:
    enum Mode { ModeOff = 0, ModeAsk = 1, ModeAlways = 2 };
    enum CardMode { CardNext = 0, CardStillWatching = 1 };
    Q_ENUM(CardMode)

    RdUpNext(qt_intf_t* intf, MainCtx* ctx, RdEffects* effects, QObject* parent = nullptr);
    ~RdUpNext() override;

    int mode() const { return m_mode; }
    int countdown() const { return m_countdown; }
    bool showActive() const;
    QString showName() const;
    bool showEnabled() const;
    QString blockedReason() const { return m_blockedReason; }
    bool hasNext() const { return m_nextIndex >= 0; }
    QString nextCode() const;
    QString nextTitle() const;
    QString nextLine() const;
    QString cardLine() const;
    QUrl nextUrl() const;
    bool nextIsNewSeason() const;
    int nextSeason() const;
    QUrl nextThumbnail() const { return m_thumbnail; }
    QUrl queuedUrl() const { return m_queuedUrl; }
    bool cardVisible() const { return m_cardVisible; }
    int cardMode() const { return m_cardMode; }
    int secondsLeft() const { return m_secondsLeft; }
    double countdownProgress() const;
    bool promptVisible() const { return m_promptVisible; }
    bool subtitlesOn() const { return m_subtitlesOn; }
    int rememberedYes() const;
    int rememberedNo() const;

    // the card's buttons
    Q_INVOKABLE void playNow();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void keepWatching();
    Q_INVOKABLE void stopWatching();
    // the prompt's buttons
    Q_INVOKABLE void answer(bool yes);
    Q_INVOKABLE void dismissPrompt();
    // the sidebar toggle: the remembered answer for the show playing
    Q_INVOKABLE void setShowEnabled(bool enabled);
    // Settings > Playback > Episodes > Remembered shows
    Q_INVOKABLE void forgetAll();

public slots:
    // the options were written (a settings row, a profile switch)
    void reloadSettings();

signals:
    void settingsChanged();
    void stateChanged();
    void nextChanged();
    void thumbnailChanged();
    void cardChanged();
    void countdownChanged();
    void promptChanged();
    void storeChanged();
    void subtitlesChanged();
    void queuedChanged();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    struct Answer
    {
        bool yes = false;
        QString name;
        QString updated;
    };

    // true when an option changed
    bool readSettings();
    void onInputChanged(bool hasInput);
    void startDetection();
    void onDetected(int generation, const rdepisode::Show& show);
    // decides everything from the current state: the item in the queue, the card, the prompt
    void evaluate();
    QString guardReason() const;
    bool queueIsCones() const;
    void updateCard();
    void setCard(bool visible, int mode);
    void setSecondsLeft(int seconds);
    void setPromptVisible(bool visible);

    // the autoplay item
    void queueNext(bool startPaused);
    void removeQueued();
    bool queuedPresent() const;
    // forgets the autoplay item (it left the queue, or it is the media playing now)
    void clearQueued();
    // an item Cone put in the queue (the waiting one or one already played)
    bool isOwn(input_item_t* input) const;
    void pruneOwnItems();
    // the user is there after all: "Still watching?" goes, the next episode is queued playing
    void leaveStillWatching();
    void refreshQueued();
    QStringList itemOptions(bool startPaused) const;

    // queue changes made by the user
    void onItemsAdded(size_t index, const QVector<PlaylistItem>& items);
    void onItemsRemoved(size_t index, size_t count);
    void onItemsMovedOrReset();
    void onStopped();

    void markWatched(const QUrl& url);
    void requestThumbnail();
    void onThumbnailDone(int generation, const QString& path);

    // the show answers
    QString showKey() const;
    bool hasAnswer() const;
    void setAnswer(bool yes);
    void loadStore(const QJsonObject& data);
    void saveStore();

    qt_intf_t* m_intf = nullptr;
    MainCtx* m_ctx = nullptr;
    PlayerController* m_player = nullptr;
    vlc::playlist::PlaylistController* m_playlist = nullptr;

    // settings
    int m_mode = ModeOff;
    int m_countdown = 10;
    int m_cardPoint = 0;
    bool m_stillWatching = true;

    // the media playing and its show
    QString m_path;
    QUrl m_url;
    rdepisode::Show m_show;
    bool m_showKnown = false;
    int m_nextIndex = -1;
    int m_generation = 0;
    QThreadPool m_scanPool;

    // the autoplay item: the media handed to the queue (held to recognise it)
    SharedInputItem m_queued;
    input_item_t* m_queuedInput = nullptr;
    QUrl m_queuedUrl;
    bool m_queuedPaused = false;
    int m_ownRemovals = 0;
    // every item Cone inserted that may still be in the queue (held, so no address is reused)
    QVector<SharedInputItem> m_ownItems;
    // the media playing came from the autoplay item, and how many in a row without the user
    bool m_currentIsAutoplay = false;
    int m_autoStreak = 0;
    // the user built the queue (several items at once, a remove, a move, a sort ...)
    bool m_userQueue = false;
    // the last item the user added alone (a single-file open plays it at once)
    SharedInputItem m_lastSingleAdd;
    // Cancel (or the autoplay row removed) for the episode playing
    bool m_cancelled = false;
    // the next episode was queued paused: "Still watching?" stays on it
    bool m_stillPending = false;
    // "Still watching?" shows over the next episode, loaded paused
    bool m_stillOnPaused = false;
    // the episode "Still watching?" names (the next one once it is loaded)
    QString m_stillLine;
    // the options the autoplay item was queued with (refreshed at the card point)
    QStringList m_queuedOptions;

    bool m_subtitlesOn = false;

    QString m_blockedReason;
    bool m_cardVisible = false;
    int m_cardMode = CardNext;
    int m_secondsLeft = 0;
    // credits chapter mode: wall-clock countdown
    QTimer m_creditsTimer;
    qint64 m_creditsStartMs = -1;
    bool m_creditsRunning = false;

    // the prompt
    bool m_promptVisible = false;
    bool m_promptDone = false;
    QTimer m_promptTimer;

    // remembered answers, keyed by the show root folder
    QHash<QString, Answer> m_answers;
    // rd-shows.json is read; until then nothing is written and Always answers nothing
    bool m_storeLoaded = false;
    bool m_storeDirty = false;
    QThreadPool m_storePool;

    // the next episode's picture (one-shot thumbnailer request)
    QUrl m_thumbnail;
    vlc_preparser_t* m_preparser = nullptr;
    vlc_preparser_req* m_thumbReq = nullptr;
    int m_thumbGeneration = 0;
};

#endif
