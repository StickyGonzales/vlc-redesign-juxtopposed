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

// redesign: Open Network Stream with a Playlist Name (video 13:09-13:20, P6-14): links to
// playlists (m3u, pls, xspf ...) are saved as stream lists under Network (with the name from the
// link when the Playlist Name is left empty) and the library shows
// the first one ("Network > Index", 13:19), next to the video when the player is shown. Loaded
// by OpenNetworkStreamDialog only when the media library is available (VLC.MediaLibrary needs
// it); the dialog sends other links to DialogsProvider.openNetworkStreams (a media library
// playlist, W6.4).
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Dialogs
import VLC.MediaLibrary

Item {
    // a link to a playlist of streams (the TV channel lists of 13:16)
    function isPlaylistUrl(url) {
        return /\.(m3u8?|pls|xspf|asx)(\?|#|$)/i.test(url)
    }

    // the name the dialog fills in for a playlist link (13:17: ".../index.m3u" is "Index"): the
    // link's file name without its extension, first letter upper case; "" without a file name
    function autoName(url) {
        let path = url.trim().replace(/[?#].*$/, "")
        const scheme = path.match(/^[a-z][a-z0-9+.-]*:\/\/[^\/]*/i)
        if (scheme)
            path = path.slice(scheme[0].length)
        const segments = path.split(/[\/\\]/).filter((s) => s !== "")
        if (segments.length === 0)
            return ""
        let fileName = segments[segments.length - 1]
        try {
            fileName = decodeURIComponent(fileName)
        } catch (e) {
            // a malformed escape: keep the name as written
        }
        const dot = fileName.lastIndexOf(".")
        if (dot >= 0)
            fileName = fileName.slice(0, dot)
        fileName = fileName.trim()
        if (fileName === "")
            return ""
        return fileName.charAt(0).toUpperCase() + fileName.slice(1)
    }

    // the name of a stream list saved without a Playlist Name: the link's file name, its host
    // name when it has no file name, "Network Stream" otherwise
    function defaultName(url) {
        const name = autoName(url)
        if (name !== "")
            return name
        const host = url.trim().match(/^[a-z][a-z0-9+.-]*:\/\/(?:[^\/?#@]*@)?(\[[^\]]+\]|[^\/?#:]+)/i)
        if (host && host[1] !== "")
            return host[1]
        return qsTr("Network Stream")
    }

    // urls: playlist links, one stream list each, each named after its own link
    function saveWithDefaultNames(urls) {
        _saveLists(urls.map((u) => ({ name: defaultName(u), url: u })))
    }

    // name: the Playlist Name; urls: playlist links, one stream list each
    function save(name, urls) {
        if (name === "")
            return
        _saveLists(urls.map((u, i) => ({ name: urls.length > 1 ? name + " " + (i + 1) : name, url: u })))
    }

    // lists: [{ name, url }]
    function _saveLists(lists) {
        if (lists.length === 0)
            return
        let first = null
        let invalid = 0
        for (let i = 0; i < lists.length; ++i) {
            const entry = RdLibraryStore.addStreamList(lists[i].name, lists[i].url)
            if (!entry.url)
                invalid += 1
            else if (!first)
                first = entry
        }
        if (invalid > 0)
            DialogsProvider.messageDialog(qsTr("%1 link could not be opened.", "%1 links could not be opened.", invalid).arg(invalid),
                                          qsTr("Open Network Stream"))
        if (!first)
            return
        // a link saved before opens its existing list
        RdLibraryNav.openPath([
            { page: "network", title: qsTr("Network") },
            { page: "streams", url: first.url, title: first.name }
        ])
        if (MainCtx.playerView)
            RdPanels.libraryOpen = true
    }
}
