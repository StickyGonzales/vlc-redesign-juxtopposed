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

// Cone's storage cleanup rules (redesign/STORAGE_CLEANUP_NOTES.md). QtCore only: the drives are a
// fake file system.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "util/rd_storage_model.hpp"

#include <QHash>
#include <QJsonDocument>

#include <cstdio>

using namespace rdstorage;

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const char* what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::printf("FAIL: %s\n", what);
    }
}

constexpr qint64 T0 = 1700000000000LL;

qint64 days(double count)
{
    return qint64(count * kDayMs);
}

// a file system of paths and the volume each existing path is on; a path can be made slow
// (a network share that does not answer)
class FakeFs : public FileSystem
{
public:
    void add(const QString& path, const QString& volume) { m_paths.insert(path, volume); }
    void remove(const QString& path) { m_paths.remove(path); }
    void slow(const QString& prefix) { m_slow.append(prefix); }

    Answer exists(const QString& path) override
    {
        for (const QString& prefix : m_slow)
            if (path.startsWith(prefix))
                return Answer::NoAnswer;
        return m_paths.contains(path) ? Answer::Yes : Answer::No;
    }
    QString volumeOf(const QString& path) override { return m_paths.value(path); }

private:
    QHash<QString, QString> m_paths;
    QStringList m_slow;
};

class FsProbe : public Probe
{
public:
    explicit FsProbe(FakeFs& fs) : m_fs(fs) {}
    Presence presence(const QString& path, const QString& volume, QString* volumeNow) override
    {
        return presenceOf(m_fs, path, volume, volumeNow);
    }

private:
    FakeFs& m_fs;
};

FileId file(const QString& relative, qint64 size)
{
    FileId id;
    id.relativePath = relative;
    id.name = relative.mid(relative.lastIndexOf(QLatin1Char('/')) + 1);
    id.size = size;
    return id;
}

Entry show(const QString& root, const QString& volume, const QVector<FileId>& files)
{
    Entry entry;
    entry.kind = Kind::Show;
    entry.path = root;
    entry.volume = volume;
    entry.files = files;
    return entry;
}

Entry movie(const QString& path, const QString& volume, qint64 size)
{
    Entry entry;
    entry.kind = Kind::Movie;
    entry.path = path;
    entry.volume = volume;
    entry.files = { file(path.mid(path.lastIndexOf(QLatin1Char('/')) + 1), size) };
    return entry;
}

const QVector<FileId> kEpisodes = {
    file(QStringLiteral("Season 1/Show S01E01.mkv"), 1001),
    file(QStringLiteral("Season 1/Show S01E02.mkv"), 1002),
    file(QStringLiteral("Season 1/Show S01E03.mkv"), 1003),
};

// a renamed show folder: the entry, its pictures and waveforms follow, the old key is gone
void testRenamedShow()
{
    Model model;
    model.recordPlay(show(QStringLiteral("/data/Shows/Old Name"), QStringLiteral("V1"), kEpisodes), T0);
    model.addArtifact(QStringLiteral("/cache/up-next/a.png"), ArtifactKind::Picture,
                      QStringLiteral("/data/Shows/Old Name/Season 1/Show S01E02.mkv"), T0);
    model.addArtifact(QStringLiteral("/data/waveforms/b.wf"), ArtifactKind::Waveform,
                      QStringLiteral("/data/Shows/Old Name/Season 1/Show S01E01.mkv"), T0);

    const Entry seen = show(QStringLiteral("/data/Shows/New Name"), QStringLiteral("V1"), kEpisodes);
    check(!model.has(seen.path), "renamed show: no entry at the new folder yet");
    const std::optional<Match> match = model.findMatch(seen);
    check(match.has_value(), "renamed show: matched by its episodes");
    if (!match)
        return;
    check(match->fromKey == Model::key(QStringLiteral("/data/Shows/Old Name")), "renamed show: the old folder");
    check(match->media.size() == 3, "renamed show: three episodes mapped");
    const QVector<Moved> moved = model.relocate(*match, seen, T0 + days(1));
    check(model.has(seen.path) && !model.has(QStringLiteral("/data/Shows/Old Name")), "renamed show: the entry moved");
    check(moved.size() == 2, "renamed show: the picture and the waveform follow");
    bool picture = false;
    for (const Moved& m : moved)
        if (m.file == QLatin1String("/cache/up-next/a.png"))
            picture = m.newMedia == Model::key(QStringLiteral("/data/Shows/New Name/Season 1/Show S01E02.mkv"));
    check(picture, "renamed show: the picture names the episode in the new folder");
}

