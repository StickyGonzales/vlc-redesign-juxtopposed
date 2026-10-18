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

#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "rdlibrarystore.hpp"

#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QJSEngine>
#include <QProcess>
#include <QSettings>
#include <QTextStream>

#include <algorithm>

#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_media_library.h>
#include <vlc_media_source.h>
#include <vlc_url.h>

#include "medialib.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "mlhelper.hpp"
#include "rdlibrarymodel.hpp"
#include "network/networkmediamodel.hpp"
#include "playlist/media.hpp"

namespace {

// Home shows this many frequently visited folders and playlists
constexpr int FREQUENT_COUNT = 10;
// folder events of a scan are reported at most this often
constexpr int FOLDER_EVENT_DELAY_MS = 300;

#define RD_LIBRARY_KEY(name) "RdLibrary/" name

// `mrl` is `root` or inside it
bool isInside(const QString& root, const QString& mrl)
{
    const QString rootKey = RdLibraryItems::mrlKey(root);
    const QString key = RdLibraryItems::mrlKey(mrl);
    return key == rootKey || (key.startsWith(rootKey) && key.at(rootKey.size()) == QLatin1Char('/'));
}

void removeMrl(QStringList& list, const QString& mrl)
{
    const QString key = RdLibraryItems::mrlKey(mrl);
    list.removeIf([&key](const QString& entry) { return RdLibraryItems::mrlKey(entry) == key; });
}

// the forms a file's MRL may have in the media library: as given, as Qt encodes it, as VLC does
QStringList mrlCandidates(const QString& mrl)
{
    QStringList candidates { mrl };
    const QUrl url(mrl);
    const QString qtEncoded = url.toString(QUrl::FullyEncoded);
    if (!candidates.contains(qtEncoded))
        candidates.append(qtEncoded);
    if (url.isLocalFile())
    {
        char* uri = vlc_path2uri(qtu(QDir::toNativeSeparators(url.toLocalFile())), "file");
        if (uri)
        {
            const QString vlcEncoded = qfu(uri);
            free(uri);
            if (!candidates.contains(vlcEncoded))
                candidates.append(vlcEncoded);
        }
    }
    return candidates;
}

// the media library stores folder MRLs with a trailing slash
QString withTrailingSlash(const QString& mrl)
{
    return mrl.endsWith(QLatin1Char('/')) ? mrl : mrl + QLatin1Char('/');
}

QString parentMrl(const QString& mrl)
{
    const int slash = mrl.lastIndexOf(QLatin1Char('/'));
    return slash > 0 ? mrl.left(slash) : mrl;
}

} // namespace

RdLibraryStore::RdLibraryStore(qt_intf_t* intf, MediaLib* mediaLib, QObject* parent)
    : QObject(parent)
    , p_intf(intf)
    , m_mediaLib(mediaLib)
    , m_eventCallback(nullptr, [this](vlc_ml_event_callback_t* cb) {
        m_mediaLib->unregisterEventListener(cb);
    })
{
    m_folderEventTimer.setSingleShot(true);
    m_folderEventTimer.setInterval(FOLDER_EVENT_DELAY_MS);
    connect(&m_folderEventTimer, &QTimer::timeout, this, &RdLibraryStore::foldersScanned);

    if (m_mediaLib)
        m_eventCallback.reset(m_mediaLib->registerEventListener(&RdLibraryStore::onMlEvent, this));

    QSettings* settings = getSettings();
    m_videoFolders = settings->value(RD_LIBRARY_KEY("videoFolders")).toStringList();
    m_musicFolders = settings->value(RD_LIBRARY_KEY("musicFolders")).toStringList();
    m_pins = settings->value(RD_LIBRARY_KEY("pins")).toList();
    m_streamLists = settings->value(RD_LIBRARY_KEY("streamLists")).toList();
    m_playlistCovers = settings->value(RD_LIBRARY_KEY("playlistCovers")).toMap();
    m_visits = settings->value(RD_LIBRARY_KEY("visits")).toMap();
    m_sortKeys = settings->value(RD_LIBRARY_KEY("sortKeys")).toMap();
    m_viewMode = settings->value(RD_LIBRARY_KEY("viewMode"), QStringLiteral("grid")).toString();
    m_compactViewMode = settings->value(RD_LIBRARY_KEY("compactViewMode"), QStringLiteral("list")).toString();
    m_hiddenRoots = settings->value(RD_LIBRARY_KEY("hiddenRoots")).toStringList();

    sortStandardFolders();
}

RdLibraryStore::~RdLibraryStore()
{
    m_eventCallback.reset();
}

void RdLibraryStore::onMlEvent(void* data, const vlc_ml_event_t* event)
{
    // media library thread
    auto* self = static_cast<RdLibraryStore*>(data);
    switch (event->i_type)
    {
    case VLC_ML_EVENT_ENTRY_POINT_ADDED:
        QMetaObject::invokeMethod(self, &RdLibraryStore::sortStandardFolders, Qt::QueuedConnection);
        [[fallthrough]];
    case VLC_ML_EVENT_FOLDER_ADDED:
        QMetaObject::invokeMethod(self, &RdLibraryStore::onFolderEvent, Qt::QueuedConnection);
        break;
    case VLC_ML_EVENT_DISCOVERY_COMPLETED:
        QMetaObject::invokeMethod(self, &RdLibraryStore::onScanCompleted, Qt::QueuedConnection);
        break;
    default:
        break;
    }
}

