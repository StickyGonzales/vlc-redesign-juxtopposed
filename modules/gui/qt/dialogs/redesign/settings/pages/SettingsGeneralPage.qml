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
// redesign: Settings > General ("Global Settings", video 17:39-17:49 and 18:48-18:55, Figma
// "Settings - global" / "Settings - global-1"); rows: P8-03, P8-04, P8-05, P8-22, IB-43.
// Theme and accent recolor the whole interface at once (P8-41, P8-42).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    readonly property bool _logging: RdEffects.values[RdEffects.optionKey("file-logging")] === true
    readonly property bool _syslog: RdEffects.values[RdEffects.optionKey("syslog")] === true

    SettingsSection {
        title: qsTr("Appearance")

        // read when Cone starts: VLC's registry key on Windows, Cone's interface settings on
        // Linux (qt.cpp); macOS keeps the system language
        SettingsRow {
            text: qsTr("Interface language")
            description: qsTr("The language of %1's menus, windows and messages. %1 uses it the next time it starts.").arg(Brand.shortName)
            keywords: "language translation"
            shown: SettingsCatalog.languageSupported

            Widgets.RdDropdown {
                id: languageDropdown

                readonly property var languages: SettingsCatalog.languageSupported ? SettingsCatalog.languages() : []
                property string current: SettingsCatalog.languageSupported ? SettingsCatalog.language() : "auto"

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: languages.map((l) => l.text)
                currentIndex: languages.findIndex((l) => l.value === current)
                Accessible.name: qsTr("Interface language")
                onActivated: (index) => {
                    current = languages[index].value
                    SettingsCatalog.setLanguage(current)
                }

                Connections {
                    target: SettingsCatalog

                    function onResetDone() {
                        languageDropdown.current = SettingsCatalog.language()
                    }
                }
            }
        }

        // Figma "Values" (3): Dark / Light / System; the scheme list of MainCtx is
        // System, Day, Night
        SettingsRow {
            text: qsTr("Theme")
            keywords: "dark light night day color scheme"

            Widgets.RdSegmented {
                readonly property var schemes: [ColorSchemeModel.Night, ColorSchemeModel.Day, ColorSchemeModel.System]
                readonly property var rows: [2, 1, 0]

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Dark"), qsTr("Light"), qsTr("System")]
                currentIndex: Math.max(0, schemes.indexOf(MainCtx.colorScheme.scheme))
                Accessible.name: qsTr("Theme")
                onActivated: (index) => {
                    const model = MainCtx.colorScheme
                    model.setData(model.index(rows[index], 0), true, Qt.CheckStateRole)
                }
            }
        }

        SettingsRow {
            text: qsTr("Accent color")
            keywords: "accent color colour orange"

            SettingsAccentPicker { }
        }
    }

    SettingsSection {
        title: qsTr("Startup")

        SettingsOption {
            option: "interact"
            text: qsTr("Show confirmation and error dialogs")
        }

        SettingsOption {
            id: updatesRow

            option: "qt-updates-notif"
            text: qsTr("Check for updates automatically")
        }

        // Cone's own update notice (util/rd_update_check.cpp); the vlc profile has VLC's row
        // above instead, and neither exists in the other profile
        SettingsOption {
            option: "qt-cone-update-check"
            text: qsTr("Check for updates")
        }

        SettingsRow {
            id: checkNowRow

            text: qsTr("Check now")
            description: qsTr("Asks GitHub for the latest release of %1 at once. Nothing is downloaded or installed.").arg(Brand.shortName)
            keywords: "update version release new"
            shown: RdUpdateCheck.supported
            belowShown: checkNowStatus.text !== ""

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                implicitWidth: VLCStyle.dp(320)
                text: qsTr("Check Now")
                enabled: RdUpdateCheck.status !== RdUpdateCheck.Checking
                onClicked: RdUpdateCheck.checkNow()
            }

            below: Text {
                id: checkNowStatus

                x: checkNowRow.width - width
                width: VLCStyle.dp(320)
                wrapMode: Text.WordWrap
                text: {
                    switch (RdUpdateCheck.status) {
                    case RdUpdateCheck.Checking:
                        return qsTr("Checking…")
                    case RdUpdateCheck.UpToDate:
                        return qsTr("%1 %2 is the latest version.").arg(Brand.name).arg(RdUpdateCheck.currentVersion)
                    case RdUpdateCheck.UpdateAvailable:
                        return qsTr("%1 %2 is available.").arg(Brand.name).arg(RdUpdateCheck.latestVersion)
                    case RdUpdateCheck.CheckFailed:
                        return qsTr("Could not reach GitHub. Try again later.")
                    default:
                        return ""
                    }
                }
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }
        }

        // "Skip this version" on the update notice: the version it no longer offers, and the way
        // back (shown only while one is skipped)
        SettingsRow {
            text: qsTr("Skipped version")
            description: qsTr("The update notice does not offer %1 %2. A newer version still shows, and Check Now always shows the newest one.").arg(Brand.name).arg(RdUpdateCheck.skippedVersion)
            keywords: "update version skip skipped undo"
            shown: RdUpdateCheck.supported && RdUpdateCheck.skippedVersion !== ""

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                implicitWidth: VLCStyle.dp(320)
                text: qsTr("Undo Skip of %1").arg(RdUpdateCheck.skippedVersion)
                Accessible.name: qsTr("Offer %1 %2 again").arg(Brand.name).arg(RdUpdateCheck.skippedVersion)
                onClicked: RdUpdateCheck.undoSkip()
            }
        }
    }

    SettingsSection {
        title: qsTr("Diagnostics")

        SettingsOption {
            option: "qt-verbose"
            text: qsTr("Developer mode")
            restartRequired: true
        }

        SettingsOption {
            option: "file-logging"
            text: qsTr("Save a log")
            restartRequired: true
        }

        // the log is opened when VLC starts (modules/logger/file.c)
        SettingsOption {
            option: "logfile"
            text: qsTr("Log file")
            kind: "savefile"
            available: root._logging
            restartRequired: true
        }

        // the file logger adds VLC's error level to this value and writes the messages up to
        // that level: 0 errors, 1 warnings too, 2 debug messages too; -1 follows "verbose"
        SettingsOption {
            option: "log-verbose"
            text: qsTr("Log details")
            available: root._logging
            restartRequired: true
            choices: [
                { value: 0, text: qsTr("Errors only") },
                { value: 1, text: qsTr("Errors and warnings") },
                { value: 2, text: qsTr("Everything (debug)") },
                { value: -1, text: qsTr("Same as %1's messages").arg(Brand.shortName) }
            ]
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "qt-error-dialogs"
                text: qsTr("Show minor warnings")
            }

            // VLC options applied at every start, as if typed after the program name (a core
            // option of the Cone build, src/libvlc.c; Figma "Settings - global-1": an empty
            // field). Options that change or remove the interface are ignored (Decision 66), as
            // the note under the field says
            SettingsOption {
                id: extraOptionsRow

                option: "extra-options"
                text: qsTr("Additional command line options")
                kind: "text"
                restartRequired: true

                below: Text {
                    x: extraOptionsRow.width - width
                    width: extraOptionsRow.controlWidth
                    wrapMode: Text.WordWrap
                    // the option names on their own line: a wrap would break them at a hyphen
                    text: qsTr("Options that change the interface are ignored:\n--intf, -I, --extraintf, skins")
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }
            }

            SettingsOption {
                option: "logmode"
                text: qsTr("Log format")
                available: root._logging
                restartRequired: true
                choices: [
                    { value: "text", text: qsTr("Plain text") },
                    { value: "html", text: qsTr("HTML") }
                ]
            }

            SettingsOption {
                option: "stats"
                text: qsTr("Collect playback statistics")
            }

            SettingsRow {
                text: qsTr("Open configurations folder")
                description: qsTr("Opens the folder where %1 keeps its settings, in the file manager.").arg(Brand.shortName)
                keywords: "config vlcrc folder"

                Widgets.RdButton {
                    style: Widgets.RdButton.Style.Plain
                    text: qsTr("Open")
                    onClicked: SettingsCatalog.openConfigFolder()
                }
            }

            SettingsRow {
                text: qsTr("Reset all settings")
                description: qsTr("Puts every setting of %1 back to how it was when %1 was installed. Your library, playlists and window layout stay.").arg(Brand.shortName)
                keywords: "reset preferences defaults"

                // Figma "Settings - global-1": the red "Reset"
                Widgets.RdButton {
                    style: Widgets.RdButton.Style.Destructive
                    text: qsTr("Reset")
                    onClicked: {
                        if (!DialogsProvider.questionDialog(qsTr("Are you sure you want to reset all of %1's settings?").arg(Brand.shortName),
                                                            qsTr("Reset all settings")))
                            return
                        // a change still on its way to VLC must not land after the reset
                        RdEffects.discardPending()
                        SettingsCatalog.resetAll()
                        RdEffects.refresh()
                    }
                }
            }
        },

        SettingsSection {
            // the system log exists on Linux and BSD only
            visible: SettingsCatalog.exists("syslog")
                     && (!_page || !_page.filtering || titleMatches || _anyRowMatches)
            title: qsTr("Developer Options")

            SettingsOption {
                option: "syslog"
                text: qsTr("Write to the system log")
                restartRequired: true
            }

            SettingsOption {
                option: "syslog-debug"
                text: qsTr("Include debug messages in the system log")
                available: root._syslog
            }

            SettingsOption {
                option: "syslog-ident"
                controlHeight: VLCStyle.dp(32)
                text: qsTr("System log identity")
                available: root._syslog
            }

            SettingsOption {
                option: "syslog-facility"
                text: qsTr("System log facility")
                available: root._syslog
            }
        },

        SettingsMoreOptions {
            category: "general"
        }
    ]
}
