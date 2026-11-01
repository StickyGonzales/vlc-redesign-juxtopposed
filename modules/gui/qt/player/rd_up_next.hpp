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

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QString>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>

#include <memory>

#include "qt.hpp"
#include "player/rd_episode_parser.hpp"
#include "playlist/media.hpp"
#include "util/shared_input_item.hpp"

class MainCtx;
class PlayerController;
class RdCreditsSubtitles;
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
 * Settings (qt.cpp): qt-autoplay-next ("Play episodes in a row", on / off), qt-autoplay-countdown
 * (5 / 10 / 15 s), qt-autoplay-credits-lead (the card's fallback point: the last 30 / 60 / 120 s)
 * and qt-autoplay-still-watching. The answer per show (yes / no) and the credits point learned
 * per show are kept per show root folder in rd-shows.json in VLC's user data folder, read and
 * written on a worker thread.
 *
 * The card shows when the credits start (rd_credits_point, UP_NEXT_PLAN.md 5.4): never before
 * the credits window, at a credits chapter, at the point learned for the show or at the set
 * point, fine-tuned by a text subtitle track. There it offers Next episode and Cancel; the
 * countdown only runs in the last `countdown` seconds, as before.
 *
 * Nothing runs while the setting is Off: no scan, no card, no item.
 */
class RdUpNext : public QObject
{
    Q_OBJECT

    // the setting "Play episodes in a row": 0 Off, 1 On
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
    // the countdown runs (the last seconds); false while the card shows during the credits
    Q_PROPERTY(bool counting READ counting NOTIFY countdownChanged FINAL)
    Q_PROPERTY(double countdownProgress READ countdownProgress NOTIFY countdownChanged FINAL)

    // the next episode plays by itself at the end (a strong name pattern: S01E02, 1x02 ...);
    // false for weak patterns (01 02, "Part 2", "Episode 2"): the card waits for a click
    Q_PROPERTY(bool autoplays READ autoplays NOTIFY nextChanged FINAL)

    // a subtitle track is on: the card sits above the subtitle band (plan 7.1)
    Q_PROPERTY(bool subtitlesOn READ subtitlesOn NOTIFY subtitlesChanged FINAL)

    // remembered answers (Settings > Playback > Episodes)
    Q_PROPERTY(int rememberedYes READ rememberedYes NOTIFY storeChanged FINAL)
    Q_PROPERTY(int rememberedNo READ rememberedNo NOTIFY storeChanged FINAL)
    // shows with a learned credits point (Forget all clears them too)
    Q_PROPERTY(int rememberedCredits READ rememberedCredits NOTIFY storeChanged FINAL)

public:
    enum Mode { ModeOff = 0, ModeOn = 1 };
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
    bool counting() const { return m_counting; }
    double countdownProgress() const;
    bool autoplays() const;
    bool subtitlesOn() const { return m_subtitlesOn; }
    int rememberedYes() const;
    int rememberedNo() const;
    int rememberedCredits() const { return int(m_learned.size()); }

    // the card's buttons
    Q_INVOKABLE void playNow();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void keepWatching();
    Q_INVOKABLE void stopWatching();
    // the card's "Turn off autoplay": the setting goes off
    Q_INVOKABLE void turnOffAutoplay();
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
    void storeChanged();
    void subtitlesChanged();
    void queuedChanged();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    // an item Cone inserted: the options it was queued with, queued paused or not
    struct OwnItem
    {
        SharedInputItem item;
        QStringList options;
        bool paused = false;
    };

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
    // decides everything from the current state: the item in the queue and the card
    void evaluate();
    // the current file is an episode Up Next acts on: a show, and not shorter than the show's
    // shortest episode (a short clip is never autoplayed, so it is not asked about either)
    bool longEnough() const;
    QString guardReason() const;
    bool queueIsCones() const;
    void updateCard();
    void setCard(bool visible, int mode);
    void setSecondsLeft(int seconds);
    void setCounting(bool counting);
    // where the credits of the episode playing start (rd_credits_point), -1 when unknown
    qint64 creditsPoint(qint64 lengthMs);
    // the text subtitle lines of the credits window, read once per episode in the background
    void startSubtitleScan(qint64 lengthMs);
    // the user went on to another episode of the show: inside the credits window, the point is
    // learned for the show
    void learnCreditsPoint(const QString& newPath);
    void setLearnedLead(const QString& key, qint64 leadMs);

    // the autoplay item
    void queueNext(bool startPaused);
    void removeQueued();
    bool queuedPresent() const;
    // forgets the autoplay item (it left the queue, or it is the media playing now)
    void clearQueued();
    // an item Cone put in the queue (the waiting one or one already played)
    bool isOwn(input_item_t* input) const;
    const OwnItem* ownItem(input_item_t* input) const;
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
    RdEffects* m_effects = nullptr;
    PlayerController* m_player = nullptr;
    vlc::playlist::PlaylistController* m_playlist = nullptr;

    // settings
    int m_mode = ModeOff;
    int m_countdown = 10;
    qint64 m_creditsLeadMs = 60 * 1000;
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
    QVector<OwnItem> m_ownItems;
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
    // that paused episode has reported PAUSED (its start may report PLAYING first)
    bool m_stillSeenPaused = false;
    // the episode "Still watching?" names (the next one once it is loaded)
    QString m_stillLine;
    // the options the autoplay item was queued with (refreshed at the card point)
    QStringList m_queuedOptions;

    bool m_subtitlesOn = false;

    QString m_blockedReason;
    bool m_cardVisible = false;
    int m_cardMode = CardNext;
    int m_secondsLeft = 0;
    bool m_counting = false;

    // the credits point of the episode playing (logged when it changes)
    qint64 m_creditsPointMs = -1;
    // the end of the dialogue the subtitle scan found in the window, -1 none
    qint64 m_dialogueEndMs = -1;
    bool m_subtitleScanStarted = false;
    std::shared_ptr<RdCreditsSubtitles> m_subtitleScan;
    // where the episode playing was last (the time and length the player reported), for learning
    qint64 m_lastTimeMs = -1;
    qint64 m_lastLengthMs = -1;
    QString m_lastShowKey;
    // the next episode at that time: only a move to it is learned
    QString m_lastNextPath;
    QString m_lastShowRoot;
    QString m_lastShowName;
    // the credits point learned per show (time before the end), keyed like the answers
    struct Learned
    {
        qint64 leadMs = 0;
        QString name;
    };
    QHash<QString, Learned> m_learned;


    // remembered answers, keyed by the show root folder
    QHash<QString, Answer> m_answers;
    // rd-shows.json is read; until then nothing is written and Always answers nothing
    bool m_storeLoaded = false;
    bool m_storeDirty = false;
    // Forget all before the file was read: its answers are not merged
    bool m_forgotten = false;
    QThreadPool m_storePool;

    // the next episode's picture (one-shot thumbnailer request)
    QUrl m_thumbnail;
    vlc_preparser_t* m_preparser = nullptr;
    vlc_preparser_req* m_thumbReq = nullptr;
    int m_thumbGeneration = 0;
};

#endif