void RdLibraryStore::onFolderEvent()
{
    // the first event of a burst starts the delay, the next ones join it
    if (!m_folderEventTimer.isActive())
        m_folderEventTimer.start();
}

void RdLibraryStore::onScanCompleted()
{
    m_folderEventTimer.stop();
    emit foldersScanned();
    emit scanFinished();
}

void RdLibraryStore::save(const char* key, const QVariant& value)
{
    getSettings()->setValue(QString::fromLatin1(key), value);
}

void RdLibraryStore::setViewMode(const QString& mode)
{
    if (m_viewMode == mode)
        return;
    m_viewMode = mode;
    save(RD_LIBRARY_KEY("viewMode"), m_viewMode);
    emit viewModeChanged();
}

void RdLibraryStore::setCompactViewMode(const QString& mode)
{
    if (m_compactViewMode == mode)
        return;
    m_compactViewMode = mode;
    save(RD_LIBRARY_KEY("compactViewMode"), m_compactViewMode);
    emit viewModeChanged();
}

void RdLibraryStore::openDialogLater(std::function<void()> dialog)
{
    if (m_dialogPending)
        return;
    m_dialogPending = true;
    QMetaObject::invokeMethod(this, [this, dialog = std::move(dialog)]() {
        // the menus, popups and panels close first, as for VLC's own pickers
        if (DialogsProvider* provider = Singleton<DialogsProvider>::getInstance<false>())
            emit provider->dialogOpening();
        dialog();
        m_dialogPending = false;
    }, Qt::QueuedConnection);
}

void RdLibraryStore::warnOnError(const QJSValue& result) const
{
    // the callback runs after the click: the item that asked may be gone by then
    if (result.isError())
        msg_Warn(p_intf, "library picker callback: %s", qtu(result.toString()));
}

void RdLibraryStore::pickFolder(const QString& title, const QUrl& start, const QString& category,
                                QJSValue callback)
{
    openDialogLater([this, title, start, category, callback]() mutable {
        // the start folder is not checked: the native dialog falls back by itself when it is gone
        QUrl dir;
        if (start.isLocalFile())
            dir = start;
        else if (!category.isEmpty())
        {
            // the folder sortStandardFolders() gives the category, as VLC names it
            const QString standard = QVLCUserDir(category == QLatin1String("music") ? VLC_MUSIC_DIR
                                                                                    : VLC_VIDEOS_DIR);
            if (!standard.isEmpty())
                dir = QUrl::fromLocalFile(QDir::fromNativeSeparators(standard));
        }
        if (dir.isEmpty())
            dir = QUrl::fromLocalFile(QDir::homePath());
        const QUrl url = QFileDialog::getExistingDirectoryUrl(nullptr, title, dir);

        QJSEngine* engine = qjsEngine(this);
        if (engine && callback.isCallable())
            warnOnError(callback.call({ engine->toScriptValue(url) }));
    });
}

void RdLibraryStore::pickFiles(const QString& title, bool images, QJSValue callback)
{
    openDialogLater([this, title, images, callback]() mutable {
        const QString filter = images ? qtr("Images (*.png *.jpg *.jpeg *.bmp *.webp)") : QString();
        const QList<QUrl> urls = QFileDialog::getOpenFileUrls(nullptr, title,
                                                              QUrl::fromLocalFile(QDir::homePath()), filter);

        QJSEngine* engine = qjsEngine(this);
        if (engine && callback.isCallable())
            warnOnError(callback.call({ engine->toScriptValue(urls) }));
    });
}

/* folders */

