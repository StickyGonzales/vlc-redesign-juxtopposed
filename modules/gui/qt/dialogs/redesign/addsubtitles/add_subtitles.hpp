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

#ifndef ADD_SUBTITLES_HPP
#define ADD_SUBTITLES_HPP

#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QThreadPool>
#include <QUrl>
#include <QVariant>
#include <QVector>

#include <functional>
#include <memory>

#include "qt.hpp"

#include "add_subtitles_model.hpp"
#include "opensubtitles.hpp"
#include "subtitle_matcher.hpp"
#include "subtitle_store.hpp"

class RdStorage;

/**
 * redesign (Add Subtitles, W6.5; video 6:02-6:24, Figma "Add Subtitles to Playlist/Folder"):
 * the dialog's logic, a QML singleton ("AddSubtitles").
 *
 * - Target (first dropdown): this file, the videos of its folder, or the videos of a playlist
 *   (the play queue, or the playlist the dialog was opened for).
 * - Source (second dropdown): a folder of the computer, an OpenSubtitles search (needs the
 *   user's API key, Settings > Subtitles), or a link to a subtitle file.
 * - "To This File" lists the subtitle files to check; "To This Folder / Playlist" matches one
 *   subtitle to each video (SubtitleMatcher) and lets the user swap a match by hand.
 * - Save adds the subtitles to the playing video and keeps them (SubtitleStore): every time a
 *   video plays later, its subtitles are added again, and the videos of a folder that has
 *   subtitles saved get theirs matched the same way, new episodes included (P3-08 / P3-09).
 *
 * Folder reading, matching and web requests run on worker threads; the interface thread only
 * swaps finished results in.
 */
class AddSubtitles : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int target READ target WRITE setTarget NOTIFY targetChanged FINAL)
    Q_PROPERTY(int source READ source WRITE setSource NOTIFY sourceChanged FINAL)

    // the targets the dialog was opened with can use
    Q_PROPERTY(bool fileAvailable READ fileAvailable NOTIFY requestChanged FINAL)
    Q_PROPERTY(bool folderAvailable READ folderAvailable NOTIFY requestChanged FINAL)
    Q_PROPERTY(bool playlistAvailable READ playlistAvailable NOTIFY requestChanged FINAL)

    // From Computer: the folder the subtitles are read from, as "Videos / Shows / The Wand"
    Q_PROPERTY(QString folderPath READ folderPath NOTIFY folderChanged FINAL)
    // From OpenSubtitles: the search text and language (two letter code)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged FINAL)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged FINAL)
    // [{ code, name }] of the OpenSubtitles languages
    Q_PROPERTY(QVariantList languages READ languages CONSTANT FINAL)

    Q_PROPERTY(AddSubtitlesModel* files READ files CONSTANT FINAL)
    Q_PROPERTY(AddSubtitlesModel* matches READ matches CONSTANT FINAL)

    // reading, searching, downloading
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    Q_PROPERTY(bool saving READ saving NOTIFY busyChanged FINAL)
    // what the body says when its list is empty (or why it is)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged FINAL)
    Q_PROPERTY(bool canSave READ canSave NOTIFY canSaveChanged FINAL)

    // the OpenSubtitles account (Settings > Subtitles); the source is off without an API key
    Q_PROPERTY(bool openSubtitlesEnabled READ openSubtitlesEnabled NOTIFY accountChanged FINAL)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY accountChanged FINAL)
    Q_PROPERTY(QString username READ username WRITE setUsername NOTIFY accountChanged FINAL)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY accountChanged FINAL)
    // redesign (Cone build, SUBTITLE_AUTO_SYNC_NOTES.md): a file downloaded from OpenSubtitles
    // for the video playing is auto-synced to its speech (off by default)
    Q_PROPERTY(bool autoSyncDownloads READ autoSyncDownloads WRITE setAutoSyncDownloads NOTIFY autoSyncDownloadsChanged FINAL)

public:
    enum Target { TargetFile = 0, TargetFolder = 1, TargetPlaylist = 2 };
    Q_ENUM(Target)
    enum Source { SourceComputer = 0, SourceOpenSubtitles = 1, SourceLink = 2 };
    Q_ENUM(Source)

    explicit AddSubtitles(qt_intf_t* intf, QObject* parent = nullptr);
    ~AddSubtitles() override;

    int target() const { return m_target; }
    void setTarget(int target);
    int source() const { return m_source; }
    void setSource(int source);

    bool fileAvailable() const { return !m_mrl.isEmpty(); }
    bool folderAvailable() const { return !m_videoFolder.isEmpty(); }
    bool playlistAvailable() const { return !m_playlistItems.isEmpty(); }

    QString folderPath() const;
    QString searchText() const { return m_searchText; }
    void setSearchText(const QString& text);
    QString language() const { return m_language; }
    void setLanguage(const QString& language);
    QVariantList languages() const;

    AddSubtitlesModel* files() { return &m_files; }
    AddSubtitlesModel* matches() { return &m_matches; }

    bool busy() const { return m_busyCount > 0; }
    bool saving() const { return m_saving; }
    QString message() const { return m_message; }
    bool canSave() const;

    bool openSubtitlesEnabled() const { return m_account.enabled(); }
    QString apiKey() const { return m_account.apiKey; }
    void setApiKey(const QString& key);
    QString username() const { return m_account.username; }
    void setUsername(const QString& username);
    QString password() const { return m_account.password; }
    void setPassword(const QString& password);
    bool autoSyncDownloads() const { return m_autoSyncDownloads; }
    void setAutoSyncDownloads(bool on);

    // asks the dialog to open: { mrl, target ("file", "folder", "playlist"), folder (mrl),
    // items ([mrl], the playlist's media), title (of the playlist) }; without a media, for the
    // one playing, with the play queue as its playlist
    Q_INVOKABLE void open(const QVariantMap& request = {});

    // From Computer: picks the folder the subtitles are read from
    Q_INVOKABLE void chooseFolder();
    // files or folders dropped on the dialog
    Q_INVOKABLE void addDropped(const QList<QUrl>& urls);
    // From OpenSubtitles: searches with the search text and language
    Q_INVOKABLE void search();
    // From Link: downloads the subtitle file of a link
    Q_INVOKABLE void addLink(const QString& link);

    // To This File: checks or unchecks a row
    Q_INVOKABLE void toggle(int row);
    // To This Folder / Playlist: the subtitles a row can be matched to, best first:
    // [{ candidate, name, matched, current }], "No subtitles" (candidate -1) last
    Q_INVOKABLE QVariantList choices(int row) const;
    // matches a row by hand (-1: no subtitle)
    Q_INVOKABLE void choose(int row, int candidate);

    Q_INVOKABLE void save();
    // the dialog closed without saving: stops what is still running
    Q_INVOKABLE void cancel();

    // Cone's own data kept tidy (STORAGE_CLEANUP_NOTES.md): each download is registered with
    // its video; a show or movie found at another place takes its links along; a forgotten one
    // drops them; deleted downloads leave every link
    void setStorage(RdStorage* storage);

