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
// redesign: Settings > Recording ("Recording, Casting & Streaming Out", video 18:23-18:25, Figma
// "Settings - recording"); rows: P8-17. The encoder settings are x264's, which VLC uses when it
// converts video for streaming (casting uses its own fast settings, from Cast quality).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    // x264's presets, fastest first; VLC leaves the option empty for x264's default ("medium")
    readonly property var _presets: [
        { value: "ultrafast", text: qsTr("Ultra fast") },
        { value: "superfast", text: qsTr("Super fast") },
        { value: "veryfast", text: qsTr("Very fast") },
        { value: "faster", text: qsTr("Faster") },
        { value: "fast", text: qsTr("Fast") },
        { value: "medium", text: qsTr("Medium") },
        { value: "slow", text: qsTr("Slow") },
        { value: "slower", text: qsTr("Slower") },
        { value: "veryslow", text: qsTr("Very slow") },
        { value: "placebo", text: qsTr("Placebo (slowest)") }
    ]
    readonly property string _preset: String(RdEffects.values[RdEffects.optionKey("sout-x264-preset")] ?? "")

    SettingsSection {
        title: qsTr("Recording")

        SettingsOption {
            option: "input-record-path"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Save recordings to")
            kind: "directory"
            placeholder: qsTr("Videos or Music folder")
        }

        SettingsOption {
            option: "input-record-native"
            text: qsTr("Record without re-encoding when possible")
        }
    }

    SettingsSection {
        title: qsTr("Casting")

        // S2-10 (video 18:23): on, the Render picker looks for cast devices while it is open (as
        // in VLC, StickyGonzales 2026-11-13); off, not at all. MainCtx applies it after the write
        SettingsOption {
            option: "qt-cast-discovery"
            text: qsTr("Discover cast devices")
        }

        SettingsOption {
            option: "sout-chromecast-conversion-quality"
            text: qsTr("Cast quality")
            choices: [
                { value: 0, text: qsTr("High (more bandwidth)") },
                { value: 1, text: qsTr("Medium") },
                { value: 2, text: qsTr("Low (less bandwidth)") },
                { value: 3, text: qsTr("Low processor use (more bandwidth)") }
            ]
        }
    }

    SettingsSection {
        title: qsTr("Streaming")

        SettingsOption {
            option: "sout-display"
            text: qsTr("Play locally while streaming")
        }

        SettingsOption {
            option: "sout-audio"
            text: qsTr("Include audio")
        }

        SettingsOption {
            option: "sout-video"
            text: qsTr("Include video")
        }

        SettingsOption {
            option: "sout-spu"
            text: qsTr("Include subtitles")
        }

        SettingsRow {
            text: qsTr("Encoding preset")
            description: qsTr("How hard the encoder works when %1 converts video for streaming (casting uses its own fast settings). Slower presets give a smaller stream at the same quality but use more processor time.").arg(Brand.shortName)
            keywords: "sout-x264-preset x264 encoder speed"
            shown: SettingsCatalog.exists("sout-x264-preset")

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: root._presets.map((p) => p.text)
                currentIndex: root._presets.findIndex((p) => p.value === (root._preset !== "" ? root._preset : "medium"))
                Accessible.name: qsTr("Encoding preset")
                onActivated: (index) => RdEffects.setOption("sout-x264-preset", root._presets[index].value)
            }
        }

        SettingsOption {
            option: "sout-x264-tune"
            text: qsTr("Tuning")
            choices: [
                { value: "", text: qsTr("None") },
                { value: "film", text: qsTr("Film") },
                { value: "animation", text: qsTr("Animation") },
                { value: "grain", text: qsTr("Film grain") },
                { value: "stillimage", text: qsTr("Still images") },
                { value: "psnr", text: qsTr("PSNR (benchmarks)") },
                { value: "ssim", text: qsTr("SSIM (benchmarks)") },
                { value: "fastdecode", text: qsTr("Fast decoding") },
                { value: "zerolatency", text: qsTr("Zero latency") }
            ]
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "sout-keep"
                text: qsTr("Keep the stream output open between items")
            }

            SettingsOption {
                option: "sout-all"
                text: qsTr("Stream all tracks")
            }

            SettingsOption {
                option: "sout-x264-profile"
                text: qsTr("H.264 profile")
                choices: [
                    { value: "baseline", text: qsTr("Baseline") },
                    { value: "main", text: qsTr("Main") },
                    { value: "high", text: qsTr("High") },
                    { value: "high10", text: qsTr("High 10-bit") },
                    { value: "high422", text: qsTr("High 4:2:2") },
                    { value: "high444", text: qsTr("High 4:4:4") }
                ]
            }

            SettingsOption {
                option: "sout-x264-level"
                text: qsTr("H.264 level")
                choices: [{ value: "0", text: qsTr("Automatic") }].concat(
                             ["1", "1.1", "1.2", "1.3", "2", "2.1", "2.2", "3", "3.1", "3.2",
                              "4", "4.1", "4.2", "5", "5.1"].map((l) => ({ value: l, text: l })))
            }
        },

        SettingsMoreOptions {
            category: "recording"
        }
    ]
}
