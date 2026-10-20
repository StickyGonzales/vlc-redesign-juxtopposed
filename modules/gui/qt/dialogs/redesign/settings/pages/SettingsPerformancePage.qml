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
// redesign: Settings > Performance ("Performance Settings", video 18:20-18:22, Figma
// "Settings - performance"); rows: P8-16. Decoding and smooth playback first, VLC's clock
// settings under "Developer" in the Advanced Options.
import QtQuick

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

    // the system refused the last priority change (raising it needs privileges outside Windows)
    property bool _priorityRefused: false

    function _applyPriority() {
        _priorityRefused = !SettingsCatalog.setPriority(highPriorityRow.value === true,
                                                        Number(processPriorityRow.value ?? 0))
    }

    // VLC tries the listed decoders first, then all the others ("codec" is not strict)
    readonly property var _decoderChoices: {
        const list = [{ value: "any", text: qsTr("Automatic") }]
        if (SettingsCatalog.exists("avcodec-threads"))
            list.push({ value: "avcodec", text: qsTr("FFmpeg") })
        if (SettingsCatalog.exists("dav1d-thread-frames"))
            list.push({ value: "dav1d", text: qsTr("dav1d (AV1)") })
        if (SettingsCatalog.exists("mft-debug"))
            list.push({ value: "mft", text: qsTr("Media Foundation") })
        return list
    }

    SettingsSection {
        title: qsTr("Decoding")

        // VLC's "hw-dec" turns hardware decoding on, "dec-dev" picks the device: Automatic,
        // a device, or Off in one list (Figma: one dropdown, "Automatic")
        SettingsRow {
            text: qsTr("Hardware-accelerated decoding")
            description: RdEffects.optionDescription("hw-dec")
            keywords: "hw-dec dec-dev hardware gpu dxva d3d11"
            shown: SettingsCatalog.exists("hw-dec")

            Widgets.RdDropdown {
                readonly property bool _enabled: root._option("hw-dec") !== false
                readonly property string _device: String(root._option("dec-dev") ?? "any")
                readonly property var entries: {
                    const list = [{ device: "any", text: qsTr("Automatic") }]
                    for (const c of RdEffects.optionChoices("dec-dev")) {
                        if (c.value !== "any" && c.value !== "none" && c.value !== "")
                            list.push({ device: c.value, text: c.text })
                    }
                    // a device VLC does not list (set elsewhere) is kept, as SettingsOption does
                    if (_device !== "any" && _device !== "none" && _device !== ""
                            && !list.some((e) => e.device === _device))
                        list.push({ device: _device, text: _device })
                    list.push({ device: "", text: qsTr("Off") })
                    return list
                }

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: entries.map((e) => e.text)
                // "none" (VLC's own Disable) is off too
                currentIndex: !_enabled || _device === "none" ? entries.length - 1
                                                              : Math.max(0, entries.findIndex((e) => e.device === _device))
                Accessible.name: qsTr("Hardware-accelerated decoding")
                onActivated: (index) => {
                    const device = entries[index].device
                    RdEffects.setOption("hw-dec", device !== "")
                    if (device !== "")
                        RdEffects.setOption("dec-dev", device)
                }
            }
        }

        // the quality is read by VLC's post-processing filter, which runs while it is in the
        // video filters: Off takes it out
        SettingsRow {
            text: qsTr("Video post-processing")
            description: RdEffects.optionDescription("postproc-q")
            keywords: "postproc-q postproc post-processing"
            shown: SettingsCatalog.exists("postproc-q")

            Widgets.RdDropdown {
                // only asked when the filter exists (VLC logs a missing filter module)
                readonly property bool _on: SettingsCatalog.exists("postproc-q")
                                            && RdEffects.values[RdEffects.videoFilterKey("postproc")] === true
                readonly property int _quality: Number(root._option("postproc-q") ?? 6)
                readonly property var levels: [qsTr("Off"), qsTr("Lowest"), qsTr("Low"), qsTr("Medium"),
                                               qsTr("High"), qsTr("Very high"), qsTr("Highest")]
                // the filter on with a quality outside 1-6 (0: it does nothing) shows that value
                readonly property bool _raw: _on && (_quality < 1 || _quality > 6)

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: _raw ? levels.concat([String(_quality)]) : levels
                currentIndex: _raw ? levels.length : (_on ? _quality : 0)
                Accessible.name: qsTr("Video post-processing")
                onActivated: (index) => {
                    if (index >= levels.length)
                        return
                    // also the running filter's quality
                    if (index > 0)
                        RdEffects.setVideoValue("postproc-q", index)
                    if (RdEffects.videoFilterEnabled("postproc") !== (index > 0))
                        RdEffects.setVideoFilterEnabled("postproc", index > 0)
                }
            }
        }

        SettingsOption {
            option: "avcodec-skiploopfilter"
            text: qsTr("Skip the H.264 loop filter")
            choices: [
                { value: 0, text: qsTr("Never") },
                { value: 1, text: qsTr("For non-reference frames") },
                { value: 2, text: qsTr("For bidirectional frames") },
                { value: 3, text: qsTr("For non-key frames") },
                { value: 4, text: qsTr("Always") }
            ]
        }

        SettingsOption {
            option: "avcodec-threads"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Decoding threads")
            // Figma: a text input; 0 lets FFmpeg pick the number of threads (the info popover)
            kind: "number"
        }
    }

    SettingsSection {
        title: qsTr("Smooth Playback")

        SettingsOption {
            option: "drop-late-frames"
            text: qsTr("Drop frames when the system can't keep up")
        }

        // Windows: VLC's process priority, raised at once and when VLC starts (the core reads
        // the option before the configuration file, so SettingsCatalog applies the saved value)
        SettingsOption {
            id: highPriorityRow

            option: "high-priority"
            text: qsTr("Give %1 high priority").arg(Brand.shortName)

            onValueChanged: {
                if (typeof value === "boolean")
                    root._applyPriority()
            }
        }

        // S2-07 (video 18:20), Decision 35: in words; applied at once and when VLC starts
        // (SettingsCatalog). Figma's row is a 38 high text input
        SettingsOption {
            id: processPriorityRow

            option: "qt-process-priority"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Process priority")
            choices: [
                { value: -2, text: qsTr("Lowest") },
                { value: -1, text: qsTr("Low") },
                { value: 0, text: qsTr("Normal") },
                { value: 1, text: qsTr("High") },
                { value: 2, text: qsTr("Highest") }
            ]

            onValueChanged: {
                if (value !== undefined)
                    root._applyPriority()
            }

            belowShown: root._priorityRefused
            below: Text {
                width: processPriorityRow.width
                wrapMode: Text.WordWrap
                text: qsTr("The system did not let %1 change its priority.").arg(Brand.shortName)
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }
        }

        // S2-08 (video 18:20): Figma "Rescan" button 320x32. VLC's plugin cache is rebuilt in
        // the background; a running VLC keeps its plugins, so the result offers a restart
        SettingsRow {
            id: rescanRow

            // "": not run yet, "done", "failed"
            property string result: ""

            text: qsTr("Rescan plugins")
            // elsewhere (Linux) the folder must be writable: SettingsCatalog.rescanPlugins() reports the failure
            description: Qt.platform.os === "windows"
                         ? qsTr("Looks through %1's plugin folder again and rebuilds the list of plugins, so plugins you added or removed are found. %1 uses the new list the next time it starts. In the Program Files folder, Windows asks for administrator rights.").arg(Brand.shortName)
                         : qsTr("Looks through %1's plugin folder again and rebuilds the list of plugins, so plugins you added or removed are found. %1 uses the new list the next time it starts. The plugin folder must be writable.").arg(Brand.shortName)
            keywords: "plugins cache rescan reset-plugins-cache vlc-cache-gen"
            belowShown: result !== ""

            Connections {
                target: SettingsCatalog

                function onRescanFinished(ok) {
                    rescanRow.result = ok ? "done" : "failed"
                }
            }

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                implicitWidth: VLCStyle.dp(320)
                text: SettingsCatalog.rescanning ? qsTr("Rescanning...") : qsTr("Rescan")
                enabled: !SettingsCatalog.rescanning
                onClicked: {
                    rescanRow.result = ""
                    SettingsCatalog.rescanPlugins()
                }
            }

            below: Row {
                spacing: VLCStyle.dp(10)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: rescanRow.result === "done"
                          ? qsTr("Done. %1 uses the new list of plugins the next time it starts.").arg(Brand.shortName)
                          : qsTr("%1 could not rebuild its list of plugins.").arg(Brand.shortName)
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }

                Widgets.RdButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rescanRow.result === "done"
                    style: Widgets.RdButton.Style.Link
                    text: qsTr("Restart now")
                    onClicked: {
                        if (SettingsCatalog.startNewInstance())
                            DialogsProvider.quit()
                    }
                }
            }
        }
    }

    advanced: [
        SettingsSection {
            title: qsTr("Developer")

            // S2-09 (video 18:20): the transcoder's video encoder ("sout-transcode-venc"), used
            // when VLC converts, streams with transcoding or records with re-encoding. VLC's
            // "none" and "any" both let it pick by score: Automatic; the encoders by VLC's names
            SettingsOption {
                id: encoderRow

                option: "sout-transcode-venc"
                text: qsTr("Encoder")
                description: qsTr("The video encoder %1 uses when it converts video: Convert / Save, streaming with conversion and recordings that cannot be saved as they are. Automatic lets %1 pick the best one for the format.").arg(Brand.shortName)
                choices: {
                    const automatic = encoderRow.value === "any" ? "any" : "none"
                    const list = [{ value: automatic, text: qsTr("Automatic") }]
                    for (const c of RdEffects.optionChoices("sout-transcode-venc")) {
                        if (c.value !== "any" && c.value !== "none" && c.value !== "")
                            list.push(c)
                    }
                    return list
                }
            }

            SettingsOption {
                option: "codec"
                text: qsTr("Decoder")
                choices: root._decoderChoices
            }

            SettingsOption {
                option: "clock-synchro"
                text: qsTr("Clock synchronisation")
            }

            SettingsOption {
                option: "clock-jitter"
                minimumLineHeight: VLCStyle.dp(38)
                text: qsTr("Clock jitter")
                unit: qsTr("ms")
            }

            SettingsOption {
                option: "cr-average"
                minimumLineHeight: VLCStyle.dp(38)
                text: qsTr("Clock reference averaging")
            }
        },

        SettingsMoreOptions {
            category: "performance"
        }
    ]
}