void RdLibraryStore::addFolder(const QString& category, const QUrl& url)
{
    if (!url.isValid() || !m_mediaLib)
        return;

    const QString mrl = RdLibraryItems::normalizedMrl(url.toString(QUrl::FullyEncoded));

    struct Ctx {
        bool isRoot = false;
        // library folders the folder is inside
        QStringList containingRoots;
    };
    m_mediaLib->runOnMLThread<Ctx>(this,
    [mrl](vlc_medialibrary_t* ml, Ctx& ctx) {
        // a folder inside a library folder is only recorded; that library folder is reloaded
        // so a folder created after its last scan is listed too (the reload only looks at
        // what changed)
        ml_unique_ptr<vlc_ml_folder_list_t> roots(vlc_ml_list_entry_points(ml, nullptr));
        if (roots)
        {
            for (const vlc_ml_folder_t& root : ml_range_iterate<vlc_ml_folder_t>(roots))
            {
                if (!root.psz_mrl)
                    continue;
                const QString rootMrl = RdLibraryItems::normalizedMrl(qfu(root.psz_mrl));
                if (RdLibraryItems::mrlKey(rootMrl) == RdLibraryItems::mrlKey(mrl))
                    ctx.isRoot = true;
                else if (isInside(rootMrl, mrl))
                {
                    ctx.containingRoots.append(rootMrl);
                    vlc_ml_reload_folder(ml, root.psz_mrl);
                }
            }
        }
        if (!ctx.isRoot && ctx.containingRoots.isEmpty())
            vlc_ml_add_folder(ml, qtu(mrl));
    },
    [this, category, mrl](quint64, Ctx& ctx) {
        // the lists are members: pick them again here instead of keeping a reference across
        // the media library task
        const bool music = category == QLatin1String("music");
        QStringList& mine = music ? m_musicFolders : m_videoFolders;
        QStringList& other = music ? m_videoFolders : m_musicFolders;
        const auto inNoList = [this](const QString& folder) {
            return !RdLibraryItems::containsMrl(m_videoFolders, folder)
                && !RdLibraryItems::containsMrl(m_musicFolders, folder);
        };

        bool changed = false;
        if (ctx.isRoot && RdLibraryItems::containsMrl(m_hiddenRoots, mrl))
        {
            removeMrl(m_hiddenRoots, mrl);
            save(RD_LIBRARY_KEY("hiddenRoots"), m_hiddenRoots);
            changed = true;
        }
        if (ctx.isRoot)
        {
            // a library folder from before the redesign shows in both categories: it stays in
            // the other one
            if (inNoList(mrl))
            {
                other.append(mrl);
                changed = true;
            }
        }
        else if (!ctx.containingRoots.isEmpty())
        {
            // a folder inside a library folder: already shown here when that library folder
            // (or a folder of this category above it) is; otherwise it is listed at the root
            // of this category (e.g. a Music folder inside a Videos folder)
            bool shownHere = std::any_of(mine.cbegin(), mine.cend(), [&mrl](const QString& folder) {
                return isInside(folder, mrl);
            });
            for (const QString& root : std::as_const(ctx.containingRoots))
                shownHere = shownHere || inNoList(root);
            if (shownHere)
            {
                emit folderAdded(category, mrl);
                return;
            }
        }

        if (!RdLibraryItems::containsMrl(mine, mrl))
        {
            mine.append(mrl);
            changed = true;
        }
        if (changed)
        {
            save(RD_LIBRARY_KEY("videoFolders"), m_videoFolders);
            save(RD_LIBRARY_KEY("musicFolders"), m_musicFolders);
            emit foldersChanged();
        }
        emit folderAdded(category, mrl);
    });
}

void RdLibraryStore::sortStandardFolders()
{
    if (!m_mediaLib)
        return;

    struct Ctx {
        QStringList roots;
        QString videosKey;
        QString musicKey;
    };
    m_mediaLib->runOnMLThread<Ctx>(this,
    [](vlc_medialibrary_t* ml, Ctx& ctx) {
        ml_unique_ptr<vlc_ml_folder_list_t> roots(vlc_ml_list_entry_points(ml, nullptr));
        if (!roots)
            return;
        for (const vlc_ml_folder_t& root : ml_range_iterate<vlc_ml_folder_t>(roots))
        {
            if (root.psz_mrl && !root.b_banned)
                ctx.roots.append(RdLibraryItems::normalizedMrl(qfu(root.psz_mrl)));
        }

        // the user folders may be read from disk (XDG user-dirs): here, off the UI thread
        const auto userDirKey = [](vlc_userdir_t type) -> QString {
            const QString path = QVLCUserDir(type);
            if (path.isEmpty())
                return {};
            return RdLibraryItems::mrlKey(QUrl::fromLocalFile(QDir::fromNativeSeparators(path))
                                              .toString(QUrl::FullyEncoded));
        };
        const QString homeKey = userDirKey(VLC_HOME_DIR);
        ctx.videosKey = userDirKey(VLC_VIDEOS_DIR);
        ctx.musicKey = userDirKey(VLC_MUSIC_DIR);
        // a system without its own Videos or Music folder names the home folder: that one
        // stays in both categories
        if (ctx.videosKey == homeKey || ctx.videosKey == ctx.musicKey)
            ctx.videosKey.clear();
        if (ctx.musicKey == homeKey)
            ctx.musicKey.clear();
    },
    [this](quint64, Ctx& ctx) {
        if (ctx.videosKey.isEmpty() && ctx.musicKey.isEmpty())
            return;

        bool changed = false;
        for (const QString& root : std::as_const(ctx.roots))
        {
            if (RdLibraryItems::containsMrl(m_videoFolders, root)
                || RdLibraryItems::containsMrl(m_musicFolders, root)
                || RdLibraryItems::containsMrl(m_hiddenRoots, root))
                continue;
            const QString key = RdLibraryItems::mrlKey(root);
            if (!ctx.videosKey.isEmpty() && key == ctx.videosKey)
                m_videoFolders.append(root);
            else if (!ctx.musicKey.isEmpty() && key == ctx.musicKey)
                m_musicFolders.append(root);
            else
                continue;
            changed = true;
        }
        if (!changed)
            return;
        save(RD_LIBRARY_KEY("videoFolders"), m_videoFolders);
        save(RD_LIBRARY_KEY("musicFolders"), m_musicFolders);
        emit foldersChanged();
    });
}

