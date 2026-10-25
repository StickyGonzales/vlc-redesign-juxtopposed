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

// Redesign menu panel (Figma "menu", "folder context menu", "Sorting Options" ...):
// BG/A3 95%, radius 10, padding 4, effect "bg blur + shadow". Put RdOptionRow and RdMenuDivider
// items inside; the panel closes when an option is clicked (closeOnClick).
// Keyboard (as RdCascadeMenu): Up / Down move between the rows, Return / Enter / Space click,
// Escape closes; opened from the keyboard (`keyboard`) the first row takes the focus. The item
// that had the focus gets it back when the menu closes. The panel stays inside the window.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style

T.Popup {
    id: control

    default property alias items: column.data
    property bool closeOnClick: true
    property bool withShadow: true
    // opened from the keyboard: the first row takes the focus
    property bool keyboard: false

    // the item that had the focus before the menu opened
    property Item _opener: null

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.rd_menuWidth
    implicitHeight: column.implicitHeight + topPadding + bottomPadding

    padding: VLCStyle.dp(4)

    modal: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent
    // while the menu is open the wheel outside it does nothing, as with RdCascadeMenu: it never
    // reaches the player or a list behind (Decision 54); a click outside still goes through. The
    // "dim" layer is only that wheel catcher, it draws nothing
    dim: true
    T.Overlay.modeless: RdWheelSink { }
    // kept inside the window
    margins: VLCStyle.margin_xsmall

    onAboutToShow: {
        const window = control.parent ? control.parent.Window.window : null
        control._opener = window ? window.activeFocusItem : null
        // keys reach the menu from the first frame of its fade in
        if (control.keyboard)
            column.moveFocus(1)
        else
            column.forceActiveFocus()
    }

    onOpened: {
        if (!column.activeFocus && !column._focusedRow())
            column.forceActiveFocus()
    }

    onClosed: {
        const opener = control._opener
        control._opener = null
        control.keyboard = false
        if (opener && opener.visible && opener.enabled)
            opener.forceActiveFocus(Qt.PopupFocusReason)
    }

    // a dialog opening (Ctrl+P, Ctrl+N, ...) closes the menu first: it never stays behind it
    readonly property Connections _dialogConnections: Connections {
        target: DialogsProvider

        function onDialogOpening() {
            control.close()
        }
    }

    // as RdCascadeMenu: fades in (video 5:08, 60 fps), closes at once
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: VLCStyle.rd_menuFadeDuration
            easing.type: Easing.OutQuad
        }
    }

    contentItem: Column {
        id: column

        width: control.availableWidth

        property var _connected: []

        // the rows in their order, with the rows of a list inside the menu (Add to Playlist)
        function _rows() {
            const rows = []
            for (let i = 0; i < children.length; ++i) {
                const child = children[i]
                if (!child.visible)
                    continue
                if (child.itemAtIndex !== undefined) {
                    for (let j = 0; j < child.count; ++j) {
                        const item = child.itemAtIndex(j)
                        if (item && item.enabled)
                            rows.push(item)
                    }
                } else if (child.clicked !== undefined && child.enabled) {
                    rows.push(child)
                }
            }
            return rows
        }

        function _focusedRow() {
            return _rows().find((r) => r.activeFocus) ?? null
        }

        function moveFocus(step) {
            const rows = _rows()
            if (rows.length === 0)
                return
            let i = rows.findIndex((r) => r.activeFocus)
            i = (i < 0) ? (step > 0 ? 0 : rows.length - 1)
                        : Math.max(0, Math.min(rows.length - 1, i + step))
            rows[i].forceActiveFocus(Qt.TabFocusReason)
        }

        // a row passes the arrows and Escape to VLC's Navigation, which hands them here
        Navigation.upAction: () => column.moveFocus(-1)
        Navigation.downAction: () => column.moveFocus(1)
        Navigation.leftAction: () => {}
        Navigation.rightAction: () => {}
        Navigation.cancelAction: () => control.close()

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const row = column._focusedRow()
                if (row) {
                    row.clicked()
                    event.accepted = true
                }
            } else {
                Navigation.defaultKeyAction(event)
            }
        }

        onChildrenChanged: {
            // rows of a Repeater are destroyed and recreated: forget the ones that are gone (a
            // destroyed object's wrapper stays truthy in a JS array)
            _connected = _connected.filter((c) => Array.prototype.indexOf.call(children, c) >= 0)
            for (let i = 0; i < children.length; ++i) {
                const child = children[i]
                if (child.clicked !== undefined && _connected.indexOf(child) < 0) {
                    _connected.push(child)
                    child.clicked.connect(() => { if (control.closeOnClick && !child.hasSubmenu) control.close() })
                    child.Navigation.parentItem = column
                }
                if (child.width !== undefined)
                    child.width = Qt.binding(() => column.width)
            }
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_panel
        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(control.rdPalette.rdBgA3Transparent, 1.0)

        RdShadow {
            visible: control.withShadow
        }
    }
}
