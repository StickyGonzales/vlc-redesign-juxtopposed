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
// Cone extra (Decision 71, redesign/UP_NEXT_PLAN.md 2.3): the one-time "Looks like a show"
// prompt, 10 s into the first episode of a show folder in "Ask for each show" (after the resume
// toast). The resume toast's look: radius 16, opaque BG/A3, padding 10/10/10/20, the tv icon,
// Inter 16 FG/2 with the show name under it in 13 FG/A3, then Yes (primary) and No (BG/A1).
// Its answer is remembered for the show folder; with no answer it goes after 20 s and asks again
// with the next episode.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

FocusScope {
    id: root

    // the widest the prompt may get (Player.qml: the video area left of an open panel)
    property real maxWidth: Number.POSITIVE_INFINITY

    readonly property real _padLeft: VLCStyle.dp(20, VLCStyle.scale)
    readonly property real _padRight: VLCStyle.dp(10, VLCStyle.scale)
    readonly property real _padVertical: VLCStyle.dp(10, VLCStyle.scale)
    readonly property real _iconGap: VLCStyle.dp(14, VLCStyle.scale)
    readonly property real _textGap: VLCStyle.dp(46, VLCStyle.scale)
    readonly property real _buttonSpacing: VLCStyle.dp(10, VLCStyle.scale)

    readonly property real _buttonsWidth: yesButton.implicitWidth + _buttonSpacing + noButton.implicitWidth
    readonly property real _textNaturalWidth: Math.ceil(Math.max(question.implicitWidth, detail.implicitWidth))
    readonly property real _textWidth: Math.max(VLCStyle.dp(120, VLCStyle.scale),
                                                Math.min(_textNaturalWidth,
                                                         maxWidth - _padLeft - icon.width - _iconGap - _textGap - _buttonsWidth - _padRight))

    implicitWidth: _padLeft + icon.width + _iconGap + _textWidth + _textGap + _buttonsWidth + _padRight
    implicitHeight: Math.max(VLCStyle.dp(64, VLCStyle.scale), 2 * _padVertical + texts.implicitHeight)

    readonly property real minimumWidth: _padLeft + icon.width + _iconGap + VLCStyle.dp(120, VLCStyle.scale)
                                         + _textGap + _buttonsWidth + _padRight

    property bool shown: false
    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Looks like a show. Play episodes in a row?")

    Keys.onEscapePressed: (event) => {
        RdUpNext.dismissPrompt()
        event.accepted = true
    }

    Navigation.cancelAction: function() { RdUpNext.dismissPrompt() }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.rd_radius_toast
        // opaque: no blur over the native video (Decision: opaque popups)
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

        Widgets.RdShadow {}

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        // the wheel over the prompt does not reach the video (volume, Decision 54)
        Widgets.RdWheelSink {
            anchors.fill: parent
        }
    }

    Widgets.RdIcon {
        id: icon

        x: root._padLeft
        anchors.verticalCenter: parent.verticalCenter
        name: "tv"
        color: VLCStyle.palette.rdAccentMain
    }

    Column {
        id: texts

        x: icon.x + icon.width + root._iconGap
        anchors.verticalCenter: parent.verticalCenter
        width: root._textWidth
        spacing: VLCStyle.dp(2, VLCStyle.scale)

        T.Label {
            id: question

            width: parent.width
            text: qsTr("Looks like a show. Play episodes in a row?")
            wrapMode: Text.Wrap
            color: VLCStyle.palette.rdFg2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
        }

        T.Label {
            id: detail

            width: parent.width
            text: qsTr("%1 · you can change this in the Playback tab").arg(RdUpNext.showName)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: VLCStyle.palette.rdFgA3
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
        }
    }

    Row {
        x: root.width - root._padRight - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root._buttonSpacing

        Widgets.RdButton {
            id: yesButton

            style: Widgets.RdButton.Style.Primary
            text: qsTr("Yes")
            implicitWidth: Math.max(VLCStyle.dp(72, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
            onClicked: RdUpNext.answer(true)

            Navigation.parentItem: root
            Navigation.rightItem: noButton
        }

        Widgets.RdButton {
            id: noButton

            style: Widgets.RdButton.Style.Toast
            text: qsTr("No")
            implicitWidth: Math.max(VLCStyle.dp(72, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
            onClicked: RdUpNext.answer(false)

            Navigation.parentItem: root
            Navigation.leftItem: yesButton
        }
    }
}
