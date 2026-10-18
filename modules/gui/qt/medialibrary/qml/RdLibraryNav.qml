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

// redesign: where the library is (video 10:22-10:27, 11:40-12:28, F-14). The compact library
// next to the video and the full-window library show the same place, so opening the full
// library from the compact one keeps the folder (11:47) and going back to the player finds it
// again (11:58).
//
// A location is a plain object:
//   { page, title, crumbs, ... }    crumbs: the locations of the address line, this one last
// Pages and their extra fields:
//   "home", "recent", "videos", "music", "songs", "albums", "artists", "genres", "network",
//   "playlists"                                 the roots and fixed lists
//   "folder"      { category, id, mrl }        a library folder (Videos or Music)
//   "collection"  { kind, id }                 the songs of an album, artist or genre
//   "playlist"    { id }                       a playlist
//   "section"     { section }                  a whole Home section (its ">" link)
//   "streams"     { url }                      a named network stream list
//   "service"     { source }                   a stream service (Podcasts, Radio)
//   "browse"      { tree }                     a node of a stream list or service
pragma Singleton

import QtQml

import VLC.MediaLibrary

QtObject {
    id: root

    property var location: _root("home")

    property var _back: []
    property var _forward: []

    readonly property bool canGoBack: _back.length > 0
    readonly property bool canGoForward: _forward.length > 0

    // the rail category of the location: "home", "video", "music", "network", "playlists",
    // "recent"
    readonly property string category: categoryOf(location)
    // true at a category's own page (filled accent rail icon), false inside it (filled gray)
    readonly property bool atCategoryRoot: !!location && location.crumbs.length === 1

    // the library asks the views to show a location that does not exist yet (a folder being
    // added); the views retry when their content reloads
    property string pendingFolderMrl: ""
    // the category it was added to
    property string pendingFolderCategory: ""

    // dialogs and popups of the library, shown by the library view that is on screen
    //   params: { items } for a new playlist, { playlist } to edit one (Properties & Metadata)
    signal playlistDialogRequested(var params)
    signal infoRequested(var item)
    //   params: { title, message, button, action } for an action that cannot be undone
    signal confirmRequested(var params)

    function _root(page) {
        const titles = {
            "home": qsTr("Home"),
            "videos": qsTr("Videos"),
            "music": qsTr("Music"),
            "network": qsTr("Network"),
            "playlists": qsTr("Playlists"),
            "recent": qsTr("Recent")
        }
        const loc = { page: page, title: titles[page] ?? page }
        loc.crumbs = [loc]
        return loc
    }

    function categoryOf(loc) {
        if (!loc)
            return "home"
        const first = loc.crumbs[0].page
        switch (first) {
        case "videos": return "video"
        case "music": return "music"
        case "network": return "network"
        case "playlists": return "playlists"
        case "recent": return "recent"
        default: return "home"
        }
    }

    function sameLocation(a, b) {
        if (!a || !b || a.page !== b.page)
            return false
        return key(a) === key(b)
    }

    // what identifies a location of a page (pins, frequent lists)
    function key(loc) {
        switch (loc.page) {
        case "folder": return loc.mrl ?? ""
        case "collection": return loc.kind + ":" + (loc.id ? loc.id.toString() : "")
        case "playlist": return loc.id ? loc.id.toString() : ""
        case "section": return loc.section
        case "streams": return loc.url
        case "service": return loc.source
        case "browse": return loc.title
        default: return ""
        }
    }

    // a media library id held by value. In Qt 6 an id read from a model row (`model.id` in a
    // delegate) is a reference to that row: when the model reloads (a scan) or the delegate is
    // destroyed (the page fades out), it reads another row's id or nothing, and a folder page
    // made from it listed its whole category (P5-16, F-14, P6-01: nested folder plus every
    // file, "3007 items")
    function detachedId(id) {
        if (!id || typeof id.isValid !== "function" || !id.isValid())
            return id
        return RdLibraryStore.detached(id)
    }

    function _go(loc) {
        if (sameLocation(loc, location))
            return
        // every place of the address line is kept (back, forward, crumbs): hold its id by value
        for (const crumb of loc.crumbs) {
            if (crumb.id !== undefined)
                crumb.id = detachedId(crumb.id)
        }
        _back = _back.concat([location])
        _forward = []
        location = loc
    }

    // a category root from the rail
    function openRoot(page) {
        _go(_root(page))
    }

    // a location below `parent` (the current location by default)
    function openChild(child, parent) {
        const from = parent ?? location
        child.crumbs = from.crumbs.concat([child])
        _go(child)
    }

    // a location with its whole address line (pins, Home rows, the folder chip)
    function openPath(locations) {
        if (locations.length === 0)
            return
        const crumbs = []
        for (let i = 0; i < locations.length; ++i) {
            locations[i].crumbs = crumbs.concat([locations[i]])
            crumbs.push(locations[i])
        }
        _go(locations[locations.length - 1])
    }

    // an earlier part of the address line (10:22-10:27)
    function openCrumb(index) {
        if (index < 0 || index >= location.crumbs.length - 1)
            return
        _go(location.crumbs[index])
    }

    function goBack() {
        if (!canGoBack)
            return
        _forward = [location].concat(_forward)
        location = _back[_back.length - 1]
        _back = _back.slice(0, _back.length - 1)
    }

    function goForward() {
        if (!canGoForward)
            return
        _back = _back.concat([location])
        location = _forward[0]
        _forward = _forward.slice(1)
    }

    /* pins of the rail (P6-18): a pin keeps the address line of its page */

    function isPinnable(loc) {
        switch (loc.page) {
        case "folder":
        case "collection":
        case "playlist":
        case "streams":
        case "service":
        case "section":
            return true
        default:
            return false
        }
    }

    // a location as plain settings data (media library ids as strings)
    function pinLocation(loc) {
        return {
            page: loc.page,
            key: key(loc),
            crumbs: loc.crumbs.map((c) => {
                const crumb = {}
                for (const field of ["page", "title", "category", "mrl", "kind", "url", "source", "section"]) {
                    if (c[field] !== undefined)
                        crumb[field] = c[field]
                }
                if (c.id)
                    crumb.idString = c.id.toString()
                return crumb
            })
        }
    }

    function openPin(pinLoc) {
        openPath(pinLoc.crumbs.map((c) => {
            const crumb = Object.assign({}, c)
            if (c.idString) {
                crumb.id = MediaLib.deserializeMlItemIdFromString(c.idString)
                delete crumb.idString
            }
            return crumb
        }))
    }

    // the library folders of a category, from RdLibraryStore.resolveFolder()
    // MRLs are percent-encoded differently by Qt, VLC and the media library: compare them decoded,
    // without a trailing slash
    function mrlKey(mrl) {
        let key = String(mrl)
        try {
            key = decodeURIComponent(key)
        } catch (e) {
            // a stray "%": compare the text as it is
        }
        key = key.replace(/\/+$/, "")
        // Windows drive letters are not case sensitive ("file:///C:/" and "file:///c:/")
        if (Qt.platform.os === "windows")
            key = key.replace(/^(file:\/\/\/)([A-Za-z]):/i, (match, scheme, drive) => scheme + drive.toLowerCase() + ":")
        return key
    }

    // `text` percent-decoded for display; as it is when it holds a stray "%"
    function decoded(text) {
        try {
            return decodeURIComponent(String(text))
        } catch (e) {
            return String(text)
        }
    }

    // keyboard: moves the focus from `item` to the next (or previous) item of the focus chain
    function focusStep(item, forward) {
        const next = item.nextItemInFocusChain(forward)
        if (next && next !== item)
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }

    // length of the deepest folder of `folders` that holds `mrl` (0: none)
    function _depthIn(folders, mrl) {
        const key = mrlKey(mrl)
        let depth = 0
        for (const folder of folders) {
            const folderKey = mrlKey(folder)
            if ((key === folderKey || key.startsWith(folderKey + "/")) && folderKey.length > depth)
                depth = folderKey.length
        }
        return depth
    }

    // the category of an item shown outside its category's pages (Home sections, Recent,
    // playlists): media by their type, folders by the deepest folder added to a category that
    // holds them, music on a tie (as RdLibraryStore.resolveFolder)
    function itemCategory(item) {
        if (item.kind === "folder") {
            const music = _depthIn(RdLibraryStore.musicFolders, item.mrl)
            return music > 0 && music >= _depthIn(RdLibraryStore.videoFolders, item.mrl) ? "music" : "video"
        }
        return item.isVideo ? "video" : "music"
    }

    function openFolderPath(result) {
        if (!result || result.crumbs.length === 0)
            return
        const categoryRoot = result.category === "music"
                           ? [_root("music"), { page: "songs", title: qsTr("Songs") }]
                           : [_root("videos")]
        const path = categoryRoot.concat(result.crumbs.map((c) => ({
            page: "folder", category: result.category, id: c.id, mrl: c.mrl, title: c.title
        })))
        openPath(path)
    }
}
