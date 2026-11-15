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

// redesign (1.5.0 fixes, FIX_1_5_0_NOTES.md): the Add Subtitles choice, the downloaded file's name
// and the external track name. QtCore only.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "dialogs/redesign/addsubtitles/rd_subtitle_picks.hpp"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>

#include <cstdio>

using namespace rdsubtitles;

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const char* what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", what);
    }
}

void checkEqual(const QString& actual, const QString& expected, const char* what)
{
    ++checks;
    if (actual != expected)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s: got \"%s\", expected \"%s\"\n", what, qPrintable(actual),
                     qPrintable(expected));
    }
}

QString s(const char* text)
{
    return QString::fromUtf8(text);
}

void write(const QString& path, const QByteArray& data)
{
    QFile file(path);
    check(file.open(QIODevice::WriteOnly) && file.write(data) == data.size(), "test file written");
}

void testPicked()
{
    // OpenSubtitles: one choice. The pre-checked best match, then a click on another result:
    // only that one stays checked (1.5.0 Windows pass: English and Hebrew were both downloaded)
    check(picked({ 0 }, 2, true) == QSet<int>{ 2 }, "single: another result moves the check");
    // a click on the checked result keeps it (it unchecked it, and Save downloaded nothing)
    check(picked({ 0 }, 0, true) == QSet<int>{ 0 }, "single: the checked result stays checked");
    check(picked({}, 1, true) == QSet<int>{ 1 }, "single: nothing checked, a click checks");
    check(picked({ 0, 3 }, 1, true) == QSet<int>{ 1 }, "single: never more than one");

    // files from the computer: several (Figma Folder-2), a click flips the row
    check(picked({ 0 }, 2, false) == (QSet<int>{ 0, 2 }), "multi: a click adds");
    check(picked({ 0, 2 }, 0, false) == QSet<int>{ 2 }, "multi: a click removes");
}

void testDownloadFile()
{
    QTemporaryDir dir;
    check(dir.isValid(), "temporary folder");
    const QString folder = dir.path();
    const QString name = s("Sintel (2010).eng.srt");

    // the subtitle's own name, no OpenSubtitles id in front (1.5.0: "67399-Sintel (2010).eng.srt")
    checkEqual(downloadFile(folder, name, "one"), folder + s("/Sintel (2010).eng.srt"), "own name");
    write(folder + s("/Sintel (2010).eng.srt"), "one");
    // the same subtitle again: the same file, no copy
    checkEqual(downloadFile(folder, name, "one"), folder + s("/Sintel (2010).eng.srt"), "same bytes reused");
    // another subtitle with the same name: numbered, the first is kept
    checkEqual(downloadFile(folder, name, "two"), folder + s("/Sintel (2010).eng (2).srt"), "numbered");
    write(folder + s("/Sintel (2010).eng (2).srt"), "two");
    checkEqual(downloadFile(folder, name, "two"), folder + s("/Sintel (2010).eng (2).srt"), "numbered reused");
    checkEqual(downloadFile(folder, name, "three"), folder + s("/Sintel (2010).eng (3).srt"), "next number");
    checkEqual(downloadFile(QString(), name, "x"), QString(), "no folder");
}

void testTrackName()
{
    checkEqual(withoutExtension(s("Sintel (2010).eng.srt")), s("Sintel (2010).eng"), "extension");
    checkEqual(withoutExtension(s("Sintel (2010)")), s("Sintel (2010)"), "no extension");

    // the 1.5.0 track "Sintel (2010 [English]": the language word went with the ")" before it
    const QString base = s("Sintel (2010).eng");
    checkEqual(withoutLastWord(base, base.size() - 3, base), s("Sintel (2010)"), "bracket kept");
    const QString wand = s("The_Wand_S01E04_EN");
    checkEqual(withoutLastWord(wand, wand.size() - 2, wand), s("The_Wand_S01E04"), "separators go");
    const QString dashes = s("Movie [HD] - en");
    checkEqual(withoutLastWord(dashes, dashes.size() - 2, dashes), s("Movie [HD]"), "square bracket kept");
    checkEqual(withoutLastWord(s("en"), 0, s("en.srt")), s("en.srt"), "fallback");

    checkEqual(withoutDownloadId(s("67399-Sintel (2010).eng.srt")), s("Sintel (2010).eng.srt"), "old id");
    checkEqual(withoutDownloadId(s("Sintel (2010).eng.srt")), s("Sintel (2010).eng.srt"), "no id");
    checkEqual(withoutDownloadId(s("2001 A Space Odyssey.srt")), s("2001 A Space Odyssey.srt"), "digits, no dash");
    checkEqual(withoutDownloadId(s("12-")), s("12-"), "nothing after the id");
}

} // namespace

int main()
{
    testPicked();
    testDownloadFile();
    testTrackName();
    std::fprintf(stderr, "test_rd_subtitle_picks: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
