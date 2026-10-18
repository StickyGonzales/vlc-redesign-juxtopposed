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

// redesign: icon of the library header and rail (Figma "Icon" 24 px in the header rows,
// "Icon Wrapper" 30x32 with padding 4 in the rail). Gray FG/A2 icons, a #FFFFFF 6% hover
// background (Figma rail hover), FG/A4 when there is nothing to do (forward without history,
// IB-12).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.MediaLibrary
import VLC.Widgets as Widgets

T.AbstractButton {
    id: control

    property string iconName: ""
    property string description: ""
    // the icon's color at rest (Figma: back / forward FG/A2, the header tools FG/A3)
    property color normalColor: VLCStyle.palette.rdFgA2
    // Figma disabled arrow: FG/A2 at 30 % opacity
    property color iconColor: !enabled ? Qt.alpha(VLCStyle.palette.rdFgA2, 0.3)
                                       : (hovered || visualFocus) ? VLCStyle.palette.rdFgA1
                                                                  : normalColor
    property bool showHoverBackground: true

    implicitWidth: VLCStyle.rd_iconSize
    implicitHeight: VLCStyle.rd_iconSize

    focusPolicy: Qt.TabFocus
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.onPressAction: control.clicked()

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            control._toolTipDismissed = true
            control.clicked()
            event.accepted = true
            return
        }
        Navigation.defaultKeyAction(event)
    }

    // VLC's Navigation takes the arrows and Escape: the arrows walk the keyboard focus chain
    // and Escape goes back in the library, unless the view sets its own (RdLibraryPage's grid)
    Navigation.upAction: () => RdLibraryNav.focusStep(control, false)
    Navigation.downAction: () => RdLibraryNav.focusStep(control, true)
    Navigation.leftAction: () => RdLibraryNav.focusStep(control, false)
    Navigation.rightAction: () => RdLibraryNav.focusStep(control, true)
    Navigation.cancelAction: () => RdLibraryNav.goBack()

    // redesign: a press hides the tooltip until the pointer and the keyboard focus leave the
    // button: it would stay over the menu or popup the button opened
    property bool _toolTipDismissed: false
    onPressedChanged: if (pressed) _toolTipDismissed = true
    onHoveredChanged: if (!hovered && !visualFocus) _toolTipDismissed = false
    onVisualFocusChanged: if (!hovered && !visualFocus) _toolTipDismissed = false

    T.ToolTip.visible: (hovered || visualFocus) && description !== "" && !_toolTipDismissed
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: description

    background: Rectangle {
        radius: VLCStyle.rd_radius_small
        color: control.showHoverBackground && (control.hovered || control.visualFocus) && control.enabled
               ? VLCStyle.palette.rdHoverOverlay : "transparent"
    }

    contentItem: Item {
        Widgets.RdIcon {
            anchors.centerIn: parent
            name: control.iconName
            color: control.iconColor
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
