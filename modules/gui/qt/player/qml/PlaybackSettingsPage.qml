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

// redesign: settings sidebar, Playback tab (video 9:06-9:19 final version; Figma "playback"
// 5187:24308). Final order (Decision 13: the video's rows plus Figma's Show Statistics):
// Show Subtitle Timeline on Seekbar, Show Waveform on Seekbar, Show Metadata, Show Statistics,
// Sleep Timer, Audio Visualizer, Speed. The subtitle timeline and waveform toggles come with
// their seek bar modes (P3-16, P6-06); Reverse is postponed (Decision 29) and has no row. The
// Cone extra "Autoplay this show" (Decision 71) sits under Sleep Timer while a show plays.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanelPage {
    id: root

    key: "playback"

    function rateText(rate) {
        return qsTr("%1x").arg(Math.round(rate * 100) / 100)
    }

    // the speeds VLC plays at (include/vlc_input.h: INPUT_RATE_MIN 1/32, INPUT_RATE_MAX 31.25):
    // the slider shows 0.25 to 2 and scrolls on to them (Decision 47)
    readonly property real _rateMin: 0.03125
    readonly property real _rateMax: 31.25

    // the sleep timer's time left ("12:34"), from the timer's deadline and `now`
    function timeLeftText(deadline, now) {
        const seconds = Math.max(0, Math.ceil((deadline - now) / 1000))
        const minutes = Math.floor(seconds / 60)
        return qsTr("%1:%2").arg(minutes).arg(String(seconds % 60).padStart(2, "0"))
    }

    // the clock of the time left: it runs only while the countdown shows on screen
    property double _now: Date.now()

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: RdSleepTimer.counting && root.active && RdPanels.settingsOpen
        onTriggered: root._now = Date.now()
    }

    Widgets.RdSettingsSection {
        showDivider: false
        // Figma "Frame 78" stacks the rows without spacing; each row keeps its own padding
        rowSpacing: 0

        // Figma "Frame 115" / "Frame 116": 52 px toggle rows (padding 10, 68x32 toggle). The
        // subtitle timeline row is Figma's first row (P4-35), the qt-seek-subtitle-timeline
        // option the thick seek bar reads (P3-16); it shows for subtitles from a text file
        Widgets.RdSettingRow {
            text: qsTr("Show Subtitle Timeline on Seekbar")
            rowHeight: VLCStyle.dp(52)

            Widgets.RdToggle {
                checked: RdEffects.values[RdEffects.optionKey("qt-seek-subtitle-timeline")] === true
                Accessible.name: qsTr("Show Subtitle Timeline on Seekbar")
                onToggled: RdEffects.setOption("qt-seek-subtitle-timeline", checked)
            }
        }

        // the waveform row is the video's (Decision 13; no Figma frame), styled like them:
        // VLC's qt-seek-waveform option, which the thick seek bar reads (P6-06)
        Widgets.RdSettingRow {
            text: qsTr("Show Waveform on Seekbar")
            rowHeight: VLCStyle.dp(52)

            Widgets.RdToggle {
                checked: RdEffects.values[RdEffects.optionKey("qt-seek-waveform")] === true
                Accessible.name: qsTr("Show Waveform on Seekbar")
                onToggled: RdEffects.setOption("qt-seek-waveform", checked)
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Show Metadata")
            rowHeight: VLCStyle.dp(52)

            Widgets.RdToggle {
                checked: RdPanels.metadataShown
                Accessible.name: qsTr("Show Metadata")
                onToggled: RdPanels.metadataShown = checked
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Show Statistics")
            rowHeight: VLCStyle.dp(52)

            Widgets.RdToggle {
                checked: RdPanels.statisticsShown
                Accessible.name: qsTr("Show Statistics")
                onToggled: RdPanels.statisticsShown = checked
            }
        }

        // Figma "Frame 114": 10 px above the 48 px dropdown row, 20 px under it. Off, 15 / 30 /
        // 45 / 60 min or the end of the current file (Decision 23); a countdown shows its time
        // left
        Widgets.RdSettingRow {
            text: qsTr("Sleep Timer")
            Layout.topMargin: VLCStyle.dp(10)
            Layout.bottomMargin: VLCStyle.dp(20)

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(220)
                model: [qsTr("Off"), qsTr("15 min"), qsTr("30 min"), qsTr("45 min"), qsTr("60 min"),
                        qsTr("End of current file")]
                currentIndex: RdSleepTimer.choice
                displayText: RdSleepTimer.counting
                             ? qsTr("%1 (%2 left)").arg(currentText)
                                                   .arg(root.timeLeftText(RdSleepTimer.deadline, root._now))
                             : currentText
                Accessible.name: qsTr("Sleep Timer")
                onActivated: (index) => RdSleepTimer.set(index)
            }
        }

        // Cone extra (Decision 71, UP_NEXT_PLAN.md 5.2): "Autoplay this show", only while a
        // detected show plays and autoplay is not Off. The 62 px row of the design: the label,
        // the show name with the tv icon under it (Inter 12 FG/A4), the 68x32 toggle. A guard
        // that keeps autoplay away (repeat one, shuffle ...) dims the label and the toggle and
        // names the reason under them, readable (FG/A3).
        Item {
            id: autoplayRow

            readonly property bool _blocked: RdUpNext.blockedReason !== ""

            visible: RdUpNext.showActive
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? VLCStyle.dp(62) : 0
            Layout.topMargin: visible ? -VLCStyle.dp(10) : 0
            Layout.bottomMargin: visible ? VLCStyle.dp(10) : 0

            Column {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(4)
                anchors.right: autoplayToggle.left
                anchors.rightMargin: VLCStyle.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.dp(3)

                Text {
                    width: parent.width
                    opacity: autoplayRow._blocked ? VLCStyle.rd_disabledRowOpacity : 1
                    text: qsTr("Autoplay this show")
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }

                Row {
                    width: parent.width
                    spacing: VLCStyle.dp(6)

                    Widgets.RdIcon {
                        id: showIcon

                        visible: !autoplayRow._blocked
                        name: "tv"
                        size: VLCStyle.dp(16)
                        color: VLCStyle.palette.rdFgA4
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (showIcon.visible ? showIcon.width + parent.spacing : 0)
                        text: autoplayRow._blocked ? RdUpNext.blockedReason : RdUpNext.showName
                        elide: Text.ElideRight
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_toggle
                        color: autoplayRow._blocked ? VLCStyle.palette.rdFgA3 : VLCStyle.palette.rdFgA4
                    }
                }
            }

            Widgets.RdToggle {
                id: autoplayToggle

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: autoplayRow._blocked ? VLCStyle.rd_disabledRowOpacity : 1
                checked: RdUpNext.showEnabled
                Accessible.name: qsTr("Autoplay this show")
                Accessible.description: autoplayRow._blocked ? RdUpNext.blockedReason : RdUpNext.showName
                onToggled: RdUpNext.setShowEnabled(checked)
            }
        }

        // Figma "Frame 111": the 48 px dropdown row with 20 px under it
        Widgets.RdSettingRow {
            text: qsTr("Audio Visualizer")
            Layout.bottomMargin: VLCStyle.dp(20)

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.audioVisualization
                // Figma "Audio Visualizer" (2372:8639) and the playback tab: "Disabled"
                displayNames: ({ [qsTr("Disable")]: qsTr("Disabled") })
                Accessible.name: qsTr("Audio Visualizer")
            }
        }

        // the video's speed slider: 0.25 to 2 in 0.25 steps with a label under each step; held
        // past an end it scrolls on through VLC's other speeds at 1x per second, and the value
        // box takes any of them. Figma "Frame 105": a 44 px row with a frameless 140x32 box,
        // 10 px, then the slider wrapper (4 px padding, labels 34 under the thumb top)
        Widgets.RdParamSlider {
            text: qsTr("Speed")
            valueBox: true
            valueFramed: false
            valueTextColor: VLCStyle.palette.rdFgA3
            rowHeight: VLCStyle.dp(44)
            spacing: VLCStyle.dp(14)
            labelSpacing: VLCStyle.dp(14)
            valueText: root.rateText(Player.rate)
            from: 0.25
            to: 2
            limitFrom: root._rateMin
            limitTo: root._rateMax
            stepSize: 0.25
            // the wheel fine-tunes in 0.05x steps (Decision 54)
            wheelStep: 0.05
            scrollSpeed: 1
            // the zero edge label points to normal speed
            zeroValue: 1
            labelStep: 0.25
            labelText: (v) => String(Math.round(v * 100) / 100)
            value: Player.rate
            enabled: Player.ratechangable
            onMoved: (v) => Player.rate = v
            onEdited: (text) => {
                const r = parseFloat(String(text).replace(",", ".").replace(/[^0-9.]/g, ""))
                if (!isNaN(r))
                    Player.rate = Math.max(root._rateMin, Math.min(root._rateMax, r))
            }
        }
    }
}