void RdLibraryStore::removeFolder(const QString& category, const QString& mrl)
{
    const QString normalized = RdLibraryItems::normalizedMrl(mrl);
    QStringList& mine = (category == QLatin1String("music")) ? m_musicFolders : m_videoFolders;
    QStringList& other = (category == QLatin1String("music")) ? m_videoFolders : m_musicFolders;

    // a folder in no list (added before the redesign) shows in both categories: removing it
    // from one keeps it in the other
    const bool inOther = RdLibraryItems::containsMrl(other, normalized);
    const bool inMine = RdLibraryItems::containsMrl(mine, normalized);
    const bool shownInOther = inOther || !inMine;
    if (!inOther && !inMine)
        other.append(normalized);
    removeMrl(mine, normalized);

    // a library folder leaves the media library once no category shows it. When folders of a
    // category are inside it (a Music folder inside a Videos folder) it stays in the media
    // library, hidden, so their media keep their data (play counts, progress, thumbnails).
    // A folder inside a library folder is only taken off its list.
    bool leaveLibrary = false;
    if (!shownInOther)
    {
        const bool hasInner = std::any_of(m_videoFolders.cbegin(), m_videoFolders.cend(), [&normalized](const QString& folder) {
            return RdLibraryItems::mrlKey(folder) != RdLibraryItems::mrlKey(normalized) && isInside(normalized, folder);
        }) || std::any_of(m_musicFolders.cbegin(), m_musicFolders.cend(), [&normalized](const QString& folder) {
            return RdLibraryItems::mrlKey(folder) != RdLibraryItems::mrlKey(normalized) && isInside(normalized, folder);
        });
        if (hasInner)
        {
            if (!RdLibraryItems::containsMrl(m_hiddenRoots, normalized))
                m_hiddenRoots.append(normalized);
            save(RD_LIBRARY_KEY("hiddenRoots"), m_hiddenRoots);
        }
        else
        {
            leaveLibrary = true;
        }
    }
    save(RD_LIBRARY_KEY("videoFolders"), m_videoFolders);
    save(RD_LIBRARY_KEY("musicFolders"), m_musicFolders);
    emit foldersChanged();

    if (leaveLibrary && m_mediaLib)
    {
        m_mediaLib->runOnMLThread(this, [normalized](vlc_medialibrary_t* ml) {
            ml_unique_ptr<vlc_ml_folder_list_t> roots(vlc_ml_list_entry_points(ml, nullptr));
            if (!roots)
                return;
            // removed by the media library's own MRL of the folder
            const QString key = RdLibraryItems::mrlKey(normalized);
            for (const vlc_ml_folder_t& root : ml_range_iterate<vlc_ml_folder_t>(roots))
            {
                if (root.psz_mrl && RdLibraryItems::mrlKey(qfu(root.psz_mrl)) == key)
                {
                    vlc_ml_remove_folder(ml, root.psz_mrl);
                    break;
                }
            }
        });
    }
}

void RdLibraryStore::reloadFolder(const QString& mrl)
{
    if (!m_mediaLib)
        return;
    m_mediaLib->runOnMLThread(this, [mrl](vlc_medialibrary_t* ml) {
        vlc_ml_reload_folder(ml, mrl.isEmpty() ? nullptr : qtu(withTrailingSlash(mrl)));
    });
}

