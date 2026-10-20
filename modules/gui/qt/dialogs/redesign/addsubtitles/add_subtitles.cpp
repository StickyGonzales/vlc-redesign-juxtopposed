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

#include "add_subtitles.hpp"
#include "subtitle_web.hpp"

#include "player/player_controller.hpp"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QLocale>
#include <QPointer>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_interface.h>
#include <vlc_interrupt.h>
#include <vlc_player.h>
#include <vlc_playlist.h>
#include <vlc_url.h>
#include <vlc_variables.h>

#include <algorithm>
#include <cstring>

namespace {

// subtitle files are small; a link to anything larger is not one
constexpr qint64 maxSubtitleSize = 10 * 1024 * 1024;
// a web request that has not finished by then is stopped
constexpr int requestTimeout = 30000;
// results fetched for a whole folder (OpenSubtitles pages of 50)
constexpr int folderSearchPages = 3;

const QString settingsGroup = QStringLiteral("RdSubtitles/");

// "*.srt;*.ass" -> { "srt", "ass" }
QSet<QString> suffixes(const char* list)
{
    QSet<QString> result;
    for (const QString& pattern : QString::fromLatin1(list).split(QChar(';'), Qt::SkipEmptyParts))
        result.insert(pattern.mid(pattern.indexOf(QChar('.')) + 1).toLower());
    return result;
}

const QSet<QString>& subtitleSuffixes()
{
    static const QSet<QString> set = suffixes(EXTENSIONS_SUBTITLE);
    return set;
}

const QSet<QString>& videoSuffixes()
{
    static const QSet<QString> set = suffixes(EXTENSIONS_VIDEO);
    return set;
}

// folders next to the videos that usually hold their subtitles ("Subs/S01E04/2_English.srt")
bool isSubtitleFolder(const QString& name)
{
    const QString n = name.toLower();
    return n == QLatin1String("subs") || n == QLatin1String("sub") || n == QLatin1String("subtitles");
}

QString localPathOf(const QString& mrl)
{
    if (!mrl.startsWith(QLatin1String("file:"), Qt::CaseInsensitive))
        return {};
    char* path = vlc_uri2path(qtu(mrl));
    if (!path)
        return {};
    const QString result = QDir::fromNativeSeparators(qfu(path));
    free(path);
    return result;
}

QString mrlOf(const QString& path)
{
    char* uri = vlc_path2uri(qtu(QDir::toNativeSeparators(path)), nullptr);
    if (!uri)
        return {};
    const QString result = qfu(uri);
    free(uri);
    return result;
}

// the file name of a media address
QString nameOf(const QString& mrl)
{
    const QString path = localPathOf(mrl);
    if (!path.isEmpty())
        return QFileInfo(path).fileName();
    return QUrl(mrl).fileName();
}

// the subtitle files of a folder and of its subtitle folders, in name order
struct ScannedFile
{
    QString display;
    QString path;
    // what the matcher reads: the name, after the folder name for files in a per-episode folder
    QString matchName;
};

QVector<ScannedFile> scanSubtitles(const QString& folder)
{
    QVector<ScannedFile> files;
    const QDir root(folder);
    if (folder.isEmpty() || !root.exists())
        return files;

    const auto addFiles = [&files, &root](const QDir& dir, const QString& prefix) {
        const QFileInfoList entries = dir.entryInfoList(QDir::Files | QDir::Readable);
        for (const QFileInfo& info : entries)
        {
            if (!subtitleSuffixes().contains(info.suffix().toLower()))
                continue;
            ScannedFile file;
            file.path = info.absoluteFilePath();
            file.display = root.relativeFilePath(file.path);
            file.matchName = prefix.isEmpty() ? info.fileName() : prefix + QChar(' ') + info.fileName();
            files.append(file);
        }
    };

    addFiles(root, {});
    for (const QFileInfo& sub : root.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable))
    {
        if (!isSubtitleFolder(sub.fileName()))
            continue;
        const QDir subDir(sub.absoluteFilePath());
        addFiles(subDir, {});
        // one folder per episode, named after it
        for (const QFileInfo& episode : subDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable))
            addFiles(QDir(episode.absoluteFilePath()), episode.fileName());
    }

    std::sort(files.begin(), files.end(), [](const ScannedFile& a, const ScannedFile& b) {
        return SubtitleMatcher::naturalCompare(a.display, b.display) < 0;
    });
    return files;
}

QStringList scanVideos(const QString& folder)
{
    QStringList videos;
    const QDir dir(folder);
    if (folder.isEmpty() || !dir.exists())
        return videos;
    for (const QFileInfo& info : dir.entryInfoList(QDir::Files | QDir::Readable))
        if (videoSuffixes().contains(info.suffix().toLower()))
            videos.append(info.absoluteFilePath());
    SubtitleMatcher::naturalSort(videos);
    return videos;
}

// a file name without characters Windows refuses
QString safeFileName(const QString& name)
{
    QString result;
    for (const QChar c : name)
        result += (c.isLetterOrNumber() || QStringLiteral(" ._-()[]").contains(c)) ? c : QChar('_');
    result = result.trimmed();
    return result.isEmpty() ? QStringLiteral("subtitle.srt") : result.left(120);
}

// where downloaded subtitles are kept: <VLC user data folder>/subtitles/<kind>
QString downloadFolder(const char* kind)
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return {};
    const QString path = qfu(dir) + QStringLiteral("/subtitles/") + QLatin1String(kind);
    free(dir);
    QDir().mkpath(path);
    return path;
}

bool writeFile(const QString& path, const QByteArray& data)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    return file.write(data) == data.size();
}

// the extension of a downloaded subtitle file from its content, empty when it is none
QString sniffSubtitle(const QByteArray& data)
{
    const QByteArray head = data.left(4096);
    if (head.startsWith("PK\x03\x04"))
        return QStringLiteral("zip");
    if (head.contains("WEBVTT"))
        return QStringLiteral("vtt");
    if (head.contains("[Script Info]"))
        return QStringLiteral("ass");
    if (head.contains("-->"))
        return QStringLiteral("srt");
    if (head.contains("{1}") || head.contains("{0}"))
        return QStringLiteral("sub");
    return {};
}

