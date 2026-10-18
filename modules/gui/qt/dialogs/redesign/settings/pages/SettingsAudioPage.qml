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
// redesign: Settings > Audio ("Audio Defaults", video 18:06-18:08 and 20:33-20:36, Figma
// "Settings - audio" / "Settings - audio-1"); rows: P8-11, P8-44. The effects are the settings
// sidebar's (RdEffects): they apply to what plays and are kept.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    function _option(name) {
        return RdEffects.values[RdEffects.optionKey(name)]
    }

    function _filterOn(module) {
        return RdEffects.values[RdEffects.audioFilterKey(module)] === true
    }

    readonly property string _aout: String(_option("aout") ?? "")
    // the device and start volume options of the output in use (VLC's preferences do the same;
    // VLC 4 has no DirectSound output any more)
    readonly property string _deviceOption: _aout === "waveout" ? "waveout-audio-device" : "mmdevice-audio-device"
    readonly property string _volumeOption: _aout === "waveout" ? "waveout-volume" : "mmdevice-volume"
    readonly property bool _rememberVolume: _option("volume-save") === true
    // the effects this build of VLC has (a toggle without its filter would stay on doing nothing)
    readonly property bool _equalizer: SettingsCatalog.moduleExists("equalizer")
    readonly property int _eqPreset: RdEffects.values.equalizerPreset
    // bands moved away from the preset's: the dropdown says "Custom"
    readonly property bool _eqCustom: {
        if (_eqPreset < 0)
            return false
        const bands = RdEffects.values.equalizerBands ?? []
        return RdEffects.equalizerPresetBands(_eqPreset)
                .some((gain, i) => Math.abs(gain - Number(bands[i] ?? 0)) > 0.05)
    }
    // spatial audio: the room spatializer or the headphone virtualization filter; the mode
    // shown is the filter that is on, else the one last chosen here
    readonly property var _spatialModes: ["headphone_channel_mixer", "spatializer"]
                                         .filter((m) => SettingsCatalog.moduleExists(m))
    property string _preferredSpatialMode: _spatialModes.length > 0 ? _spatialModes[0] : ""
    readonly property string _spatialMode: _filterOn("spatializer") ? "spatializer"
                                         : _filterOn("headphone_channel_mixer") ? "headphone_channel_mixer"
                                         : _preferredSpatialMode
    readonly property bool _spatial: _filterOn("spatializer") || _filterOn("headphone_channel_mixer")

    // S2-06 Night mode: VLC's compressor with a fixed preset (Sticky tunes it by listening,
    // Decision 38). It reads ON only while the compressor runs with exactly these values, so
    // editing the Compressor (here or in the sidebar) turns it off
    readonly property var _nightPreset: ({
        "compressor-rms-peak": 0.2,
        "compressor-attack": 5,
        "compressor-release": 200,
        "compressor-threshold": -24,
        "compressor-ratio": 6,
        "compressor-knee": 4,
        "compressor-makeup-gain": 9
    })
    readonly property bool _nightMode: {
        if (!_filterOn("compressor"))
            return false
        for (const name in _nightPreset) {
            const target = _nightPreset[name]
            const v = Number(RdEffects.values[RdEffects.audioKey(name)])
            // VLC keeps floats in single precision
            if (!(Math.abs(v - target) <= 0.001 * Math.max(1, Math.abs(target))))
                return false
        }
        return true
    }

    // on: keeps the compressor's state and values ("qt-night-mode-restore") and applies the
    // preset; off: puts them back (VLC's defaults and off when nothing was kept)
    function _setNightMode(on) {
        if (on) {
            const saved = { on: _filterOn("compressor"), values: {} }
            for (const name in _nightPreset)
                saved.values[name] = Number(RdEffects.values[RdEffects.audioKey(name)])
            RdEffects.setOption("qt-night-mode-restore", JSON.stringify(saved))
            for (const name in _nightPreset)
                RdEffects.setAudioValue(name, _nightPreset[name])
            if (!_filterOn("compressor"))
                RdEffects.setAudioFilterEnabled("compressor", true)
            return
        }
        let saved = null
        try {
            saved = JSON.parse(String(_option("qt-night-mode-restore") ?? ""))
        } catch (e) {
            saved = null
        }
        for (const name in _nightPreset) {
            let v = saved && saved.values ? Number(saved.values[name]) : NaN
            if (isNaN(v))
                v = Number(RdEffects.optionRange(name).default)
            if (!isNaN(v))
                RdEffects.setAudioValue(name, v)
        }
        const wasOn = !!saved && saved.on === true
        if (_filterOn("compressor") !== wasOn)
            RdEffects.setAudioFilterEnabled("compressor", wasOn)
        RdEffects.setOption("qt-night-mode-restore", "")
    }

    function _setSpatial(enabled, mode) {
        for (const m of _spatialModes) {
            const on = enabled && m === mode
            if (_filterOn(m) !== on)
                RdEffects.setAudioFilterEnabled(m, on)
        }
    }

    SettingsSection {
        title: qsTr("Output")

        SettingsOption {
            option: "audio"
            text: qsTr("Enable audio")
        }

        // VLC's outputs list their devices only while they run: the devices of the player's
        // output, as in the tracks popup (Player.audioDevices), the system default first as
        // "System default" (Figma). The dropdown shows the device in use; a choice switches the
        // output at once and is kept for the next start
        SettingsRow {
            id: deviceRow

            // bumped when the output's device list changes
            property int _revision: 0

            // the id of the output's default device: "" (mmdevice), "wavemapper" (waveout)
            function _isDefault(id) {
                return id === "" || (root._aout === "waveout" && id === "wavemapper")
            }

            readonly property string current: deviceRow._isDefault(Player.audioDevices.current) ? "" : Player.audioDevices.current

            readonly property var devices: {
                void _revision
                const list = Player.audioDevices.devices().filter((d) => !deviceRow._isDefault(d.value))
                list.unshift({ value: "", text: qsTr("System default") })
                // a device in use that the output does not list (any more) keeps its id
                if (!list.some((d) => d.value === deviceRow.current))
                    list.push({ value: deviceRow.current, text: deviceRow.current })
                return list
            }

            text: qsTr("Output device")
            description: RdEffects.optionDescription(root._deviceOption)
            keywords: "audio-device speakers headphones " + root._deviceOption
            shown: SettingsCatalog.exists(root._deviceOption)

            Connections {
                target: Player.audioDevices

                function onModelReset() { ++deviceRow._revision }
                function onRowsInserted() { ++deviceRow._revision }
                function onRowsRemoved() { ++deviceRow._revision }
            }

            Widgets.RdDropdown {
                id: deviceDropdown

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: deviceRow.devices.map((d) => d.text)
                currentIndex: Math.max(0, deviceRow.devices.findIndex((d) => d.value === deviceRow.current))
                Accessible.name: qsTr("Output device")
                // kept for the next start only when the output took it (else the dropdown goes
                // back to the device in use: AudioDeviceModel signals `current`)
                onActivated: (index) => {
                    const id = deviceRow.devices[index].value
                    if (Player.audioDevices.select(id))
                        RdEffects.setOption(root._deviceOption, id)
                }

                // devices plugged in since the list was read
                Connections {
                    target: deviceDropdown.popup

                    function onAboutToShow() { Player.audioDevices.refresh() }
                }
            }
        }

        SettingsOption {
            option: "mix-mode"
            text: qsTr("Speaker setup")
            choices: RdEffects.optionChoices("mix-mode").map((c, i) => i === 0 ? { value: c.value, text: qsTr("Automatic") } : c)
        }
    }

    SettingsSection {
        title: qsTr("Volume")

        SettingsOption {
            option: "qt-max-volume"
            text: qsTr("Maximum volume")
            kind: "slider"
            // Figma's range (100 / 200 / 300 % evenly spaced); VLC also allows 60 to 99 %, which
            // only the command line or All Other Options set: such a value shows at the left end
            from: 100
            to: 300
            step: 25
            labels: [qsTr("100%"), qsTr("200%"), qsTr("300%")]
        }

        // Figma "Values" (stacked): remember the last volume, or always start at a level
        SettingsRow {
            text: qsTr("Startup volume")
            rowPadding: VLCStyle.dp(10)
            description: RdEffects.optionDescription("volume-save")
            keywords: "volume-save " + root._volumeOption

            Rectangle {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(78)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2

                Column {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(2)
                    spacing: VLCStyle.dp(2)

                    VolumeChoice {
                        width: parent.width
                        selected: root._rememberVolume
                        text: qsTr("Remember last volume")
                        onClicked: RdEffects.setOption("volume-save", true)
                    }

                    VolumeChoice {
                        id: fixedChoice

                        width: parent.width
                        selected: !root._rememberVolume
                        text: qsTr("Always starts at:")
                        onClicked: RdEffects.setOption("volume-save", false)

                        Widgets.RdValueBox {
                            anchors.right: parent.right
                            anchors.rightMargin: VLCStyle.dp(2)
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: VLCStyle.dp(182)
                            implicitHeight: VLCStyle.dp(32)
                            framed: false
                            backgroundRadius: VLCStyle.rd_radius_xsmall
                            textColor: Qt.alpha(VLCStyle.palette.rdFgA2, fixedChoice.selected ? 1.0 : 0.4)
                            visible: SettingsCatalog.exists(root._volumeOption)
                            text: Math.round(Number(root._option(root._volumeOption) ?? 1) * 100) + "%"
                            Accessible.name: qsTr("Startup volume")
                            onEdited: (text) => {
                                const percent = parseFloat(text)
                                if (isNaN(percent))
                                    return
                                RdEffects.setOption("volume-save", false)
                                // the output's own limit (mmdevice 125 %, waveout 200 %)
                                const max = RdEffects.optionRange(root._volumeOption).max
                                            ?? (root._volumeOption === "waveout-volume" ? 2 : 1.25)
                                RdEffects.setOption(root._volumeOption, Math.max(0, Math.min(max, percent / 100)))
                            }
                        }
                    }
                }
            }
        }

        // VLC's step is on its 0-256 scale (256 = 100%)
        SettingsOption {
            option: "volume-step"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Volume step")
            valueScale: 2.56
            unit: "%"
        }
    }

    SettingsSection {
        title: qsTr("Loudness")

        FilterToggle {
            module: "normvol"
            description: qsTr("Keeps the loudness even, so quiet and loud parts end up closer to the same level.")
            text: qsTr("Normalize loudness")
        }

        SettingsOption {
            option: "norm-max-level"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Target level")
            decimals: 1
            available: root._filterOn("normvol")
        }

        // S2-06 (video 18:05): Figma toggle row 32 high, between Target level and Replay gain
        SettingsRow {
            text: qsTr("Night mode")
            description: qsTr("Makes loud scenes quieter and quiet dialogue louder, for listening late at night. It runs the compressor with its own settings; turning it off puts the compressor back as it was.")
            keywords: "night compressor dynamic range loud quiet dialogue"
            shown: SettingsCatalog.moduleExists("compressor")

            Widgets.RdToggle {
                checked: root._nightMode
                Accessible.name: qsTr("Night mode")
                onToggled: root._setNightMode(checked)
            }
        }

        SettingsOption {
            option: "audio-replay-gain-mode"
            text: qsTr("Replay gain")
            choices: [
                { value: "none", text: qsTr("Off") },
                { value: "track", text: qsTr("Track") },
                { value: "album", text: qsTr("Album") }
            ]
        }

        SettingsOption {
            option: "audio-replay-gain-preamp"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Replay gain preamp")
            decimals: 1
            unit: qsTr("dB")
            available: String(root._option("audio-replay-gain-mode")) !== "none"
        }
    }

    SettingsSection {
        title: qsTr("Effects")

        SettingsRow {
            text: qsTr("Equalizer")
            description: qsTr("Raises or lowers ten bands of frequencies, from the deep bass to the high treble.")
            keywords: "equalizer eq"
            shown: root._equalizer

            Widgets.RdToggle {
                checked: root._eqPreset >= 0
                Accessible.name: qsTr("Equalizer")
                onToggled: {
                    if (checked)
                        RdEffects.setAudioFilterEnabled("equalizer", true)
                    else
                        RdEffects.setEqualizerPreset(-1)
                }
            }
        }

        SettingsRow {
            text: qsTr("Equalizer preset")
            description: qsTr("Ready-made settings of the equalizer for a kind of music or place.")
            keywords: "equalizer preset eq"
            shown: root._equalizer
            minimumLineHeight: VLCStyle.dp(38)

            Widgets.RdDropdown {
                readonly property var presets: RdEffects.equalizerPresetNames()

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("None")].concat(presets).concat(root._eqCustom ? [qsTr("Custom")] : [])
                currentIndex: root._eqCustom ? presets.length + 1 : root._eqPreset + 1
                Accessible.name: qsTr("Equalizer preset")
                onActivated: (index) => {
                    // "Custom" is the bands as they are
                    if (index <= presets.length)
                        RdEffects.setEqualizerPreset(index - 1)
                }
            }
        }

        SettingsEqualizer {
            visible: root._equalizer
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
        }

        SettingsRow {
            text: qsTr("Two-pass")
            description: RdEffects.optionDescription("equalizer-2pass")
            keywords: "equalizer-2pass"
            shown: root._equalizer

            Widgets.RdToggle {
                checked: RdEffects.values[RdEffects.audioFlagKey("equalizer-2pass")] === true
                Accessible.name: qsTr("Two-pass")
                onToggled: RdEffects.setAudioFlag("equalizer-2pass", checked)
            }
        }

        SettingsRow {
            text: qsTr("Spatial audio")
            description: qsTr("Makes the sound seem to come from around you: in a room, or through headphones.")
            keywords: "spatializer headphone"
            shown: root._spatialModes.length > 0

            Widgets.RdToggle {
                checked: root._spatial
                Accessible.name: qsTr("Spatial audio")
                onToggled: root._setSpatial(checked, root._spatialMode)
            }
        }

        SettingsRow {
            text: qsTr("Spatial audio mode")
            description: qsTr("Headphone virtualization places the speakers around you in headphones; Room adds the echo of a room.")
            keywords: "spatializer headphone"
            // a choice only when this build has both filters
            shown: root._spatialModes.length > 1

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Headphone virtualization"), qsTr("Room")]
                currentIndex: root._spatialModes.indexOf(root._spatialMode)
                Accessible.name: qsTr("Spatial audio mode")
                onActivated: (index) => {
                    root._preferredSpatialMode = root._spatialModes[index]
                    if (root._spatial)
                        root._setSpatial(true, root._preferredSpatialMode)
                }
            }
        }

        FilterToggle {
            module: "stereo_widen"
            description: qsTr("Makes the stereo sound wider, as if the speakers were further apart.")
            text: qsTr("Stereo widening")
        }

        FilterToggle {
            module: "compressor"
            description: qsTr("Narrows the gap between the quiet and the loud parts, so dialogue stays audible without loud scenes being too loud.")
            text: qsTr("Compressor")
        }

        // the pitch shifter is on while the pitch is not 0 (as in the settings sidebar)
        SettingsRow {
            text: qsTr("Pitch shift")
            description: RdEffects.optionDescription("pitch-shift")
            keywords: "pitch-shift scaletempo_pitch semitones"
            shown: SettingsCatalog.moduleExists("scaletempo_pitch")

            Widgets.RdValueBox {
                readonly property real pitch: root._filterOn("scaletempo_pitch")
                                              ? Number(RdEffects.values[RdEffects.audioKey("pitch-shift")] ?? 0) : 0

                // Figma "Frame 265" 320x32
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(32)
                text: pitch.toFixed(2)
                Accessible.name: qsTr("Pitch shift")
                onEdited: (text) => {
                    const v = parseFloat(text.replace(",", "."))
                    if (isNaN(v))
                        return
                    const pitch = Math.max(-12, Math.min(12, v))
                    RdEffects.setAudioValue("pitch-shift", pitch)
                    if ((pitch !== 0) !== RdEffects.audioFilterEnabled("scaletempo_pitch"))
                        RdEffects.setAudioFilterEnabled("scaletempo_pitch", pitch !== 0)
                }
            }
        }

        FilterToggle {
            module: "chorus_flanger"
            description: qsTr("Adds a chorus or flanger effect: copies of the sound, slightly delayed.")
            text: qsTr("Chorus/flanger")
        }

        FilterToggle {
            module: "karaoke"
            description: qsTr("Removes the voice from songs where it is mixed in the center.")
            text: qsTr("Karaoke")
        }
    }

    SettingsSection {
        title: qsTr("Tracks")

        SettingsLanguageOption {
            option: "audio-language"
            text: qsTr("Preferred audio language")
        }

        SettingsOption {
            option: "audio-desync"
            text: qsTr("Audio delay")
            valueScale: 1000
            decimals: 2
            unit: qsTr("s")
        }
    }

    SettingsSection {
        title: qsTr("Visualization")

        SettingsOption {
            option: "audio-visual"
            text: qsTr("Visualizer")
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "mmdevice-passthrough"
                text: qsTr("Pass compressed audio to the receiver")
            }

            SettingsOption {
                option: "force-dolby-surround"
                text: qsTr("Detect Dolby Surround")
                choices: [
                    { value: 0, text: qsTr("Automatic") },
                    { value: 1, text: qsTr("On") },
                    { value: 2, text: qsTr("Off") }
                ]
            }

            SettingsOption {
                option: "soxr-resampler-quality"
                text: qsTr("Resampling quality")
                choices: [
                    { value: 0, text: qsTr("Fastest") },
                    { value: 1, text: qsTr("Low") },
                    { value: 2, text: qsTr("Balanced") },
                    { value: 3, text: qsTr("High") },
                    { value: 4, text: qsTr("Best") }
                ]
            }

            SettingsOption {
                option: "role"
                text: qsTr("Media role")
            }
        },

        SettingsMoreOptions {
            category: "audio"
        }
    ]

    // an audio filter of the settings sidebar turned on or off
    component FilterToggle: SettingsRow {
        id: filterRow

        property string module

        keywords: module
        shown: SettingsCatalog.moduleExists(module)

        Widgets.RdToggle {
            checked: RdEffects.values[RdEffects.audioFilterKey(filterRow.module)] === true
            Accessible.name: filterRow.text
            onToggled: RdEffects.setAudioFilterEnabled(filterRow.module, checked)
        }
    }

    // a row of the startup volume choice (Figma "Values": 316x36, padding 12; BG/Accent
    // Bright + Accent/Main when chosen, BG/A4 + FG/A3 otherwise)
    component VolumeChoice: T.AbstractButton {
        id: choice

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        property bool selected: false

        implicitHeight: VLCStyle.dp(36)
        leftPadding: VLCStyle.dp(12)

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        Accessible.role: Accessible.RadioButton
        Accessible.checked: selected

        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: choice.selected ? VLCStyle.palette.rdBgAccentBright
                                   : (choice.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA4)
            border.width: choice.visualFocus ? VLCStyle.dp(1) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Text {
            verticalAlignment: Text.AlignVCenter
            text: choice.text
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: choice.selected ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA3
        }
    }
}
