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
// redesign: Settings > Interface ("Interface Settings", video 17:50-17:51, Figma
// "Settings - interface" / "Settings - interface-1"); rows: P8-06.
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

    readonly property bool _skin: String(_option("intf")) === "skins2"
    readonly property bool _tray: _option("qt-system-tray") === true

    SettingsSection {
        title: qsTr("Skin")
        // only in builds with VLC's skinnable interface; Cone has none (Decision 63)
        shown: !Brand.isPublic

        // only in builds with VLC's skinnable interface
        SettingsOption {
            option: "intf"
            shown: !Brand.isPublic && SettingsCatalog.exists("skins2-last")
            text: qsTr("Use a custom skin")
            description: qsTr("Replaces this interface with %1's skinnable one, drawn by a skin file. %1 uses it the next time it starts.").arg(Brand.shortName)
            kind: "toggle"
            checkedValue: "skins2"
            uncheckedValue: ""
        }

        SettingsOption {
            option: "skins2-last"
            text: qsTr("Skin file")
            kind: "file"
            available: root._skin
        }
    }

    SettingsSection {
        title: qsTr("Window")

        SettingsOption {
            option: "embedded-video"
            text: qsTr("Play video inside main window")
            restartRequired: true
        }

        SettingsOption {
            option: "qt-video-autoresize"
            text: qsTr("Resize window to fit video")
            choices: [
                { value: false, text: qsTr("Never") },
                { value: true, text: qsTr("When a video starts") }
            ]
        }

        // S2-02 (video 17:50): read when the window opens, written when it closes
        SettingsOption {
            option: "qt-remember-window"
            text: qsTr("Remember window size and position")
        }

        SettingsOption {
            option: "video-on-top"
            text: qsTr("Keep window above other windows")
        }

        // applies at once (MainCtx reads it again and the window changes its frame)
        SettingsOption {
            option: "qt-titlebar"
            text: qsTr("Show window decorations")
        }

        SettingsOption {
            option: "qt-name-in-title"
            text: qsTr("Show the file name in the title bar")
        }

        SettingsOption {
            option: "qt-fullscreen-screennumber"
            text: qsTr("Open fullscreen on")
            choices: {
                const list = [{ value: -1, text: qsTr("Current screen") }]
                const screens = Qt.application.screens
                for (let i = 0; i < screens.length; ++i) {
                    // the monitor's maker and model; the system name ("\\.\DISPLAY1") as a fallback
                    const model = [screens[i].manufacturer, screens[i].model].filter((t) => !!t).join(" ")
                    list.push({ value: i, text: qsTr("Screen %1 (%2)").arg(i + 1).arg(model !== "" ? model : screens[i].name) })
                }
                return list
            }
        }
    }

    SettingsSection {
        title: qsTr("Playback Controls")

        SettingsOption {
            option: "qt-minimal-view"
            text: qsTr("Start in compact mode")
        }

        // Decision 30: the bars float over the video and hide; "pin video controls" keeps
        // them in a window
        SettingsOption {
            option: "qt-pin-controls"
            text: qsTr("Auto-hide the controls")
            choices: [
                { value: false, text: qsTr("Always") },
                { value: true, text: qsTr("In fullscreen only") }
            ]
        }

        // VLC declares no range (milliseconds): the slider scrolls on past 10 s, up to a minute
        // (Decision 47)
        SettingsOption {
            option: "mouse-hide-timeout"
            text: qsTr("Hide after")
            kind: "slider"
            sliderTrackTop: VLCStyle.dp(4)
            sliderLabelSpacing: VLCStyle.dp(8)
            valueScale: 1000
            from: 0
            to: 10
            limitTo: 60
            step: 0.5
            labelStep: 5
            labelText: (v) => qsTr("%1 s").arg(Math.round(v * 10) / 10)
        }

        SettingsOption {
            id: fsControllerRow

            option: "qt-fs-controller"
            text: qsTr("Show controls in fullscreen")
        }
    }

    SettingsSection {
        title: qsTr("Notifications and System Tray")

        SettingsOption {
            option: "qt-system-tray"
            text: qsTr("Show a system tray icon")
            restartRequired: true
        }

        SettingsOption {
            option: "qt-start-minimized"
            text: qsTr("Start minimized to the tray")
            available: root._tray
        }

        SettingsOption {
            id: notificationRow

            option: "qt-notification"
            text: qsTr("Show a popup when the track changes")
        }

        // S2-03 (Figma "Settings - interface" 3062:11148): the "Hide after" slider wrapper (47
        // high, track 4 down, labels 8 under it), 0.5 s steps; VLC keeps 1 s at least. Dimmed
        // while the popup is off (Never)
        SettingsOption {
            option: "qt-notification-duration"
            text: qsTr("Popup duration")
            kind: "slider"
            available: notificationRow.value !== 0
            sliderTrackTop: VLCStyle.dp(4)
            sliderLabelSpacing: VLCStyle.dp(8)
            valueScale: 1000
            from: 0
            to: 10
            step: 0.5
            labels: [qsTr("0 s"), qsTr("5 s"), qsTr("10 s")]
        }
    }

    SettingsSection {
        title: qsTr("Playlist")

        SettingsOption {
            option: "playlist-tree"
            text: qsTr("Show the playlist as a tree")
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "qt-opacity"
                text: qsTr("Window opacity")
                kind: "slider"
                sliderTrackTop: VLCStyle.dp(4)
                sliderLabelSpacing: VLCStyle.dp(8)
                valueScale: 0.01
                from: 10
                to: 100
                step: 5
                labels: [qsTr("10%"), qsTr("100%")]
            }

            SettingsOption {
                option: "qt-pause-minimized"
                text: qsTr("Pause video when window is minimized")
            }

            SettingsOption {
                option: "qt-auto-raise"
                text: qsTr("Bring %1 to the front when playback starts").arg(Brand.shortName)
            }

            SettingsOption {
                option: "qt-bgcone"
                text: qsTr("Show cover art in the window when playing audio")
            }

            SettingsOption {
                option: "qt-embedded-open"
                text: qsTr("Show the file browser inside the open dialog")
            }

            SettingsOption {
                option: "qt-icon-change"
                text: qsTr("Allow the app icon to change")
            }

            SettingsOption {
                option: "qt-fs-opacity"
                text: qsTr("Fullscreen controls opacity")
                kind: "slider"
                sliderTrackTop: VLCStyle.dp(4)
                sliderLabelSpacing: VLCStyle.dp(8)
                valueScale: 0.01
                from: 10
                to: 100
                step: 5
                labels: [qsTr("10%"), qsTr("100%")]
            }

            // how near the top or bottom edge the mouse shows a bar in fullscreen (Figma: a three
            // stop slider, "wrapper" 320x47)
            SettingsRow {
                text: qsTr("Fullscreen controls sensitivity")
                description: qsTr("How near the top or bottom edge of the screen the mouse has to be to show the controls in fullscreen. High shows them from further away.")
                keywords: "qt-fs-sensitivity fullscreen mouse edge"
                shown: SettingsCatalog.exists("qt-fs-sensitivity")
                available: fsControllerRow.value !== false

                Widgets.RdSlider {
                    // distance from the edge, in dp (Player.qml); Medium is the default
                    readonly property var distances: [16, 40, 96]

                    implicitWidth: VLCStyle.dp(320)
                    trackTop: VLCStyle.dp(4)
                    labelSpacing: VLCStyle.dp(8)
                    from: 0
                    to: distances.length - 1
                    stepSize: 1
                    labels: [qsTr("Low"), qsTr("Medium"), qsTr("High")]
                    // a value set elsewhere shows as the nearest choice
                    value: {
                        const v = MainCtx.fsSensitivity
                        let best = 0
                        for (let i = 1; i < distances.length; ++i) {
                            if (Math.abs(distances[i] - v) < Math.abs(distances[best] - v))
                                best = i
                        }
                        return best
                    }
                    Accessible.name: qsTr("Fullscreen controls sensitivity")
                    onMoved: MainCtx.fsSensitivity = distances[Math.round(value)]
                }
            }
        },

        SettingsMoreOptions {
            category: "interface"
        }
    ]
}