void RdLibraryStore::resolveFolder(const QString& mrl, QJSValue callback, const QString& preferred)
{
    if (!m_mediaLib || !callback.isCallable())
        return;

    struct Crumb {
        MLItemId id;
        QString title;
        QString mrl;
    };
    struct Ctx {
        std::vector<Crumb> crumbs;
        bool audio = false;
    };

    const QString target = RdLibraryItems::normalizedMrl(mrl);
    const QStringList candidates = mrlCandidates(target);
    m_mediaLib->runOnMLThread<Ctx>(this,
    [target, candidates](vlc_medialibrary_t* ml, Ctx& ctx) {
        QString folderMrl = target;
        for (const QString& candidate : candidates)
        {
            ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media_by_mrl(ml, qtu(candidate)));
            if (media)
            {
                ctx.audio = media->i_type == VLC_ML_MEDIA_TYPE_AUDIO;
                folderMrl = parentMrl(target);
                break;
            }
        }

        ml_unique_ptr<vlc_ml_folder_list_t> roots(vlc_ml_list_entry_points(ml, nullptr));
        if (!roots)
            return;
        int64_t current = 0;
        QString currentMrl;
        for (const vlc_ml_folder_t& root : ml_range_iterate<vlc_ml_folder_t>(roots))
        {
            if (!root.psz_mrl || root.b_banned)
                continue;
            const QString rootMrl = RdLibraryItems::normalizedMrl(qfu(root.psz_mrl));
            if (isInside(rootMrl, folderMrl))
            {
                current = root.i_id;
                currentMrl = rootMrl;
                ctx.crumbs.push_back({ MLItemId(root.i_id, VLC_ML_PARENT_FOLDER), qfu(root.psz_name), rootMrl });
                break;
            }
        }

        // walk down the subfolders to the folder itself
        while (current != 0 && RdLibraryItems::mrlKey(currentMrl) != RdLibraryItems::mrlKey(folderMrl))
        {
            vlc_ml_folder_list_t* list = nullptr;
            if (vlc_ml_list(ml, VLC_ML_LIST_SUBFOLDERS, nullptr, current, &list) != VLC_SUCCESS || !list)
                break;
            ml_unique_ptr<vlc_ml_folder_list_t> subfolders(list);
            int64_t next = 0;
            for (const vlc_ml_folder_t& folder : ml_range_iterate<vlc_ml_folder_t>(subfolders))
            {
                if (!folder.psz_mrl)
                    continue;
                const QString subMrl = RdLibraryItems::normalizedMrl(qfu(folder.psz_mrl));
                if (isInside(subMrl, folderMrl))
                {
                    next = folder.i_id;
                    currentMrl = subMrl;
                    ctx.crumbs.push_back({ MLItemId(folder.i_id, VLC_ML_PARENT_FOLDER), qfu(folder.psz_name), subMrl });
                    break;
                }
            }
            current = next;
        }
    },
    [this, callback, preferred](quint64, Ctx& ctx) mutable {
        QJSEngine* engine = qjsEngine(this);
        if (!engine)
            return;
        if (ctx.crumbs.empty())
        {
            callback.call({ QJSValue(QJSValue::NullValue) });
            return;
        }

        // the deepest folder added to a category decides it, and the address line starts there
        // (a Music folder inside a Videos folder is listed at the root of Music). A preferred
        // category wins when the folder is shown there: below one of its folders, or below a
        // library folder from before the redesign (in no list, shown in both)
        const auto deepestIn = [&ctx](const QStringList& folders) -> int {
            for (size_t i = ctx.crumbs.size(); i-- > 0;)
            {
                if (RdLibraryItems::containsMrl(folders, ctx.crumbs[i].mrl))
                    return static_cast<int>(i);
            }
            return -1;
        };
        const int deepestMusic = deepestIn(m_musicFolders);
        const int deepestVideo = deepestIn(m_videoFolders);

        QString category = ctx.audio ? QStringLiteral("music") : QStringLiteral("video");
        size_t first = 0;
        const int preferredDepth = preferred == QLatin1String("music") ? deepestMusic
                                 : preferred == QLatin1String("video") ? deepestVideo : -1;
        const bool rootInNoList = deepestMusic < 0 && deepestVideo < 0;
        if (preferredDepth >= 0)
        {
            category = preferred;
            first = static_cast<size_t>(preferredDepth);
        }
        else if (!preferred.isEmpty() && rootInNoList)
        {
            category = preferred;
        }
        else if (deepestMusic >= 0 || deepestVideo >= 0)
        {
            // same depth (a folder in both lists): music, as Home does
            const bool music = deepestMusic >= deepestVideo;
            category = music ? QStringLiteral("music") : QStringLiteral("video");
            first = static_cast<size_t>(music ? deepestMusic : deepestVideo);
        }
        ctx.crumbs.erase(ctx.crumbs.begin(), ctx.crumbs.begin() + first);

        QVariantList crumbs;
        for (const Crumb& crumb : ctx.crumbs)
        {
            crumbs.append(QVariantMap {
                { QStringLiteral("id"), QVariant::fromValue(crumb.id) },
                { QStringLiteral("title"), crumb.title },
                { QStringLiteral("mrl"), crumb.mrl },
            });
        }
        const QVariantMap result {
            { QStringLiteral("category"), category },
            { QStringLiteral("crumbs"), crumbs },
        };
        callback.call({ engine->toScriptValue(result) });
    });
}

/* pins */

void RdLibraryStore::addPin(const QString& kind, const QString& title, const QString& image,
                            const QVariantMap& location)
{
    if (pinIndex(location) >= 0)
        return;
    m_pins.append(QVariantMap {
        { QStringLiteral("kind"), kind },
        { QStringLiteral("title"), title },
        { QStringLiteral("image"), image },
        { QStringLiteral("location"), location },
    });
    save(RD_LIBRARY_KEY("pins"), m_pins);
    emit pinsChanged();
}

void RdLibraryStore::removePin(int index)
{
    if (index < 0 || index >= m_pins.size())
        return;
    m_pins.removeAt(index);
    save(RD_LIBRARY_KEY("pins"), m_pins);
    emit pinsChanged();
}

void RdLibraryStore::movePin(int from, int to)
{
    if (from < 0 || from >= m_pins.size() || to < 0 || to >= m_pins.size() || from == to)
        return;
    m_pins.move(from, to);
    save(RD_LIBRARY_KEY("pins"), m_pins);
    emit pinsChanged();
}

int RdLibraryStore::pinIndex(const QVariantMap& location) const
{
    // a location is identified by its page and its key (folder MRL, playlist id, stream list URL)
    const QString page = location.value(QStringLiteral("page")).toString();
    const QString key = location.value(QStringLiteral("key")).toString();
    for (int i = 0; i < m_pins.size(); ++i)
    {
        const QVariantMap pin = m_pins.at(i).toMap().value(QStringLiteral("location")).toMap();
        if (pin.value(QStringLiteral("page")).toString() == page && pin.value(QStringLiteral("key")).toString() == key)
            return i;
    }
    return -1;
}

/* network stream lists */

