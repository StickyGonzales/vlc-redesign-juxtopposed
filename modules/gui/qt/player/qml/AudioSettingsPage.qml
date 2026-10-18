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

// redesign: settings sidebar, Audio tab (video 8:41-8:56 final version; Figma "audio
// settings", "Audio - Equalizer", "Audio - Compressor Settings", "Audio - Spatializer Settings",
// "Audio - Stereo Widener"). Delay, stereo mode and the filters apply live (VLC's audio effects);
// the default track and language are used from the next file. Parameter names, ranges and units
// are VLC's (dialogs/extended/extended_panels.cpp).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanelPage {
    id: root

    key: "audioSettings"

    // values may have changed elsewhere (VLC's effects dialog, hotkeys) while the page was hidden
    onActiveChanged: {
        if (active)
            RdEffects.refresh()
    }
    // a page created while its tab is already selected starts active
    Component.onCompleted: {
        if (active)
            RdEffects.refresh()
        _countModes()
    }

    // VLC offers mix modes (Original, Stereo, Binaural, 5.1...) for a multichannel track and
    // stereo modes (Mono, Left, Right...) for a stereo one; a multichannel track mixed down to
    // stereo has both, and its mix modes must stay reachable (back to Original). The dropdown
    // lists the mix modes when there are some, else the stereo modes, like VLC's Audio menu
    property int _mixModeCount: 0

    function _countModes() {
        _mixModeCount = Player.audioMixMode.rowCount()
    }

    Connections {
        target: Player.audioMixMode

        function onModelReset() { root._countModes() }
        function onRowsInserted() { root._countModes() }
        function onRowsRemoved() { root._countModes() }
    }

    // a binding reading RdEffects.values[key] follows only that value
    function opt(name) {
        return RdEffects.values[RdEffects.optionKey(name)]
    }

    // editing a band or the preamp while the preset is "None" turns the equalizer on
    function ensureEqualizer() {
        if (root._eqPreset < 0)
            RdEffects.setAudioFilterEnabled("equalizer", true)
    }

    function parseNumber(text) {
        return parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
    }

    // the delay VLC's own Synchronization panel accepts (dialogs/extended/extended_panels.cpp,
    // SyncWidget: -600 to 600 s); the player itself takes any delay. The slider shows -10 to 10 s
    // and scrolls on to it (Decision 47)
    readonly property real _delayLimit: 600

    // a delay on the slider's scale: "-10 s", "0 s", "+10 s", "-13.5 s"
    function secondsText(v) {
        const s = Math.round(v * 10) / 10
        return qsTr("%1 s").arg((s > 0 ? "+" : "") + s)
    }

    readonly property int _eqPreset: RdEffects.values.equalizerPreset
    readonly property var _eqBands: RdEffects.values.equalizerBands
    readonly property real _eqPreamp: RdEffects.values[RdEffects.audioKey("equalizer-preamp")]

    Widgets.RdSettingsSection {
        title: qsTr("Defaults")
        showDivider: false
        note: qsTr("Track and language apply from the next file")

        Widgets.RdSettingRow {
            text: qsTr("Audio Track")

            Widgets.RdValueBox {
                readonly property int track: root.opt("audio-track")

                text: track < 0 ? qsTr("Auto") : String(track + 1)
                Accessible.name: qsTr("Audio Track")
                onEdited: (value) => {
                    const n = parseInt(value)
                    RdEffects.setOption("audio-track", isNaN(n) || n < 1 ? -1 : n - 1)
                }
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Audio Language")

            Widgets.RdValueBox {
                readonly property string language: root.opt("audio-language")

                text: language === "" ? qsTr("Auto") : language
                Accessible.name: qsTr("Audio Language")
                onEdited: (value) => RdEffects.setOption("audio-language", value === qsTr("Auto") ? "" : value.trim())
            }
        }

        // Figma "Frame 102" (1052:2920): 10 px under the rows above, a 52 px label row with the
        // "Test" button (2250:9842), 10 px, then the dropdown
        Widgets.RdSettingRow {
            text: qsTr("Stereo Mode")
            Layout.topMargin: VLCStyle.dp(5)
            rowHeight: VLCStyle.dp(52)
            spacing: VLCStyle.dp(10)

            TestButton {
                text: qsTr("Test")
                Accessible.description: qsTr("Plays a tone on the left speaker, then on the right one")
                onClicked: Player.audioDevices.playStereoTest()
            }

            below: Widgets.RdChoiceDropdown {
                width: parent.width
                choices: root._mixModeCount > 0 ? Player.audioMixMode : Player.audioStereoMode
                // nothing playing: VLC has no modes to offer, the sound stays as it is
                placeholderText: qsTr("Original")
                Accessible.name: qsTr("Stereo Mode")
            }
        }
    }

    Widgets.RdSettingsSection {
        title: qsTr("Synchronization")

        // each audio delay change shifts the audio against the video clock (VLC inserts
        // silence or holds the video back): applied once, when the slider is released
        Widgets.RdParamSlider {
            id: audioDelaySlider

            readonly property RdSliderCommit delay: RdSliderCommit {
                pressed: audioDelaySlider.pressed
                current: Player.audioDelayMS / 1000
                keyDelay: 300
                onCommit: (v) => Player.audioDelayMS = Math.round(v * 1000)
            }

            text: qsTr("Audio Track Delay")
            valueBox: true
            valueText: qsTr("%1 s").arg(delay.shown.toFixed(3))
            from: -10
            to: 10
            limitFrom: -root._delayLimit
            limitTo: root._delayLimit
            stepSize: 0.05
            scrollSpeed: 5
            bipolar: true
            showTicks: false
            labelStep: 10
            labelText: (v) => root.secondsText(v)
            value: delay.shown
            onMoved: (v) => delay.push(v)
            onEdited: (text) => {
                const s = root.parseNumber(text)
                if (!isNaN(s))
                    Player.audioDelayMS = Math.round(Math.max(-root._delayLimit, Math.min(root._delayLimit, s)) * 1000)
            }
        }
    }

    // Figma "Frame 70" (536:1109): 10 px between the label, preset list, card and 2 Pass
    Widgets.RdSettingsSection {
        title: qsTr("Filters")
        rowSpacing: VLCStyle.dp(10)

        // "Equalizer" sub-label, then the preset list (None = equalizer off)
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(37)
            leftPadding: VLCStyle.dp(4)
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Equalizer")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Widgets.RdDropdown {
            id: eqPresets

            Layout.fillWidth: true
            // Figma "EQ presets" (2372:8487) wording ("Full base" typos fixed, Decision 17)
            displayNames: ({ [qsTr("Full bass and treble")]: qsTr("Full bass & treble"),
                             [qsTr("Large Hall")]: qsTr("Large hall") })
            model: [qsTr("None")].concat(RdEffects.equalizerPresetNames().map((name) => eqPresets.displayName(name)))
            currentIndex: root._eqPreset + 1
            Accessible.name: qsTr("Equalizer")
            onActivated: (index) => RdEffects.setEqualizerPreset(index - 1)

            delegate: Widgets.RdOptionRow {
                required property int index
                required property var modelData

                width: ListView.view ? ListView.view.width : implicitWidth
                height: VLCStyle.dp(44)
                radius: VLCStyle.rd_radius_small
                text: modelData
                selected: eqPresets.currentIndex === index
                highlighted: eqPresets.highlightedIndex === index
                leading: index > 0 ? curve : null

                readonly property Component curve: Component {
                    Widgets.RdEqCurve {
                        bands: RdEffects.equalizerPresetBands(index - 1)
                    }
                }
            }
        }

        // Figma "Audio - Equalizer" expanded (6114:13615): 90 px per band, a 56 px name row with
        // the value box (Inter 12) and the slider right under it, 10 px padding under each
        Widgets.RdExpander {
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: VLCStyle.dp(10)

                Widgets.RdParamSlider {
                    text: qsTr("Preamp")
                    valueBox: true
                    valueFontSize: VLCStyle.rd_fontSize_toggle
                    textInset: 0
                    spacing: 0
                    valueText: root._eqPreamp.toFixed(1) + " " + qsTr("dB")
                    from: -20
                    to: 20
                    stepSize: 0.1
                    showTicks: false
                    value: root._eqPreamp
                    onMoved: (v) => {
                        RdEffects.setAudioValue("equalizer-preamp", v)
                        root.ensureEqualizer()
                    }
                    onEdited: (text) => {
                        const v = root.parseNumber(text)
                        if (isNaN(v))
                            return
                        RdEffects.setAudioValue("equalizer-preamp", Math.max(-20, Math.min(20, v)))
                        root.ensureEqualizer()
                    }
                }

                Repeater {
                    model: RdEffects.equalizerBandNames()

                    delegate: Widgets.RdParamSlider {
                        required property int index
                        required property var modelData

                        readonly property real gain: Number(root._eqBands[index] ?? 0)

                        text: modelData
                        valueBox: true
                        valueFontSize: VLCStyle.rd_fontSize_toggle
                        textInset: 0
                        spacing: 0
                        valueText: gain.toFixed(1) + " " + qsTr("dB")
                        from: -20
                        to: 20
                        stepSize: 0.1
                        showTicks: false
                        value: gain
                        onMoved: (v) => {
                            RdEffects.setEqualizerBand(index, v)
                            root.ensureEqualizer()
                        }
                        onEdited: (text) => {
                            const v = root.parseNumber(text)
                            if (isNaN(v))
                                return
                            RdEffects.setEqualizerBand(index, Math.max(-20, Math.min(20, v)))
                            root.ensureEqualizer()
                        }
                    }
                }
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("2 Pass")

            Widgets.RdToggle {
                checked: RdEffects.values[RdEffects.audioFlagKey("equalizer-2pass")]
                Accessible.name: qsTr("2 Pass")
                onToggled: RdEffects.setAudioFlag("equalizer-2pass", checked)
            }
        }
    }

    FilterSection {
        name: qsTr("Compressor")
        module: "compressor"
        params: [
            { name: "compressor-rms-peak", label: qsTr("RMS / Peak"), unit: "", from: 0, to: 1, step: 0.001, scale: 1 },
            { name: "compressor-attack", label: qsTr("Attack"), unit: qsTr("ms"), from: 1.5, to: 400, step: 0.1, scale: 1 },
            { name: "compressor-release", label: qsTr("Release"), unit: qsTr("ms"), from: 2, to: 800, step: 0.1, scale: 1 },
            { name: "compressor-threshold", label: qsTr("Threshold"), unit: qsTr("dB"), from: -30, to: 0, step: 0.01, scale: 1 },
            { name: "compressor-ratio", label: qsTr("Ratio"), unit: ": 1", from: 1, to: 20, step: 0.01, scale: 1 },
            { name: "compressor-knee", label: qsTr("Knee Radius"), unit: qsTr("dB"), from: 1, to: 10, step: 0.01, scale: 1 },
            { name: "compressor-makeup-gain", label: qsTr("Makeup Gain"), unit: qsTr("dB"), from: 0, to: 24, step: 0.01, scale: 1 }
        ]
    }

    FilterSection {
        name: qsTr("Spatializer")
        module: "spatializer"
        params: [
            { name: "spatializer-roomsize", label: qsTr("Size"), unit: "", from: 0, to: 1.1, step: 0.1, scale: 10 },
            { name: "spatializer-width", label: qsTr("Width"), unit: "", from: 0, to: 1, step: 0.1, scale: 10 },
            { name: "spatializer-wet", label: qsTr("Wet"), unit: "", from: 0, to: 1, step: 0.1, scale: 10 },
            { name: "spatializer-dry", label: qsTr("Dry"), unit: "", from: 0, to: 1, step: 0.1, scale: 10 },
            { name: "spatializer-damp", label: qsTr("Damp"), unit: "", from: 0, to: 1, step: 0.1, scale: 10 }
        ]
    }

    FilterSection {
        name: qsTr("Stereo Widener")
        module: "stereo_widen"
        params: [
            { name: "stereowiden-delay", label: qsTr("Delay Time"), unit: qsTr("ms"), from: 1, to: 100, step: 1, scale: 1 },
            { name: "stereowiden-feedback", label: qsTr("Feedback Gain"), unit: "%", from: 0, to: 0.9, step: 0.1, scale: 1 },
            { name: "stereowiden-crossfeed", label: qsTr("Crossfeed"), unit: "%", from: 0, to: 0.8, step: 0.1, scale: 1 },
            { name: "stereowiden-dry-mix", label: qsTr("Dry Mix"), unit: "%", from: 0, to: 1, step: 0.1, scale: 1 }
        ]
    }

    // pitch shifter ("scaletempo_pitch"): on while the pitch is not 0
    Widgets.RdSettingsSection {
        id: pitchSection

        readonly property real pitch: RdEffects.values[RdEffects.audioFilterKey("scaletempo_pitch")]
                                      ? RdEffects.values[RdEffects.audioKey("pitch-shift")] : 0

        // the shift changes live on the running filter; switching the filter on or off restarts
        // the audio filters, so it is switched on once and off only when released at 0
        Widgets.RdParamSlider {
            id: pitchSlider

            readonly property RdSliderCommit pitchCommit: RdSliderCommit {
                pressed: pitchSlider.pressed
                current: pitchSection.pitch
                dragInterval: 0
                keyDelay: 150
                tolerance: 0.01
                onCommit: (v, last) => {
                    const enabled = RdEffects.audioFilterEnabled("scaletempo_pitch")
                    if (v !== 0 || enabled)
                        RdEffects.setAudioValue("pitch-shift", v)
                    if (v !== 0 && !enabled)
                        RdEffects.setAudioFilterEnabled("scaletempo_pitch", true)
                    else if (v === 0 && enabled && last)
                        RdEffects.setAudioFilterEnabled("scaletempo_pitch", false)
                }
            }

            text: qsTr("Adjust Pitch")
            valueText: pitchCommit.shown.toFixed(1) + " " + qsTr("semitones")
            from: -12
            to: 12
            stepSize: 0.25
            bipolar: true
            // Figma 612:1416: one tick at 0
            showTicks: true
            tickIntervals: 2
            value: pitchCommit.shown
            onMoved: (v) => pitchCommit.push(v)
        }
    }

    // one audio filter (Figma "Frame 103" 2375:8984): no section header, a 37 px row with the
    // name and the on/off toggle, 10 px, then its parameters in an "Expand Settings" card
    // (76 px per parameter: 37 px name row, 5, slider, 10)
    component FilterSection: Widgets.RdSettingsSection {
        id: filter

        property string name
        property string module
        property var params: []

        readonly property bool filterEnabled: RdEffects.values[RdEffects.audioFilterKey(module)]

        rowSpacing: VLCStyle.dp(10)

        Widgets.RdSettingRow {
            text: filter.name
            rowHeight: VLCStyle.dp(37)

            Widgets.RdToggle {
                checked: filter.filterEnabled
                Accessible.name: filter.name
                onToggled: RdEffects.setAudioFilterEnabled(filter.module, checked)
            }
        }

        Widgets.RdExpander {
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: VLCStyle.dp(10)

                Repeater {
                    model: filter.params

                    delegate: Widgets.RdParamSlider {
                        required property var modelData

                        readonly property real current: RdEffects.values[RdEffects.audioKey(modelData.name)]

                        textInset: 0
                        text: modelData.label
                        valueText: (current * modelData.scale).toFixed(1) + (modelData.unit !== "" ? " " + modelData.unit : "")
                        from: modelData.from
                        to: modelData.to
                        stepSize: modelData.step
                        showTicks: false
                        value: current
                        onMoved: (v) => RdEffects.setAudioValue(modelData.name, v)
                    }
                }
            }
        }
    }

    // Figma "Button" (2250:9842): 68x32, padding 4,16, radius 4, BG/Accent Dark, label Inter 14
    // Accent/DIm; hover and press: BG/Accent Bright and Accent/Main (the video's 8:41 look)
    component TestButton: T.AbstractButton {
        id: testButton

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        // Figma: fixed 68 wide
        implicitWidth: Math.max(VLCStyle.dp(68), implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: VLCStyle.dp(32)
        leftPadding: VLCStyle.dp(16)
        rightPadding: VLCStyle.dp(16)

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.role: Accessible.Button
        Accessible.name: text

        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: (testButton.hovered || testButton.down) ? VLCStyle.palette.rdBgAccentBright
                                                           : VLCStyle.palette.rdBgAccentDark
            border.width: testButton.visualFocus ? VLCStyle.dp(1) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: testButton.text
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: (testButton.hovered || testButton.down) ? VLCStyle.palette.rdAccentMain
                                                           : VLCStyle.palette.rdAccentDim
        }
    }
}
