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

// redesign: the page area of the library: the page of RdLibraryNav.location, crossfading into
// the next one (video 12:12-12:14, IB-21: the old page fades out while the new one fades in at
// the same place, no slide; 10:56-10:59, IB-05 after Add Folder). It also shows the library
// dialogs (New Playlist, folder info, confirmations) and opens a folder that was just
// added once the media library has it (P5-16).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.MediaLibrary

FocusScope {
    id: content

    property bool compact: true

    // the page on screen (RdLibraryPage or RdLibraryHome), for the header
    readonly property Item page: _current

    property Item _current: null
    property Item _previous: null

    // Figma has no duration for this transition: 180 ms (Sticky's 150-200 ms rule); the header's
    // address line crossfades with it (RdLibraryHeader)
    readonly property int _fadeDuration: VLCStyle.rd_libraryPageFadeDuration

    function _show(location) {
        // a transition still running ends at once
        if (fade.running)
            fade.complete()

        const component = location.page === "home" ? homeComponent : pageComponent
        const next = component.createObject(content, {
            location: location,
            compact: Qt.binding(() => content.compact),
            width: Qt.binding(() => content.width),
            height: Qt.binding(() => content.height),
            opacity: _current ? 0 : 1
        })
        next.loaded.connect(content._tryReveal)

        _previous = _current
        _current = next
        if (_previous) {
            fadeOut.target = _previous
            fadeIn.target = next
            fade.start()
        }
        // the new page takes the focus inside the library (keyboard use goes on after opening a
        // folder, Back or a crumb)
        const hadFocus = content.activeFocus
        next.focus = true
        if (hadFocus)
            next.forceActiveFocus()
    }

    Component.onCompleted: _show(RdLibraryNav.location)

    Connections {
        target: RdLibraryNav

        function onLocationChanged() {
            content._show(RdLibraryNav.location)
        }
    }

    ParallelAnimation {
        id: fade

        NumberAnimation {
            id: fadeOut

            property: "opacity"
            to: 0
            duration: content._fadeDuration
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: fadeIn

            property: "opacity"
            to: 1
            duration: content._fadeDuration
            easing.type: Easing.OutQuad
        }

        onFinished: {
            if (content._previous) {
                content._previous.destroy()
                content._previous = null
            }
        }
    }

    Component {
        id: pageComponent

        RdLibraryPage { }
    }

    Component {
        id: homeComponent

        RdLibraryHome { }
    }

    /* a folder being added opens once the media library lists it */

    Connections {
        target: RdLibraryStore

        function onFolderAdded(category, mrl) {
            RdLibraryNav.pendingFolderCategory = category
            RdLibraryNav.pendingFolderMrl = mrl
            content._tryReveal()
        }

        function onFoldersScanned() {
            content._tryReveal(false)
        }

        // the scan ended: one last look, then stop waiting for the folder
        function onScanFinished() {
            content._tryReveal(true)
        }
    }

    function _tryReveal(last) {
        const mrl = RdLibraryNav.pendingFolderMrl
        if (mrl === "")
            return
        RdLibraryStore.resolveFolder(mrl, (result) => {
            if (RdLibraryNav.pendingFolderMrl !== mrl)
                return
            const crumbs = result ? result.crumbs : []
            if (crumbs.length === 0 || RdLibraryNav.mrlKey(crumbs[crumbs.length - 1].mrl) !== RdLibraryNav.mrlKey(mrl)) {
                // (another scan may still run: keep waiting for it)
                if (last === true && !MediaLib.discoveryPending)
                    RdLibraryNav.pendingFolderMrl = ""
                return
            }
            RdLibraryNav.pendingFolderMrl = ""
            RdLibraryNav.openFolderPath(result)
        }, RdLibraryNav.pendingFolderCategory)
    }

    /* dialogs */

    Connections {
        target: RdLibraryNav

        function onPlaylistDialogRequested(params) {
            playlistDialog.openWith(params)
        }

        function onInfoRequested(item) {
            infoPopup.show(item)
        }

        function onConfirmRequested(params) {
            confirmDialog.ask(params)
        }
    }

    RdConfirmDialog {
        id: confirmDialog
    }

    RdPlaylistDialog {
        id: playlistDialog
    }

    RdFolderInfoPopup {
        id: infoPopup
    }
}
