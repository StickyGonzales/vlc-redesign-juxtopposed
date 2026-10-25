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

// redesign (W6.5, P3-07): Settings > Subtitles, the OpenSubtitles account behind the Add
// Subtitles dialog's "From OpenSubtitles" source. Figma's page has no such rows: kept (Decision 31,
// the function comes from the video) as the page's last section, after her sections, so her page
// reads as in "Settings - subtitles", and built like its text rows ("Font", and the empty fields of
// "Settings - network": 320x36, value in FG/A2, 38 px line). The source stays off until an API
// key is entered; the username and password are optional and raise the daily download quota.
// Kept by AddSubtitles in the interface's settings, applied when a field is left.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsSection {
    id: root

    title: qsTr("OpenSubtitles")
    keywords: qsTr("opensubtitles api key account download subtitles online")

    // SettingsOption's text field
    component AccountField: Widgets.RdTextField {
        implicitWidth: VLCStyle.dp(320)
        implicitHeight: VLCStyle.dp(36)
        color: VLCStyle.palette.rdFgA2
        placeholderTextColor: VLCStyle.palette.rdFgA2
    }

    component AccountRow: SettingsRow {
        minimumLineHeight: VLCStyle.dp(38)
    }

    AccountRow {
        text: qsTr("API key")
        description: qsTr("Searching and downloading subtitles from OpenSubtitles.com needs an API key. Create a free account on opensubtitles.com, then add an API consumer in your profile to get one. Without a key, the OpenSubtitles source of Add Subtitles stays off.")
        keywords: "opensubtitles api key"

        AccountField {
            text: AddSubtitles.apiKey
            echoMode: TextInput.Password
            Accessible.name: qsTr("OpenSubtitles API key")
            onEditingFinished: AddSubtitles.apiKey = text.trim()
        }
    }

    AccountRow {
        text: qsTr("Username")
        description: qsTr("Optional. Signing in to your OpenSubtitles account allows more downloads a day than the API key alone.")
        keywords: "opensubtitles account user login"
        available: AddSubtitles.openSubtitlesEnabled

        AccountField {
            text: AddSubtitles.username
            Accessible.name: qsTr("OpenSubtitles username")
            onEditingFinished: AddSubtitles.username = text.trim()
        }
    }

    AccountRow {
        text: qsTr("Password")
        description: qsTr("Optional. Kept on this computer with the interface settings.")
        keywords: "opensubtitles account password login"
        available: AddSubtitles.openSubtitlesEnabled

        AccountField {
            text: AddSubtitles.password
            echoMode: TextInput.Password
            Accessible.name: qsTr("OpenSubtitles password")
            onEditingFinished: AddSubtitles.password = text
        }
    }
}
