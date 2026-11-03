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
#ifndef RD_SUB_SYNC_HPP
#define RD_SUB_SYNC_HPP

// redesign (Cone build, redesign/SUBTITLE_AUTO_SYNC_NOTES.md): "Auto-sync" in the settings
// sidebar's Subtitles tab. The selected subtitle track is lined up with the speech in the
// audio, or with another subtitle track of the file, and moved with the subtitle delay (and,
// for an external file timed for another frame rate, the subtitle speed); Undo puts both back.

#include <QObject>
#include <QString>
#include <QStringList>
#include <QThreadPool>
#include <QTimer>

#include <memory>

#include "qt.hpp"

class PlayerController;
class RdSyncScanner;

class RdSubSync : public QObject
{
    Q_OBJECT

    // a subtitle track is selected in a local file: Auto-sync can run
    Q_PROPERTY(bool available READ available NOTIFY availableChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged FINAL)
    // 0 to 1 while busy
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged FINAL)
    // the last run's outcome ("Moved +2.4 s"), empty when there is none to show
    Q_PROPERTY(QString resultText READ resultText NOTIFY stateChanged FINAL)
    // the same in a few words, for the row's label ("Moved +2.4 s", "No match found")
    Q_PROPERTY(QString resultShort READ resultShort NOTIFY stateChanged FINAL)
    // the outcome moved the subtitles (not a "no match" or an error)
    Q_PROPERTY(bool moved READ moved NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY stateChanged FINAL)
    // what the track is lined up with: "Speech in the audio" first, then the file's other
    // subtitle tracks (only listed when there is one)
    Q_PROPERTY(QStringList references READ references NOTIFY referencesChanged FINAL)
    Q_PROPERTY(int reference READ reference WRITE setReference NOTIFY referencesChanged FINAL)

public:
    RdSubSync(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdSubSync() override;

    bool available() const { return m_available; }
    bool busy() const { return m_busy; }
    qreal progress() const { return m_progress; }
    QString resultText() const { return m_resultText; }
    QString resultShort() const { return m_resultShort; }
    bool moved() const { return m_moved; }
    bool canUndo() const { return m_undo.valid; }
    QStringList references() const;
    int reference() const { return m_reference; }
    void setReference(int index);

    Q_INVOKABLE void sync();
    Q_INVOKABLE void undo();
    Q_INVOKABLE void cancel();

public slots:
    // a subtitle file downloaded from OpenSubtitles was just added and selected: synced to the
    // speech when Settings > Subtitles "Auto-sync downloaded subtitles" is on (the caller checks)
    void syncDownloaded(const QByteArray& uri);

signals:
    void availableChanged();
    void stateChanged();
    void progressChanged();
    void referencesChanged();
    // a short line for the player's notification (an automatic sync, where the sidebar is
    // closed)
    void notice(const QString& text);

private:
    struct TrackRef
    {
        bool valid = false;
        QByteArray strId;
        QString name;
        bool external = false;
        // external: the file's URI; embedded: the demuxer's track id
        QByteArray uri;
        int demuxId = -1;
    };
    struct Request;
    struct Outcome;
    class Job;

    std::vector<TrackRef> subtitleTracks() const;
    TrackRef selectedSubtitle() const;
    void updateTracks();
    void start(const TrackRef& track, const QByteArray& referenceStrId, bool automatic);
    void finish(int generation, std::shared_ptr<Outcome> outcome);
    void setResult(const QString& text, bool moved, const QString& shortText = QString());
    void setBusy(bool busy);
    void clearForNewMedia();

    qt_intf_t* m_intf;
    PlayerController* m_player;
    std::unique_ptr<QThreadPool> m_pool;
    QTimer m_progressTimer;
    QTimer m_downloadRetry;

    bool m_available = false;
    bool m_busy = false;
    qreal m_progress = 0;
    QString m_resultText;
    QString m_resultShort;
    bool m_moved = false;
    int m_generation = 0;
    std::shared_ptr<RdSyncScanner> m_scanner;

    // the choices of "Sync to" beyond the speech: the file's other subtitle tracks
    std::vector<TrackRef> m_referenceTracks;
    int m_reference = 0;

    // a download waiting for its track to be listed and selected
    QByteArray m_downloadUri;
    int m_downloadLookups = 0;

    // what Undo puts back, for the media and track it was made on
    struct Undo
    {
        bool valid = false;
        QByteArray mediaUri;
        int delayMs = 0;
        float fps = 0;
        bool fpsChanged = false;
        float appliedFps = 0;
    } m_undo;
    QByteArray m_mediaUri;
};

#endif // RD_SUB_SYNC_HPP
