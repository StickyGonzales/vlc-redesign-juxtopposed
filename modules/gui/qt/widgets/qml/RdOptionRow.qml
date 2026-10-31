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

// Redesign menu / list option row (Figma component "option", 48 px, padding 2,14, gap 10, radius 6):
// [icon 24] label [shortcut | > | check]. Hover and selected rows get BG/A2.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.ItemDelegate {
    id: control

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    property string rdIcon: ""              // Figma icon name (Widgets.RdIcon), two-tone menu icons included
    property string shortcut: ""
    property bool hasSubmenu: false
    // the ">" of a submenu row (Figma's "Add to Playlist" row has none)
    property bool showChevron: true
    property bool selected: false           // orange check at the right
    property bool dimmed: false             // e.g. "+ New Custom Preset"
    property Component leading: null        // optional item before the text (equalizer curve)
    property bool reserveIconSpace: false   // keep the icon column when the row has no icon (menus)
    property bool active: false             // highlighted without hover, e.g. its submenu is open
    property color iconColor: control.rdPalette.rdFgA2
    // menu rows 6; dropdown list options 4 (Figma "option" 2372:8369)
    property real radius: VLCStyle.rd_radius_normal

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.rd_menuWidth - VLCStyle.dp(8)
    implicitHeight: VLCStyle.rd_menuRowHeight

    leftPadding: VLCStyle.dp(14)
    rightPadding: VLCStyle.dp(14)
    topPadding: VLCStyle.dp(2)
    bottomPadding: VLCStyle.dp(2)
    spacing: VLCStyle.dp(10)

    focusPolicy: Qt.StrongFocus

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // accessibility tools (UI Automation's Invoke pattern) choose the row as a click does: a
    // list item has no press action of its own (the dropdown takes the row's clicked())
    Accessible.onPressAction: control.clicked()

    background: Rectangle {
        radius: control.radius
        color: (control.hovered || control.visualFocus || control.selected || control.active)
               ? control.rdPalette.rdBgA2 : "transparent"
    }

    contentItem: Row {
        spacing: control.spacing

        RdIcon {
            visible: control.rdIcon !== "" || control.reserveIconSpace
            anchors.verticalCenter: parent.verticalCenter
            name: control.rdIcon
            color: control.enabled ? control.iconColor : control.rdPalette.rdFgA4
            color2: control.enabled ? control.rdPalette.rdAccentDim : control.rdPalette.rdFgA4
            accentColor: control.enabled ? control.rdPalette.rdAccentMain : control.rdPalette.rdFgA4
        }

        Loader {
            active: !!control.leading
            visible: active
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: control.leading
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: control.availableWidth - x - trailing.width - control.spacing
            elide: Text.ElideRight
            text: control.text
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: !control.enabled ? control.rdPalette.rdFgA4
                                    : control.dimmed ? control.rdPalette.rdFgA3 : control.rdPalette.rdFgA2
        }

        Item {
            id: trailing

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(shortcutText.visible ? shortcutText.implicitWidth : 0, VLCStyle.rd_iconSize)
            height: VLCStyle.rd_iconSize

            Text {
                id: shortcutText

                visible: control.shortcut !== "" && !control.hasSubmenu && !control.selected
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: control.shortcut
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: control.enabled ? control.rdPalette.rdFgA3 : control.rdPalette.rdFgA4
            }

            RdIcon {
                visible: (control.hasSubmenu && control.showChevron) || control.selected
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: control.selected ? "check_state-active" : "chevron_direction-right"
                color: control.enabled ? control.rdPalette.rdFgA3 : control.rdPalette.rdFgA4
            }
        }
    }
}
