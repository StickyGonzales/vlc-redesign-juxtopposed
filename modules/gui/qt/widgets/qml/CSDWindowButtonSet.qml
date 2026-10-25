/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick.Window


import VLC.MainInterface
import VLC.Style

Row {
    id: windowButtonGroup

    spacing: 0
    padding: 0

    width: implicitWidth

    property color color: theme.fg.primary
    property color hoverColor: theme.bg.primary.alpha(0.5)

    property bool showFullscreenButton: false

    // redesign (W8.1b): an item shown between maximize and close, where Figma's top bar has its
    // fullscreen button: the right zone of the editable top bar (TopBar.qml). The slot takes its
    // width; the owner draws the item over `middleSlotItem` (the item stays the owner's child)
    property Item middleItem: null
    readonly property Item middleSlotItem: middleSlot

    readonly property bool useWinIcons: ((MainCtx.osName === MainCtx.Windows)&&(MainCtx.osVersion >= 10))

    readonly property bool buttonHovered: {
        let h = fullscreenButton.visible && fullscreenButton.hovered
        for (const rep of [repeater, closeRepeater]) {
            for (let i = 0; i < rep.count; ++i) {
                const button = rep.itemAt(i)
                h = h || button.hovered || button.showHovered
            }
        }

        return h
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // redesign: optional fullscreen button between maximize and close (Decision 1, Figma top bar:
    // minimize, maximize, fullscreen, close). Window buttons come from two repeaters around it.
    Repeater {
        id: repeater

        model: MainCtx.csdButtonModel.windowCSDButtons.filter((b) => b.type !== CSDButton.Close)

        CSDWindowButton {
            required property var modelData

            height: windowButtonGroup.height

            showHovered: modelData.showHovered

            externalPressed: modelData.externalPressed

            color: (modelData.type === CSDButton.Close && (hovered || modelData.showHovered))
                   ? "white"
                   : windowButtonGroup.color

            hoverColor: (modelData.type === CSDButton.Close) ? "red" : windowButtonGroup.hoverColor

            isThemeDark: theme.palette.isDark

            // redesign: Figma window icons (maximize has no separate restore variant)
            rdIcon: {
                switch (modelData.type) {
                case CSDButton.Minimize:
                    return "minimize"
                case CSDButton.MaximizeRestore:
                    return "maximize"
                case CSDButton.Close:
                    return "close"
                }
                return ""
            }

            iconTxt:{
                switch (modelData.type) {
                case CSDButton.Minimize:
                {
                    if (useWinIcons)
                        return "\uE921"

                    else
                        return VLCIcons.window_minimize
                }

                case CSDButton.MaximizeRestore:
                {
                    if (useWinIcons)
                        return (MainCtx.intfMainWindow.visibility === Window.Maximized)
                                ? "\uE923"
                                : "\uE922"

                    else
                        return (MainCtx.intfMainWindow.visibility === Window.Maximized)
                                ? VLCIcons.window_restore
                                : VLCIcons.window_maximize
                }

                case CSDButton.Close:
                {
                    if (useWinIcons)
                        return "\uE8BB"

                    else
                        return VLCIcons.window_close
                }
                }
                console.assert(false, "unreachable")
            }

            onClicked: modelData.click()

            // handles VLCStyle.scale changes
            onWidthChanged: Qt.callLater(updateRect)
            onHeightChanged: Qt.callLater(updateRect)

            Connections {
                target: VLCStyle

                // handle window resize
                function onAppWidthChanged() { Qt.callLater(updateRect) }
                function onAppHeightChanged() { Qt.callLater(updateRect) }
            }

            function updateRect() {
                const point = mapToItem(null, 0, 0)
                const rect = Qt.rect(point.x, point.y, width, height)

                modelData.rect = rect
            }
        }
    }

    CSDWindowButton {
        id: fullscreenButton

        visible: windowButtonGroup.showFullscreenButton
        height: windowButtonGroup.height
        color: windowButtonGroup.color
        hoverColor: windowButtonGroup.hoverColor
        isThemeDark: theme.palette.isDark
        iconTxt: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen : VLCIcons.fullscreen
        rdIcon: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? "fullscreen_state-active" : "fullscreen"
        onClicked: MainCtx.toggleInterfaceFullScreen()
    }

    Item {
        id: middleSlot

        width: windowButtonGroup.middleItem ? windowButtonGroup.middleItem.width : 0
        height: windowButtonGroup.height
    }

    // redesign (W8.1b): the set is anchored to the right, so a wider middle slot (or the
    // fullscreen button shown or hidden) moves minimize and maximize: the window's hit test learns
    // where every button is now (after the Row placed them)
    onWidthChanged: {
        for (const rep of [repeater, closeRepeater]) {
            for (let i = 0; i < rep.count; ++i) {
                const button = rep.itemAt(i)
                if (button)
                    Qt.callLater(button.updateRect)
            }
        }
    }

    Repeater {
        id: closeRepeater

        model: MainCtx.csdButtonModel.windowCSDButtons.filter((b) => b.type === CSDButton.Close)

        CSDWindowButton {
            required property var modelData

            height: windowButtonGroup.height

            showHovered: modelData.showHovered

            externalPressed: modelData.externalPressed

            color: (modelData.type === CSDButton.Close && (hovered || modelData.showHovered))
                   ? "white"
                   : windowButtonGroup.color

            hoverColor: (modelData.type === CSDButton.Close) ? "red" : windowButtonGroup.hoverColor

            isThemeDark: theme.palette.isDark

            // redesign: Figma window icons (maximize has no separate restore variant)
            rdIcon: {
                switch (modelData.type) {
                case CSDButton.Minimize:
                    return "minimize"
                case CSDButton.MaximizeRestore:
                    return "maximize"
                case CSDButton.Close:
                    return "close"
                }
                return ""
            }

            iconTxt:{
                switch (modelData.type) {
                case CSDButton.Minimize:
                {
                    if (useWinIcons)
                        return "\uE921"

                    else
                        return VLCIcons.window_minimize
                }

                case CSDButton.MaximizeRestore:
                {
                    if (useWinIcons)
                        return (MainCtx.intfMainWindow.visibility === Window.Maximized)
                                ? "\uE923"
                                : "\uE922"

                    else
                        return (MainCtx.intfMainWindow.visibility === Window.Maximized)
                                ? VLCIcons.window_restore
                                : VLCIcons.window_maximize
                }

                case CSDButton.Close:
                {
                    if (useWinIcons)
                        return "\uE8BB"

                    else
                        return VLCIcons.window_close
                }
                }
                console.assert(false, "unreachable")
            }

            onClicked: modelData.click()

            // handles VLCStyle.scale changes
            onWidthChanged: Qt.callLater(updateRect)
            onHeightChanged: Qt.callLater(updateRect)

            Connections {
                target: VLCStyle

                // handle window resize
                function onAppWidthChanged() { Qt.callLater(updateRect) }
                function onAppHeightChanged() { Qt.callLater(updateRect) }
            }

            function updateRect() {
                const point = mapToItem(null, 0, 0)
                const rect = Qt.rect(point.x, point.y, width, height)

                modelData.rect = rect
            }
        }
    }
}
