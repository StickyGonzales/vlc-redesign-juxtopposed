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
// redesign: Settings > Library ("Playlists, Folders & Files", video 18:15-18:17, Figma
// "Settings - library"); rows: P8-14. The two rows under "Only allow one VLC window" depend on
// it and are dimmed while it is off (video 18:15).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Dialogs
import VLC.Widgets as Widgets

SettingsPage {
    id: root

    readonly property bool _oneInstance: RdEffects.values[RdEffects.optionKey("one-instance")] === true

    SettingsSection {
        title: qsTr("Opening Files")

        SettingsOption {
            option: "one-instance"
            text: qsTr("Only allow one %1 window").arg(Brand.shortName)
        }

        SettingsOption {
            option: "one-instance-when-started-from-file"
            text: qsTr("Apply to files opened from the file manager")
            available: root._oneInstance
        }

        SettingsOption {
            option: "playlist-enqueue"
            text: qsTr("Add to the playlist instead of replacing it")
            available: root._oneInstance
        }

        SettingsOption {
            option: "recursive"
            text: qsTr("When opening a folder")
            choices: [
                { value: "expand", text: qsTr("Include subfolders") },
                { value: "collapse", text: qsTr("Show subfolders as folders") },
                { value: "none", text: qsTr("Ignore subfolders") }
            ]
        }

        SettingsOption {
            option: "show-hiddenfiles"
            text: qsTr("Show hidden files")
        }
    }

    SettingsSection {
        title: qsTr("Metadata & Artwork")

        SettingsOption {
            option: "metadata-network-access"
            text: qsTr("Fetch titles and artwork")
            choices: [
                { value: false, text: qsTr("From the file only") },
                { value: true, text: qsTr("From the file and the internet") }
            ]
        }

        // the state of the library, not the saved "media-library" value: VLC's launcher starts
        // every session with --media-library, so the saved value can neither turn it off nor on.
        // The toggle shows whether the library runs and cannot be switched (dimmed)
        SettingsRow {
            text: qsTr("Use the media library")
            description: {
                const note = qsTr("%1 always starts with the media library: its launcher turns it on, whatever is saved here.").arg(Brand.shortName)
                const text = RdEffects.optionDescription("media-library")
                return text !== "" ? text + "\n\n" + note : note
            }
            keywords: "media-library"
            shown: SettingsCatalog.exists("media-library")

            Widgets.RdToggle {
                checked: MainCtx.mediaLibraryAvailable
                enabled: false
                Accessible.name: qsTr("Use the media library")
            }
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "auto-preparse"
                text: qsTr("Read the details of added items")
            }

            SettingsOption {
                option: "ignore-filetypes"
                text: qsTr("Ignore files ending with")
            }
        },

        SettingsMoreOptions {
            category: "library"
        }
    ]
}
