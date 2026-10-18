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

// redesign: the mini player of the full library (video 11:48-11:56; P5-27, P5-28, IB-18, F-17;
// Figma "Miniplayer" 391x339, 391x690 with the queue): a card (BG/A3, radius 14, padding 8,
// shadow) with the video (375x211, radius 6, 2 px BG/B2 border) or the cover of a song, a thin
// seek bar, the file name, the folder (and artist) chips and the queue button (accent while the
// queue shows). Hovering the picture dims it and shows close, open, previous, play and next.
// The queue opens attached to the card. The card is dragged by its player part (picture, title,
// chips) and snaps to the nearest corner (300 ms, ease out).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Widgets as Widgets

Item {
    id: root

    // distance to the window edges in its corner (Figma Player-1..3: 6)
    property real margin: VLCStyle.dp(6)
    // kept free at the top (the library header stays usable when the card is in a top corner)
    property real topInset: 0
    property bool queueOpen: false
    // corner: "bottomRight" (default), "bottomLeft", "topRight", "topLeft"
    property string corner: "bottomRight"

    // the folder chip: the library opens the folder of the playing file
    signal folderClicked()

    readonly property real cardWidth: VLCStyle.dp(391)
    readonly property real playerHeight: VLCStyle.dp(339)
    readonly property real queueHeight: VLCStyle.dp(351)

    readonly property bool atTop: corner === "topRight" || corner === "topLeft"
    readonly property bool _left: corner === "bottomLeft" || corner === "topLeft"

    width: cardWidth
    height: playerHeight + (queueOpen ? queueHeight : 0)

    x: _left ? margin : (parent ? parent.width - width - margin : 0)
    y: atTop ? topInset + margin : (parent ? parent.height - height - margin : 0)

    // Figma "Miniplayer" smart animate: 300 ms
    readonly property int _snapDuration: 300

    // only the snap after a drag animates: window resizes and the queue opening move the card
    // at once
    property bool _snapping: false

    Behavior on x {
        enabled: root._snapping
        NumberAnimation {
            id: snapX

            duration: root._snapDuration
            easing.type: Easing.OutCubic
            onRunningChanged: if (!running) root._snapping = false
        }
    }
    Behavior on y {
        enabled: root._snapping
        NumberAnimation {
            id: snapY

            duration: root._snapDuration
            easing.type: Easing.OutCubic
            onRunningChanged: if (!running) root._snapping = false
        }
    }

    // Parent folder of the playing file (as the top bar's folder chip)
    readonly property string folderName: {
        const url = Player.url ? Player.url.toString() : ""
        if (url === "")
            return ""
        const parts = decodeURIComponent(url).replace(/\\/g, "/").split("/").filter((p) => p !== "")
        return parts.length >= 2 ? parts[parts.length - 2] : ""
    }

    readonly property string fileName: {
        const url = Player.url ? Player.url.toString() : ""
        if (url === "")
            return Player.title
        const parts = decodeURIComponent(url).split("/")
        return parts[parts.length - 1]
    }

    readonly property bool _ended: Player.playingState === Player.PLAYING_STATE_STOPPED

    Rectangle {
        id: card

        anchors.fill: parent
        radius: VLCStyle.rd_radius_large
        color: VLCStyle.palette.rdBgA3

        // Figma "Miniplayer" drop shadow: #000000 38 %, no offset, blur 11.8
        Widgets.RdShadow {
            color: VLCStyle.palette.rdMiniPlayerShadow
            yOffset: 0
            blurRadius: VLCStyle.dp(11.8)
        }

        // the card (queue included) takes the presses, hover and wheel turns that no control
        // takes, so they never reach the library under it (a library row took the mouse there,
        // and a drag of the card was lost)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: (wheel) => { wheel.accepted = true }
        }

        // the drag handlers of the library rows under the card still see its presses (Qt hands
        // a press to the handlers under an item that took it): this one takes a mouse drag on the
        // card first and does nothing with it, so no library drag starts from the card. The card
        // move (player part) and the queue's reorder handle are handlers of items above, they
        // take the drag before it; a library handler cannot take over from it (same type).
        DragHandler {
            target: null
            acceptedDevices: PointerDevice.AllDevices & ~(PointerDevice.TouchScreen)
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
        }

        // the queue sits above the player in the bottom corners, below it in the top ones
        Loader {
            id: queueLoader

            active: root.queueOpen
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.atTop ? root.playerHeight : 0
            height: root.queueHeight

            sourceComponent: RdMiniQueue { }
        }

        Item {
            id: player

            anchors.left: parent.left
            anchors.right: parent.right
            y: root.atTop || !root.queueOpen ? 0 : root.queueHeight
            height: root.playerHeight

            // drag the card by its player part (also from the title and chips rows); it snaps to
            // the nearest corner. A handler of the item under the controls also sees the presses
            // the video takes; the seek bar keeps its own drags (preventStealing).
            DragHandler {
                id: dragHandler

                target: root
                cursorShape: Qt.DragMoveCursor

                onActiveChanged: {
                    if (active || !root.parent)
                        return
                    const left = root.x + root.width / 2 < root.parent.width / 2
                    const top = root.y + root.height / 2 < root.parent.height / 2
                    root.corner = (top ? "top" : "bottom") + (left ? "Left" : "Right")
                    // back to the corner bindings, animated by the Behaviors
                    root._snapping = true
                    root.x = Qt.binding(() => root._left ? root.margin : root.parent.width - root.width - root.margin)
                    root.y = Qt.binding(() => root.atTop ? root.topInset + root.margin : root.parent.height - root.height - root.margin)
                    // released right on its corner: nothing to animate
                    if (!snapX.running && !snapY.running)
                        root._snapping = false
                }
            }

            Rectangle {
                id: picture

                x: VLCStyle.dp(8)
                y: VLCStyle.dp(8)
                width: parent.width - VLCStyle.dp(16)
                height: VLCStyle.dp(211)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdMediaBase
                border.width: VLCStyle.dp(2)
                border.color: VLCStyle.palette.rdBgB2
                clip: true

                // only where VLC can show the video outside the player (as VLC's own PIP player)
                Loader {
                    id: videoLoader

                    // a new video starts without the pointer known over it
                    onActiveChanged: picture._forgetPointer()

                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    active: MainCtx.canShowVideoPIP && Player.hasVideoOutput && MainCtx.hasEmbededVideo

                    sourceComponent: VideoSurface {
                        videoSurfaceProvider: MainCtx.videoSurfaceProvider
                    }
                }

                // nor does the wheel over the picture reach the video, which would change the
                // volume (Decision 54)
                Widgets.RdWheelSink {
                    anchors.fill: parent
                }

                // songs show their cover
                Image {
                    id: coverImage

                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    visible: !Player.hasVideoOutput && status === Image.Ready
                    source: Player.artwork
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                }

                // a song without cover: the library's placeholder (media base with the "music"
                // icon, 48 px as on the library cards)
                Widgets.RdIcon {
                    anchors.centerIn: parent
                    visible: !Player.hasVideoOutput && !coverImage.visible
                    name: "music"
                    size: VLCStyle.dp(48)
                    color: VLCStyle.palette.rdFgA2
                }

                HoverHandler {
                    id: pictureHover
                }

                // the video surface takes the hover events over the video, so pictureHover never
                // sees the pointer there: the window's own mouse moves (InterfaceWindowHandler)
                // tell when it is over the picture. Not under a modal redesign dialog. The last
                // position is tested again when the card moves under a still pointer (snap after a
                // drag, which sends no moves while the button is held; window resize).
                property bool _pointerOverVideo: false
                property point _lastScenePos
                property bool _lastScenePosValid: false
                readonly property bool pointerInside: pictureHover.hovered
                                                      || (_pointerOverVideo && RdPanels.modalCount === 0)

                function _hitTest() {
                    if (!_lastScenePosValid)
                        return
                    const p = mapFromItem(null, _lastScenePos.x, _lastScenePos.y)
                    _pointerOverVideo = p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
                }

                function _forgetPointer() {
                    _lastScenePosValid = false
                    _pointerOverVideo = false
                }

                Connections {
                    target: MainCtx
                    enabled: videoLoader.active

                    function onIntfMouseMoved(scenePos) {
                        picture._lastScenePos = scenePos
                        picture._lastScenePosValid = true
                        picture._hitTest()
                    }
                    function onIntfMouseLeft() {
                        picture._forgetPointer()
                    }
                }

                Connections {
                    target: root
                    enabled: videoLoader.active

                    function onXChanged() { picture._hitTest() }
                    function onYChanged() { picture._hitTest() }
                }

                // hover overlay (IB-18): dimmed picture, white controls
                Rectangle {
                    anchors.fill: parent
                    visible: picture.pointerInside || closeButton.hovered || openButton.hovered
                    color: VLCStyle.palette.rdMiniPlayerDim
                    radius: parent.radius

                    // Figma "Miniplayer" hover: 24 px icons 16 px from the top left and 17 px
                    // from the top right of the picture
                    OverlayButton {
                        id: closeButton

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: VLCStyle.dp(13)
                        anchors.topMargin: VLCStyle.dp(12)
                        iconName: "close"
                        description: qsTr("Close")
                        onClicked: MainPlaylistController.stop()
                    }

                    OverlayButton {
                        id: openButton

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: VLCStyle.dp(14)
                        anchors.topMargin: VLCStyle.dp(12)
                        iconName: "open"
                        description: qsTr("Open the player")
                        onClicked: MainCtx.playerView = true
                    }

                    // Figma: 42.857 px icons (24 px scaled 1.786) at x 90.357 / 167.572 / 240.357,
                    // y 82.57 in the 375 x 210.94 picture
                    OverlayButton {
                        x: VLCStyle.dp(90.357)
                        y: VLCStyle.dp(82.57)
                        iconSize: VLCStyle.dp(42.857)
                        iconName: "previous"
                        description: qsTr("Previous")
                        onClicked: MainPlaylistController.prev()
                    }

                    OverlayButton {
                        x: VLCStyle.dp(167.572)
                        y: VLCStyle.dp(82.57)
                        iconSize: VLCStyle.dp(42.857)
                        iconName: root._ended ? "replay"
                                : Player.playingState === Player.PLAYING_STATE_PLAYING ? "pause" : "play"
                        description: Player.playingState === Player.PLAYING_STATE_PLAYING ? qsTr("Pause") : qsTr("Play")
                        onClicked: MainPlaylistController.togglePlayPause()
                    }

                    OverlayButton {
                        x: VLCStyle.dp(240.357)
                        y: VLCStyle.dp(82.57)
                        iconSize: VLCStyle.dp(42.857)
                        iconName: "next"
                        description: qsTr("Next")
                        onClicked: MainPlaylistController.next()
                    }
                }
            }

            // seek bar (Figma 375x16, fill 12 px, accent playhead pill)
            Rectangle {
                id: seek

                anchors.left: picture.left
                anchors.right: picture.right
                anchors.top: picture.bottom
                anchors.topMargin: VLCStyle.dp(4)
                height: VLCStyle.dp(16)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2

                Rectangle {
                    id: seekFill

                    x: VLCStyle.dp(2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, (parent.width - VLCStyle.dp(4)) * Player.position)
                    height: VLCStyle.dp(12)
                    radius: VLCStyle.rd_radius_small
                    color: VLCStyle.palette.rdBgAccentBright
                }

                // Figma: 8 x 12, its right edge 1 px past the end of the fill
                Rectangle {
                    visible: seekArea.containsMouse || picture.pointerInside
                    x: Math.max(seekFill.x, seekFill.x + seekFill.width - VLCStyle.dp(7))
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(8)
                    height: VLCStyle.dp(12)
                    radius: VLCStyle.rd_radius_small
                    color: VLCStyle.palette.rdAccentMain
                }

                MouseArea {
                    id: seekArea

                    anchors.fill: parent
                    hoverEnabled: true
                    // seeking, not moving the card
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => Player.position = Math.max(0, Math.min(1, mouse.x / width))
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            Player.position = Math.max(0, Math.min(1, mouse.x / width))
                    }
                }
            }

            Text {
                id: titleText

                anchors.left: picture.left
                anchors.leftMargin: VLCStyle.dp(8)
                anchors.right: picture.right
                anchors.rightMargin: VLCStyle.dp(8)
                anchors.top: seek.bottom
                anchors.topMargin: VLCStyle.dp(23)
                elide: Text.ElideRight
                text: root.fileName
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: VLCStyle.palette.rdFgA1
            }

            // the chips share the room left of the queue button: both keep their whole label when
            // they fit, else the longer one is elided first (never below half of the room)
            Row {
                id: chips

                readonly property real room: Math.max(0, queueButton.x - x - VLCStyle.dp(8))
                readonly property bool both: folderChip.visible && artistChip.visible
                readonly property real available: room - (both ? spacing : 0)

                anchors.left: titleText.left
                anchors.top: titleText.bottom
                anchors.topMargin: VLCStyle.dp(14)
                spacing: VLCStyle.dp(20)

                Chip {
                    id: folderChip

                    visible: root.folderName !== ""
                    iconName: "folder"
                    text: root.folderName
                    maximumWidth: chips.both ? Math.max(chips.available / 2, chips.available - artistChip.naturalWidth)
                                             : chips.available
                    onClicked: root.folderClicked()
                }

                Chip {
                    id: artistChip

                    visible: !Player.hasVideoOutput && Player.artist !== ""
                    iconName: "artist"
                    text: Player.artist
                    maximumWidth: chips.both ? chips.available - Math.min(folderChip.naturalWidth, folderChip.maximumWidth)
                                             : chips.available
                    enabled: false
                }
            }

            // Figma: 30 x 32 at card x 345, centred 30 px below the title, "lists" state=active
            // (accent, 2 px) while the queue shows, the #FFFFFF 6 % wrapper on hover
            OverlayButton {
                id: queueButton

                anchors.right: picture.right
                anchors.rightMargin: VLCStyle.dp(8)
                anchors.verticalCenter: titleText.bottom
                anchors.verticalCenterOffset: VLCStyle.dp(30)
                iconName: root.queueOpen ? "lists_state-active" : "lists"
                description: qsTr("Queue")
                iconColor: root.queueOpen ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA2
                showHoverBackground: true
                onClicked: root.queueOpen = !root.queueOpen
            }
        }
    }

    component OverlayButton: T.AbstractButton {
        id: overlayButton

        property string iconName: ""
        property string description: ""
        property color iconColor: VLCStyle.palette.rdFg1
        property real iconSize: VLCStyle.rd_iconSize
        property bool showHoverBackground: false

        // the 30 x 32 Figma icon wrapper, or exactly the icon when it is larger
        implicitWidth: Math.max(VLCStyle.rd_iconButtonWidth, iconSize)
        implicitHeight: Math.max(VLCStyle.rd_iconButtonHeight, iconSize)
        hoverEnabled: true

        background: Rectangle {
            visible: overlayButton.showHoverBackground && overlayButton.hovered
            radius: VLCStyle.rd_radius_small
            color: VLCStyle.palette.rdHoverOverlay
        }

        Accessible.role: Accessible.Button
        Accessible.name: description

        T.ToolTip.visible: hovered && description !== ""
        T.ToolTip.delay: VLCStyle.delayToolTipAppear
        T.ToolTip.text: description

        contentItem: Item {
            Widgets.RdIcon {
                anchors.centerIn: parent
                name: overlayButton.iconName
                size: overlayButton.iconSize
                color: overlayButton.iconColor
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }

    component Chip: T.AbstractButton {
        id: chip

        property string iconName: ""
        // the room it may take; the label is elided to fit
        property real maximumWidth: Number.POSITIVE_INFINITY
        // icon, gap and the whole label
        readonly property real naturalWidth: chipIcon.width + chipRow.spacing + chipLabel.implicitWidth

        // Figma "Frame 114": 32 high, the 24 px chips centred
        implicitHeight: VLCStyle.dp(32)
        implicitWidth: chipRow.implicitWidth
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: text

        contentItem: Row {
            id: chipRow

            spacing: VLCStyle.dp(8)

            Widgets.RdIcon {
                id: chipIcon

                anchors.verticalCenter: parent.verticalCenter
                name: chip.iconName
                color: chip.hovered && chip.enabled ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA2
            }

            Text {
                id: chipLabel

                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                width: Math.max(0, Math.min(implicitWidth, chip.maximumWidth - chipIcon.width - chipRow.spacing))
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: chip.hovered && chip.enabled ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA1
            }
        }
    }
}