QVariantMap RdLibraryStore::addStreamList(const QString& name, const QString& url)
{
    // as DialogsProvider::openNetworkStreams
    const QString link = url.trimmed();
    if (link.isEmpty())
        return {};
    char* uri = link.contains(QLatin1String("://"))
              ? vlc_uri_fixup(qtu(link))
              : vlc_path2uri(qtu(QDir::toNativeSeparators(link)), nullptr);
    if (uri == nullptr)
    {
        msg_Warn(p_intf, "invalid network link: %s", qtu(link));
        return {};
    }
    const QString mrl = qfu(uri);
    free(uri);

    const QString key = RdLibraryItems::mrlKey(mrl);
    for (const QVariant& entry : std::as_const(m_streamLists))
    {
        const QVariantMap map = entry.toMap();
        if (RdLibraryItems::mrlKey(map.value(QStringLiteral("url")).toString()) == key)
            return map;
    }
    const QVariantMap entry {
        { QStringLiteral("name"), name },
        { QStringLiteral("url"), mrl },
    };
    m_streamLists.append(entry);
    save(RD_LIBRARY_KEY("streamLists"), m_streamLists);
    emit streamListsChanged();
    return entry;
}

void RdLibraryStore::removeStreamList(int index)
{
    if (index < 0 || index >= m_streamLists.size())
        return;
    m_streamLists.removeAt(index);
    save(RD_LIBRARY_KEY("streamLists"), m_streamLists);
    emit streamListsChanged();
}

void RdLibraryStore::renameStreamList(int index, const QString& name)
{
    if (index < 0 || index >= m_streamLists.size() || name.trimmed().isEmpty())
        return;
    QVariantMap entry = m_streamLists.at(index).toMap();
    entry.insert(QStringLiteral("name"), name.trimmed());
    m_streamLists[index] = entry;
    save(RD_LIBRARY_KEY("streamLists"), m_streamLists);
    emit streamListsChanged();
}

QVariant RdLibraryStore::treeForUrl(const QString& url, const QString& name) const
{
    const QUrl qurl(url);
    input_item_t* item = qurl.isLocalFile()
        ? input_item_NewDirectory(qtu(url), qtu(name), ITEM_LOCAL)
        : input_item_NewExt(qtu(url), qtu(name), INPUT_DURATION_UNSET, ITEM_TYPE_PLAYLIST, ITEM_NET);
    if (!item)
        return {};

    SharedInputItem inputItem(item, false);
    MediaTreePtr tree(vlc_media_tree_New(), false);
    if (!tree)
        return {};
    {
        MediaTreeLocker lock{tree};
        vlc_media_tree_Add(tree.get(), &(tree->root), item);
    }
    return QVariant::fromValue(NetworkTreeItem(tree, inputItem));
}

/* visits */

void RdLibraryStore::noteVisit(const QString& kind, const MLItemId& id)
{
    if (!id.isValid())
        return;
    const QString key = kind + QLatin1Char(':') + QString::number(id.id);
    m_visits.insert(key, m_visits.value(key).toInt() + 1);
    save(RD_LIBRARY_KEY("visits"), m_visits);
    emit visitsChanged();
}

QVariantList RdLibraryStore::frequentIds(const QString& kind) const
{
    const QString prefix = kind + QLatin1Char(':');
    std::vector<std::pair<qint64, int>> counts;
    for (auto it = m_visits.cbegin(); it != m_visits.cend(); ++it)
    {
        if (it.key().startsWith(prefix))
            counts.emplace_back(it.key().mid(prefix.size()).toLongLong(), it.value().toInt());
    }
    std::stable_sort(counts.begin(), counts.end(), [](const auto& a, const auto& b) {
        return a.second > b.second;
    });

    QVariantList ids;
    for (const auto& entry : counts)
    {
        if (ids.size() >= FREQUENT_COUNT)
            break;
        ids.append(entry.first);
    }
    return ids;
}

/* playlists */

void RdLibraryStore::appendItems(vlc_medialibrary_t* ml, int64_t playlistId, const QVariantList& items)
{
    for (const QVariant& item : items)
    {
        int64_t mediaId = 0;
        if (item.canConvert<MLItemId>() && item.value<MLItemId>().isValid())
        {
            mediaId = item.value<MLItemId>().id;
        }
        else
        {
            const QString mrl = item.canConvert<QUrl>() ? item.toUrl().toString(QUrl::FullyEncoded) : item.toString();
            if (mrl.isEmpty())
                continue;
            ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media_by_mrl(ml, qtu(mrl)));
            if (!media)
                media.reset(vlc_ml_new_external_media(ml, qtu(mrl)));
            if (!media)
                continue;
            mediaId = media->i_id;
        }
        vlc_ml_playlist_append(ml, playlistId, &mediaId, 1);
    }
}

void RdLibraryStore::createPlaylist(const QString& name, const QVariantList& items, const QUrl& cover)
{
    if (!m_mediaLib || name.trimmed().isEmpty())
        return;

    struct Ctx {
        int64_t id = 0;
    };
    const QString title = name.trimmed();
    m_mediaLib->runOnMLThread<Ctx>(this,
    [title, items](vlc_medialibrary_t* ml, Ctx& ctx) {
        ml_unique_ptr<vlc_ml_playlist_t> playlist(vlc_ml_playlist_create(ml, qtu(title)));
        if (!playlist)
            return;
        ctx.id = playlist->i_id;
        appendItems(ml, ctx.id, items);
    },
    [this, cover](quint64, Ctx& ctx) {
        if (ctx.id == 0)
            return;
        const MLItemId id(ctx.id, VLC_ML_PARENT_PLAYLIST);
        if (cover.isValid())
            setPlaylistCover(id, cover);
        emit playlistCreated(id);
    });
}

