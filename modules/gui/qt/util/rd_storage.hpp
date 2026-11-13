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
#ifndef RD_STORAGE_HPP
#define RD_STORAGE_HPP

// Cone's own data per show and movie, kept tidy (redesign/STORAGE_CLEANUP_NOTES.md). The rules
// are in rd_storage_model.*; this applies them inside Cone while it is open:
// - a show or movie Cone has no data for is compared with the saved ones by its fingerprint;
//   a match carries its data over (Up Next's answer, track choice and credits, the subtitle
//   links, the pictures and waveforms)
// - the daily check (at most once a day, never on battery saver, never in the first minute,
//   only on drives Cone read this session): folders gone, drives that never come back,
//   downloaded subtitles unused for 30 days, the caps
// - a video that closes: its downloaded subtitles that were never selected
// - Forget all: also the pictures and the downloaded subtitles
// Every file access runs as a job of the background queue (RdBackgroundQueue).
#include "util/rd_storage_model.hpp"

#include <QFileInfo>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>

#include <functional>

struct qt_intf_t;
class PlayerController;

class RdStorage : public QObject
{
    Q_OBJECT

public:
    RdStorage(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdStorage() override;

    // the interface's (set while it exists)
    static RdStorage* instance();

    // Cone's folders of its own files (only files in them are ever deleted)
    static QString picturesDir();
    static QString waveformsDir();
    static QString downloadsDir();
    // an Up Next picture's file for a video, and a waveform's (named after the video's path,
    // size and last change: a replaced file gets new ones)
    static QString pictureFile(const QString& videoPath);
    static QString waveformFile(const QString& dir, const QFileInfo& video);
    // Windows' battery saver: background work waits
    static bool batterySaver();

    // a show or movie as seen now, with its fingerprint and volume; worker thread (it reads the
    // sizes of the files and asks the volume)
    struct Seen
    {
        rdstorage::Entry entry;
        // where its volume is mounted now (the drives Cone read this session)
        QString volumeRoot;
    };
    static Seen describeShow(const QString& root, const QStringList& episodes);
    static Seen describeMovie(const QString& path);

    // the show or movie playing: recorded, and matched with a saved one when it is new
    void seen(const Seen& seen);
    // entries from before the fingerprints (Up Next's shows): by their path only, until played
    void importLegacy(const QStringList& paths, rdstorage::Kind kind, qint64 lastPlayed);

    // Cone's files that belong to a video
    void pictureWritten(const QString& file, const QString& videoPath);
    void waveformUsed(const QString& file, const QString& videoPath);
    void downloadWritten(const QString& file, const QString& videoPath);
    // the downloaded subtitles linked to each video (files from before the registry)
    void setDownloadOwners(const QHash<QString, QString>& owners);

    // Up Next's Forget all: also the pictures and the downloaded subtitles
    void forgetAll();

signals:
    // a show or movie found at another place: its saved data moves (each matched video's old
    // key and new path in `media`)
    void relocated(const QString& oldRoot, const QString& newRoot, const QHash<QString, QString>& media);
    // shows and movies whose saved data goes (Up Next's, the subtitle links)
    void forgetEntries(const QStringList& paths);
    // deleted downloads, out of the subtitle links
    void unlinkDownloads(const QStringList& files);

private:
    void whenLoaded(std::function<void()> action);
    void scheduleSave();
    void save();
    void dailyTick();
    void apply(const rdstorage::Plan& plan, const QString& why);
    void deleteFiles(const QStringList& files);
    void renameArtifacts(const QVector<rdstorage::Moved>& moved);
    void checkPictureCap();
    void onInputChanged();
    void checkSelectedDownload();
    void log(const QString& text) const;

    qt_intf_t* m_intf;
    PlayerController* m_player;
    rdstorage::Model m_model;
    bool m_loaded = false;
    QVector<std::function<void()>> m_beforeLoad;
    // the volumes Cone read from this session (the system's among them), and where they are
    QSet<QString> m_sessionVolumes;
    QStringList m_sessionRoots;
    QString m_currentMedia;
    QTimer m_saveTimer;
    QTimer m_dailyTimer;
    bool m_dailyRunning = false;
    // changes made, and the last one written to rd-storage.json
    quint64 m_changes = 0;
    quint64 m_savedChanges = 0;
    bool m_pictureCapQueued = false;
};

#endif
