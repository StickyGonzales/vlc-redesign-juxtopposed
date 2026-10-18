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

// redesign: settings sidebar, Subtitles tab (video 7:16-8:41 final version; Figma
// "subtitle settings"). Delay, speed, duration, offset and size apply live; the defaults and
// the text style options are VLC options used from the next file (Decision 29 notice).
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanelPage {
    id: root

    key: "subtitleSettings"

    // values may have changed elsewhere (VLC's effects dialog, hotkeys) while the page was hidden
    onActiveChanged: {
        if (active)
            RdEffects.refresh()
    }
    // a page created while its tab is already selected starts active
    Component.onCompleted: {
        if (active)
            RdEffects.refresh()
    }

    // a binding reading RdEffects.values[key] follows only that value
    readonly property real _durationFactor: RdEffects.values.subtitleDurationFactor

    // the delay VLC's own Synchronization panel accepts (dialogs/extended/extended_panels.cpp,
    // SyncWidget: -600 to 600 s); the player itself takes any delay. The slider shows -10 to 10 s
    // and scrolls on to it (Decision 47)
    readonly property real _delayLimit: 600

    // the delay is cheap to change: it follows a drag ten times a second
    readonly property RdSliderCommit _delay: RdSliderCommit {
        pressed: delaySlider.pressed
        current: Player.subtitleDelayMS / 1000
        dragInterval: 100
        keyDelay: 150
        onCommit: (v) => Player.subtitleDelayMS = Math.round(v * 1000)
    }

    // every speed change makes VLC re-read the subtitle file at the new rate and flush what was
    // decoded at the old one: applied once, when the slider is released
    readonly property RdSliderCommit _speed: RdSliderCommit {
        pressed: speedSlider.pressed
        current: Player.subtitleFPS
        tolerance: 0.001
        keyDelay: 400
        onCommit: (v) => Player.subtitleFPS = v
    }

    // the factor changes live on the running "subsdelay" filter; the filter is switched off only
    // when the slider is released at 0 (no filter restart while dragging)
    readonly property RdSliderCommit _duration: RdSliderCommit {
        pressed: durationSlider.pressed
        current: root._durationFactor
        tolerance: 0.001
        dragInterval: 50
        keyDelay: 150
        onCommit: (v, last) => {
            if (v > 0 || last)
                RdEffects.setSubtitleDurationFactor(v)
        }
    }

    function opt(name) {
        return RdEffects.values[RdEffects.optionKey(name)]
    }

    function colorText(value) {
        return "#" + ("000000" + Number(value).toString(16)).slice(-6).toUpperCase()
    }

    function parseColor(text) {
        const v = parseInt(String(text).replace("#", "").trim(), 16)
        return isNaN(v) ? -1 : (v & 0xFFFFFF)
    }

    function parseNumber(text) {
        return parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
    }

    // a delay on the slider's scale: "-10 s", "0 s", "+10 s", "-13.5 s"
    function secondsText(v) {
        const s = Math.round(v * 10) / 10
        return qsTr("%1 s").arg((s > 0 ? "+" : "") + s)
    }

    Widgets.RdSettingsSection {
        title: qsTr("Defaults")
        showDivider: false
        note: qsTr("Applies from the next file")
        // Figma "Frame 92" (845:1597): 10 px under the rows
        bottomPadding: VLCStyle.dp(10)

        Widgets.RdSettingRow {
            text: qsTr("Subtitle Track")

            Widgets.RdValueBox {
                readonly property int track: root.opt("sub-track")

                text: track < 0 ? qsTr("Auto") : String(track + 1)
                Accessible.name: qsTr("Subtitle Track")
                onEdited: (value) => {
                    const n = parseInt(value)
                    RdEffects.setOption("sub-track", isNaN(n) || n < 1 ? -1 : n - 1)
                }
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Subtitle Language")

            Widgets.RdValueBox {
                readonly property string language: root.opt("sub-language")

                text: language === "" ? qsTr("Auto") : language
                Accessible.name: qsTr("Subtitle Language")
                onEdited: (value) => RdEffects.setOption("sub-language", value === qsTr("Auto") ? "" : value.trim())
            }
        }
    }

    Widgets.RdSettingsSection {
        title: qsTr("Synchronization")

        Widgets.RdParamSlider {
            id: delaySlider

            text: qsTr("Subtitle Track Delay")
            valueBox: true
            valueText: qsTr("%1 s").arg(root._delay.shown.toFixed(3))
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
            value: root._delay.shown
            onMoved: (v) => root._delay.push(v)
            onEdited: (text) => {
                const s = root.parseNumber(text)
                if (!isNaN(s))
                    Player.subtitleDelayMS = Math.round(Math.max(-root._delayLimit, Math.min(root._delayLimit, s)) * 1000)
            }
        }

        // VLC's subtitle speed ("sub-fps", as in VLC's Synchronization tab and the video 7:16):
        // the frame rate the subtitle file was timed for, 1 to 100 fps; 1 fps keeps the file's
        // own timing. It rescales external subtitle files only.
        Widgets.RdParamSlider {
            id: speedSlider

            text: qsTr("Subtitle Speed")
            valueBox: true
            valueText: qsTr("%1 fps").arg(Math.max(1, root._speed.shown).toFixed(3))
            from: 1
            to: 100
            stepSize: 0.2
            showTicks: false
            value: root._speed.shown
            onMoved: (v) => root._speed.push(v)
            onEdited: (text) => {
                const f = root.parseNumber(text)
                if (!isNaN(f))
                    Player.subtitleFPS = Math.max(1, Math.min(100, f))
            }
        }

        Widgets.RdParamSlider {
            id: durationSlider

            text: qsTr("Subtitle Duration Factor")
            valueBox: true
            valueText: root._duration.shown.toFixed(3)
            from: 0
            to: 20
            stepSize: 0.2
            showTicks: false
            value: root._duration.shown
            onMoved: (v) => root._duration.push(v)
            onEdited: (text) => {
                const f = root.parseNumber(text)
                if (!isNaN(f))
                    RdEffects.setSubtitleDurationFactor(Math.max(0, Math.min(20, f)))
            }
        }
    }

    Widgets.RdSettingsSection {
        title: qsTr("Appearance")
        note: qsTr("Font, colors, outline and background apply from the next file")
        // Figma "Frame 91" (800:1126): 10 px under the rows
        bottomPadding: VLCStyle.dp(10)

        Widgets.RdSettingRow {
            text: qsTr("Embedded Sub Format")

            Widgets.RdToggle {
                checked: root.opt("subsdec-formatted")
                Accessible.name: qsTr("Embedded Sub Format")
                onToggled: RdEffects.setOption("subsdec-formatted", checked)
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Subtitle Font")

            Widgets.RdValueBox {
                text: root.opt("freetype-font")
                Accessible.name: qsTr("Subtitle Font")
                onEdited: (value) => RdEffects.setOption("freetype-font", value.trim())
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Text Color")

            Widgets.RdValueBox {
                readonly property string hex: root.colorText(root.opt("freetype-color"))

                text: hex
                showSwatch: true
                swatch: hex
                Accessible.name: qsTr("Text Color")
                onEdited: (value) => {
                    const v = root.parseColor(value)
                    if (v >= 0)
                        RdEffects.setOption("freetype-color", v)
                }
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Outline Color")

            Widgets.RdValueBox {
                readonly property string hex: root.colorText(root.opt("freetype-outline-color"))

                text: hex
                showSwatch: true
                swatch: hex
                Accessible.name: qsTr("Outline Color")
                onEdited: (value) => {
                    const v = root.parseColor(value)
                    if (v >= 0)
                        RdEffects.setOption("freetype-outline-color", v)
                }
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Subtitle Offset")

            Widgets.RdValueBox {
                text: qsTr("%1px").arg(Number(RdEffects.values[RdEffects.videoKey("sub-margin")]) || 0)
                Accessible.name: qsTr("Subtitle Offset")
                onEdited: (value) => {
                    const px = Math.round(root.parseNumber(value))
                    if (!isNaN(px))
                        RdEffects.setVideoValue("sub-margin", px)
                }
            }
        }

        // VLC sizes subtitles relative to the video (sub-text-scale, 100 % = VLC's automatic
        // size); a size in pixels would need a core change (VIDEO_INDEX Decisions (Claude)).
        // VLC accepts 10 to 500 %: the slider scrolls on past 25 / 300 % (Decision 47)
        Widgets.RdParamSlider {
            text: qsTr("Font Size")
            // Figma "Frame 96" (804:1341): padding 10,0,10,0
            Layout.topMargin: VLCStyle.dp(10)
            Layout.bottomMargin: VLCStyle.dp(10)
            valueText: value === 100 ? qsTr("Auto") : qsTr("%1 %").arg(value)
            from: 25
            to: 300
            limitFrom: 10
            limitTo: 500
            stepSize: 25
            // the wheel fine-tunes in 5 % steps (Decision 54)
            wheelStep: 5
            value: RdEffects.values.subtitleTextScale
            onMoved: (v) => RdEffects.setSubtitleTextScale(v)
        }

        Widgets.RdParamSlider {
            // VLC's outline thickness values: 0, 2, 4, 6
            readonly property var names: [qsTr("None"), qsTr("Thin"), qsTr("Normal"), qsTr("Thick")]

            text: qsTr("Outline Thickness")
            // Figma "Frame 96" (804:1341): padding 10,0,10,0
            Layout.topMargin: VLCStyle.dp(10)
            Layout.bottomMargin: VLCStyle.dp(10)
            valueText: names[Math.round(value)] ?? ""
            from: 0
            to: 3
            stepSize: 1
            value: Math.round(root.opt("freetype-outline-thickness") / 2)
            onMoved: (v) => RdEffects.setOption("freetype-outline-thickness", Math.round(v) * 2)
        }

        Widgets.RdParamSlider {
            text: qsTr("Background Opacity")
            // Figma "Frame 96" (804:1341): padding 10,0,10,0
            Layout.topMargin: VLCStyle.dp(10)
            Layout.bottomMargin: VLCStyle.dp(10)
            valueText: qsTr("%1 %").arg(Math.round(value / 255 * 100))
            from: 0
            to: 255
            stepSize: 255 / 20
            // Figma 848:1693: 9 inner ticks (tenths)
            tickIntervals: 10
            value: root.opt("freetype-background-opacity")
            onMoved: (v) => RdEffects.setOption("freetype-background-opacity", Math.round(v))
        }
    }
}