void RdLibraryStore::appendToPlaylist(const MLItemId& playlistId, const QVariantList& items)
{
    if (!m_mediaLib || !playlistId.isValid() || items.isEmpty())
        return;
    const int64_t id = playlistId.id;
    m_mediaLib->runOnMLThread(this, [id, items](vlc_medialibrary_t* ml) {
        appendItems(ml, id, items);
    });
}

void RdLibraryStore::renamePlaylist(const MLItemId& playlistId, const QString& name)
{
    if (!m_mediaLib || !playlistId.isValid() || name.trimmed().isEmpty())
        return;
    const int64_t id = playlistId.id;
    const QString title = name.trimmed();
    m_mediaLib->runOnMLThread(this, [id, title](vlc_medialibrary_t* ml) {
        vlc_ml_playlist_rename(ml, id, qtu(title));
    });
}

void RdLibraryStore::deletePlaylist(const MLItemId& playlistId)
{
    if (!m_mediaLib || !playlistId.isValid())
        return;
    struct Ctx {
        bool deleted = false;
    };
    const int64_t id = playlistId.id;
    m_mediaLib->runOnMLThread<Ctx>(this,
    [id](vlc_medialibrary_t* ml, Ctx& ctx) {
        ctx.deleted = vlc_ml_playlist_delete(ml, id) == VLC_SUCCESS;
    },
    [this, id](quint64, Ctx& ctx) {
        if (!ctx.deleted)
        {
            msg_Warn(p_intf, "could not delete playlist %" PRId64, id);
            return;
        }
        const QString key = QString::number(id);
        const QString cover = m_playlistCovers.value(key).toUrl().toLocalFile();
        if (!cover.isEmpty())
            QFile::remove(cover);
        m_playlistCovers.remove(key);
        save(RD_LIBRARY_KEY("playlistCovers"), m_playlistCovers);
        emit playlistCoversChanged();
    });
}

QString RdLibraryStore::coverDirectory() const
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return {};
    const QString path = QDir(qfu(dir)).filePath(QStringLiteral("playlist-covers"));
    free(dir);
    if (!QDir().mkpath(path))
    {
        msg_Warn(p_intf, "could not create %s", qtu(path));
        return {};
    }
    return path;
}

void RdLibraryStore::setPlaylistCover(const MLItemId& playlistId, const QUrl& image)
{
    if (!playlistId.isValid() || !image.isLocalFile())
        return;

    // the cover is copied, so it stays when the original image moves
    const QString directory = coverDirectory();
    if (directory.isEmpty())
        return;
    const QString key = QString::number(playlistId.id);
    const QString previous = m_playlistCovers.value(key).toUrl().toLocalFile();
    const QString target = QDir(directory).filePath(
        QStringLiteral("%1-%2.%3").arg(key)
                                  .arg(QDateTime::currentMSecsSinceEpoch())
                                  .arg(QFileInfo(image.toLocalFile()).suffix().toLower()));
    if (!QFile::copy(image.toLocalFile(), target))
    {
        msg_Warn(p_intf, "could not copy the playlist cover to %s", qtu(target));
        return;
    }
    if (!previous.isEmpty())
        QFile::remove(previous);

    m_playlistCovers.insert(key, QUrl::fromLocalFile(target));
    save(RD_LIBRARY_KEY("playlistCovers"), m_playlistCovers);
    emit playlistCoversChanged();
}

QUrl RdLibraryStore::playlistCover(const MLItemId& playlistId) const
{
    return m_playlistCovers.value(QString::number(playlistId.id)).toUrl();
}

void RdLibraryStore::exportPlaylist(const MLItemId& playlistId, const QString& name)
{
    if (!m_mediaLib || !playlistId.isValid())
        return;

    // asked from a menu row: the dialog opens once the menu's click is handled (see pickFolder)
    openDialogLater([this, playlistId, name]() {
        const QString file = QFileDialog::getSaveFileName(nullptr, qtr("Export Playlist"),
                                                          QDir(QDir::homePath()).filePath(name + QStringLiteral(".m3u8")),
                                                          qtr("M3U playlist (*.m3u8 *.m3u)"));
        if (!file.isEmpty())
            writePlaylist(playlistId, file);
    });
}