// a show copied to another drive with one episode less and one more: still 2 in common
void testShowOtherDrive()
{
    Model model;
    model.recordPlay(show(QStringLiteral("D:/TV/Show"), QStringLiteral("VOL-D"), kEpisodes), T0);
    const Entry seen = show(QStringLiteral("E:/Archive/Show"), QStringLiteral("VOL-E"), {
        file(QStringLiteral("Show S01E01.mkv"), 1001),
        file(QStringLiteral("Show S01E02.mkv"), 1002),
        file(QStringLiteral("Show S01E04.mkv"), 1004),
    });
    const std::optional<Match> match = model.findMatch(seen);
    check(match.has_value(), "other drive: two episodes match by name and size");
    if (match)
    {
        model.relocate(*match, seen, T0 + days(2));
        const Entry* entry = model.entry(seen.path);
        check(entry && entry->volume == QLatin1String("VOL-E"), "other drive: the entry takes the new volume");
    }

    // one episode in common, or the same names with other sizes, is not the same show
    Model other;
    other.recordPlay(show(QStringLiteral("D:/TV/Show"), QStringLiteral("VOL-D"), kEpisodes), T0);
    const Entry one = show(QStringLiteral("E:/X"), QStringLiteral("VOL-E"), {
        file(QStringLiteral("Show S01E01.mkv"), 1001), file(QStringLiteral("Show S01E02.mkv"), 5555) });
    check(!other.findMatch(one).has_value(), "other drive: one episode of the same size is not enough");
}

// a movie in a renamed folder: the file of the same name and size
void testRenamedMovie()
{
    Model model;
    model.recordPlay(movie(QStringLiteral("/m/Film/Film.mkv"), QStringLiteral("V1"), 7777), T0);
    model.addArtifact(QStringLiteral("/subs/1-film.srt"), ArtifactKind::Download, QStringLiteral("/m/Film/Film.mkv"), T0);
    const Entry seen = movie(QStringLiteral("/m/Film (2024)/Film.mkv"), QStringLiteral("V1"), 7777);
    const std::optional<Match> match = model.findMatch(seen);
    check(match.has_value(), "renamed movie: the file matches");
    if (match)
    {
        const QVector<Moved> moved = model.relocate(*match, seen, T0);
        check(moved.size() == 1 && moved.first().kind == ArtifactKind::Download,
              "renamed movie: its downloaded subtitle follows");
    }
    check(!model.findMatch(movie(QStringLiteral("/m/Other.mkv"), QStringLiteral("V1"), 7778)).has_value(),
          "renamed movie: another size is another movie");
}

// a drive back under another letter: the old path is not "missing" (another volume or no drive
// at the old letter), and the show found at the new letter takes its data
void testDriveNewLetter()
{
    FakeFs fs;
    fs.add(QStringLiteral("C:/"), QStringLiteral("SYSTEM"));
    fs.add(QStringLiteral("F:/"), QStringLiteral("USB-1"));
    fs.add(QStringLiteral("F:/Shows/Show"), QStringLiteral("USB-1"));
    FsProbe probe(fs);

    Model model;
    model.recordPlay(show(QStringLiteral("E:/Shows/Show"), QStringLiteral("USB-1"), kEpisodes), T0);
    model.daily(T0 + days(1), probe, { QStringLiteral("SYSTEM"), QStringLiteral("USB-1") });
    const Entry* entry = model.entry(QStringLiteral("E:/Shows/Show"));
    check(entry && entry->missingSince == 0, "new letter: no drive at E: is not a missing folder");

    // another drive now at E:, with no such folder: still not missing
    fs.add(QStringLiteral("E:/"), QStringLiteral("OTHER"));
    model.daily(T0 + days(2), probe, { QStringLiteral("SYSTEM"), QStringLiteral("USB-1"), QStringLiteral("OTHER") });
    entry = model.entry(QStringLiteral("E:/Shows/Show"));
    check(entry && entry->missingSince == 0, "new letter: another volume at E: is not a missing folder");

    const std::optional<Match> match = model.findMatch(show(QStringLiteral("F:/Shows/Show"), QStringLiteral("USB-1"), kEpisodes));
    check(match.has_value(), "new letter: the show at F: matches");
}

