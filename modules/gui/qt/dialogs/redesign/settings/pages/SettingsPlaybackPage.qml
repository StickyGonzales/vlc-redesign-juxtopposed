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
// redesign: Settings > Playback ("Playback Preferences", video 17:59-18:01, Figma
// "Settings - playback" / "Settings - playback-1"); rows: P8-09. The settings for a file
// while it plays.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    // Figma: the disc drives in a dropdown; empty lets VLC use the first drive it finds
    readonly property var _driveChoices: [{ value: "", text: qsTr("Automatic") }].concat(SettingsCatalog.opticalDrives())

    function _option(name) {
        return RdEffects.values[RdEffects.optionKey(name)]
    }

    // a default track as words: Automatic, then the tracks counted from 1 (VLC counts from 0)
    function _trackChoices() {
        const list = [{ value: -1, text: qsTr("Automatic") }]
        for (let i = 0; i < 10; ++i)
            list.push({ value: i, text: qsTr("Track %1").arg(i + 1) })
        return list
    }

    readonly property bool _loop: _option("loop") === true
    readonly property bool _repeat: _option("repeat") === true
    readonly property bool _exit: _option("play-and-exit") === true
    readonly property bool _pause: _option("play-and-pause") === true
    readonly property bool _autoplayOn: Number(_option("qt-autoplay-next")) !== 0

    SettingsSection {
        title: qsTr("Startup")

        SettingsOption {
            option: "restore-playback-pos"
            text: qsTr("Continue where you left off")
            choices: [
                { value: 0, text: qsTr("Never") },
                { value: 1, text: qsTr("Ask") },
                { value: 2, text: qsTr("Always") }
            ]
        }

        SettingsOption {
            option: "playlist-autostart"
            text: qsTr("Start playing as soon as a file opens")
        }

        // 0.25 to 2 as in the video; held past an end it scrolls on through the speeds VLC
        // plays at (include/vlc_input.h: INPUT_RATE_MIN 1/32 to INPUT_RATE_MAX 31.25), 1x per
        // second (Decision 47)
        SettingsOption {
            option: "rate"
            text: qsTr("Default playback speed")
            kind: "slider"
            from: 0.25
            to: 2
            limitFrom: 0.03125
            limitTo: 31.25
            scrollSpeed: 1
            step: 0.25
            // the wheel fine-tunes in 0.05x steps (Decision 54)
            wheelStep: 0.05
            decimals: 2
            zeroValue: 1
            labelStep: 0.25
            labelText: (v) => String(Math.round(v * 100) / 100)
        }

        SettingsOption {
            option: "playlist-cork"
            text: qsTr("Pause when another app uses audio")
        }
    }

    SettingsSection {
        title: qsTr("Tracks")

        SettingsOption {
            option: "preferred-resolution"
            text: qsTr("Preferred video quality")
        }

        SettingsLanguageOption {
            option: "menu-language"
            text: qsTr("Preferred menu language")
        }

        SettingsOption {
            option: "audio-track"
            text: qsTr("Default audio track")
            // the note the sidebar's Audio Defaults had
            note: qsTr("Applies from the next file.")
            choices: root._trackChoices()
        }

        SettingsOption {
            option: "sub-track"
            text: qsTr("Default subtitle track")
            // the note the sidebar's Subtitles Defaults had (SHEET_CONFIRMATIONS, IA-29)
            note: qsTr("Applies from the next file.")
            choices: root._trackChoices()
        }
    }

    SettingsSection {
        title: qsTr("Order")

        // VLC's "loop" repeats the list, "repeat" the current item
        SettingsRow {
            text: qsTr("Repeat")
            description: qsTr("Plays the whole list again when it ends (All), or the current item again and again (One).")
            keywords: "loop repeat"

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Off"), qsTr("All"), qsTr("One")]
                currentIndex: root._repeat ? 2 : (root._loop ? 1 : 0)
                Accessible.name: qsTr("Repeat")
                onActivated: (index) => {
                    RdEffects.setOption("loop", index === 1)
                    RdEffects.setOption("repeat", index === 2)
                }
            }
        }

        SettingsOption {
            option: "random"
            text: qsTr("Shuffle")
        }

        SettingsOption {
            option: "play-and-stop"
            text: qsTr("Stop after each item")
        }

        SettingsRow {
            text: qsTr("When playback finishes")
            description: qsTr("What %1 does when the last item of the list ends: stop, stay paused on the last frame, or quit.").arg(Brand.shortName)
            keywords: "play-and-exit play-and-pause quit"

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Stop"), qsTr("Pause on the last frame"), qsTr("Quit %1").arg(Brand.shortName)]
                currentIndex: root._exit ? 2 : (root._pause ? 1 : 0)
                Accessible.name: qsTr("When playback finishes")
                onActivated: (index) => {
                    RdEffects.setOption("play-and-pause", index === 1)
                    RdEffects.setOption("play-and-exit", index === 2)
                }
            }
        }
    }

    // Cone extra (Decision 71, UP_NEXT_PLAN.md 5.1): autoplay of the next episode of a show
    // folder; the rows under the mode wait at 30 % while it is Off
    SettingsSection {
        title: qsTr("Episodes")

        SettingsOption {
            option: "qt-autoplay-next"
            text: qsTr("Autoplay next episode")
            keywords: "autoplay next episode binge up next show series"
        }

        SettingsOption {
            option: "qt-autoplay-countdown"
            text: qsTr("Countdown")
            keywords: "autoplay up next countdown"
            available: root._autoplayOn
        }

        SettingsOption {
            option: "qt-autoplay-credits-lead"
            text: qsTr("Show Up Next")
            keywords: "autoplay up next credits chapter end"
            available: root._autoplayOn
        }

        SettingsOption {
            option: "qt-autoplay-still-watching"
            text: qsTr("Ask if I'm still watching after 3 episodes")
            keywords: "autoplay still watching binge"
            available: root._autoplayOn
        }

        // the answers given per show folder (rd-shows.json); they do not follow the profiles
        SettingsRow {
            text: qsTr("Remembered shows")
            description: qsTr("The shows you answered the \"Looks like a show\" question for, or turned autoplay on or off for in the Playback tab. Forget all asks again for each show and forgets where their credits start.")
            keywords: "autoplay show remembered forget"
            available: root._autoplayOn

            Row {
                spacing: VLCStyle.dp(16)

                Text {
                    // the row dims its label only; this text is part of the control
                    opacity: root._autoplayOn ? 1.0 : VLCStyle.rd_disabledRowOpacity
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int total: RdUpNext.rememberedYes + RdUpNext.rememberedNo
                    text: total === 0 ? qsTr("No shows yet")
                        : total === 1 ? qsTr("1 show: %1 autoplay, %2 never")
                                            .arg(RdUpNext.rememberedYes).arg(RdUpNext.rememberedNo)
                        : qsTr("%1 shows: %2 autoplay, %3 never")
                              .arg(total).arg(RdUpNext.rememberedYes).arg(RdUpNext.rememberedNo)
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }

                Widgets.RdButton {
                    style: Widgets.RdButton.Style.Plain
                    text: qsTr("Forget all")
                    enabled: RdUpNext.rememberedYes + RdUpNext.rememberedNo + RdUpNext.rememberedCredits > 0
                    onClicked: RdUpNext.forgetAll()
                }
            }
        }
    }

    SettingsSection {
        title: qsTr("Seeking")

        // VLC's option is "fast seek" (less precise)
        SettingsOption {
            option: "input-fast-seek"
            text: qsTr("Seek precisely")
            kind: "toggle"
            checkedValue: false
            uncheckedValue: true
        }

        // the seek bar preview card (P2-04); Figma: on
        SettingsOption {
            option: "qt-seek-thumbnails"
            text: qsTr("Show thumbnail while scrubbing")
        }
    }

    SettingsSection {
        title: qsTr("Files & Discs")

        SettingsOption {
            option: "dvd"
            text: qsTr("Default optical drive")
            kind: "dropdown"
            choices: root._driveChoices
        }

        SettingsOption {
            option: "avi-index"
            text: qsTr("Repair damaged AVI files")
            choices: [
                { value: 0, text: qsTr("Ask") },
                { value: 1, text: qsTr("Always") },
                { value: 2, text: qsTr("Never") },
                { value: 3, text: qsTr("When needed") }
            ]
        }

        SettingsOption {
            option: "mkv-preload-local-dir"
            text: qsTr("Load matching .mkv files from the same folder")
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "input-timeshift-path"
                controlHeight: VLCStyle.dp(32)
                text: qsTr("Time-shift buffer folder")
                kind: "directory"
            }

            SettingsOption {
                option: "input-timeshift-granularity"
                text: qsTr("Time-shift buffer size")
                choices: [
                    { value: 10485760, text: qsTr("Small (10 MB)") },
                    { value: -1, text: qsTr("Medium (50 MB)") },
                    { value: 104857600, text: qsTr("Large (100 MB)") }
                ]
            }
        },

        SettingsMoreOptions {
            category: "playback"
        }
    ]
}
