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
#ifndef RD_STORAGE_MODEL_HPP
#define RD_STORAGE_MODEL_HPP

// Cone's own data per show and per movie, and the rules that clean it up
// (redesign/STORAGE_CLEANUP_NOTES.md). QtCore only: no VLC, no file system access (the
// presence of a folder is asked through Probe), so every rule has a unit test
// (tests/test_rd_storage_model.cpp).
//
// - an entry: a show (its root folder) or a movie (its file), with the volume it is on (an ID,
//   never a drive letter or a mount folder), a fingerprint (the name and exact size of each
//   episode, or of the movie file), when it was last played and since when it is missing
// - artifacts: Cone's files that belong to a video: Up Next pictures, waveforms, downloaded
//   subtitles (with when they were last used and whether they were ever selected)
// - volumes: when each one was last connected
#include <QHash>
#include <QJsonObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVector>

#include <optional>

namespace rdstorage {

constexpr qint64 kDayMs = 24LL * 3600 * 1000;
// a show matches an earlier entry with at least this many episodes of the same name and size
constexpr int kMinShowMatches = 2;
// a folder gone from a drive that is there: everything tied to it goes after this many days
constexpr int kMissingDays = 14;
// a drive not connected and a show not played: pictures and waveforms go
constexpr int kDriveGoneDays = 90;
// ... and after a year the entry and its subtitle links too
constexpr int kForgetDays = 365;
// a downloaded subtitle not used for this many days goes
constexpr int kSubtitleUnusedDays = 30;
// backup caps, in case the rules cannot run (oldest first)
constexpr int kPictureCap = 300;
constexpr int kDownloadCap = 1000;

enum class Kind { Show, Movie };
enum class ArtifactKind { Picture, Waveform, Download };

struct FileId
{
    // the file name, and its path below the show's root ("Season 1/x.mkv"; the name for a movie)
    QString name;
    QString relativePath;
    qint64 size = -1;
};

struct Entry
{
    Kind kind = Kind::Show;
    // the show's root folder or the movie file, as Cone saw it
    QString path;
    // the volume it is on; empty for an entry saved before the fingerprints (until it plays)
    QString volume;
    // the fingerprint; empty for an entry saved before the fingerprints
    QVector<FileId> files;
    qint64 lastPlayed = 0;
    // when the daily check first found it gone from a volume that was there (0: not missing)
    qint64 missingSince = 0;
};

struct Artifact
{
    ArtifactKind kind = ArtifactKind::Picture;
    // the video it belongs to (Model::key of its path)
    QString media;
    // downloaded subtitles: when it was downloaded or last selected, and whether it ever was
    qint64 used = 0;
    bool selected = false;
};

// what the rules decided; the caller does it (files, the stores of Up Next and of the subtitles)
struct Plan
{
    // Cone's own files to delete (pictures, waveforms, downloaded subtitles)
    QStringList deleteFiles;
    // shows and movies whose saved data goes: Up Next's answer, track choice and credits, and the
    // subtitle links of their videos
    QStringList forgetEntries;
    // downloaded subtitles to take out of the subtitle links (deleted with deleteFiles)
    QStringList unlinkDownloads;

    bool isEmpty() const
    {
        return deleteFiles.isEmpty() && forgetEntries.isEmpty() && unlinkDownloads.isEmpty();
    }
    void merge(const Plan& other);
};

// a show or movie found again at another place (a rename, a move, a copy to another drive)
struct Match
{
    QString fromKey;
    QString toPath;
    // each matched video: its old key and its new path
    QHash<QString, QString> media;
};

// an artifact whose video moved
struct Moved
{
    QString file;
    ArtifactKind kind = ArtifactKind::Picture;
    // the key of the video's new path, and the path as seen (empty when no file matched)
    QString newMedia;
    QString newPath;
};

enum class Presence
{
    // the folder or file is there
    Present,
    // its volume is there, the folder or file is gone
    Missing,
    // its volume is not there: another one at its drive letter or mount folder, an empty mount
    // folder, or a network share that did not answer in time
    Disconnected,
    // not looked at: it would mean reading a drive Cone has not read this session
    Unchecked,
};

class Probe
{
public:
    virtual ~Probe() = default;
    // `volume` is the entry's volume, empty when not known yet; `volumeNow` receives the
    // volume of a present path
    virtual Presence presence(const QString& path, const QString& volume, QString* volumeNow) = 0;
};

// what the presence of a path is decided from: the file system, behind an interface so the
// rules are tested without drives
class FileSystem
{
public:
    enum class Answer { Yes, No, NoAnswer };
    virtual ~FileSystem() = default;
    // whether the path exists; NoAnswer when it did not answer in time (a network share)
    virtual Answer exists(const QString& path) = 0;
    // the volume of an existing path, empty when unknown
    virtual QString volumeOf(const QString& path) = 0;
};

// a folder or file of `volume` (empty: not known): there; gone from its volume, which is there
// (the nearest existing folder above it is on that volume); or its volume is not there (another
// volume at the drive letter or the mount folder, an empty mount folder: the folder above is on
// the system's volume; a share that does not answer)
Presence presenceOf(FileSystem& fs, const QString& path, const QString& volume, QString* volumeNow);

class Model
{
public:
    // the key of a path: clean, '/' separators, case folded on Windows
    static QString key(const QString& path);
    // the key of `path`'s folder is under (or is) the key `root`
    static bool under(const QString& pathKey, const QString& rootKey);