// an empty mount folder (the drive is not mounted): the folder above is on the system's volume
void testEmptyMountFolder()
{
    FakeFs fs;
    fs.add(QStringLiteral("/"), QStringLiteral("ROOT"));
    fs.add(QStringLiteral("/mnt"), QStringLiteral("ROOT"));
    fs.add(QStringLiteral("/mnt/usb"), QStringLiteral("ROOT"));
    FsProbe probe(fs);
    QString now;
    check(presenceOf(fs, QStringLiteral("/mnt/usb/Shows/Show"), QStringLiteral("USB-UUID"), &now) == Presence::Disconnected,
          "empty mount folder: disconnected, not missing");

    Model model;
    model.recordPlay(show(QStringLiteral("/mnt/usb/Shows/Show"), QStringLiteral("USB-UUID"), kEpisodes), T0);
    for (int day = 1; day <= 20; ++day)
        model.daily(T0 + days(day), probe, { QStringLiteral("ROOT"), QStringLiteral("USB-UUID") });
    check(model.has(QStringLiteral("/mnt/usb/Shows/Show")), "empty mount folder: kept after 20 days");

    // mounted again, the folder deleted: missing
    fs.add(QStringLiteral("/mnt/usb"), QStringLiteral("USB-UUID"));
    check(presenceOf(fs, QStringLiteral("/mnt/usb/Shows/Show"), QStringLiteral("USB-UUID"), &now) == Presence::Missing,
          "empty mount folder: mounted, the folder gone: missing");
}

// a network share that does not answer in time: like a disconnected drive
void testSlowShare()
{
    FakeFs fs;
    fs.add(QStringLiteral("//nas/media"), QStringLiteral("net://nas/media"));
    fs.slow(QStringLiteral("//nas/"));
    FsProbe probe(fs);
    QString now;
    check(presenceOf(fs, QStringLiteral("//nas/media/Show"), QStringLiteral("net://nas/media"), &now) == Presence::Disconnected,
          "slow share: disconnected");
    Model model;
    model.recordPlay(show(QStringLiteral("//nas/media/Show"), QStringLiteral("net://nas/media"), kEpisodes), T0);
    for (int day = 1; day <= 20; ++day)
        model.daily(T0 + days(day), probe, { QStringLiteral("net://nas/media") });
    const Entry* entry = model.entry(QStringLiteral("//nas/media/Show"));
    check(entry && entry->missingSince == 0, "slow share: never marked missing");
}