signals:
    void openRequested();
    // the dialog's work is done: it closes
    void saved();

    void targetChanged();
    void sourceChanged();
    void requestChanged();
    void folderChanged();
    void searchTextChanged();
    void languageChanged();
    void busyChanged();
    void messageChanged();
    void canSaveChanged();
    void accountChanged();
    void autoSyncDownloadsChanged();
    // a subtitle file just downloaded from OpenSubtitles was added to the video playing and is
    // being selected, and "Auto-sync downloaded subtitles" is on
    void downloadAttached(const QByteArray& uri);

private:
    struct Candidate
    {
        QString name;
        // local path, or empty for an OpenSubtitles result (fileId)
        QString path;
        qint64 fileId = 0;
        SubtitleMatcher::Name parsed;
    };

    struct Video
    {
        QString name;
        QString mrl;
        SubtitleMatcher::Name parsed;
    };

    // a running worker job, cancelled through its VLC interrupt context
    struct Job;

    using Work = std::function<void(vlc_object_t*)>;
    using Done = std::function<void()>;
    // runs `work` on a worker thread, then `done` on this thread; a `tracked` job belongs to the
    // dialog (busy state, dropped when a newer request replaced it); a job making `requests` web
    // requests is stopped when they take longer than 30 s each
    void run(Work work, Done done, int requests, bool tracked = true);
    void cancelJobs();

    void setMessage(const QString& message);
    void setBusy(bool busy);
    void loadComputerFolder(const QString& path, const QStringList& preselect = {});
    void loadVideos();
    void rebuild();
    void updateMessage();
    const QVector<Candidate>& pool() const;
    SubtitleMatcher::Preference preference() const;
    QString defaultSearchText() const;
    void saveAccount();
    void writeStore();
    // a change asked by the storage cleanup; waits until the store is read
    void whenStoreLoaded(std::function<void()> action);

    // playback: adds the saved subtitles of the media that starts
    void onInputChanged(bool hasInput);
    void onPlayingStateChanged();
    void applyTo(const QString& mrl);
    // `downloaded`: the files were just downloaded from OpenSubtitles
    void attach(const QString& mrl, const QStringList& subtitles, bool select, bool downloaded = false);

    qt_intf_t* m_intf;
    QThreadPool m_pool;
    // the store's file is written by one thread, in order
    QThreadPool m_storePool;
    QList<std::shared_ptr<Job>> m_jobs;
    // results of older requests are dropped
    int m_generation = 0;
    // the folder rows of an older rebuild are dropped
    int m_rebuildSerial = 0;
    int m_busyCount = 0;
    bool m_saving = false;
    bool m_autoSyncDownloads = false;

    int m_target = TargetFile;
    int m_source = SourceComputer;

    // the request
    QString m_mrl;
    QString m_videoFolder;
    QStringList m_playlistItems;

    QString m_computerFolder;
    QString m_searchText;
    // the OpenSubtitles source has searched since the dialog opened
    bool m_searched = false;
    QString m_language;
    // VLC's preferred subtitle language ("sub-language"), as a two letter code
    QString m_preferredLanguage;
    OpenSubtitles::Account m_account;

    QVector<Candidate> m_computer;
    QVector<Candidate> m_online;
    QVector<Candidate> m_links;
    QVector<Video> m_folderVideos;
    QVector<Video> m_playlistVideos;
    // the checked candidates ("To This File") and the hand-made matches ("To This Folder"),
    // per source, so switching back and forth keeps them
    QHash<int, QSet<int>> m_selected;
    QHash<int, QHash<QString, int>> m_manual;
    QString m_sourceError;

    AddSubtitlesModel m_files;
    AddSubtitlesModel m_matches;
    QString m_message;

    SubtitleStore m_store;
    bool m_storeLoaded = false;
    QVector<std::function<void()>> m_afterStoreLoad;
    RdStorage* m_storage = nullptr;
    // playback: the media whose subtitles are added once it plays
    QString m_pendingApply;
};

#endif // ADD_SUBTITLES_HPP
