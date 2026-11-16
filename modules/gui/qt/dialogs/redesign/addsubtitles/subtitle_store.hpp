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

#ifndef SUBTITLE_STORE_HPP
#define SUBTITLE_STORE_HPP

#include <QHash>
#include <QJsonObject>
#include <QString>
#include <QStringList>

/**
 * redesign (Add Subtitles, W6.5, P3-08 / P3-09): what the dialog saved, so it applies again
 * every time a video plays (video 6:12-6:22: subtitles added to a folder are matched to its
 * episodes, and a match picked by hand is kept for the next episodes).
 *
 * - per video: the subtitle files added to it;
 * - per folder: where its subtitles come from (a folder of the computer or an OpenSubtitles
 *   search), and the variant and language picked by hand, so episodes played later (new
 *   files too) get theirs matched the same way.
 *
 * Kept as JSON in VLC's user data folder. The object itself lives on the interface thread;
 * read() and write() do the file work and belong on a worker thread.
 */
class SubtitleStore
{
public:
    enum Source { Computer = 0, OpenSubtitles = 1 };

    struct Rule
    {
        bool valid = false;
        Source source = Computer;
        // Computer: the folder the subtitles are in (local path)
        QString path;
        // OpenSubtitles: the search text without the episode, and the language code
        QString query;
        QString language;
        // the variant picked by hand ("english", "forced"), preferred for the next episodes
        QStringList variant;
    };

    // the store's file: <VLC user data folder>/rd-subtitles.json
    static QString filePath();
    static QJsonObject read();
    static bool write(const QJsonObject& data);

    // the key of a media: its local path for files (VLC writes the same path in several ways),
    // its address otherwise
    static QString mediaKey(const QString& mrl);
    // the key of the folder a local media is in, empty for other media
    static QString folderKey(const QString& mrl);

    void setData(const QJsonObject& data) { m_data = data; }
    const QJsonObject& data() const { return m_data; }

    // subtitles saved for a media: local paths or addresses
    QStringList subtitlesFor(const QString& mrl) const;
    void setSubtitles(const QString& mrl, const QStringList& subtitles);

    Rule ruleFor(const QString& folderKey) const;
    void setRule(const QString& folderKey, const Rule& rule);

    // the storage cleanup (redesign/STORAGE_CLEANUP_NOTES.md); each returns whether it changed
    // anything. A show or movie found at another place: its videos' links (`media`: each
    // matched video's old key and new path) and its folders' rules move from `oldRoot` to
    // `newRoot`
    bool relocate(const QString& oldRoot, const QString& newRoot, const QHash<QString, QString>& media);
    // a show or movie forgotten: the links of its videos and the rules of its folders
    bool forgetUnder(const QString& root);
    // deleted downloads taken out of every video's links
    bool unlink(const QStringList& files);
    // the downloaded subtitle files each video links to (for the files from before the registry)
    QHash<QString, QString> downloadOwners(const QString& downloadsDir) const;

private:
    QJsonObject m_data;
};

#endif // SUBTITLE_STORE_HPP