// a show deleted from a drive that is there: missing from the first check, everything tied to
// it goes 14 days later (not before)
void testDeletedShow()
{
    FakeFs fs;
    fs.add(QStringLiteral("/"), QStringLiteral("ROOT"));
    fs.add(QStringLiteral("/home"), QStringLiteral("ROOT"));
    fs.add(QStringLiteral("/home/u"), QStringLiteral("ROOT"));
    fs.add(QStringLiteral("/home/u/Show"), QStringLiteral("ROOT"));
    FsProbe probe(fs);
    const QSet<QString> connected = { QStringLiteral("ROOT") };

    Model model;
    model.recordPlay(show(QStringLiteral("/home/u/Show"), QStringLiteral("ROOT"), kEpisodes), T0);
    model.addArtifact(QStringLiteral("/c/p.png"), ArtifactKind::Picture, QStringLiteral("/home/u/Show/Season 1/Show S01E02.mkv"), T0);
    model.addArtifact(QStringLiteral("/d/w.wf"), ArtifactKind::Waveform, QStringLiteral("/home/u/Show/Season 1/Show S01E01.mkv"), T0);
    model.addArtifact(QStringLiteral("/d/s.srt"), ArtifactKind::Download, QStringLiteral("/home/u/Show/Season 1/Show S01E01.mkv"), T0);
    model.markSelected(QStringLiteral("/d/s.srt"), T0);
    model.addArtifact(QStringLiteral("/c/other.png"), ArtifactKind::Picture, QStringLiteral("/home/u/Show 2/x.mkv"), T0);

    check(model.daily(T0 + days(1), probe, connected).isEmpty(), "deleted show: there, nothing to do");
    fs.remove(QStringLiteral("/home/u/Show"));
    Plan plan = model.daily(T0 + days(2), probe, connected);
    check(plan.isEmpty() && model.entry(QStringLiteral("/home/u/Show"))->missingSince == T0 + days(2),
          "deleted show: marked missing");
    plan = model.daily(T0 + days(15.9), probe, connected);
    check(plan.forgetEntries.isEmpty(), "deleted show: kept 13.9 days after");
    plan = model.daily(T0 + days(16), probe, connected);
    check(plan.forgetEntries == QStringList{ QStringLiteral("/home/u/Show") }, "deleted show: forgotten after 14 days");
    check(plan.deleteFiles.contains(QStringLiteral("/c/p.png")) && plan.deleteFiles.contains(QStringLiteral("/d/w.wf"))
          && plan.deleteFiles.contains(QStringLiteral("/d/s.srt")), "deleted show: its picture, waveform and subtitle go");
    check(plan.unlinkDownloads == QStringList{ QStringLiteral("/d/s.srt") }, "deleted show: its subtitle link goes");
    check(!plan.deleteFiles.contains(QStringLiteral("/c/other.png")), "deleted show: \"Show 2\" is another show");
    model.applied(plan);
    check(!model.has(QStringLiteral("/home/u/Show")) && model.artifacts().size() == 1, "deleted show: the registry forgets it");

    // found again (moved) before the 14 days: matched, never forgotten
    Model again;
    again.recordPlay(show(QStringLiteral("/home/u/Show"), QStringLiteral("ROOT"), kEpisodes), T0);
    again.daily(T0 + days(2), probe, connected);
    const Entry moved = show(QStringLiteral("/home/u/Moved"), QStringLiteral("ROOT"), kEpisodes);
    if (const std::optional<Match> match = again.findMatch(moved))
        again.relocate(*match, moved, T0 + days(3));
    fs.add(QStringLiteral("/home/u/Moved"), QStringLiteral("ROOT"));
    check(again.daily(T0 + days(30), probe, connected).forgetEntries.isEmpty() && again.has(moved.path),
          "deleted show: one moved within 14 days is kept");
}

