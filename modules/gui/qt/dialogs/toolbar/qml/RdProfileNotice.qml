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

// redesign (W8.2, Decision 29): after a profile switch (RdProfiles.applied), tells when some of
// the profile's settings do not apply at once. No Figma frame (Decision 21): the resume toast's
// style (Figma "continue": 52 high pill, radius 16, BG/A3, Inter 16 FG/2, a primary button and
// the dark close button), centered over the bottom of the window, 18 px above the control bar
// (its real height: one row, or two when the seek row has its own row).
// - settings that only apply after a restart: "Restart Now" (VLC starts again with them) and
//   the close button; it stays until one is clicked.
// - settings that apply from the next file, while one plays: the sentence alone, for 6 s.
// It also has every value cache of the interface read again (RdEffects), so the sidebar shows
// the profile's values at once. It never takes the keyboard focus from the player.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    property bool _restart: false
    property string _profile: ""

    parent: T.Overlay.overlay

    x: Math.round(((parent ? parent.width : 0) - width) / 2)
    readonly property real _barHeight: (RdPanels.controlBarHeight > 0) ? RdPanels.controlBarHeight
                                                                       : VLCStyle.rd_controlBarHeight

    y: (parent ? parent.height : 0) - height - _barHeight - VLCStyle.dp(18, VLCStyle.scale)
    width: Math.min(VLCStyle.dp(552, VLCStyle.scale), content.implicitWidth + VLCStyle.dp(30, VLCStyle.scale),
                    (parent ? parent.width : 0) - 2 * VLCStyle.margin_large)
    height: VLCStyle.dp(52, VLCStyle.scale)

    padding: 0
    modal: false
    dim: false
    focus: false
    closePolicy: T.Popup.CloseOnEscape

    Accessible.role: Accessible.AlertMessage
    Accessible.name: label.text

    Connections {
        target: RdProfiles

        function onApplied(profile, nextMedia, restartOptions) {
            // the sidebar, the Settings pages and the bars read the profile's values
            RdEffects.refresh()

            root._profile = profile
            root._restart = restartOptions.length > 0
            if (root._restart || (nextMedia && Player.isStarted)) {
                hideTimer.restart()
                root.open()
            } else {
                root.close()
            }
        }
    }

    Timer {
        id: hideTimer

        interval: 6000
        running: false
        onTriggered: {
            if (!root._restart)
                root.close()
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_toast
        // opaque: the bg blur cannot run over the native video
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)
    }

    contentItem: RowLayout {
        id: content

        spacing: VLCStyle.dp(10, VLCStyle.scale)

        T.Label {
            id: label

            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: closeButton.visible ? 0 : VLCStyle.dp(20, VLCStyle.scale)
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: implicitWidth

            text: root._restart
                  ? qsTr("Some settings of “%1” apply after %2 restarts.").arg(root._profile).arg(Brand.shortName)
                  : qsTr("Some settings of “%1” apply from the next file.").arg(root._profile)
            elide: Text.ElideRight
            color: VLCStyle.palette.rdFg2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
        }

        Widgets.RdButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: VLCStyle.dp(30, VLCStyle.scale)

            visible: root._restart
            style: Widgets.RdButton.Style.Primary
            text: qsTr("Restart Now")

            onClicked: {
                root.close()
                if (SettingsCatalog.startNewInstance())
                    DialogsProvider.quit()
            }
        }

        T.Button {
            id: closeButton

            // the pointing hand over the clickable controls
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
            implicitWidth: VLCStyle.dp(44, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            visible: root._restart
            focusPolicy: Qt.TabFocus
            Accessible.name: qsTr("Later")

            onClicked: root.close()

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: closeButton.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA1
            }

            contentItem: Item {
                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: "close"
                    color: VLCStyle.palette.rdFgA2
                }
            }
        }
    }
}
