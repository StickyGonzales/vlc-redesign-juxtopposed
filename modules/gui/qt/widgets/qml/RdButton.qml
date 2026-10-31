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

// Redesign text button (Figma "Frame 140/141", 100x32, radius 6, Inter 600 14):
// - Standard: BG/A3 + FG/A2 (Cancel, Back, Browse); in the light theme a dark button, FG/A2 +
//   BG/A1 text, like "Browse" at video 17:43 (Figma has no light dialog)
// - Save: BG/Accent Bright + Accent/Main (dialog Save, Test); disabled is gray (BG/A1 + FG/A2)
//   at 50% opacity, as the Figma "Open network stream" export and the video (13:10) show it
// - Primary: Accent/Main + FG/B1 (Next, Finish, Continue Watching)
// - Bar: full-width BG/B2 + FG/A3, regular weight (Show Preferences)
// - Link: the Bar layout without a fill, FG/A3, FG/A2 on hover (Open Advanced Settings: the
//   Figma instance 812:1585 clears the fill, the video at 7:58 shows no button)
// - Plain: Standard on BG/A4, the Settings pages' buttons (Figma "Settings - *" "Frame 141":
//   Browse, Open, Reset picture, Edit Keyboard Shortcuts)
// - Destructive: red text on a red-tinted fill (Settings > General "Reset all settings")
// - Toast: Standard on a BG/A3 toast or card, BG/A1 like the resume toast's close button
//   (Up Next Cancel, the show prompt's No)
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Button {
    id: control

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    enum Style { Standard, Save, Primary, Bar, Plain, Destructive, Link, Toast }

    property int style: RdButton.Style.Standard
    property string rdIcon: ""            // optional Figma icon (Widgets.RdIcon) shown before the text
    // Figma dialog buttons use Inter 14; onboarding buttons Inter 16 (Next 600, Browse 400)
    property int fontPixelSize: VLCStyle.rd_fontSize_label
    property int fontWeight: (style === RdButton.Style.Bar || style === RdButton.Style.Link) ? Font.Normal
                                                                                            : Font.DemiBold

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: Math.max(VLCStyle.dp(100), contentRow.implicitWidth + leftPadding + rightPadding)
    implicitHeight: VLCStyle.dp(32)

    leftPadding: VLCStyle.dp(8)
    rightPadding: VLCStyle.dp(8)

    focusPolicy: Qt.StrongFocus

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    Accessible.onPressAction: control.clicked()

    // Figma has no button component with a disabled state; its one disabled button (Save in
    // "Open network stream") is gray at 50 %: Standard buttons are gray already, so both at 50 %
    opacity: (!enabled && (style === RdButton.Style.Save || style === RdButton.Style.Standard
                           || style === RdButton.Style.Plain)) ? 0.5 : 1.0

    readonly property color _bg: {
        switch (style) {
        case RdButton.Style.Save: return enabled ? rdPalette.rdBgAccentBright : rdPalette.rdBgA1
        case RdButton.Style.Primary: return hovered ? rdPalette.rdAccentBright : rdPalette.rdAccentMain
        case RdButton.Style.Bar: return hovered ? rdPalette.rdBgA4 : rdPalette.rdBgB2
        case RdButton.Style.Link: return "transparent"
        case RdButton.Style.Destructive:
            return hovered ? Qt.lighter(rdPalette.rdBgDestructive, 1.3) : rdPalette.rdBgDestructive
        default:
            if (!rdPalette.isDark)
                return hovered ? rdPalette.rdFgA1 : rdPalette.rdFgA2
            if (style === RdButton.Style.Toast)
                return hovered ? rdPalette.rdBgA2 : rdPalette.rdBgA1
            return hovered ? rdPalette.rdBgA1
                           : (style === RdButton.Style.Plain ? rdPalette.rdBgA4 : rdPalette.rdBgA3)
        }
    }
    readonly property color _fg: {
        switch (style) {
        case RdButton.Style.Save: return enabled ? rdPalette.rdAccentMain : rdPalette.rdFgA2
        case RdButton.Style.Primary: return rdPalette.rdFgB1
        case RdButton.Style.Bar:
        case RdButton.Style.Link:
            return hovered ? rdPalette.rdFgA2 : rdPalette.rdFgA3
        case RdButton.Style.Destructive: return rdPalette.rdFgDestructive
        default: return rdPalette.isDark ? rdPalette.rdFgA2 : rdPalette.rdBgA1
        }
    }

    background: Rectangle {
        radius: (control.style === RdButton.Style.Bar || control.style === RdButton.Style.Link)
                ? VLCStyle.rd_radius_small : VLCStyle.rd_radius_normal
        color: control._bg
        border.width: control.visualFocus ? VLCStyle.dp(1) : 0
        // the light Standard button is dark itself: its focus ring is the accent
        border.color: (control.rdPalette.isDark || (control.style !== RdButton.Style.Standard
                                                     && control.style !== RdButton.Style.Plain
                                                     && control.style !== RdButton.Style.Toast))
                      ? control.rdPalette.rdFg2 : control.rdPalette.rdAccentMain
    }

    contentItem: Item {
        Row {
            id: contentRow

            anchors.centerIn: parent
            spacing: VLCStyle.dp(6)

            RdIcon {
                visible: control.rdIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: control.rdIcon
                size: VLCStyle.dp(20)
                color: control._fg
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: control.fontPixelSize
                font.weight: control.fontWeight
                color: control._fg
            }
        }
    }
}