// a drive that never comes back: 90 days (pictures and waveforms), a year (everything)
void testDriveGone()
{
    FakeFs fs;
    FsProbe probe(fs);
    Model model;
    model.recordPlay(show(QStringLiteral("G:/Show"), QStringLiteral("USB-G"), kEpisodes), T0);
    model.markConnected({ QStringLiteral("USB-G") }, T0);
    model.addArtifact(QStringLiteral("p.png"), ArtifactKind::Picture, QStringLiteral("G:/Show/Season 1/Show S01E02.mkv"), T0);
    model.addArtifact(QStringLiteral("w.wf"), ArtifactKind::Waveform, QStringLiteral("G:/Show/Season 1/Show S01E01.mkv"), T0);
    model.addArtifact(QStringLiteral("s.srt"), ArtifactKind::Download, QStringLiteral("G:/Show/Season 1/Show S01E01.mkv"), T0);
    model.markSelected(QStringLiteral("s.srt"), T0 + days(80));

    Plan plan = model.daily(T0 + days(89), probe, {});
    check(plan.deleteFiles.isEmpty(), "drive gone: nothing after 89 days");
    plan = model.daily(T0 + days(90), probe, {});
    check(plan.deleteFiles.contains(QStringLiteral("p.png")) && plan.deleteFiles.contains(QStringLiteral("w.wf"))
          && plan.forgetEntries.isEmpty(), "drive gone: pictures and waveforms after 90 days, the entry stays");
    check(!plan.deleteFiles.contains(QStringLiteral("s.srt")), "drive gone: the subtitle used on day 80 stays");
    model.applied(plan);
    check(model.has(QStringLiteral("G:/Show")), "drive gone: the entry kept at 90 days");
    plan = model.daily(T0 + days(365), probe, {});
    check(plan.forgetEntries == QStringList{ QStringLiteral("G:/Show") }, "drive gone: forgotten after a year");

    // played on another computer's copy? No: played here recently keeps it (the newer of both)
    Model played;
    played.recordPlay(show(QStringLiteral("G:/Show"), QStringLiteral("USB-G"), kEpisodes), T0 + days(100));
    played.markConnected({ QStringLiteral("USB-G") }, T0);
    check(played.daily(T0 + days(150), probe, {}).isEmpty(), "drive gone: counted from the last play");

    // an entry from before the volumes (no volume): from its last play
    Model legacy;
    legacy.importLegacy(QStringLiteral("H:/Old Show"), Kind::Show, T0);
    legacy.addArtifact(QStringLiteral("old.png"), ArtifactKind::Picture, QStringLiteral("H:/Old Show/e1.mkv"), T0);
    check(legacy.daily(T0 + days(91), probe, {}).deleteFiles == QStringList{ QStringLiteral("old.png") },
          "drive gone: a legacy entry's pictures after 90 days from its last play");
    check(legacy.daily(T0 + days(366), probe, {}).forgetEntries == QStringList{ QStringLiteral("H:/Old Show") },
          "drive gone: a legacy entry forgotten after a year");

    // a legacy entry seen on a drive Cone reads: its volume is recorded
    FakeFs here;
    here.add(QStringLiteral("/v/Show"), QStringLiteral("ROOT"));
    FsProbe hereProbe(here);
    Model seen;
    seen.importLegacy(QStringLiteral("/v/Show"), Kind::Show, T0);
    seen.daily(T0 + days(1), hereProbe, { QStringLiteral("ROOT") });
    check(seen.entry(QStringLiteral("/v/Show"))->volume == QLatin1String("ROOT"), "legacy: the volume is recorded when seen");
}

// downloaded subtitles: not selected when the video closes, not used for 30 days
void testSubtitles()
{
    FakeFs fs;
    FsProbe probe(fs);
    Model model;
    model.addArtifact(QStringLiteral("a.srt"), ArtifactKind::Download, QStringLiteral("/v/e1.mkv"), T0);
    model.addArtifact(QStringLiteral("b.srt"), ArtifactKind::Download, QStringLiteral("/v/e1.mkv"), T0);
    model.addArtifact(QStringLiteral("c.srt"), ArtifactKind::Download, QStringLiteral("/v/e2.mkv"), T0);
    model.markSelected(QStringLiteral("a.srt"), T0);
    const Plan closed = model.closed(QStringLiteral("/v/e1.mkv"));
    check(closed.deleteFiles == QStringList{ QStringLiteral("b.srt") } && closed.unlinkDownloads == closed.deleteFiles,
          "subtitles: the unselected download of the closed video goes, the one in use stays");
    model.applied(closed);

    check(model.daily(T0 + days(29), probe, {}).deleteFiles.isEmpty(), "subtitles: kept 29 days");
    model.markSelected(QStringLiteral("a.srt"), T0 + days(20));
    const Plan aged = model.daily(T0 + days(30), probe, {});
    check(aged.deleteFiles == QStringList{ QStringLiteral("c.srt") }, "subtitles: unused for 30 days goes, used on day 20 stays");
    check(aged.unlinkDownloads == aged.deleteFiles, "subtitles: its link goes too");
}

