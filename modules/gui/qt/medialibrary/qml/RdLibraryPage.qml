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

// redesign: one library page (every location of RdLibraryNav but Home): the "+ Add" row and
// fixed rows on top, then the page's items as rows (list view) or cards (grid view).
//   Videos, Songs and their folders (video 10:56-11:59, 12:00-12:07; P5-16, P5-29, F-14)
//   Music with Songs, Albums, Artists, Genres (12:07-12:14, P6-02, P6-03)
//   Network with the stream lists, Podcasts and Radio (12:23-12:28, 13:13-13:20; P6-07, P6-14)
//   Playlists and a playlist (13:20-13:30; P6-15)
//   Recent and the whole Home sections (13:42-13:44; P6-19)
// Interface used by RdLibraryHeader: itemCount, sortOptions, sortKey, defaultSortKey,
// setSortKey(), searchable, searchText, viewMode, setViewMode().
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.MediaLibrary

FocusScope {
    id: page

    required property var location
    // next to the video (one column of rows by default) or in the full library
    property bool compact: true

    property string searchText: ""

    readonly property string viewMode: compact ? RdLibraryStore.compactViewMode : RdLibraryStore.viewMode
    readonly property bool listMode: viewMode === "list"

    function setViewMode(mode) {
        if (compact)
            RdLibraryStore.compactViewMode = mode
        else
            RdLibraryStore.viewMode = mode
    }

    readonly property int itemCount: (dataModel ? dataModel.count : 0) + (subfolderModel ? subfolderModel.count : 0)
                                     + fixedRows.filter((r) => !r.isAction).length
    readonly property bool searchable: !!dataModel

    // the category of the page (folder rows open as folders of it)
    readonly property string category: {
        switch (location.page) {
        case "folder": return location.category
        case "videos": return "video"
        default: return "music"
        }
    }

    // the pages of a category; elsewhere (Home sections, Recent, playlists, streams) an item
    // belongs to its own category
    readonly property bool _categoryPage: ["folder", "videos", "music", "songs", "albums", "artists",
                                           "genres", "collection"].indexOf(location.page) >= 0

    function categoryOf(item) {
        return _categoryPage ? category : RdLibraryNav.itemCategory(item)
    }

    // sort: one remembered order per kind of page (IB-03, P5-13)
    readonly property string sortPage: {
        switch (location.page) {
        case "folder": return location.category === "music" ? "musicFolder" : "videoFolder"
        case "collection": return "collection-" + location.kind
        default: return location.page
        }
    }

    // sort orders of the page (Figma "Sorting Options", P5-13, IB-03): criteria of VLC's models,
    // sorted by the media library
    readonly property var _nameOptions: [
        { key: "title", text: qsTr("Title A-Z"), criteria: "name", desc: false },
        { key: "titleDesc", text: qsTr("Title Z-A"), criteria: "name", desc: true }
    ]
    // a folder's media are listed by VLC's media library, which keeps the order of equal values
    // (e.g. the unwatched files among themselves) as it stores them
    readonly property var _videoOptions: [
        { key: "unwatched", text: qsTr("Unwatched First"), criteria: "playcount", desc: false },
        { key: "watched", text: qsTr("Watched First"), criteria: "playcount", desc: true },
        { key: "newest", text: qsTr("Newest First"), criteria: "insertion", desc: true },
        { key: "oldest", text: qsTr("Oldest First"), criteria: "insertion", desc: false },
        { key: "title", text: qsTr("Title A-Z"), criteria: "title", desc: false },
        { key: "titleDesc", text: qsTr("Title Z-A"), criteria: "title", desc: true },
        { key: "uri", text: qsTr("URI Ascending"), criteria: "filename", desc: false },
        { key: "uriDesc", text: qsTr("URI Descending"), criteria: "filename", desc: true }
    ]
    readonly property var _songOptions: [
        { key: "newest", text: qsTr("Newest First"), criteria: "insertion", desc: true },
        { key: "oldest", text: qsTr("Oldest First"), criteria: "insertion", desc: false },
        { key: "title", text: qsTr("Title A-Z"), criteria: "title", desc: false },
        { key: "titleDesc", text: qsTr("Title Z-A"), criteria: "title", desc: true },
        { key: "artist", text: qsTr("Artist A-Z"), criteria: "main_artist", desc: false },
        { key: "artistDesc", text: qsTr("Artist Z-A"), criteria: "main_artist", desc: true },
        { key: "album", text: qsTr("Album A-Z"), criteria: "album_title", desc: false },
        { key: "albumDesc", text: qsTr("Album Z-A"), criteria: "album_title", desc: true },
        { key: "track", text: qsTr("Track Number Ascending"), criteria: "track_number", desc: false },
        { key: "trackDesc", text: qsTr("Track Number Descending"), criteria: "track_number", desc: true },
        { key: "uri", text: qsTr("URI Ascending"), criteria: "filename", desc: false },
        { key: "uriDesc", text: qsTr("URI Descending"), criteria: "filename", desc: true }
    ]
    readonly property var _albumOptions: [
        { key: "title", text: qsTr("Title A-Z"), criteria: "title", desc: false },
        { key: "titleDesc", text: qsTr("Title Z-A"), criteria: "title", desc: true },
        { key: "artist", text: qsTr("Artist A-Z"), criteria: "main_artist", desc: false },
        { key: "artistDesc", text: qsTr("Artist Z-A"), criteria: "main_artist", desc: true },
        { key: "newest", text: qsTr("Newest First"), criteria: "release_year", desc: true },
        { key: "oldest", text: qsTr("Oldest First"), criteria: "release_year", desc: false }
    ]
    // the category roots (Videos, Music > Songs): her order is the order the folders were
    // added in (video 11:58 "Shows, Youtube Footage, Courses, Films, Anime"; Figma sidebar)
    readonly property var _rootFolderOptions: [
        { key: "newest", text: qsTr("Newest First"), criteria: "insertion", desc: true },
        { key: "oldest", text: qsTr("Oldest First"), criteria: "insertion", desc: false },
        { key: "title", text: qsTr("Title A-Z"), criteria: "title", desc: false },
        { key: "titleDesc", text: qsTr("Title Z-A"), criteria: "title", desc: true }
    ]
    readonly property var _playlistOptions: [
        { key: "title", text: qsTr("Title A-Z"), criteria: "title", desc: false },
        { key: "titleDesc", text: qsTr("Title Z-A"), criteria: "title", desc: true }
    ]

    readonly property var sortOptions: {
        switch (location.page) {
        case "folder":
            return location.category === "music" ? _songOptions : _videoOptions
        case "collection":
            return _songOptions
        case "playlist":
            return _playlistOptions
        case "videos":
        case "songs":
            return _rootFolderOptions
        case "albums":
            return _albumOptions
        case "artists":
        case "genres":
            return _nameOptions
        default:
            return []
        }
    }

    readonly property string defaultSortKey: {
        switch (location.page) {
        case "collection": return location.kind === "album" ? "track" : "title"
        case "playlist": return ""   // the playlist's own order
        case "videos":
        case "songs": return "oldest"
        default: return sortOptions.length > 0 ? "title" : ""
        }
    }

    property string sortKey: RdLibraryStore.sortKey(sortPage, defaultSortKey)

    function setSortKey(key) {
        sortKey = key
        RdLibraryStore.setSortKey(sortPage, key)
    }

    readonly property var _sortSpec: {
        for (let i = 0; i < sortOptions.length; ++i) {
            if (sortOptions[i].key === sortKey)
                return sortOptions[i]
        }
        return { criteria: "", desc: false }
    }
    readonly property string sortCriteria: _sortSpec.criteria
    readonly property int sortOrder: _sortSpec.desc ? Qt.DescendingOrder : Qt.AscendingOrder

    // the file playing now, to mark its row (11:41)
    // compared as RdLibraryNav.mrlKey (decoded safely, drive letters as on disk)
    readonly property string playingMrl: Player.url.toString() !== "" ? RdLibraryNav.mrlKey(Player.url.toString()) : ""

    function isPlaying(mrl) {
        return playingMrl !== "" && !!mrl && RdLibraryNav.mrlKey(mrl) === playingMrl
    }

    readonly property bool _folderHasAddRow: {
        if (location.page !== "folder")
            return false
        if (category === "music")
            return true
        if (subfolderModel && subfolderModel.count > 0)
            return true
        // empty, not just without search results
        return searchText === "" && !!dataModel && !dataModel.loading && dataModel.count === 0
               && !!subfolderModel && !subfolderModel.loading
    }

    // rows above the items: "+ Add" rows (isAction) and the fixed entries of Music and Network
    readonly property var fixedRows: {
        switch (location.page) {
        case "folder":
            // Figma sidebar and video 10:59 / 12:00: a Videos folder of media only (S01) has no
            // Add row; a level of folders (Shows, The Wand), a Music folder (My Songs) and an
            // empty folder have it. A Videos folder decides once its rows are loaded, so the
            // row does not show and then vanish
            if (!page._folderHasAddRow)
                return []
            return [{ kind: "action", isAction: true, title: qsTr("Add"), icon: "add",
                      run: () => RdLibraryActions.addFolder(page.category, page.location.mrl) }]
        case "videos":
        case "songs":
        case "albums":
        case "artists":
        case "genres":
        case "collection":
            return [{ kind: "action", isAction: true, title: qsTr("Add"), icon: "add",
                      run: () => RdLibraryActions.addFolder(page.category) }]
        case "music":
            return [
                { kind: "action", isAction: true, title: qsTr("Add"), icon: "add",
                  run: () => RdLibraryActions.addFolder("music") },
                { kind: "link", title: qsTr("Songs"), icon: "music", location: { page: "songs", title: qsTr("Songs") } },
                { kind: "link", title: qsTr("Albums"), icon: "album", location: { page: "albums", title: qsTr("Albums") } },
                { kind: "link", title: qsTr("Artists"), icon: "artist", location: { page: "artists", title: qsTr("Artists") } },
                { kind: "link", title: qsTr("Genres"), icon: "genre", location: { page: "genres", title: qsTr("Genres") } }
            ]
        case "network": {
            const rows = [{ kind: "action", isAction: true, title: qsTr("Add Network Stream"), icon: "add",
                            run: () => RdLibraryActions.openNetworkStream() }]
            const lists = RdLibraryStore.streamLists
            for (let i = 0; i < lists.length; ++i)
                rows.push({ kind: "streamList", index: i, title: lists[i].name, mrl: lists[i].url, icon: "streaming",
                            location: { page: "streams", url: lists[i].url, title: lists[i].name } })
            rows.push({ kind: "link", title: qsTr("Podcasts"), icon: "streaming",
                        location: { page: "service", source: "podcast", title: qsTr("Podcasts") } })
            rows.push({ kind: "link", title: qsTr("Radio"), icon: "streaming",
                        location: { page: "service", source: "radio", title: qsTr("Radio") } })
            return rows
        }
        case "playlists":
            return [{ kind: "action", isAction: true, title: qsTr("Create playlist"), icon: "add",
                      run: () => RdLibraryNav.playlistDialogRequested({ items: [] }) }]
        case "playlist":
            return [{ kind: "action", isAction: true, title: qsTr("Add"), icon: "add",
                      run: () => RdLibraryActions.addFiles(location.id) }]
        default:
            return []
        }
    }

    // the model of the page's items: VLC's paged models (rows load on demand, sorting and search
    // run in the media library)
    readonly property var dataModel: modelLoader.item

    // a folder, an album / artist / genre or a playlist without a valid id lists nothing: VLC's
    // models with no parent list the whole library
    readonly property bool _hasParent: {
        if (["folder", "collection", "playlist"].indexOf(location.page) < 0)
            return true
        const id = location.id
        return !!id && typeof id.isValid === "function" && id.isValid()
    }

    readonly property string modelKind: {
        if (!_hasParent)
            return ""
        switch (location.page) {
        case "videos":
        case "songs": return "subfolder"
        case "folder": return location.category === "music" ? "audio" : "video"
        case "albums": return "album"
        case "artists": return "artist"
        case "genres": return "genre"
        case "collection": return "audio"
        case "playlists": return "playlistList"
        case "playlist": return "playlistMedia"
        case "recent": return "recent"
        case "section": return location.section === "latestStreams" ? "url" : "collection"
        case "streams":
        case "browse": return "network"
        case "service": return "service"
        default: return ""
        }
    }

    Loader {
        id: modelLoader

        sourceComponent: {
            switch (page.modelKind) {
            case "subfolder": return subfolderModelComponent
            case "video": return videoModelComponent
            case "audio": return audioModelComponent
            case "album": return albumModelComponent
            case "artist": return artistModelComponent
            case "genre": return genreModelComponent
            case "playlistList": return playlistListModelComponent
            case "playlistMedia": return playlistMediaModelComponent
            case "recent": return recentModelComponent
            case "url": return urlModelComponent
            case "collection": return collectionModelComponent
            case "network": return networkModelComponent
            case "service": return serviceModelComponent
            default: return null
            }
        }
    }

    // a folder shows its subfolders, then its media: one list, both models paged (rows load as
    // they scroll in, however many subfolders a folder has)
    Loader {
        id: subfolderLoader

        active: page.location.page === "folder" && page._hasParent
        sourceComponent: subfolderModelComponent
    }
    readonly property var subfolderModel: subfolderLoader.item

    Loader {
        id: folderContentLoader

        active: !!page.subfolderModel && !!page.dataModel

        sourceComponent: RdConcatModel {
            first: page.subfolderModel
            second: page.dataModel
        }
    }

    // the model the view shows
    readonly property var viewModel: folderContentLoader.item ?? dataModel

    readonly property var _noParent: MediaLib.deserializeMlItemIdFromString("")

    Component {
        id: subfolderModelComponent

        RdSubfolderModel {
            ml: MediaLib
            parentId: page.location.page === "folder" ? page.location.id : page._noParent
            categoryMrls: page.category === "music" ? RdLibraryStore.musicFolders : RdLibraryStore.videoFolders
            // hidden library folders count as the other category's: not listed here, their
            // folders of this category are
            otherMrls: (page.category === "music" ? RdLibraryStore.videoFolders : RdLibraryStore.musicFolders)
                       .concat(RdLibraryStore.hiddenRoots)
            // a folder's subfolders by title (S01, S02), the roots as the page's sort says
            sortCriteria: page.location.page === "folder" ? "title" : page.sortCriteria
            sortOrder: page.location.page === "folder" ? Qt.AscendingOrder : page.sortOrder
            searchPattern: page.searchText
            onCountChanged: page.loaded()
        }
    }

    Component {
        id: videoModelComponent

        MLVideoModel {
            ml: MediaLib
            parentId: page.location.id
            sortCriteria: page.sortCriteria
            sortOrder: page.sortOrder
            searchPattern: page.searchText
        }
    }

    Component {
        id: audioModelComponent

        MLAudioModel {
            ml: MediaLib
            parentId: page.location.id
            sortCriteria: page.sortCriteria
            sortOrder: page.sortOrder
            searchPattern: page.searchText
        }
    }

    Component {
        id: albumModelComponent

        MLAlbumModel {
            ml: MediaLib
            sortCriteria: page.sortCriteria
            sortOrder: page.sortOrder
            searchPattern: page.searchText
        }
    }

    Component {
        id: artistModelComponent

        MLArtistModel {
            ml: MediaLib
            sortCriteria: page.sortCriteria
            sortOrder: page.sortOrder
            searchPattern: page.searchText
        }
    }

    Component {
        id: genreModelComponent

        MLGenreModel {
            ml: MediaLib
            sortCriteria: page.sortCriteria
            sortOrder: page.sortOrder
            searchPattern: page.searchText
        }
    }

    Component {
        id: playlistListModelComponent

        MLPlaylistListModel {
            ml: MediaLib
            searchPattern: page.searchText
        }
    }

    Component {
        id: playlistMediaModelComponent

        MLPlaylistModel {
            ml: MediaLib
            parentId: page.location.id
            sortCriteria: page.sortCriteria
            sortOrder: page.sortOrder
            searchPattern: page.searchText
        }
    }

    Component {
        id: recentModelComponent

        MLRecentMediaModel {
            ml: MediaLib
            searchPattern: page.searchText
        }
    }

    Component {
        id: urlModelComponent

        MLUrlModel {
            ml: MediaLib
            searchPattern: page.searchText
        }
    }

    Component {
        id: collectionModelComponent

        RdCollectionModel {
            ml: MediaLib
            section: page.location.section ?? ""
            ids: {
                if (page.location.section === "frequentFolders")
                    return RdLibraryStore.frequentFolderIds
                if (page.location.section === "frequentPlaylists")
                    return RdLibraryStore.frequentPlaylistIds
                return []
            }
            searchPattern: page.searchText
        }
    }

    Component {
        id: networkModelComponent

        NetworkMediaModel {
            ctx: MainCtx
            searchPattern: page.searchText
            tree: page.location.page === "browse" ? page.location.tree
                                                  : RdLibraryStore.treeForUrl(page.location.url, page.location.title)
        }
    }

    Component {
        id: serviceModelComponent

        NetworkDeviceModel {
            ctx: MainCtx
            searchPattern: page.searchText
            sd_source: NetworkDeviceModel.CAT_INTERNET
            source_name: page.location.source
        }
    }

    // the content changed (a folder being added may now be in it)
    signal loaded()

    // one row of the page's model as a library item (see RdLibraryActions)
    function toItem(model, index) {
        // held by value: a location, a menu or a dialog keeps it after the model reloads
        const id = RdLibraryNav.detachedId(model.id)
        // a folder page: its subfolders first, then its media
        if (folderContentLoader.item) {
            if (model.rdFirst)
                return { kind: "folder", index: model.rdSourceRow, id: id, title: model.title ?? "",
                         mrl: model.mrl ?? "", isRoot: false }
            index = model.rdSourceRow
        }
        switch (modelKind) {
        case "subfolder":
            return { kind: "folder", index: index, id: id, title: model.title ?? "", mrl: model.mrl ?? "",
                     isRoot: location.page !== "folder" }
        case "album":
            // an album without a tag has no title
            return { kind: "album", index: index, id: id, title: model.title || qsTr("Unknown Album"),
                     subtitle: model.main_artist ?? "", thumbnail: model.cover ?? "" }
        case "artist":
            return { kind: "artist", index: index, id: id, title: model.name ?? "", thumbnail: model.cover ?? "" }
        case "genre":
            return { kind: "genre", index: index, id: id, title: model.name ?? "" }
        case "playlistList":
            return { kind: "playlist", index: index, id: id, title: model.name ?? "",
                     thumbnail: model.thumbnail ?? "" }
        case "url":
            return { kind: "stream", index: index, id: id, title: model.url ?? "", mrl: model.url ?? "",
                     progress: -1, watched: false, isVideo: true }
        case "collection":
            return { kind: model.kind, index: index, id: id, title: model.title, subtitle: model.subtitle,
                     mrl: model.mrl, thumbnail: model.thumbnail, progress: model.progress, watched: model.watched,
                     isVideo: model.isVideo, isFavorite: model.isFavorite }
        case "network":
        case "service": {
            const container = model.type === NetworkMediaModel.TYPE_DIRECTORY
                              || model.type === NetworkMediaModel.TYPE_NODE
                              || model.type === NetworkMediaModel.TYPE_PLAYLIST
                              || modelKind === "service"
            return { kind: container ? "browse" : "stream", index: index, title: model.name ?? "",
                     mrl: model.mrl ? model.mrl.toString() : "", thumbnail: model.artwork ? model.artwork.toString() : "",
                     // held by value, like the ids: Back to a stream folder needs it later
                     tree: model.tree ? RdLibraryStore.detached(model.tree) : model.tree,
                     progress: -1, watched: false, isVideo: true }
        }
        default: {
            // media of VLC's media models (MLMediaModel roles); a playlist's media
            // (MLPlaylistModel) have no isVideo or artist role: a video track tells a video
            const isVideo = model.isVideo ?? (modelKind === "playlistMedia" ? (model.videoDesc?.length ?? 0) > 0
                                                                             : modelKind !== "audio")
            const progress = model.progress ?? -1
            return {
                kind: "media",
                index: index,
                id: id,
                // videos show their file name, as in the design ("The_Wand_S01E05.mp4")
                title: (isVideo && model.fileName) ? model.fileName : (model.title ?? ""),
                subtitle: model.main_artist ?? "",
                mrl: model.mrl ? model.mrl.toString() : "",
                thumbnail: model.small_cover ?? model.thumbnail ?? model.cover ?? "",
                progress: (progress > 0 && progress < 1) ? progress : -1,
                watched: (model.playcount ?? 0) > 0,
                isVideo: isVideo,
                // undefined where the model has no favorite role (a playlist's media)
                isFavorite: model.isFavorite
            }
        }
        }
    }

    function iconOf(item) {
        switch (item.kind) {
        case "folder": return "folder"
        case "playlist": return "playlist"
        case "album": return "album"
        case "artist": return "artist"
        case "genre": return "genre"
        case "browse": return modelKind === "service" ? "streaming" : "folder"
        case "stream": return "window"
        default: return item.isVideo ? "" : "music"
        }
    }

    // songs show "title - artist" (12:00)
    function titleOf(item) {
        if (item.kind === "media" && !item.isVideo && item.subtitle)
            return qsTr("%1 - %2").arg(item.title).arg(item.subtitle)
        return item.title
    }

    function thumbnailOf(item) {
        if (item.kind === "playlist") {
            // read the map so the binding follows cover changes
            const covers = RdLibraryStore.playlistCovers
            const own = covers ? RdLibraryStore.playlistCover(item.id).toString() : ""
            return own !== "" ? own : (item.thumbnail ?? "")
        }
        return item.thumbnail ?? ""
    }

    function activate(item) {
        if (item.kind === "browse") {
            RdLibraryNav.openChild({ page: "browse", tree: item.tree, title: item.title })
            return
        }
        if (item.kind === "stream" && (modelKind === "network" || modelKind === "service")) {
            dataModel.addAndPlay(item.index)
            return
        }
        // a folder listed outside its category (Frequently Visited Folders) opens in its own
        // category with its whole address line, as on Home
        if (item.kind === "folder" && !_categoryPage) {
            RdLibraryStore.noteVisit("folder", item.id)
            RdLibraryStore.resolveFolder(item.mrl, (result) => RdLibraryNav.openFolderPath(result))
            return
        }
        RdLibraryActions.activate(item, categoryOf(item))
    }

    function activateFixed(row) {
        if (row.run)
            row.run()
        else if (row.location)
            RdLibraryNav.openChild(Object.assign({}, row.location))
    }

    function dragUrlsOf(item) {
        if ((item.kind === "media" || item.kind === "stream") && item.mrl)
            return [item.mrl]
        return []
    }

    // videos show 16:9 cards, everything else square ones (IB-06, IB-34)
    readonly property bool wideCards: category === "video" || location.page === "recent"
                                      || (location.page === "section" && location.section === "continueWatching")

    // grid geometry. Next to the video: one column of rows, or cards of at least 150, 10 apart.
    // Full library (Figma Player-1..4): list rows 406 wide, 10 apart both ways; cards 316 wide
    // (16:9) or 200 (square), 20 apart, rows of cards 40 apart
    readonly property real _gapX: (compact || listMode) ? VLCStyle.dp(10) : VLCStyle.dp(20)
    readonly property real _gapY: (compact || listMode) ? VLCStyle.dp(10) : VLCStyle.dp(40)
    readonly property real _itemWidth: listMode ? VLCStyle.dp(406) : (wideCards ? VLCStyle.dp(316) : VLCStyle.dp(200))
    readonly property int _columns: {
        const w = page.width
        if (compact)
            return listMode ? 1 : Math.max(1, Math.floor((w + _gapX) / (VLCStyle.dp(150) + _gapX)))
        return Math.max(1, Math.floor((w + _gapX) / (_itemWidth + _gapX)))
    }
    // songs and albums show their artist on a second line
    readonly property bool _cardSubtitles: !wideCards && (modelKind === "audio" || modelKind === "album"
                                                          || modelKind === "collection")

    FontMetrics {
        id: cardTitleMetrics

        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_header
    }

    GridView {
        id: grid

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // full library: a cell is an item and the gap after it, so the view reaches one gap past
        // the page: the last column's gap falls outside and every column that fits is shown
        // (Figma Player-1..5 at 1920: 5 columns of cards, 4 of list rows; P5-17, P5-26)
        width: page.compact ? page.width : page.width + page._gapX
        clip: true
        focus: true

        cellWidth: page.compact ? Math.floor(width / page._columns) : page._itemWidth + page._gapX
        // a card: picture, 20, title (and 10, artist), then the row gap
        cellHeight: page.listMode ? VLCStyle.rd_rowHeight + page._gapY
                                  : (cellWidth - page._gapX) * (page.wideCards ? 9 / 16 : 1)
                                    + VLCStyle.dp(20) + cardTitleMetrics.height
                                    + (page._cardSubtitles ? VLCStyle.dp(10) + cardTitleMetrics.height : 0)
                                    + page._gapY
        // a few rows ahead of the view, no more
        cacheBuffer: cellHeight * 2

        model: page.viewModel
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true

        header: Column {
            width: page.width
            spacing: VLCStyle.dp(10)
            // Figma Player-1: list rows start 30 below the divider in the full library
            topPadding: !page.compact && page.listMode ? VLCStyle.dp(10) : 0
            bottomPadding: page.fixedRows.length > 0 ? page._gapY : 0

            Repeater {
                model: page.fixedRows

                delegate: RdLibraryRow {
                    required property var modelData

                    width: page.compact ? parent.width : Math.min(parent.width, VLCStyle.dp(406))
                    title: modelData.title
                    iconName: modelData.icon
                    // Figma: the "+" of Add rows is FG/A3, other icons FG/A2
                    iconColor: modelData.isAction ? VLCStyle.palette.rdFgA3 : VLCStyle.palette.rdFgA2
                    boxed: false
                    secondary: true
                    showMore: modelData.kind === "streamList"
                    onClicked: page.activateFixed(modelData)
                    onMoreClicked: (button) => itemMenu.openForItem(modelData, button, page.category)
                }
            }

            Text {
                // a folder's subfolders load next to its media: wait for both, so a folder of
                // folders does not flash the text
                // (a folder or playlist that is gone, e.g. a pin of a removed folder, too)
                visible: !page._hasParent
                         || (!!page.dataModel && page.dataModel.count === 0 && !page.dataModel.loading
                             && !(page.subfolderModel && (page.subfolderModel.count > 0 || page.subfolderModel.loading))
                             && page.searchText === "")
                width: parent.width
                wrapMode: Text.WordWrap
                text: {
                    switch (page.location.page) {
                    case "videos": return qsTr("Add a folder and its videos show up here.")
                    case "songs": return qsTr("Add a folder and its songs show up here.")
                    case "playlists": return qsTr("Create a playlist and it shows up here.")
                    case "recent": return qsTr("What you play shows up here.")
                    default: return qsTr("Nothing here yet.")
                    }
                }
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }
        }

        // keyboard: the arrows move the current cell (GridView), its row or card takes the focus
        // and shows it; Space or Enter opens or plays it
        delegate: FocusScope {
            id: cell

            required property var model
            required property int index

            readonly property var item: page.toItem(model, index)

            width: grid.cellWidth
            height: grid.cellHeight

            focus: GridView.isCurrentItem

            // the arrows made this cell current: show the keyboard focus on it (a click gives
            // the focus first, so it keeps its mouse focus)
            GridView.onIsCurrentItemChanged: {
                if (GridView.isCurrentItem && grid.activeFocus && cellLoader.item && !cellLoader.item.activeFocus)
                    cellLoader.item.forceActiveFocus(Qt.TabFocusReason)
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    page.activate(cell.item)
                    event.accepted = true
                }
            }

            // the row or the card, never both
            Loader {
                id: cellLoader

                focus: true
                sourceComponent: page.listMode ? rowComponent : cardComponent
            }

            // keyboard focus moves the view along (GridView scrolls to its current item)
            Connections {
                target: cellLoader.item
                function onActiveFocusChanged() {
                    if (cellLoader.item.activeFocus)
                        grid.currentIndex = cell.index
                }
            }

            Component {
                id: rowComponent

                RdLibraryRow {
                    focus: true
                    width: page.compact && page._columns === 1 ? cell.width : cell.width - page._gapX
                    title: page.titleOf(cell.item)
                    iconName: page.iconOf(cell.item)
                    thumbnail: page.thumbnailOf(cell.item)
                    boxed: cell.item.kind === "media" || cell.item.kind === "stream" || cell.item.kind === "album"
                           || cell.item.kind === "playlist" && page.thumbnailOf(cell.item) !== ""
                    progress: cell.item.progress ?? -1
                    watched: cell.item.watched ?? false
                    playing: page.isPlaying(cell.item.mrl)
                    // Figma: playlist rows are FG/A1 like media, folders and categories FG/A3
                    secondary: cell.item.kind !== "media" && cell.item.kind !== "stream"
                               && cell.item.kind !== "playlist"
                    dragUrls: page.dragUrlsOf(cell.item)
                    // VLC's Navigation takes the arrows and Escape first: move in the grid,
                    // Escape goes back in the library
                    Navigation.upAction: () => grid.moveCurrentIndexUp()
                    Navigation.downAction: () => grid.moveCurrentIndexDown()
                    Navigation.leftAction: () => grid.moveCurrentIndexLeft()
                    Navigation.rightAction: () => grid.moveCurrentIndexRight()
                    Navigation.cancelAction: () => RdLibraryNav.goBack()
                    onClicked: {
                        grid.currentIndex = cell.index
                        page.activate(cell.item)
                    }
                    onMoreClicked: (button) => itemMenu.openForItem(cell.item, button, page.categoryOf(cell.item))
                }
            }

            Component {
                id: cardComponent

                RdLibraryCard {
                    focus: true
                    width: cell.width - page._gapX
                    title: cell.item.title
                    subtitle: (cell.item.kind === "media" && !cell.item.isVideo) || cell.item.kind === "album"
                              ? (cell.item.subtitle ?? "") : ""
                    iconName: page.iconOf(cell.item) || "videos"
                    thumbnail: page.thumbnailOf(cell.item)
                    wide: page.wideCards
                    progress: cell.item.progress ?? -1
                    watched: cell.item.watched ?? false
                    playing: page.isPlaying(cell.item.mrl)
                    dragUrls: page.dragUrlsOf(cell.item)
                    // VLC's Navigation takes the arrows and Escape first: move in the grid,
                    // Escape goes back in the library
                    Navigation.upAction: () => grid.moveCurrentIndexUp()
                    Navigation.downAction: () => grid.moveCurrentIndexDown()
                    Navigation.leftAction: () => grid.moveCurrentIndexLeft()
                    Navigation.rightAction: () => grid.moveCurrentIndexRight()
                    Navigation.cancelAction: () => RdLibraryNav.goBack()
                    onClicked: {
                        grid.currentIndex = cell.index
                        page.activate(cell.item)
                    }
                    onMoreClicked: (button) => itemMenu.openForItem(cell.item, button, page.categoryOf(cell.item))
                }
            }
        }

        T.ScrollBar.vertical: scrollBar
    }

    // at the page's right edge in every view (the grid reaches one gap further in the full
    // library); a scroll bar with another parent than the view is not placed by it
    T.ScrollBar {
        id: scrollBar

        anchors.right: parent.right
        anchors.top: grid.top
        anchors.bottom: grid.bottom
        policy: grid.contentHeight > grid.height ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
        width: VLCStyle.dp(6)
        contentItem: Rectangle {
            implicitWidth: VLCStyle.dp(4)
            radius: width / 2
            color: VLCStyle.palette.rdDividerBright
            opacity: scrollBar.active ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: VLCStyle.duration_long }
            }
        }
    }

    RdLibraryItemMenu {
        id: itemMenu

        location: page.location
    }
}
