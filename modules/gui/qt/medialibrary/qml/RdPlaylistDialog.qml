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

// redesign: New Playlist (video 13:25-13:30, P6-16, IB-30; Figma "new playlist"): "Playlist
// Details" with the name field and the square thumbnail picker, "Select Files" with the dashed
// drop zone (drop files or click to pick them), Cancel / Save (Save once a name is typed).
// The same dialog shows a playlist's "Properties & Metadata" (F-11): rename it, change its
// thumbnail, add files.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.MediaLibrary

RdLibraryDialog {
    id: dialog

    // edited playlist ({ id, title }), null for a new one
    property var playlist: null
    // MLItemIds or URLs added to the playlist
    property var files: []
    property url cover: ""

    title: playlist ? qsTr("Playlist Properties") : qsTr("New Playlist")
    canSave: nameField.text.trim() !== ""

    function openWith(params) {
        playlist = params.playlist ?? null
        files = params.items ?? []
        cover = playlist ? RdLibraryStore.playlistCover(playlist.id) : ""
        nameField.text = playlist ? playlist.title : ""
        open()
        nameField.forceActiveFocus()
    }

    function _addFiles(urls) {
        const list = files.slice()
        for (let i = 0; i < urls.length; ++i) {
            const url = urls[i].toString()
            if (list.indexOf(url) < 0)
                list.push(url)
        }
        files = list
    }

    function _fileName(entry) {
        if (typeof entry === "string") {
            const parts = RdLibraryNav.decoded(entry).split("/")
            return parts[parts.length - 1]
        }
        return qsTr("Library item")
    }

    onSaved: {
        const name = nameField.text.trim()
        if (playlist) {
            if (name !== playlist.title)
                RdLibraryStore.renamePlaylist(playlist.id, name)
            if (cover.toString() !== RdLibraryStore.playlistCover(playlist.id).toString() && cover.toString() !== "")
                RdLibraryStore.setPlaylistCover(playlist.id, cover)
            if (files.length > 0)
                RdLibraryStore.appendToPlaylist(playlist.id, files)
        } else {
            RdLibraryStore.createPlaylist(name, files, cover)
        }
    }

    Item {
        width: dialog.bodyWidth
        height: Math.max(details.implicitHeight, thumbnailPicker.height)

        // name (Figma "Frame 499": details 541 wide, gap 20, picker 112x112)
        Column {
            id: details

            anchors.left: parent.left
            anchors.right: thumbnailPicker.left
            anchors.rightMargin: VLCStyle.dp(20)
            spacing: VLCStyle.dp(20)

            RdLibraryDialog.Section {
                width: parent.width
                title: qsTr("Playlist Details")
                hint: qsTr("The playlist will be saved and displayed with this title and thumbnail.")
            }

            // Figma "Frame 328": a 41 px slot, the 37 px field centred
            Item {
                width: parent.width
                height: VLCStyle.dp(41)

                Widgets.RdTextField {
                    id: nameField

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    placeholderText: qsTr("e.g., Favorite Videos")
                    onAccepted: {
                        if (dialog.canSave) {
                            dialog.saved()
                            dialog.close()
                        }
                    }
                }
            }
        }

        // thumbnail picker (IB-30): dark square with a "+"; the chosen image fills it
        T.AbstractButton {
            id: thumbnailPicker

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: VLCStyle.dp(7)
            width: VLCStyle.dp(112)
            height: VLCStyle.dp(112)
            hoverEnabled: true

            Accessible.name: qsTr("Choose a thumbnail")

            onClicked: {
                RdLibraryStore.pickFiles(qsTr("Choose a thumbnail"), true, (images) => {
                    if (images.length > 0 && dialog.opened)
                        dialog.cover = images[0]
                })
            }

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2
                border.width: VLCStyle.dp(2)
                border.color: thumbnailPicker.hovered ? VLCStyle.palette.rdDividerBright : VLCStyle.palette.rdBgA4

                Widgets.ImageExt {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    radius: VLCStyle.rd_radius_small
                    source: dialog.cover
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                    visible: status === Image.Ready
                }
            }

            contentItem: Item {
                Rectangle {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(30)
                    height: VLCStyle.dp(30)
                    radius: VLCStyle.dp(5)
                    color: VLCStyle.palette.rdFgB1
                    opacity: dialog.cover.toString() !== "" ? 0.7 : 1

                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "add"
                    }
                }
            }
        }
    }

    // Figma: a Divider/Dim line between the details and the files
    Rectangle {
        width: dialog.bodyWidth
        height: VLCStyle.dp(1)
        color: VLCStyle.palette.rdDividerDim
    }

    RdLibraryDialog.Section {
        width: dialog.bodyWidth
        title: qsTr("Select Files")
        hint: qsTr("These files will be added to the playlist.")
    }

    // drop zone (Figma 673x186, BG/B2, dashed 2 px border)
    T.AbstractButton {
        id: dropZone

        width: dialog.bodyWidth
        height: VLCStyle.dp(186)
        hoverEnabled: true

        Accessible.name: qsTr("Select files")

        onClicked: RdLibraryStore.pickFiles(qsTr("Select Files"), false, (urls) => {
            if (dialog.opened)
                dialog._addFiles(urls)
        })

        background: Rectangle {
            radius: VLCStyle.rd_radius_normal
            color: VLCStyle.palette.rdBgB2

            RdDashedBorder {
                anchors.fill: parent
                cornerInset: VLCStyle.rd_radius_normal
                color: dropArea.containsDrag || dropZone.hovered ? VLCStyle.palette.rdFgA4
                                                                 : VLCStyle.palette.rdDropZoneDash
            }
        }

        contentItem: Item {
            Column {
                anchors.centerIn: parent
                width: parent.width - VLCStyle.dp(36)
                spacing: VLCStyle.dp(20)

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: dialog.files.length === 0
                          ? qsTr("Drag files into the box or click here to select files.")
                          : dialog.files.length === 1 ? dialog._fileName(dialog.files[0])
                                                      : qsTr("%1 file selected", "%1 files selected", dialog.files.length).arg(dialog.files.length)
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: dialog.files.length === 0 ? VLCStyle.palette.rdFgA4 : VLCStyle.palette.rdFgA2
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: VLCStyle.dp(84)
                    height: VLCStyle.dp(30)
                    radius: VLCStyle.dp(5)
                    color: VLCStyle.palette.rdFgB1

                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "add"
                    }
                }
            }
        }

        DropArea {
            id: dropArea

            anchors.fill: parent

            onEntered: (drag) => {
                drag.accepted = drag.hasUrls || (!!drag.source && !!drag.source.rdDragUrls)
            }

            onDropped: (drop) => {
                if (drop.source && drop.source.rdDragUrls)
                    dialog._addFiles(drop.source.rdDragUrls)
                else if (drop.hasUrls)
                    dialog._addFiles(drop.urls)
                drop.accept()
            }
        }
    }
}