void testCaps()
{
    Model model;
    QVector<QPair<QString, qint64>> pictures;
    for (int i = 0; i < kPictureCap + 5; ++i)
        pictures.append({ QStringLiteral("p%1.png").arg(i), T0 + i });
    for (int i = 0; i < kDownloadCap + 3; ++i)
        model.addArtifact(QStringLiteral("s%1.srt").arg(i), ArtifactKind::Download, QStringLiteral("/v/x.mkv"), T0 + i);
    const Plan plan = model.caps(pictures);
    check(plan.deleteFiles.contains(QStringLiteral("p0.png")) && plan.deleteFiles.contains(QStringLiteral("p4.png"))
          && !plan.deleteFiles.contains(QStringLiteral("p5.png")), "caps: the 5 oldest pictures over 300");
    check(plan.unlinkDownloads.size() == 3 && plan.unlinkDownloads.contains(QStringLiteral("s0.srt"))
          && !plan.unlinkDownloads.contains(QStringLiteral("s3.srt")), "caps: the 3 oldest downloads over 1,000");
}

void testForgetAll()
{
    Model model;
    model.recordPlay(show(QStringLiteral("/s/Show"), QStringLiteral("V"), kEpisodes), T0);
    model.recordPlay(movie(QStringLiteral("/m/Film.mkv"), QStringLiteral("V"), 9), T0);
    model.addArtifact(QStringLiteral("w.wf"), ArtifactKind::Waveform, QStringLiteral("/m/Film.mkv"), T0);
    model.addArtifact(QStringLiteral("p.png"), ArtifactKind::Picture, QStringLiteral("/s/Show/e2.mkv"), T0);
    const Plan plan = model.forgetAll({ QStringLiteral("p.png"), QStringLiteral("q.png") }, { QStringLiteral("d.srt") });
    check(plan.deleteFiles.contains(QStringLiteral("q.png")) && plan.deleteFiles.contains(QStringLiteral("d.srt"))
          && !plan.deleteFiles.contains(QStringLiteral("w.wf")), "forget all: pictures and downloads, not waveforms");
    check(plan.unlinkDownloads == QStringList{ QStringLiteral("d.srt") }, "forget all: the downloads' links");
    check(!model.has(QStringLiteral("/s/Show")) && model.has(QStringLiteral("/m/Film.mkv")), "forget all: shows forgotten, movies kept");
}

void testJson()
{
    Model model;
    model.recordPlay(show(QStringLiteral("/s/Show"), QStringLiteral("V"), kEpisodes), T0);
    model.markConnected({ QStringLiteral("V") }, T0);
    model.addArtifact(QStringLiteral("s.srt"), ArtifactKind::Download, QStringLiteral("/s/Show/e.mkv"), T0);
    model.markSelected(QStringLiteral("s.srt"), T0 + 5);
    const QByteArray json = QJsonDocument(model.toJson()).toJson();
    const Model back = Model::fromJson(QJsonDocument::fromJson(json).object());
    const Entry* entry = back.entry(QStringLiteral("/s/Show"));
    check(entry && entry->files.size() == 3 && entry->files.at(1).relativePath == QLatin1String("Season 1/Show S01E02.mkv")
          && entry->files.at(1).size == 1002 && entry->volume == QLatin1String("V") && entry->lastPlayed == T0,
          "json: the entry comes back");
    check(back.volumeLastConnected(QStringLiteral("V")) == T0, "json: the volume");
    check(back.artifacts().value(QStringLiteral("s.srt")).selected && back.artifacts().value(QStringLiteral("s.srt")).used == T0 + 5,
          "json: the download");
}

} // namespace

int main()
{
    testRenamedShow();
    testShowOtherDrive();
    testRenamedMovie();
    testDriveNewLetter();
    testEmptyMountFolder();
    testSlowShare();
    testDeletedShow();
    testDriveGone();
    testSubtitles();
    testCaps();
    testForgetAll();
    testJson();
    std::printf("rd_storage_model: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