SubtitleMatcher::Name parseResult(const OpenSubtitles::Result& result)
{
    SubtitleMatcher::Name name = SubtitleMatcher::parse(result.fileName);
    if (result.episode >= 0)
    {
        name.episode = result.episode;
        name.season = result.season;
    }
    if (!result.language.isEmpty())
        name.language = result.language;
    return name;
}

// the OpenSubtitles languages offered in the dialog
const char* const languageCodes[] = {
    "ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "et", "eu", "fa", "fi", "fr",
    "gl", "he", "hi", "hr", "hu", "id", "is", "it", "ja", "ko", "lt", "lv", "ms", "nl", "no",
    "pl", "pt-br", "pt-pt", "ro", "ru", "sk", "sl", "sr", "sv", "ta", "te", "th", "tr", "uk",
    "ur", "vi", "zh-cn", "zh-tw"
};

QString languageName(const QString& code)
{
    if (code == QLatin1String("pt-br"))
        return qtr("Portuguese (Brazil)");
    if (code == QLatin1String("pt-pt"))
        return qtr("Portuguese (Portugal)");
    if (code == QLatin1String("zh-cn"))
        return qtr("Chinese (Simplified)");
    if (code == QLatin1String("zh-tw"))
        return qtr("Chinese (Traditional)");
    return QLocale::languageToString(QLocale(code).language());
}

// VLC creates the track of a file added during playback a moment later; its string id starts
// with the MD5 of the file's URI ("<32 hex digits>/spu/0", src/input/es_out.c). Looked up this
// many times, this often, then selected alone (the video: the new file gets the check)
constexpr int kSelectLookups = 20;
constexpr int kSelectLookupDelayMs = 100;

void selectSubtitleWhenListed(QObject* context, vlc_player_t* player, const QByteArray& uriHash, int lookups)
{
    QTimer::singleShot(kSelectLookupDelayMs, context, [context, player, uriHash, lookups]() {
        {
            vlc_player_locker lock{ player };
            const size_t count = vlc_player_GetTrackCount(player, SPU_ES);
            for (size_t i = 0; i < count; ++i)
            {
                const vlc_player_track* track = vlc_player_GetTrackAt(player, SPU_ES, i);
                const char* strId = track ? vlc_es_id_GetStrId(track->es_id) : nullptr;
                if (!strId || std::strncmp(strId, uriHash.constData(), uriHash.size()) != 0
                    || strId[uriHash.size()] != '/')
                    continue;
                if (!track->selected)
                    vlc_player_SelectTrack(player, track, VLC_PLAYER_SELECT_EXCLUSIVE);
                return;
            }
        }
        if (lookups > 1)
            selectSubtitleWhenListed(context, player, uriHash, lookups - 1);
    });
}

} // namespace

struct AddSubtitles::Job
{
    vlc_interrupt_t* interrupt = vlc_interrupt_create();
    // belongs to the dialog (not to playback)
    bool tracked = true;

    ~Job()
    {
        if (interrupt)
            vlc_interrupt_destroy(interrupt);
    }
};

AddSubtitles::AddSubtitles(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_pool.setMaxThreadCount(3);
    m_storePool.setMaxThreadCount(1);

    QSettings* settings = m_intf->mainSettings;
    m_account.apiKey = settings->value(settingsGroup + QStringLiteral("OpenSubtitlesApiKey")).toString();
    m_account.username = settings->value(settingsGroup + QStringLiteral("OpenSubtitlesUser")).toString();
    m_account.password = settings->value(settingsGroup + QStringLiteral("OpenSubtitlesPassword")).toString();

    // the language the user prefers for subtitles (VLC's "sub-language": "eng,fre" or names)
    char* preferred = var_InheritString(m_intf, "sub-language");
    if (preferred)
    {
        const QString first = qfu(preferred).split(QChar(','), Qt::SkipEmptyParts).value(0).trimmed();
        m_preferredLanguage = SubtitleMatcher::languageCode(first, true);
        free(preferred);
    }
    m_language = settings->value(settingsGroup + QStringLiteral("Language"), m_preferredLanguage).toString();
    if (m_language.isEmpty())
    {
        const QString system = QLocale::system().name().left(2).toLower();
        m_language = std::any_of(std::begin(languageCodes), std::end(languageCodes),
                                 [&system](const char* code) { return system == QLatin1String(code); })
                     ? system : QStringLiteral("en");
    }

    PlayerController* player = m_intf->p_mainPlayerController;
    connect(player, &PlayerController::inputChanged, this, &AddSubtitles::onInputChanged);
    connect(player, &PlayerController::playingStateChanged, this, &AddSubtitles::onPlayingStateChanged);

    // the saved subtitles, read in the background
    auto data = std::make_shared<QJsonObject>();
    run([data](vlc_object_t*) { *data = SubtitleStore::read(); },
        [this, data]() {
            // a save made before the file was read wins over the file's entries, and the file
            // is written only now, so it never loses what it held
            const QJsonObject saved = m_store.data();
            QJsonObject merged = *data;
            for (auto group = saved.constBegin(); group != saved.constEnd(); ++group)
            {
                QJsonObject entries = merged.value(group.key()).toObject();
                const QJsonObject added = group.value().toObject();
                for (auto it = added.constBegin(); it != added.constEnd(); ++it)
                    entries.insert(it.key(), it.value());
                merged.insert(group.key(), entries);
            }
            m_store.setData(merged);
            m_storeLoaded = true;
            if (!saved.isEmpty())
                writeStore();
            onPlayingStateChanged();
        }, 0, false);
}

AddSubtitles::~AddSubtitles()
{
    // the worker threads must not wait on the network while the interface closes
    for (const std::shared_ptr<Job>& job : m_jobs)
        vlc_interrupt_kill(job->interrupt);
    m_pool.waitForDone();
    m_storePool.waitForDone();
}

void AddSubtitles::run(Work work, Done done, int requests, bool tracked)
{
    auto job = std::make_shared<Job>();
    if (!job->interrupt)
        return;
    job->tracked = tracked;
    m_jobs.append(job);

    const int generation = m_generation;
    if (tracked)
        setBusy(true);

    QPointer<AddSubtitles> self(this);
    vlc_object_t* obj = VLC_OBJECT(m_intf);

    if (requests > 0)
    {
        std::weak_ptr<Job> weak = job;
        QTimer::singleShot(requests * requestTimeout, this, [weak]() {
            if (const std::shared_ptr<Job> running = weak.lock())
                vlc_interrupt_kill(running->interrupt);
        });
    }

    m_pool.start([self, job, obj, work = std::move(work), done = std::move(done), generation, tracked]() {
        vlc_interrupt_t* previous = vlc_interrupt_set(job->interrupt);
        work(obj);
        vlc_interrupt_set(previous);

        QMetaObject::invokeMethod(self, [self, job, done, generation, tracked]() {
            if (!self)
                return;
            self->m_jobs.removeOne(job);
            if (tracked)
                self->setBusy(false);
            // a newer request (another folder, search, target) replaced this one
            if (!tracked || generation == self->m_generation)
                done();
        }, Qt::QueuedConnection);
    });
}

