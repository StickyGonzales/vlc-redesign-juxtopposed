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
// redesign: one setting of the Settings dialog (Figma "Settings - *" frames, "Frame 69" rows).
// Label Inter 14 FG/A2; when `description` is set, an 18 px info icon (FG/A4) 10 px after the
// label shows it in a popover on click (Decision 26, video 18:48-18:55); the control (default
// property) is right-aligned; the row is padded 5 px above and below (42 px with a toggle, 46 px
// with a 36 px field). `below` items (sliders, panels) go under the row at full width.
// While the dialog's search is active the row hides itself unless its text, description,
// keywords or its section title match. Hide a row conditionally with `shown`, not `visible`;
// set `available: false` while it depends on a setting that is off: the row is drawn at 30 %
// and its control disabled, its info icon stays usable. The redesign controls draw themselves
// at 30 % while disabled, so the row dims its label, info icon and `below` items only: dimming
// the whole row as well put its control at 9 % (Figma: the row frame alone at 30 %).
// Escape closes an open info popover first (before the search field and the dialog).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root

    property alias text: label.text
    // the setting's explanation for the info popover; empty: no info icon
    property string description: ""
    // extra words the search finds this row by (e.g. VLC's option name)
    property string keywords: ""
    property bool shown: true
    property bool available: true
    // Figma row geometry: the line is at least 32 high (most text input rows: 38), padded 5
    // above and below (10 around the start volume choice)
    property real minimumLineHeight: VLCStyle.rd_rowHeight
    property real rowPadding: VLCStyle.dp(5)
    default property alias control: controlSlot.data
    property alias below: belowSlot.data
    // false hides the `below` items and their spacing (a note shown only in some states)
    property bool belowShown: true

    readonly property bool isSettingsRow: true
    readonly property bool matches: !_page || !_page.filtering
                                    || (!!_section && _section.titleMatches)
                                    || _page.textMatches([text, description, keywords])

    // the page and section this row belongs to, found when the row is created
    property Item _page: null
    property Item _section: null

    readonly property SystemPalette rdPalette: VLCStyle.palette

    visible: shown && matches
    // a setting that depends on another one that is off (Figma "Settings - library", video 18:15)
    readonly property real _dimmedOpacity: available ? 1.0 : VLCStyle.rd_disabledRowOpacity
    Layout.fillWidth: true
    spacing: VLCStyle.dp(5)

    Component.onCompleted: {
        for (let item = root.parent; item; item = item.parent) {
            if (!root._section && item.isSettingsSection === true)
                root._section = item
            if (item.isSettingsPage === true) {
                root._page = item
                break
            }
        }
        if (root._section)
            root._section.registerRow(root)
        if (root._page)
            root._page.registerRow(root)
    }

    // the page and the section count the shown rows that match
    onShownChanged: {
        if (root._section)
            root._section.recount()
        if (root._page)
            root._page.recount()
    }

    Component.onDestruction: {
        if (root._section)
            root._section.unregisterRow(root)
        if (root._page)
            root._page.unregisterRow(root)
    }

    Item {
        id: line

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(root.minimumLineHeight, controlSlot.height) + 2 * root.rowPadding

        Text {
            id: label

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth,
                            line.width - controlSlot.width - VLCStyle.dp(20)
                            - (infoButton.visible ? infoButton.width + VLCStyle.dp(10) : 0))
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA2
            opacity: root._dimmedOpacity
        }

        // Figma "Icon" name=info at 18 px, FG/A4
        T.AbstractButton {
            id: infoButton

            visible: root.description !== ""
            anchors.left: label.right
            anchors.leftMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: VLCStyle.dp(18)
            implicitHeight: VLCStyle.dp(18)
            opacity: root._dimmedOpacity

            focusPolicy: Qt.StrongFocus
            hoverEnabled: true

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("About \"%1\"").arg(root.text)
            Accessible.description: root.description

            Keys.onReturnPressed: popover.toggle()
            Keys.onEnterPressed: popover.toggle()
            // Escape is a shortcut of the dialog popup: take it while the popover is open
            Keys.onShortcutOverride: (event) => {
                if (event.key === Qt.Key_Escape && popover.opened)
                    event.accepted = true
            }
            Keys.onEscapePressed: (event) => {
                if (popover.opened) {
                    popover.hide()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            onClicked: popover.toggle()

            // a popover stays with its row: close it when the row, the page or the dialog hides
            onActiveFocusChanged: {
                if (!activeFocus && popover.opened)
                    popover.hide()
            }

            onVisibleChanged: {
                if (!visible)
                    popover.hide()
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            background: Rectangle {
                radius: width / 2
                color: "transparent"
                border.width: infoButton.visualFocus ? VLCStyle.dp(1) : 0
                border.color: root.rdPalette.rdFgA3
            }

            contentItem: Widgets.RdIcon {
                name: "info"
                size: VLCStyle.dp(18)
                color: (infoButton.hovered || popover.opened) ? root.rdPalette.rdFgA2
                                                               : root.rdPalette.rdFgA4
            }
        }

        // created on the first click only, so long pages do not hold one popup per row
        Loader {
            id: popover

            readonly property bool opened: !!item && item.opened

            function toggle() {
                active = true
                if (!item)
                    return
                if (item.opened)
                    item.close()
                else
                    item.open()
            }

            function hide() {
                if (item)
                    item.close()
            }

            active: false

            sourceComponent: Component {
                Widgets.RdTooltip {
                    parent: infoButton
                    x: (infoButton.width - width) / 2
                    y: infoButton.height + VLCStyle.dp(6)
                    margins: VLCStyle.dp(8)

                    text: root.description
                    textAlignment: Text.AlignLeft
                    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent

                    // opaque, like the dialog and its other popups: where it passes the dialog's
                    // edge, Figma's 95 % (meant with a background blur) shows the video through
                    background: Rectangle {
                        radius: VLCStyle.rd_radius_normal
                        color: Qt.alpha(root.rdPalette.rdBgB1, 1.0)

                        Widgets.RdShadow { }
                    }
                }
            }
        }

        // sized by its child; the control is right-aligned
        Item {
            id: controlSlot

            enabled: root.available
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // full-width items under the row; each child should bind its width to the row
    Column {
        id: belowSlot

        enabled: root.available
        opacity: root._dimmedOpacity
        visible: children.length > 0 && root.belowShown
        Layout.fillWidth: true
    }
}
