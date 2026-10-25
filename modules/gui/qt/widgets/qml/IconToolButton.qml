/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

import QtQuick
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

T.ToolButton {
    id: control

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    // Properties

    property bool paintOnly: false

    required property string description

    property color color: (control.checked) ? theme.accent : theme.fg.primary

    property color backgroundColor: theme.bg.primary

    property real radius: VLCStyle.button_radius

    // redesign: Figma icon (Widgets.RdIcon) drawn instead of the font glyph when set;
    // rdIconChecked is the variant shown while checked (e.g. "subtitles_state-active")
    property string rdIcon: ""
    property string rdIconChecked: ""

    // Settings

    padding: 0

    enabled: !paintOnly

    // redesign: size of the Figma "Icon Wrapper" around the icon (control bar: 30x32), 0 = icon size
    property real rdMinimumWidth: 0
    property real rdMinimumHeight: 0

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding,
                            rdMinimumWidth)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             rdMinimumHeight)

    baselineOffset: contentItem.y + contentItem.baselineOffset

    font.pixelSize: VLCStyle.icon_toolbar
    font.family: VLCIcons.fontFamily

    // Keys

    Keys.priority: Keys.AfterItem

    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // Accessible

    Accessible.onPressAction: control.clicked()

    Accessible.name: description

    // Tooltip

    // redesign: a press hides the tooltip until the pointer and the keyboard focus leave the
    // button: it would stay over the menu or popup the button opened
    property bool _toolTipDismissed: false
    onPressedChanged: if (pressed) _toolTipDismissed = true
    onHoveredChanged: if (!hovered && !visualFocus) _toolTipDismissed = false
    onVisualFocusChanged: if (!hovered && !visualFocus) _toolTipDismissed = false

    T.ToolTip.visible: (hovered || visualFocus) && !_toolTipDismissed

    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    T.ToolTip.text: description

    // Events

    Component.onCompleted: console.assert(text !== "", "text is empty")

    // Children

    readonly property ColorContext colorContext : ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton

        enabled: control.paintOnly || control.enabled
        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    background: Widgets.AnimatedBackground {
        implicitWidth: control.font.pixelSize
        implicitHeight: control.font.pixelSize

        enabled: theme.initialized

        color: control.backgroundColor

        border.color: visualFocus ? theme.visualFocus : theme.border

        radius: control.radius
    }

    contentItem: Item {
        implicitWidth: control.rdIcon !== "" ? rdIconItem.implicitWidth : glyph.implicitWidth
        implicitHeight: control.rdIcon !== "" ? rdIconItem.implicitHeight : glyph.implicitHeight
        baselineOffset: glyph.baselineOffset

        Widgets.IconLabel {
            id: glyph

            anchors.fill: parent

            // redesign: unused when a Figma icon is set: no text, no color updates or animation
            readonly property bool used: control.rdIcon === ""

            visible: used

            text: used ? control.text : ""

            color: used ? control.color : "transparent"

            DelayedBehavior on color {
                delayedEnabled: theme.initialized && glyph.used

                ColorAnimation {
                    duration: VLCStyle.duration_long
                }
            }

            font: control.font
        }

        Widgets.RdIcon {
            id: rdIconItem

            anchors.centerIn: parent

            visible: control.rdIcon !== ""

            name: {
                if (control.rdIcon === "")
                    return ""
                return (control.checked && control.rdIconChecked !== "") ? control.rdIconChecked : control.rdIcon
            }
            size: control.font.pixelSize
            color: control.color
            accentColor: theme.accent
        }
    }
}