void AddSubtitles::cancelJobs()
{
    ++m_generation;
    // the dialog's requests only: playback lookups go on
    for (const std::shared_ptr<Job>& job : m_jobs)
        if (job->tracked)
            vlc_interrupt_kill(job->interrupt);
}

void AddSubtitles::setBusy(bool busy)
{
    const bool was = this->busy();
    m_busyCount += busy ? 1 : -1;
    if (was != this->busy())
    {
        emit busyChanged();
        updateMessage();
    }
}

void AddSubtitles::setMessage(const QString& message)
{
    if (m_message == message)
        return;
    m_message = message;
    emit messageChanged();
}

// --------------------------------------------------------------------------------- request

void AddSubtitles::open(const QVariantMap& request)
{
    cancelJobs();
    m_saving = false;

    QString mrl = request.value(QStringLiteral("mrl")).toString();
    QStringList items = request.value(QStringLiteral("items")).toStringList();
    const QString folder = request.value(QStringLiteral("folder")).toString();

    // without a media: the one playing, and the play queue as its playlist
    if (mrl.isEmpty() && folder.isEmpty() && items.isEmpty())
    {
        vlc_player_t* player = m_intf->p_mainPlayerController->getPlayer();
        {
            vlc_player_locker lock{ player };
            if (input_item_t* item = vlc_player_GetCurrentMedia(player))
                mrl = qfu(item->psz_uri);
        }

        vlc_playlist_t* playlist = m_intf->p_playlist;
        vlc_playlist_Lock(playlist);
        const size_t count = vlc_playlist_Count(playlist);
        for (size_t i = 0; count > 1 && i < count; ++i)
        {
            input_item_t* media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i));
            if (media && media->psz_uri)
                items.append(qfu(media->psz_uri));
        }
        vlc_playlist_Unlock(playlist);
    }

    // a playlist of one video is that file
    if (mrl.isEmpty() && folder.isEmpty() && items.size() == 1)
        mrl = items.first();

    m_mrl = mrl;
    m_playlistItems = items.size() > 1 ? items : QStringList();
    const QString folderPath = !folder.isEmpty() ? localPathOf(folder) : QFileInfo(localPathOf(mrl)).path();
    m_videoFolder = (!folder.isEmpty() || !localPathOf(mrl).isEmpty()) ? folderPath : QString();

    const QString target = request.value(QStringLiteral("target")).toString();
    if (target == QLatin1String("folder") && folderAvailable())
        m_target = TargetFolder;
    else if (target == QLatin1String("playlist") && playlistAvailable())
        m_target = TargetPlaylist;
    else if (fileAvailable())
        m_target = TargetFile;
    else
        m_target = folderAvailable() ? TargetFolder : TargetPlaylist;

    // Decision 12: the dialog opens on "From Computer", in the videos' folder
    m_source = SourceComputer;
    m_computerFolder = m_videoFolder;
    if (m_computerFolder.isEmpty())
        m_computerFolder = m_intf->mainSettings->value(settingsGroup + QStringLiteral("LastFolder"),
                                                QStandardPaths::writableLocation(QStandardPaths::HomeLocation)).toString();

    m_computer.clear();
    m_online.clear();
    m_links.clear();
    m_folderVideos.clear();
    m_playlistVideos.clear();
    m_selected.clear();
    m_manual.clear();
    m_sourceError.clear();
    m_searched = false;
    m_searchText = defaultSearchText();
    m_files.setRows({});
    m_matches.setRows({});

    emit requestChanged();
    emit targetChanged();
    emit sourceChanged();
    emit folderChanged();
    emit searchTextChanged();
    emit canSaveChanged();
    emit busyChanged();

    loadComputerFolder(m_computerFolder);
    loadVideos();
    updateMessage();

    emit openRequested();
}

void AddSubtitles::cancel()
{
    cancelJobs();
    m_saving = false;
    emit busyChanged();
}

void AddSubtitles::setTarget(int target)
{
    if (target == m_target || target < TargetFile || target > TargetPlaylist)
        return;
    if ((target == TargetFile && !fileAvailable()) || (target == TargetFolder && !folderAvailable())
            || (target == TargetPlaylist && !playlistAvailable()))
        return;

    const bool defaultText = m_searchText == defaultSearchText();
    m_target = target;
    emit targetChanged();

    // the search follows the target ("The Wand S01E01" for a file, "The Wand S01" for a season),
    // unless the user wrote their own; a file asks OpenSubtitles for its episode, a folder or a
    // playlist for the whole season, so the results change too
    if (defaultText)
    {
        m_searchText = defaultSearchText();
        emit searchTextChanged();
    }
    if (m_source == SourceOpenSubtitles)
        search();
    else
        m_searched = false;

    loadVideos();
    rebuild();
    emit canSaveChanged();
}

void AddSubtitles::setSource(int source)
{
    if (source == m_source || source < SourceComputer || source > SourceLink)
        return;
    m_source = source;
    m_sourceError.clear();
    emit sourceChanged();

    if (m_source == SourceOpenSubtitles && !m_searched)
        search();
    rebuild();
    emit canSaveChanged();
}

QString AddSubtitles::folderPath() const
{
    // "Videos / Shows / The Wand / S01": the path under the home folder, like the library's
    // breadcrumb
    QString path = QDir::cleanPath(m_computerFolder);
    const QString home = QDir::cleanPath(QDir::homePath());
    if (path.startsWith(home + QChar('/'), Qt::CaseInsensitive))
        path = path.mid(home.size() + 1);
    return path.split(QChar('/'), Qt::SkipEmptyParts).join(QStringLiteral(" / "));
}

void AddSubtitles::setSearchText(const QString& text)
{
    if (text == m_searchText)
        return;
    m_searchText = text;
    emit searchTextChanged();
}

