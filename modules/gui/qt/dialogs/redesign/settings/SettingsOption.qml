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
// redesign: a Settings row bound to one VLC option (W6.2; video 16:57-17:35 and 18:48-18:55).
// The row reads and writes the option through RdEffects (the settings bridge of the settings
// sidebar: the change applies, is saved, and both stay in sync), shows VLC's explanation of the
// option in the info popover, and hides itself when this build of VLC has no such option.
// The control follows the option's type unless `kind` names one (Figma "Settings - *" rows,
// controls 320 px wide):
//   toggle    Toggle (ON / OFF); `checkedValue` / `uncheckedValue` for options that are not booleans
//   dropdown  values in words (`choices`, else the ones VLC declares) - never a number code
//   number    a value box; `valueScale` and `unit` show it in the user's unit (ms as "3 s")
//   slider    a slider under the label's line (`from`, `to`, `step`, `labels` or `labelStep`);
//             `limitFrom` / `limitTo` past from..to make it endless (Decision 47)
//   text, password, file, savefile, directory (field + Browse), color (hex + swatch)
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsRow {
    id: root

    // VLC's option name ("sub-autodetect-file")
    property string option: ""
    // empty: from the option's type
    property string kind: ""
    // [{ value, text }], replaces the choices VLC declares
    property var choices: null
    // toggle: the values written for ON and OFF (booleans by default)
    property var checkedValue: true
    property var uncheckedValue: false
    // number / slider: shown = value / valueScale (1000 shows milliseconds in seconds)
    property real valueScale: 1
    property string unit: ""
    property int decimals: 0
    property real from: info.min !== undefined ? info.min / valueScale : 0
    property real to: info.max !== undefined ? info.max / valueScale : 100
    property real step: decimals > 0 ? Math.pow(10, -decimals) : 1
    property var labels: []
    // slider: one label every labelStep from labelAnchor, written by labelText (endless sliders:
    // the labels scroll with the scale)
    property real labelStep: 0
    property real labelAnchor: zeroValue
    property var labelText: (v) => String(v)
    // slider: the values VLC accepts past from..to (shown unit); the scale scrolls on to them at
    // scrollSpeed per second while the pointer is held past an end
    property real limitFrom: from
    property real limitTo: to
    property real scrollSpeed: (to - from) * VLCStyle.rd_sliderScrollRate
    // slider: one mouse wheel notch over the slider (Decision 54)
    property real wheelStep: step
    // slider filled from 0 (delays)
    property bool bipolar: false
    // slider: the value the fill starts from (bipolar) and the edge label points to
    property real zeroValue: 0
    // Figma "Settings - *": every control 320 wide; text inputs 36 high, a few 32 (row 42)
    property real controlWidth: VLCStyle.dp(320)
    property real controlHeight: VLCStyle.dp(36)
    // slider: Figma "wrapper" of most Settings sliders (track 8 px down, labels 14 px under
    // it, 57 high); the Interface page's are 4 and 8 (47 high)
    property real sliderTrackTop: VLCStyle.dp(8)
    property real sliderLabelSpacing: VLCStyle.dp(14)
    property real tickStep: step
    // text fields
    property string placeholder: ""
    // VLC reads the option when it starts: the info popover says so
    property bool restartRequired: false

    readonly property var info: SettingsCatalog.describe(option)
    // a binding reading RdEffects.values[key] follows only this option's value
    readonly property var value: RdEffects.values[RdEffects.optionKey(option)]

    readonly property string resolvedKind: {
        if (kind !== "")
            return kind
        switch (info.type) {
        // a yes / no option the page words as two choices is a dropdown (Figma "Resize window
        // to fit video", "Auto-hide the controls")
        case "bool": return choices ? "dropdown" : "toggle"
        case "integer":
        case "float": return _choices.length > 0 ? "dropdown" : "number"
        case "color": return "color"
        case "password": return "password"
        case "module": return "dropdown"
        case "file":
        case "savefile":
        case "directory": return info.type
        default: return _choices.length > 0 ? "dropdown" : "text"
        }
    }

    readonly property bool _integer: info.type === "integer"
    // VLC words "no module" as "Disable" (Visualizer...): Figma and the settings sidebar say
    // "Disabled"
    readonly property var _choices: choices ?? RdEffects.optionChoices(option).map((c) =>
        (info.type === "module" && c.value === "none") ? { value: c.value, text: qsTr("Disabled") } : c)

    // options the interface reads into MainCtx (MainCtx::loadPrefs): it reads them again once
    // RdEffects has written the change, so they apply at once (as after VLC's preferences).
    // Not "qt-minimal-view": it is the compact mode VLC starts in, and reading it again would
    // switch the running window's compact mode
    readonly property bool _readByInterface: ["mouse-hide-timeout", "mouse-pause-policy",
                                              "qt-bgcone", "qt-cast-discovery",
                                              "qt-fs-opacity", "qt-max-volume",
                                              "qt-menubar", "qt-pin-controls", "qt-safe-area",
                                              "qt-smooth-scrolling", "qt-titlebar", "qt-video-double-click",
                                              "video-on-top"].indexOf(option) >= 0
    property bool _reloadPending: false
    // a slider being dragged: the interface reads the value once it is released
    property bool _dragging: false

    function apply(v) {
        RdEffects.setOption(option, v)
        if (_readByInterface && !_dragging)
            _reloadPending = true
    }

    // a number typed by the user, in the option's own unit, within VLC's range
    function applyNumber(shown) {
        let v = shown * valueScale
        if (info.min !== undefined)
            v = Math.max(info.min, v)
        if (info.max !== undefined)
            v = Math.min(info.max, v)
        apply(_integer ? Math.round(v) : v)
    }

    // VLC keeps floats in single precision: 0.04 reads back as 0.0399999...
    function sameValue(a, b) {
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) <= 1e-5 * Math.max(1, Math.abs(a), Math.abs(b))
        return String(a) === String(b)
    }

    function _numberText(v) {
        const n = Number(v ?? 0) / valueScale
        const text = decimals > 0 ? n.toFixed(decimals) : String(Math.round(n))
        return unit !== "" ? text + " " + unit : text
    }

    function _colorText(v) {
        const hex = (Number(v ?? 0) & 0xFFFFFF).toString(16).toUpperCase()
        return "#" + "000000".substring(hex.length) + hex
    }

    text: info.text ?? option
    description: {
        const text = RdEffects.optionDescription(option)
        if (!restartRequired)
            return text
        const note = qsTr("%1 uses this setting the next time it starts.").arg(Brand.shortName)
        return text !== "" ? text + "\n\n" + note : note
    }
    keywords: option
    shown: SettingsCatalog.exists(option)

    Connections {
        target: RdEffects
        enabled: root._reloadPending

        // RdEffects signals once the change has reached VLC's configuration
        function onChanged() {
            root._reloadPending = false
            MainCtx.reloadPrefs()
        }
    }

    Loader {
        sourceComponent: {
            switch (root.resolvedKind) {
            case "toggle": return toggleControl
            case "dropdown": return dropdownControl
            case "number": return numberControl
            case "slider": return sliderControl
            case "color": return colorControl
            case "file":
            case "savefile":
            case "directory": return pathControl
            default: return textControl
            }
        }
    }

    Component {
        id: toggleControl

        Widgets.RdToggle {
            checked: typeof root.checkedValue === "boolean" ? root.value === root.checkedValue
                                                           : root.sameValue(root.value, root.checkedValue)
            Accessible.name: root.text
            onToggled: root.apply(checked ? root.checkedValue : root.uncheckedValue)
        }
    }

    Component {
        id: dropdownControl

        Widgets.RdDropdown {
            // the current value is kept even when VLC does not list it (set elsewhere)
            readonly property var entries: {
                const list = root._choices.slice()
                const current = root.value
                if (current !== undefined && current !== ""
                        && !list.some((c) => root.sameValue(c.value, current)))
                    list.push({ value: current, text: String(current) })
                return list
            }

            implicitWidth: root.controlWidth
            implicitHeight: VLCStyle.dp(36)
            model: entries.map((c) => c.text)
            currentIndex: entries.findIndex((c) => root.sameValue(c.value, root.value))
            Accessible.name: root.text
            onActivated: (index) => root.apply(entries[index].value)
        }
    }

    Component {
        id: numberControl

        // Figma "Frame 265": a 320 wide text input
        Widgets.RdValueBox {
            implicitWidth: root.controlWidth
            implicitHeight: root.controlHeight
            text: root._numberText(root.value)
            validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*\s*\S*/ }
            Accessible.name: root.text
            onEdited: (text) => {
                const n = parseFloat(text.replace(",", "."))
                if (!isNaN(n))
                    root.applyNumber(n)
            }
        }
    }

    Component {
        id: sliderControl

        Widgets.RdEndlessSlider {
            implicitWidth: root.controlWidth
            rangeFrom: root.from
            rangeTo: root.to
            limitFrom: root.limitFrom
            limitTo: root.limitTo
            step: root.step
            scrollSpeed: root.scrollSpeed
            wheelStep: root.wheelStep
            labels: root.labels
            labelStep: root.labelStep
            labelAnchor: root.labelAnchor
            labelText: root.labelText
            tickStep: root.tickStep
            trackTop: root.sliderTrackTop
            labelSpacing: root.sliderLabelSpacing
            bipolar: root.bipolar
            zeroValue: root.zeroValue
            current: Number(root.value ?? 0) / root.valueScale
            Accessible.name: root.text
            onPressedChanged: {
                root._dragging = pressed
                // the released value is written once more, so the interface reads it after the
                // write (RdEffects signals nothing when the last step was already applied)
                if (!pressed && root._readByInterface)
                    root.applyNumber(value)
            }
            onValueMoved: (v) => root.applyNumber(v)
        }
    }

    Component {
        id: colorControl

        Widgets.RdValueBox {
            implicitWidth: root.controlWidth
            implicitHeight: VLCStyle.dp(32)
            text: root._colorText(root.value)
            // Figma "Frame 87": BG/B2 without a frame
            framed: false
            showSwatch: true
            swatch: text
            validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
            Accessible.name: root.text
            onEdited: (text) => {
                const hex = text.replace("#", "")
                if (hex.length === 6)
                    root.apply(parseInt(hex, 16))
            }
        }
    }

    Component {
        id: textControl

        Widgets.RdTextField {
            // typed text not written to VLC yet (the dialog keeps it from an outside click)
            readonly property bool dirty: activeFocus && text !== String(root.value ?? "")

            implicitWidth: root.controlWidth
            implicitHeight: root.controlHeight
            // Figma "Frame 265": the value in FG/A2
            color: VLCStyle.palette.rdFgA2
            placeholderTextColor: VLCStyle.palette.rdFgA2
            text: String(root.value ?? "")
            placeholderText: root.placeholder
            echoMode: root.resolvedKind === "password" ? TextInput.Password : TextInput.Normal
            Accessible.name: root.text
            onEditingFinished: {
                if (text !== String(root.value ?? ""))
                    root.apply(text)
            }
        }
    }

    // Figma "Frame 268": field 210 wide, 10 px, "Browse" 100x32
    Component {
        id: pathControl

        Row {
            spacing: VLCStyle.dp(10)

            Widgets.RdTextField {
                id: pathField

                readonly property bool dirty: activeFocus && text !== String(root.value ?? "")

                width: root.controlWidth - browseButton.width - parent.spacing
                height: root.controlHeight
                color: VLCStyle.palette.rdFgA2
                placeholderTextColor: VLCStyle.palette.rdFgA2
                text: String(root.value ?? "")
                placeholderText: root.placeholder
                Accessible.name: root.text
                onEditingFinished: {
                    if (text !== String(root.value ?? ""))
                        root.apply(text)
                }
            }

            Widgets.RdButton {
                id: browseButton

                anchors.verticalCenter: parent.verticalCenter
                style: Widgets.RdButton.Style.Plain
                text: qsTr("Browse")
                Accessible.name: qsTr("Browse for \"%1\"").arg(root.text)
                onClicked: {
                    const current = String(root.value ?? "")
                    const path = root.resolvedKind === "directory"
                               ? SettingsCatalog.pickDirectory(root.text, current)
                               : SettingsCatalog.pickFile(root.text, current, root.resolvedKind === "savefile")
                    if (path !== "")
                        root.apply(path)
                }
            }
        }
    }
}
