/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick

import VLC.MediaLibrary
import VLC.Player
import VLC.Menus

Item {
    // redesign: Ctrl+B creates a bookmark at the current time at once, no dialog (video
    // 15:03-15:08, Decision 22); the queue sidebar's Bookmarks tab shows it. VLC keeps
    // bookmarks in the media library, so the shortcut lives here.
    MLBookmarkModel {
        id: bookmarkModel

        player: Player
        ml: MediaLib
    }

    ShortcutExt{ sequence:"Ctrl+B"; onActivated: bookmarkModel.add() }

    MLRecentMediaModel {
        id: recentModel
        limit: 10
        ml: MediaLib
    }

    //build all the shortcuts everytime, it seems that they can't be added/removed dynamically
    Repeater {
        model: 10

        Item {
            ShortcutExt {
                sequence: "Ctrl+" + ((index + 1) % 10)
                onActivated:  {
                    if (index < recentModel.count)
                    {

                        // redesign: the role enum is not visible to QML (MLRecentMediaModel.MEDIA_ID
                        // is undefined), so data() returned the display role, a local path, which
                        // was then played as an address ("c:/..."); read the item's id by role name
                        const trackId = recentModel.getDataAt(index).id
                        if (!!trackId)
                            MediaLib.addAndPlay([trackId])
                    }
                }
            }
        }
    }
}