    static Model fromJson(const QJsonObject& data);
    QJsonObject toJson() const;

    bool has(const QString& path) const { return m_entries.contains(key(path)); }
    const Entry* entry(const QString& path) const;
    const QHash<QString, Entry>& entries() const { return m_entries; }
    const QHash<QString, Artifact>& artifacts() const { return m_artifacts; }
    qint64 volumeLastConnected(const QString& volume) const { return m_volumes.value(volume, 0); }
    qint64 lastDaily() const { return m_lastDaily; }

    // an entry saved before the fingerprints (Up Next's shows, the subtitle links): known by its
    // path only, until it plays
    bool importLegacy(const QString& path, Kind kind, qint64 lastPlayed);

    // a show or movie Cone plays now: its fingerprint, volume and the time
    void recordPlay(const Entry& seen, qint64 now);

    // an earlier entry with the same files at another path: at least kMinShowMatches episodes
    // of the same name and exact size for a show, the file for a movie; the best match first,
    // an entry whose folder is missing before one that is there
    std::optional<Match> findMatch(const Entry& seen) const;

    // moves the matched entry to the new path; returns the artifacts whose video moved
    QVector<Moved> relocate(const Match& match, const Entry& seen, qint64 now);

    // the volumes Cone read from this session (the system drive among them)
    void markConnected(const QSet<QString>& volumes, qint64 now);

    void addArtifact(const QString& file, ArtifactKind kind, const QString& media, qint64 now);
    void removeArtifact(const QString& file) { m_artifacts.remove(file); }
    // an artifact file renamed (a picture or waveform named after its video's new path)
    void renameArtifact(const QString& from, const QString& to);
    // the registered artifacts of one kind for one video
    QStringList artifactsOf(const QString& media, ArtifactKind kind) const;
    // a downloaded subtitle selected for its video (in use)
    void markSelected(const QString& file, qint64 now);

    // the daily check (at most once a day): folders gone from drives that are there, drives
    // that never come back, downloaded subtitles not used for 30 days, the caps
    bool dailyDue(qint64 now) const { return m_lastDaily <= 0 || now - m_lastDaily >= kDayMs; }
    Plan daily(qint64 now, Probe& probe, const QSet<QString>& connected);

    // a video closes: its downloaded subtitles that were never selected go
    Plan closed(const QString& media);

    // the caps on files that are on disk: `pictures` with their last change (all of them, also
    // the ones from before the registry), and the registered downloads by their last use
    Plan caps(const QVector<QPair<QString, qint64>>& pictures) const;

    // Forget all: every show's data, the pictures and the downloaded subtitles
    Plan forgetAll(const QStringList& pictures, const QStringList& downloads);

    // everything tied to one entry
    Plan forget(const QString& entryKey);
    // its pictures and waveforms only (Cone makes them again if the show comes back)
    Plan dropRebuildable(const QString& entryKey);

    // takes the files of a plan out of the registry (the caller deleted them)
    void applied(const Plan& plan);

private:
    bool belongs(const Artifact& artifact, const QString& entryKey, const Entry& entry) const;

    QHash<QString, Entry> m_entries;
    QHash<QString, qint64> m_volumes;
    QHash<QString, Artifact> m_artifacts;
    qint64 m_lastDaily = 0;
};

} // namespace rdstorage

#endif