void AddSubtitles::setLanguage(const QString& language)
{
    if (language == m_language)
        return;
    m_language = language;
    m_intf->mainSettings->setValue(settingsGroup + QStringLiteral("Language"), language);
    emit languageChanged();
    if (m_source == SourceOpenSubtitles)
        search();
}

QVariantList AddSubtitles::languages() const
{
    QVariantList list;
    for (const char* code : languageCodes)
        list.append(QVariantMap { { QStringLiteral("code"), QString::fromLatin1(code) },
                                  { QStringLiteral("name"), languageName(QString::fromLatin1(code)) } });
    std::sort(list.begin(), list.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(QStringLiteral("name")).toString()
               .localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return list;
}

QString AddSubtitles::defaultSearchText() const
{
    // the title and the episode of the file, or the title and the season of the folder
    QString name;
    if (m_target == TargetFile || m_videoFolder.isEmpty())
        name = nameOf(m_mrl);
    else if (m_target == TargetFolder)
        name = QFileInfo(m_videoFolder).fileName();
    else
        name = nameOf(m_playlistItems.value(0));

    // a season folder ("S01") is named after the season only: the show is its parent
    SubtitleMatcher::Name parsed = SubtitleMatcher::parse(name + QStringLiteral(".x"));
    if (m_target == TargetFolder && parsed.title.isEmpty() && !m_videoFolder.isEmpty())
        parsed.title = SubtitleMatcher::parse(QFileInfo(QFileInfo(m_videoFolder).path()).fileName()
                                              + QStringLiteral(".x")).title;
    if (m_target != TargetFile)
    {
        // a playlist or folder of episodes: their season
        if (parsed.season < 0 && !m_mrl.isEmpty())
            parsed.season = SubtitleMatcher::parse(nameOf(m_mrl)).season;
        parsed.episode = -1;
    }

    QString text = parsed.title;
    if (parsed.season >= 0 && parsed.episode >= 0)
        text += QStringLiteral(" S%1E%2").arg(parsed.season, 2, 10, QChar('0')).arg(parsed.episode, 2, 10, QChar('0'));
    else if (parsed.season >= 0)
        text += QStringLiteral(" S%1").arg(parsed.season, 2, 10, QChar('0'));
    else if (parsed.episode >= 0)
        text += QStringLiteral(" %1").arg(parsed.episode);
    return text.trimmed();
}

// ----------------------------------------------------------------------------------- sources

void AddSubtitles::loadComputerFolder(const QString& path, const QStringList& preselect)
{
    m_computerFolder = path;
    m_computer.clear();
    m_selected.remove(SourceComputer);
    m_manual.remove(SourceComputer);
    emit folderChanged();
    rebuild();

    auto files = std::make_shared<QVector<ScannedFile>>();
    run([files, path](vlc_object_t*) { *files = scanSubtitles(path); },
        [this, files, preselect]() {
            m_computer.clear();
            m_computer.reserve(files->size());
            QSet<int> selected;
            for (const ScannedFile& file : *files)
            {
                if (preselect.contains(file.path))
                    selected.insert(int(m_computer.size()));
                m_computer.append({ file.display, file.path, 0, SubtitleMatcher::parse(file.matchName) });
            }
            if (!selected.isEmpty())
                m_selected.insert(SourceComputer, selected);
            rebuild();
        }, 0);
}

void AddSubtitles::loadVideos()
{
    if (m_target == TargetPlaylist && m_playlistVideos.isEmpty())
    {
        for (const QString& mrl : m_playlistItems)
        {
            const QString name = nameOf(mrl);
            m_playlistVideos.append({ name, mrl, SubtitleMatcher::parse(name) });
        }
    }
    else if (m_target == TargetFolder && m_folderVideos.isEmpty() && !m_videoFolder.isEmpty())
    {
        auto videos = std::make_shared<QStringList>();
        const QString folder = m_videoFolder;
        run([videos, folder](vlc_object_t*) { *videos = scanVideos(folder); },
            [this, videos]() {
                m_folderVideos.clear();
                for (const QString& path : *videos)
                {
                    const QString name = QFileInfo(path).fileName();
                    m_folderVideos.append({ name, mrlOf(path), SubtitleMatcher::parse(name) });
                }
                rebuild();
            }, 0);
    }
}

void AddSubtitles::chooseFolder()
{
    const QString folder = QFileDialog::getExistingDirectory(nullptr, qtr("Choose the folder of the subtitles"),
                                                             m_computerFolder);
    if (folder.isEmpty())
        return;
    m_intf->mainSettings->setValue(settingsGroup + QStringLiteral("LastFolder"), folder);
    if (m_source != SourceComputer)
    {
        m_source = SourceComputer;
        emit sourceChanged();
    }
    m_sourceError.clear();
    loadComputerFolder(QDir::fromNativeSeparators(folder));
}

void AddSubtitles::addDropped(const QList<QUrl>& urls)
{
    QStringList files;
    QString folder;
    for (const QUrl& url : urls)
    {
        const QString path = url.toLocalFile();
        if (path.isEmpty())
        {
            // a link dropped from a web page
            if (url.isValid() && !url.scheme().isEmpty())
                addLink(url.toString());
            continue;
        }
        const QFileInfo info(path);
        if (info.isDir() && folder.isEmpty())
            folder = info.absoluteFilePath();
        else if (subtitleSuffixes().contains(info.suffix().toLower()))
            files.append(info.absoluteFilePath());
    }
    if (folder.isEmpty() && !files.isEmpty())
        folder = QFileInfo(files.first()).path();
    if (folder.isEmpty())
        return;

    if (m_source != SourceComputer)
    {
        m_source = SourceComputer;
        emit sourceChanged();
    }
    m_sourceError.clear();
    loadComputerFolder(folder, files);
}

void AddSubtitles::search()
{
    m_searched = true;
    m_online.clear();
    m_selected.remove(SourceOpenSubtitles);
    m_manual.remove(SourceOpenSubtitles);
    m_sourceError.clear();
    if (!openSubtitlesEnabled())
    {
        rebuild();
        return;
    }

    // "The Wand S01E01": the title as the query, the episode as its own parameters
    const SubtitleMatcher::Name query = SubtitleMatcher::parse(m_searchText + QStringLiteral(".x"));
    const QString text = query.title.isEmpty() ? m_searchText : query.title;
    const bool wholeSeason = m_target != TargetFile;
    const int season = query.season;
    const int episode = wholeSeason ? -1 : query.episode;
    const int pages = wholeSeason ? folderSearchPages : 1;

    auto results = std::make_shared<QVector<OpenSubtitles::Result>>();
    auto error = std::make_shared<QString>();
    const OpenSubtitles::Account account = m_account;
    const QString language = m_language;
    rebuild();
    run([=](vlc_object_t* obj) {
            *results = OpenSubtitles::search(obj, account, text, language, season, episode, pages, error.get());
        },
        [this, results, error]() {
            m_online.clear();
            for (const OpenSubtitles::Result& result : *results)
                m_online.append({ result.fileName, QString(), result.fileId, parseResult(result) });
            m_sourceError = *error;
            rebuild();
        }, pages);
}

void AddSubtitles::addLink(const QString& link)
{
    const QString text = link.trimmed();
    if (text.isEmpty())
        return;

    if (m_source != SourceLink)
    {
        m_source = SourceLink;
        emit sourceChanged();
    }
    m_sourceError.clear();

    // a local file needs no download
    const QUrl url = QUrl::fromUserInput(text);
    if (url.isLocalFile())
    {
        const QFileInfo info(url.toLocalFile());
        if (!info.isFile())
            m_sourceError = qtr("This file does not exist.");
        else
        {
            m_selected[SourceLink].insert(int(m_links.size()));
            m_links.append({ info.fileName(), info.absoluteFilePath(), 0, SubtitleMatcher::parse(info.fileName()) });
        }
        rebuild();
        emit canSaveChanged();
        return;
    }

    auto path = std::make_shared<QString>();
    auto error = std::make_shared<QString>();
    const QString address = url.toString(QUrl::FullyEncoded);
    rebuild();
    run([path, error, address, url](vlc_object_t* obj) {
            const SubtitleWeb::Reply reply = SubtitleWeb::fetch(obj, address, maxSubtitleSize);
            if (!reply.ok() || reply.body.isEmpty())
            {
                *error = reply.error == QLatin1String("file too large")
                         ? qtr("This link does not lead to a subtitle file.")
                         : qtr("This link cannot be opened.");
                return;
            }
            QString name = url.fileName();
            QString suffix = QFileInfo(name).suffix().toLower();
            if (!subtitleSuffixes().contains(suffix))
            {
                suffix = sniffSubtitle(reply.body);
                if (suffix == QLatin1String("zip"))
                {
                    *error = qtr("This link leads to a zip file. Extract it first, then add the subtitles From Computer.");
                    return;
                }
                if (suffix.isEmpty())
                {
                    *error = qtr("This link does not lead to a subtitle file.");
                    return;
                }
                name = (name.isEmpty() ? QStringLiteral("subtitle") : QFileInfo(name).completeBaseName())
                       + QChar('.') + suffix;
            }
            // one file per link, so the same name from two links does not collide
            const QString hash = QString::fromLatin1(QCryptographicHash::hash(address.toUtf8(), QCryptographicHash::Sha1).toHex().left(8));
            const QString folder = downloadFolder("links");
            const QString file = folder + QChar('/') + hash + QChar('-') + safeFileName(name);
            if (folder.isEmpty() || !writeFile(file, reply.body))
            {
                *error = qtr("The subtitle file cannot be saved.");
                return;
            }
            *path = file;
        },
        [this, path, error]() {
            m_sourceError = *error;
            if (!path->isEmpty())
            {
                const QString name = QFileInfo(*path).fileName().section(QChar('-'), 1);
                m_selected[SourceLink].insert(int(m_links.size()));
                m_links.append({ name, *path, 0, SubtitleMatcher::parse(name) });
            }
            rebuild();
            emit canSaveChanged();
        }, 1);
}

const QVector<AddSubtitles::Candidate>& AddSubtitles::pool() const
{
    return m_source == SourceOpenSubtitles ? m_online : m_source == SourceLink ? m_links : m_computer;
}

SubtitleMatcher::Preference AddSubtitles::preference() const
{
    SubtitleMatcher::Preference preference;
    const SubtitleStore::Rule rule = m_store.ruleFor(SubtitleStore::folderKey(m_mrl.isEmpty() ? mrlOf(m_videoFolder + QStringLiteral("/x"))
                                                                                             : m_mrl));
    preference.variantTokens = rule.variant;
    preference.language = !rule.language.isEmpty() ? rule.language
                        : m_source == SourceOpenSubtitles ? m_language : m_preferredLanguage;
    return preference;
}

// ------------------------------------------------------------------------------------ rows

void AddSubtitles::rebuild()
{
    const SubtitleMatcher::Preference pref = preference();
    const QVector<Candidate> candidates = pool();

    if (m_target == TargetFile)
    {
        // the files of this episode first, best first (Figma "Folder-2": the episode's
        // languages); then every other subtitle of the source
        const SubtitleMatcher::Name video = SubtitleMatcher::parse(nameOf(m_mrl));
        QVector<QPair<int, int>> order;
        order.reserve(candidates.size());
        for (int i = 0; i < candidates.size(); ++i)
            order.append({ SubtitleMatcher::score(video, candidates.at(i).parsed, pref), i });
        std::stable_sort(order.begin(), order.end(), [](const QPair<int, int>& a, const QPair<int, int>& b) {
            return a.first > b.first;
        });

        // the first time a source has files: the best match is checked
        if (!m_selected.contains(m_source) && !order.isEmpty())
        {
            QSet<int>& selected = m_selected[m_source];
            if (order.first().first >= 0)
                selected.insert(order.first().second);
        }
        const QSet<int> selected = m_selected.value(m_source);

        QVector<AddSubtitlesModel::Row> rows;
        rows.reserve(order.size());
        for (const QPair<int, int>& entry : order)
        {
            AddSubtitlesModel::Row row;
            row.name = candidates.at(entry.second).name;
            row.candidate = entry.second;
            row.selected = selected.contains(entry.second);
            rows.append(row);
        }
        m_files.setRows(rows);
    }
    else
    {
        // every video against every subtitle: on a worker thread (a large folder takes a while)
        const QVector<Video> videos = m_target == TargetFolder ? m_folderVideos : m_playlistVideos;
        auto rows = std::make_shared<QVector<AddSubtitlesModel::Row>>();
        const int serial = ++m_rebuildSerial;
        const int source = m_source;
        run([rows, videos, candidates, pref](vlc_object_t*) {
                QVector<SubtitleMatcher::Name> names;
                names.reserve(candidates.size());
                for (const Candidate& candidate : candidates)
                    names.append(candidate.parsed);
                rows->reserve(videos.size());
                for (const Video& video : videos)
                {
                    AddSubtitlesModel::Row row;
                    row.videoName = video.name;
                    row.videoMrl = video.mrl;
                    row.candidate = SubtitleMatcher::bestMatch(video.parsed, names, pref);
                    if (row.candidate >= 0)
                        row.name = candidates.at(row.candidate).name;
                    rows->append(row);
                }
            },
            [this, rows, serial, source]() {
                // a newer rebuild (other target, source, files) replaced this one
                if (serial != m_rebuildSerial || source != m_source)
                    return;
                // the matches made by hand meanwhile win
                const QHash<QString, int> manual = m_manual.value(m_source);
                const QVector<Candidate>& current = pool();
                for (AddSubtitlesModel::Row& row : *rows)
                {
                    const auto it = manual.constFind(row.videoMrl);
                    if (it == manual.cend())
                        continue;
                    row.manual = true;
                    row.candidate = it.value() < current.size() ? it.value() : -1;
                    row.name = row.candidate >= 0 ? current.at(row.candidate).name : QString();
                }
                m_matches.setRows(*rows);
                updateMessage();
                emit canSaveChanged();
            }, 0, false);
    }

    updateMessage();
    emit canSaveChanged();
}

void AddSubtitles::updateMessage()
{
    const bool fileRows = m_target == TargetFile;
    const int count = fileRows ? m_files.count() : m_matches.count();
    const bool noCandidates = pool().isEmpty();

    QString text;
    if (m_source == SourceOpenSubtitles && !openSubtitlesEnabled())
        text = qtr("To search OpenSubtitles, enter your OpenSubtitles API key in Settings > Subtitles. "
                   "You can get a free key with an account on opensubtitles.com.");
    else if (!m_sourceError.isEmpty())
        text = m_sourceError;
    else if (m_saving)
        text = qtr("Downloading the subtitles...");
    else if (busy() && (count == 0 || noCandidates))
        text = m_source == SourceOpenSubtitles ? qtr("Searching OpenSubtitles...")
             : m_source == SourceLink ? qtr("Downloading...")
             : qtr("Reading the folder...");
    else if (!fileRows && count == 0)
        text = m_target == TargetFolder ? qtr("There are no videos in this folder.")
                                        : qtr("This playlist has no videos.");
    else if (noCandidates)
        text = m_source == SourceOpenSubtitles ? qtr("No subtitles found. Try other words or another language.")
             : m_source == SourceLink ? qtr("Paste a link to a subtitle file and press Enter.")
             : qtr("There are no subtitle files in this folder. Click the folder above to choose another one, or drop subtitle files here.");
    setMessage(text);
}

void AddSubtitles::toggle(int row)
{
    if (m_target != TargetFile || row < 0 || row >= m_files.count())
        return;
    AddSubtitlesModel::Row value = m_files.at(row);
    value.selected = !value.selected;
    QSet<int>& selected = m_selected[m_source];
    if (value.selected)
        selected.insert(value.candidate);
    else
        selected.remove(value.candidate);
    m_files.setRow(row, value);
    emit canSaveChanged();
}

QVariantList AddSubtitles::choices(int row) const
{
    QVariantList list;
    if (m_target == TargetFile || row < 0 || row >= m_matches.count())
        return list;

    const QString mrl = m_matches.at(row).videoMrl;
    const QVector<Video>& videos = m_target == TargetFolder ? m_folderVideos : m_playlistVideos;
    const auto video = std::find_if(videos.cbegin(), videos.cend(), [&mrl](const Video& v) { return v.mrl == mrl; });
    if (video == videos.cend())
        return list;

    // the subtitles of this episode first, then all the others in name order
    const SubtitleMatcher::Preference pref = preference();
    const QVector<Candidate>& candidates = pool();
    QVector<QPair<int, int>> order;
    for (int i = 0; i < candidates.size(); ++i)
        order.append({ SubtitleMatcher::score(video->parsed, candidates.at(i).parsed, pref), i });
    std::stable_sort(order.begin(), order.end(), [](const QPair<int, int>& a, const QPair<int, int>& b) {
        return a.first > b.first;
    });
    const int current = m_matches.at(row).candidate;
    for (const QPair<int, int>& entry : order)
        list.append(QVariantMap { { QStringLiteral("candidate"), entry.second },
                                  { QStringLiteral("name"), candidates.at(entry.second).name },
                                  { QStringLiteral("matched"), entry.first >= 0 },
                                  { QStringLiteral("current"), entry.second == current } });
    list.append(QVariantMap { { QStringLiteral("candidate"), -1 },
                              { QStringLiteral("name"), qtr("No subtitles") },
                              { QStringLiteral("matched"), true },
                              { QStringLiteral("current"), current < 0 } });
    return list;
}

void AddSubtitles::choose(int row, int candidate)
{
    if (m_target == TargetFile || row < 0 || row >= m_matches.count())
        return;
    const QVector<Candidate>& candidates = pool();
    AddSubtitlesModel::Row value = m_matches.at(row);
    value.candidate = (candidate >= 0 && candidate < candidates.size()) ? candidate : -1;
    value.name = value.candidate >= 0 ? candidates.at(value.candidate).name : QString();
    value.manual = true;
    m_manual[m_source].insert(value.videoMrl, value.candidate);
    m_matches.setRow(row, value);
    emit canSaveChanged();
}

bool AddSubtitles::canSave() const
{
    if (m_saving)
        return false;
    if (m_target == TargetFile)
        return std::any_of(m_files.rows().cbegin(), m_files.rows().cend(),
                           [](const AddSubtitlesModel::Row& row) { return row.selected; });
    return std::any_of(m_matches.rows().cbegin(), m_matches.rows().cend(),
                       [](const AddSubtitlesModel::Row& row) { return row.candidate >= 0; });
}

// ------------------------------------------------------------------------------------ save

void AddSubtitles::save()
{
    if (!canSave())
        return;

    // what goes where: (video, candidate)
    QVector<QPair<QString, int>> assignments;
    if (m_target == TargetFile)
    {
        for (const AddSubtitlesModel::Row& row : m_files.rows())
            if (row.selected)
                assignments.append({ m_mrl, row.candidate });
    }
    else
    {
        for (const AddSubtitlesModel::Row& row : m_matches.rows())
            if (row.candidate >= 0)
                assignments.append({ row.videoMrl, row.candidate });
    }

    const QVector<Candidate> candidates = pool();
    const int source = m_source;
    const int target = m_target;

    // the matches made by hand say which variant the user wants for the next episodes
    QStringList variant;
    if (target == TargetFolder)
    {
        QHash<QString, int> votes;
        const QVector<Video>& videos = m_folderVideos;
        for (const AddSubtitlesModel::Row& row : m_matches.rows())
        {
            if (!row.manual || row.candidate < 0)
                continue;
            const auto video = std::find_if(videos.cbegin(), videos.cend(),
                                            [&row](const Video& v) { return v.mrl == row.videoMrl; });
            if (video != videos.cend())
                votes[SubtitleMatcher::variantOf(video->parsed, candidates.at(row.candidate).parsed).join(QChar(' '))]++;
        }
        int best = 0;
        for (auto it = votes.cbegin(); it != votes.cend(); ++it)
            if (it.value() > best && !it.key().isEmpty())
            {
                best = it.value();
                variant = it.key().split(QChar(' '));
            }
    }

    // OpenSubtitles results are downloaded first
    QHash<int, qint64> downloads;
    for (const auto& assignment : assignments)
        if (candidates.at(assignment.second).fileId > 0)
            downloads.insert(assignment.second, candidates.at(assignment.second).fileId);

    auto paths = std::make_shared<QHash<int, QString>>();
    auto error = std::make_shared<QString>();
    for (const auto& assignment : assignments)
        if (!downloads.contains(assignment.second))
            paths->insert(assignment.second, candidates.at(assignment.second).path);

    m_saving = true;
    emit busyChanged();
    emit canSaveChanged();
    updateMessage();

    const OpenSubtitles::Account account = m_account;
    const QString searchText = m_searchText;
    const QString language = m_language;
    const QString computerFolder = m_computerFolder;
    const QString folderKey = target == TargetFolder ? SubtitleStore::folderKey(mrlOf(m_videoFolder + QStringLiteral("/x")))
                                                     : QString();

    run([downloads, candidates, paths, error, account](vlc_object_t* obj) {
            const QString folder = downloadFolder("opensubtitles");
            for (auto it = downloads.cbegin(); it != downloads.cend(); ++it)
            {
                QString name;
                QString failure;
                const QByteArray data = OpenSubtitles::download(obj, account, it.value(), &name, &failure);
                if (data.isEmpty())
                {
                    *error = failure.isEmpty() ? qtr("A subtitle could not be downloaded.") : failure;
                    // the next ones would fail the same way (quota, key, network)
                    break;
                }
                if (name.isEmpty())
                    name = candidates.at(it.key()).name;
                const QString file = folder + QChar('/') + QString::number(it.value()) + QChar('-') + safeFileName(name);
                if (folder.isEmpty() || !writeFile(file, data))
                {
                    *error = qtr("The subtitle file cannot be saved.");
                    break;
                }
                paths->insert(it.key(), file);
            }
        },
        [this, assignments, paths, error, target, source, variant, searchText, language, computerFolder, folderKey]() {
            m_saving = false;
            emit busyChanged();

            // the subtitles of each video; a folder's match replaces the previous one, a file
            // keeps the ones added before
            QHash<QString, QStringList> added;
            for (const auto& assignment : assignments)
            {
                const QString path = paths->value(assignment.second);
                if (!path.isEmpty() && !added[assignment.first].contains(path))
                    added[assignment.first].append(path);
            }
            for (auto it = added.cbegin(); it != added.cend(); ++it)
            {
                QStringList subtitles = target == TargetFile ? m_store.subtitlesFor(it.key()) : QStringList();
                for (const QString& path : it.value())
                    if (!subtitles.contains(path))
                        subtitles.append(path);
                m_store.setSubtitles(it.key(), subtitles);
            }

            // the folder keeps where its subtitles come from, for the episodes played later
            if (target == TargetFolder && !folderKey.isEmpty() && source != SourceLink && error->isEmpty())
            {
                SubtitleStore::Rule rule = m_store.ruleFor(folderKey);
                rule.valid = true;
                rule.source = source == SourceOpenSubtitles ? SubtitleStore::OpenSubtitles : SubtitleStore::Computer;
                rule.path = source == SourceComputer ? computerFolder : QString();
                const SubtitleMatcher::Name query = SubtitleMatcher::parse(searchText + QStringLiteral(".x"));
                rule.query = source == SourceOpenSubtitles ? (query.title.isEmpty() ? searchText : query.title) : QString();
                rule.language = source == SourceOpenSubtitles ? language : rule.language;
                if (!variant.isEmpty())
                    rule.variant = variant;
                m_store.setRule(folderKey, rule);
            }
            writeStore();

            // the video playing gets them now
            vlc_player_t* player = m_intf->p_mainPlayerController->getPlayer();
            QString playing;
            {
                vlc_player_locker lock{ player };
                if (input_item_t* item = vlc_player_GetCurrentMedia(player))
                    playing = SubtitleStore::mediaKey(qfu(item->psz_uri));
            }
            for (auto it = added.cbegin(); it != added.cend(); ++it)
                if (!playing.isEmpty() && SubtitleStore::mediaKey(it.key()) == playing)
                    attach(it.key(), it.value(), true);

            if (!error->isEmpty())
            {
                m_sourceError = *error;
                updateMessage();
                emit canSaveChanged();
                return;
            }
            emit saved();
        }, 1 + 2 * int(downloads.size()));
}

void AddSubtitles::writeStore()
{
    // before the file is read, writing it would drop its entries: the read writes it after
    if (!m_storeLoaded)
        return;
    const QJsonObject data = m_store.data();
    m_storePool.start([data]() { SubtitleStore::write(data); });
}

// ------------------------------------------------------------------------------ account

void AddSubtitles::setApiKey(const QString& key)
{
    if (key == m_account.apiKey)
        return;
    m_account.apiKey = key;
    saveAccount();
}

void AddSubtitles::setUsername(const QString& username)
{
    if (username == m_account.username)
        return;
    m_account.username = username;
    saveAccount();
}

void AddSubtitles::setPassword(const QString& password)
{
    if (password == m_account.password)
        return;
    m_account.password = password;
    saveAccount();
}

void AddSubtitles::saveAccount()
{
    QSettings* settings = m_intf->mainSettings;
    settings->setValue(settingsGroup + QStringLiteral("OpenSubtitlesApiKey"), m_account.apiKey);
    settings->setValue(settingsGroup + QStringLiteral("OpenSubtitlesUser"), m_account.username);
    settings->setValue(settingsGroup + QStringLiteral("OpenSubtitlesPassword"), m_account.password);
    emit accountChanged();
    // a new key: the next search uses it
    m_searched = false;
    updateMessage();
}

// ---------------------------------------------------------------------------------- playback

void AddSubtitles::onInputChanged(bool hasInput)
{
    m_pendingApply.clear();
    if (!hasInput)
        return;
    vlc_player_t* player = m_intf->p_mainPlayerController->getPlayer();
    vlc_player_locker lock{ player };
    if (input_item_t* item = vlc_player_GetCurrentMedia(player))
        m_pendingApply = qfu(item->psz_uri);
}

void AddSubtitles::onPlayingStateChanged()
{
    if (m_pendingApply.isEmpty() || !m_storeLoaded)
        return;
    // the media's own subtitles are loaded once it plays: added ones come after them
    const PlayerController::PlayingState state = m_intf->p_mainPlayerController->getPlayingState();
    if (state != PlayerController::PLAYING_STATE_PLAYING && state != PlayerController::PLAYING_STATE_PAUSED)
        return;
    const QString mrl = m_pendingApply;
    m_pendingApply.clear();
    applyTo(mrl);
}

void AddSubtitles::applyTo(const QString& mrl)
{
    const QStringList saved = m_store.subtitlesFor(mrl);
    const SubtitleStore::Rule rule = saved.isEmpty() ? m_store.ruleFor(SubtitleStore::folderKey(mrl))
                                                     : SubtitleStore::Rule();
    if (saved.isEmpty() && !rule.valid)
        return;
    if (saved.isEmpty() && rule.source == SubtitleStore::OpenSubtitles && !openSubtitlesEnabled())
        return;

    auto result = std::make_shared<QStringList>();
    const OpenSubtitles::Account account = m_account;
    const QString name = nameOf(mrl);
    const bool network = saved.isEmpty() && rule.source == SubtitleStore::OpenSubtitles;

    run([result, saved, rule, account, name](vlc_object_t* obj) {
            if (!saved.isEmpty())
            {
                // files moved or deleted since are left out
                for (const QString& subtitle : saved)
                    if (QUrl(subtitle).scheme().size() > 1 || QFileInfo::exists(subtitle))
                        result->append(subtitle);
                return;
            }

            // an episode of a folder with saved subtitles: matched the same way
            const SubtitleMatcher::Name video = SubtitleMatcher::parse(name);
            const SubtitleMatcher::Preference pref { rule.variant, rule.language };
            if (rule.source == SubtitleStore::Computer)
            {
                const QVector<ScannedFile> files = scanSubtitles(rule.path);
                QVector<SubtitleMatcher::Name> names;
                for (const ScannedFile& file : files)
                    names.append(SubtitleMatcher::parse(file.matchName));
                const int best = SubtitleMatcher::bestMatch(video, names, pref);
                if (best >= 0)
                    result->append(files.at(best).path);
                return;
            }

            const QVector<OpenSubtitles::Result> results =
                OpenSubtitles::search(obj, account, rule.query, rule.language, video.season, video.episode, 1, nullptr);
            QVector<SubtitleMatcher::Name> names;
            for (const OpenSubtitles::Result& r : results)
                names.append(parseResult(r));
            const int best = SubtitleMatcher::bestMatch(video, names, pref);
            if (best < 0)
                return;
            QString fileName;
            const QByteArray data = OpenSubtitles::download(obj, account, results.at(best).fileId, &fileName, nullptr);
            const QString folder = downloadFolder("opensubtitles");
            const QString file = folder + QChar('/') + QString::number(results.at(best).fileId) + QChar('-')
                                 + safeFileName(fileName.isEmpty() ? results.at(best).fileName : fileName);
            if (!data.isEmpty() && !folder.isEmpty() && writeFile(file, data))
                result->append(file);
        },
        [this, result, mrl, saved]() {
            if (result->isEmpty())
                return;
            // matched by the folder's rule: kept for this video, so the next time is direct
            if (saved.isEmpty())
            {
                m_store.setSubtitles(mrl, *result);
                writeStore();
            }
            attach(mrl, *result, true);
        }, network ? 3 : 0, false);
}

void AddSubtitles::attach(const QString& mrl, const QStringList& subtitles, bool select)
{
    vlc_player_t* player = m_intf->p_mainPlayerController->getPlayer();
    vlc_player_locker lock{ player };

    input_item_t* item = vlc_player_GetCurrentMedia(player);
    if (!item || SubtitleStore::mediaKey(qfu(item->psz_uri)) != SubtitleStore::mediaKey(mrl))
        return;

    // the subtitles VLC already loaded (found next to the video, added before)
    QSet<QString> loaded;
    vlc_mutex_lock(&item->lock);
    for (int i = 0; i < item->i_slaves; ++i)
        loaded.insert(SubtitleStore::mediaKey(qfu(item->pp_slaves[i]->psz_uri)));
    vlc_mutex_unlock(&item->lock);

    bool first = select;
    QString selectUri;
    for (const QString& subtitle : subtitles)
    {
        const QString uri = QUrl(subtitle).scheme().size() > 1 ? subtitle : mrlOf(subtitle);
        if (uri.isEmpty() || loaded.contains(SubtitleStore::mediaKey(uri)))
            continue;
        vlc_player_AddAssociatedMedia(player, SPU_ES, qtu(uri), first, false, false);
        if (first)
            selectUri = uri;
        first = false;
    }

    // the forced flag alone does not take the selection from a track the user picked (P3-10):
    // the added file's track is selected once VLC lists it
    if (!selectUri.isEmpty())
        selectSubtitleWhenListed(this, player,
                                 QCryptographicHash::hash(selectUri.toUtf8(), QCryptographicHash::Md5).toHex(),
                                 kSelectLookups);
}
