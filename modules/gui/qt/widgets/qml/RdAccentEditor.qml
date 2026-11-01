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
// redesign (Cone extra, redesign/CUSTOM_ACCENT_NOTES.md): the editor of the custom accent color,
// opened by the "Custom" swatch after the nine Decision 15 colors (Settings > General > Accent
// color, onboarding). A preview square and a hex field (#RRGGBB): every complete code recolors
// the whole interface at once (MainCtx.accentColor, kept in "qt-accent-color" as the hex code,
// so profiles keep it like the presets); Enter or a click outside keeps it, Escape goes back to
// the accent the editor opened with. Under the field, a warning when the color is hard to see on
// the theme's surfaces. Styled as the info popovers (RdTooltip): opaque BG/B1, radius 6,
// padding 10, Inter 14.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style

T.Popup {
    id: control

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // the last custom color, shown on the Custom swatch while a preset is chosen
    readonly property string lastCustomKey: "RdAccent/Custom"

    // the accent when the editor opened: Escape restores it ("default" stays "default")
    property color _openedWith
    property bool _openedValid: false

    // a custom color was chosen in the editor (the swatches show it)
    signal customColorChanged(color value)

    // "#RRGGBB" or "RRGGBB" as a color; anything else (still being typed) gives none
    function colorOf(text: string): var {
        const match = /^#?([0-9A-Fa-f]{6})$/.exec(text.trim())
        return match ? Qt.color("#" + match[1]) : undefined
    }

    function hexOf(value: color): string {
        return value.toString().toUpperCase()
    }

    function _apply(value: color) {
        MainCtx.accentColor = value
        const hex = hexOf(value)
        MainCtx.setSettingValue(lastCustomKey, hex)
        customColorChanged(value)
    }

    function _revert() {
        if (_openedValid)
            MainCtx.accentColor = _openedWith
        else
            MainCtx.resetAccentColor()
        close()
    }

    implicitWidth: Math.max(implicitContentWidth, implicitBackgroundWidth) + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    padding: VLCStyle.dp(10)
    modal: false
    focus: true
    closePolicy: T.Popup.CloseOnPressOutsideParent

    onAboutToShow: {
        _openedValid = MainCtx.accentColor.valid
        _openedWith = _openedValid ? MainCtx.accentColor : rdPalette.rdAccentMain
        field.text = hexOf(_openedWith)
        field.selectAll()
        field.forceActiveFocus(Qt.TabFocusReason)
    }

    // a dialog opening (Ctrl+P, Ctrl+N, ...) closes the editor first; the color stays
    readonly property Connections _dialogConnections: Connections {
        target: DialogsProvider

        function onDialogOpening() {
            if (control.opened)
                control.close()
        }
    }

    contentItem: Column {
        spacing: VLCStyle.dp(8)

        Text {
            text: qsTr("Custom color")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: control.rdPalette.rdFg2
        }

        Row {
            spacing: VLCStyle.dp(8)

            // the color the field stands for, or the accent while the code is incomplete
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(32)
                height: VLCStyle.dp(32)
                radius: VLCStyle.rd_radius_small
                color: control.colorOf(field.text) ?? control.rdPalette.rdAccentMain
                border.width: VLCStyle.dp(1)
                border.color: control.rdPalette.rdSwatchStroke
            }

            RdTextField {
                id: field

                width: VLCStyle.dp(132)
                maximumLength: 7
                placeholderText: "#RRGGBB"
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhPreferUppercase
                validator: RegularExpressionValidator {
                    regularExpression: /#?[0-9A-Fa-f]{0,6}/
                }

                Accessible.name: qsTr("Custom accent color, hex code")

                // every complete code recolors the interface at once
                onTextEdited: {
                    const value = control.colorOf(text)
                    if (value !== undefined)
                        control._apply(value)
                }

                Keys.onReturnPressed: control.close()
                Keys.onEnterPressed: control.close()
                Keys.onEscapePressed: control._revert()
            }
        }

        // the accent of headings, icons and the seek bar would vanish on the theme's surfaces
        Text {
            width: VLCStyle.dp(172)
            visible: control.rdPalette.rdAccentLowContrast && control.colorOf(field.text) !== undefined
            wrapMode: Text.WordWrap
            text: qsTr("Hard to see on this theme. Try a brighter or darker color.")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_toggle
            color: control.rdPalette.rdFgA1
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        // opaque, like the other popovers: the bg blur cannot run over the native video
        color: Qt.alpha(control.rdPalette.rdBgB1Transparent, 1.0)

        RdShadow { }
    }
}