void RdLibraryStore::writePlaylist(const MLItemId& playlistId, const QString& file)
{
    struct Ctx {
        QStringList lines;
    };
    const int64_t id = playlistId.id;
    m_mediaLib->runOnMLThread<Ctx>(this,
    [id](vlc_medialibrary_t* ml, Ctx& ctx) {
        ml_unique_ptr<vlc_ml_media_list_t> media(vlc_ml_list_media_of(ml, nullptr, VLC_ML_PARENT_PLAYLIST, id));
        if (!media)
            return;
        for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(media))
        {
            if (!m.p_files || m.p_files->i_nb_items == 0 || !m.p_files->p_items[0].psz_mrl)
                continue;
            // -1: unknown length (a stream), as the M3U format says
            const int64_t seconds = m.i_duration > 0 ? m.i_duration / 1000 : -1;
            ctx.lines.append(QStringLiteral("#EXTINF:%1,%2").arg(seconds).arg(qfu(m.psz_title)));
            const QUrl url(qfu(m.p_files->p_items[0].psz_mrl));
            ctx.lines.append(url.isLocalFile() ? QDir::toNativeSeparators(url.toLocalFile())
                                               : qfu(m.p_files->p_items[0].psz_mrl));
        }
    },
    [this, file](quint64, Ctx& ctx) {
        QFile out(file);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        {
            msg_Warn(p_intf, "could not write the playlist to %s", qtu(file));
            return;
        }
        QTextStream stream(&out);
        stream << "#EXTM3U\n";
        for (const QString& line : std::as_const(ctx.lines))
            stream << line << '\n';
    });
}

void RdLibraryStore::playlistMedia(const MLItemId& playlistId, QJSValue callback)
{
    if (!m_mediaLib || !playlistId.isValid() || !callback.isCallable())
        return;

    struct Ctx {
        QStringList mrls;
    };
    const int64_t id = playlistId.id;
    m_mediaLib->runOnMLThread<Ctx>(this,
    [id](vlc_medialibrary_t* ml, Ctx& ctx) {
        ml_unique_ptr<vlc_ml_media_list_t> media(vlc_ml_list_media_of(ml, nullptr, VLC_ML_PARENT_PLAYLIST, id));
        if (!media)
            return;
        for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(media))
        {
            if (m.p_files && m.p_files->i_nb_items > 0 && m.p_files->p_items[0].psz_mrl)
                ctx.mrls.append(qfu(m.p_files->p_items[0].psz_mrl));
        }
    },
    [this, callback](quint64, Ctx& ctx) mutable {
        QJSEngine* engine = qjsEngine(this);
        if (!engine)
            return;
        callback.call({ engine->toScriptValue(ctx.mrls) });
    });
}

/* media */

void RdLibraryStore::setWatched(const QVariantList& mediaIds, bool watched)
{
    if (!m_mediaLib)
        return;
    std::vector<int64_t> ids;
    for (const QVariant& id : mediaIds)
    {
        if (id.canConvert<MLItemId>() && id.value<MLItemId>().isValid())
            ids.push_back(id.value<MLItemId>().id);
    }
    m_mediaLib->runOnMLThread(this, [ids, watched](vlc_medialibrary_t* ml) {
        for (int64_t id : ids)
            vlc_ml_media_set_played(ml, id, watched);
    });
}

void RdLibraryStore::setFavorite(const MLItemId& id, const QString& mrl, bool favorite)
{
    if (!m_mediaLib || !id.isValid())
        return;
    const MLItemId item = id;
    m_mediaLib->runOnMLThread(this, [item, mrl, favorite](vlc_medialibrary_t* ml) {
        switch (item.type)
        {
        case VLC_ML_PARENT_FOLDER:
            vlc_ml_folder_set_favorite(ml, qtu(withTrailingSlash(mrl)), favorite);
            break;
        case VLC_ML_PARENT_PLAYLIST:
            vlc_ml_playlist_set_favorite(ml, item.id, favorite);
            break;
        case VLC_ML_PARENT_ARTIST:
            vlc_ml_artist_set_favorite(ml, item.id, favorite);
            break;
        case VLC_ML_PARENT_ALBUM:
            vlc_ml_album_set_favorite(ml, item.id, favorite);
            break;
        case VLC_ML_PARENT_GENRE:
            vlc_ml_genre_set_favorite(ml, item.id, favorite);
            break;
        default:
            vlc_ml_media_set_favorite(ml, item.id, favorite);
            break;
        }
    });
}

void RdLibraryStore::showInFileExplorer(const QString& mrl) const
{
    const QUrl url(mrl);
    if (!url.isLocalFile())
        return;
    const QString path = QDir::toNativeSeparators(url.toLocalFile());
#ifdef _WIN32
    // "/select," and the path as separate arguments: explorer does not parse a quoted pair
    QProcess::startDetached(QStringLiteral("explorer.exe"), { QStringLiteral("/select,"), path });
#else
    QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(url.toLocalFile()).absolutePath()));
#endif
}

void RdLibraryStore::clearHistory()
{
    if (!m_mediaLib)
        return;
    m_mediaLib->runOnMLThread(this, [](vlc_medialibrary_t* ml) {
        vlc_ml_clear_history(ml, VLC_ML_HISTORY_TYPE_GLOBAL);
    });
}

/* sorting */

QString RdLibraryStore::sortKey(const QString& page, const QString& fallback) const
{
    return m_sortKeys.value(page, fallback).toString();
}

void RdLibraryStore::setSortKey(const QString& page, const QString& key)
{
    if (m_sortKeys.value(page).toString() == key)
        return;
    m_sortKeys.insert(page, key);
    save(RD_LIBRARY_KEY("sortKeys"), m_sortKeys);
    emit sortKeysChanged();
}
