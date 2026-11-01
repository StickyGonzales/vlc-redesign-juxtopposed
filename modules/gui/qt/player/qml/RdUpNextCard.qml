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
// Cone extra (Decision 71, redesign/UP_NEXT_PLAN.md 7): the Up Next card near the end of an
// episode. Variant A (Q8): 400 wide (the side panel width), radius 14, opaque BG/A3, 12 px
// padding, the 160x90 thumbnail left, the text right, Play now + Cancel under them and the 3 px
// countdown line along the foot. In a narrow video area (`compact`) it takes Variant C's layout:
// the resume toast's 60 px pill with a 64x36 thumbnail, one line of text, Play now and the dark
// close button. "Still watching?" (after 3 episodes in a row) drops the picture and the line and
// asks Keep watching / Stop.
// During the credits (UP_NEXT_PLAN.md 5.4) it waits without a countdown: Next episode and Cancel;
// the countdown only runs in the last seconds, so a post-credits scene is never cut by itself.
// It never takes the focus by itself (Space still pauses); Tab reaches its buttons, Escape cancels
// while it has the focus.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

FocusScope {
    id: root

    // Variant C's pill (Player.qml: under 900 px of video width)
    property bool compact: false

    // what the card shows, held while it fades out: when the next episode starts, the card fades
    // out while RdUpNext already looks at the new episode (its name first empty, then the one
    // after it, the PC session's retest of #87), so its texts stay those of the moment it began
    // to hide. Shown or fully hidden, they follow RdUpNext
    QtObject {
        id: shownState

        property int cardMode: RdUpNext.CardNext
        property bool nextIsNewSeason: false
        property int nextSeason: -1
        property bool autoplays: true
        property bool counting: false
        property int secondsLeft: 0
        property string showName: ""
        property string cardLine: ""
        property url nextThumbnail: ""
        property real countdownProgress: 0
    }

    Binding { target: shownState; property: "cardMode"; value: RdUpNext.cardMode; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "nextIsNewSeason"; value: RdUpNext.nextIsNewSeason; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "nextSeason"; value: RdUpNext.nextSeason; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "autoplays"; value: RdUpNext.autoplays; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "counting"; value: RdUpNext.counting; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "secondsLeft"; value: RdUpNext.secondsLeft; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "showName"; value: RdUpNext.showName; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "cardLine"; value: RdUpNext.cardLine; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "nextThumbnail"; value: RdUpNext.nextThumbnail; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }
    Binding { target: shownState; property: "countdownProgress"; value: RdUpNext.countdownProgress; when: root.shown || !root.visible; restoreMode: Binding.RestoreNone }

    readonly property bool _still: shownState.cardMode === RdUpNext.CardStillWatching
    readonly property bool _season: !_still && shownState.nextIsNewSeason
    // shown during the credits, before the countdown
    readonly property bool _waiting: !_still && !shownState.counting

    readonly property real _pad: VLCStyle.dp(12, VLCStyle.scale)
    readonly property real _thumbWidth: VLCStyle.dp(160, VLCStyle.scale)
    readonly property real _thumbHeight: VLCStyle.dp(90, VLCStyle.scale)
    readonly property real _cardWidth: VLCStyle.dp(400, VLCStyle.scale)
    readonly property real _lineHeight: VLCStyle.dp(3, VLCStyle.scale)

    readonly property string _heading: _still ? qsTr("Still watching?")
                                              : (_season ? qsTr("Up next · Season %1").arg(shownState.nextSeason)
                                                         : qsTr("Up next"))
    // a weak name pattern (01 02, "Part 2") never plays by itself: the card waits for a click
    readonly property string _waitingText: shownState.autoplays ? qsTr("Plays at the end of the episode")
                                                              : qsTr("Plays when you choose")
    readonly property string _countdownText: _waiting ? _waitingText
                                                      : qsTr("Playing in %1 s").arg(shownState.secondsLeft)
    readonly property string _playText: _still ? qsTr("Keep watching")
                                               : (_waiting ? qsTr("Next episode") : qsTr("Play now"))

    implicitWidth: compact ? pill.implicitWidth : _cardWidth
    implicitHeight: compact ? pill.implicitHeight : full.implicitHeight

    // the pill's minimum: Player.qml hides the card below it (plan 7.1, the countdown runs on)
    readonly property real minimumWidth: pill.minimumWidth

    // 150 ms fade, no movement (plan 7.2); the buttons go with the card
    property bool shown: false
    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Accessible.role: Accessible.Dialog
    Accessible.name: _still ? qsTr("Still watching? %1 is paused after 3 episodes in a row.").arg(shownState.cardLine)
                            : _waiting ? qsTr("Up next: %1, %2. %3.")
                                             .arg(shownState.showName).arg(shownState.cardLine).arg(_waitingText)
                                       : qsTr("Up next: %1, %2. Playing in %3 seconds.")
                                             .arg(shownState.showName).arg(shownState.cardLine).arg(shownState.secondsLeft)

    function _primary() {
        if (root._still)
            RdUpNext.keepWatching()
        else
            RdUpNext.playNow()
    }

    function _secondary() {
        if (root._still)
            RdUpNext.stopWatching()
        else
            RdUpNext.cancel()
    }

    // Escape cancels only while a button of the card has the focus (plan 7.2)
    Keys.onEscapePressed: (event) => {
        root._secondary()
        event.accepted = true
    }

    Navigation.cancelAction: function() { root._secondary() }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Rectangle {
        id: background

        anchors.fill: parent
        radius: root.compact ? VLCStyle.rd_radius_toast : VLCStyle.rd_radius_large
        // opaque: no blur over the native video (Decision: opaque popups)
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

        Widgets.RdShadow {}

        // the presses and the wheel over the card stay on it: no pause toggle, no volume
        // change (Decision 54), and a right click opens nothing
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        Widgets.RdWheelSink {
            anchors.fill: parent
        }
    }

    // ---------------------------------------------------------------- Variant A, the full card
    Item {
        id: full

        anchors.fill: parent
        visible: !root.compact

        readonly property real _textWidth: root._still ? root._cardWidth - 2 * root._pad
                                                       : root._cardWidth - 2 * root._pad - root._thumbWidth - VLCStyle.dp(14, VLCStyle.scale)
        readonly property real _topHeight: root._still ? texts.implicitHeight
                                                       : Math.max(root._thumbHeight, texts.implicitHeight)

        implicitHeight: root._pad + _topHeight + VLCStyle.dp(12, VLCStyle.scale) + fullButtons.height
                        + VLCStyle.dp(12, VLCStyle.scale) + (root._still ? 0 : root._lineHeight + VLCStyle.dp(6, VLCStyle.scale))

        Rectangle {
            id: thumb

            x: root._pad
            y: root._pad
            width: root._thumbWidth
            height: root._thumbHeight
            visible: !root._still
            radius: VLCStyle.rd_radius_normal
            color: "black"
            clip: true

            Image {
                anchors.fill: parent
                source: shownState.nextThumbnail
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }

            // the 36 px round play mark: a click on the picture plays the episode now
            Rectangle {
                anchors.centerIn: parent
                width: VLCStyle.dp(36, VLCStyle.scale)
                height: width
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.6)

                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: "play"
                    size: VLCStyle.dp(20, VLCStyle.scale)
                    color: VLCStyle.palette.rdFg2
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: RdUpNext.playNow()
            }
        }

        Column {
            id: texts

            x: root._still ? root._pad : thumb.x + thumb.width + VLCStyle.dp(14, VLCStyle.scale)
            y: root._pad
            width: full._textWidth
            spacing: VLCStyle.dp(4, VLCStyle.scale)

            T.Label {
                width: parent.width
                text: root._heading
                elide: Text.ElideRight
                color: VLCStyle.palette.rdAccentMain
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_toggle
                font.weight: Font.DemiBold
                font.letterSpacing: VLCStyle.dp(0.4, VLCStyle.scale)
            }

            T.Label {
                width: parent.width
                text: shownState.showName
                elide: Text.ElideRight
                color: VLCStyle.palette.rdFgA2
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
            }

            // two lines, then elided (matrix row 115)
            T.Label {
                width: parent.width
                text: shownState.cardLine
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: VLCStyle.palette.rdFg2
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                font.weight: Font.Medium
            }

            T.Label {
                width: parent.width
                topPadding: VLCStyle.dp(2, VLCStyle.scale)
                text: root._still ? qsTr("Paused after 3 episodes in a row.") : root._countdownText
                wrapMode: Text.Wrap
                color: VLCStyle.palette.rdFgA3
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
            }
        }

        Row {
            id: fullButtons

            x: root._pad
            y: root._pad + full._topHeight + VLCStyle.dp(12, VLCStyle.scale)
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Widgets.RdButton {
                id: playButton

                style: Widgets.RdButton.Style.Primary
                rdIcon: root._still ? "" : "play"
                text: root._playText
                // 120 px wide at least (the design's Play now)
                implicitWidth: Math.max(VLCStyle.dp(120, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
                onClicked: root._primary()

                Navigation.parentItem: root
                Navigation.rightItem: cancelButton
            }

            Widgets.RdButton {
                id: cancelButton

                style: Widgets.RdButton.Style.Toast
                text: root._still ? qsTr("Stop") : qsTr("Cancel")
                onClicked: root._secondary()

                Navigation.parentItem: root
                Navigation.leftItem: playButton
                Navigation.rightItem: turnOffLink.visible ? turnOffLink : null
            }
        }

        // "Turn off autoplay": the setting Play episodes in a row goes off (UP_NEXT_PLAN.md 2.3)
        T.AbstractButton {
            id: turnOffLink

            anchors.right: parent.right
            anchors.rightMargin: root._pad
            anchors.verticalCenter: fullButtons.verticalCenter
            visible: !root._still
            focusPolicy: Qt.StrongFocus
            text: qsTr("Turn off autoplay")
            implicitWidth: linkLabel.implicitWidth
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            // a button to assistive technology, like the card's other buttons: the activate action
            // (UI Automation's Invoke, Narrator) presses it as a click does; the underline is
            // only its look
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.description: qsTr("Turns off Play episodes in a row")
            Accessible.onPressAction: turnOffLink.clicked()

            onClicked: RdUpNext.turnOffAutoplay()

            Navigation.parentItem: root
            Navigation.leftItem: cancelButton
            Keys.priority: Keys.AfterItem
            // Space presses it (AbstractButton); Enter and Return as well, as on a link
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true
                    turnOffLink.clicked()
                    return
                }
                turnOffLink.Navigation.defaultKeyAction(event)
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            contentItem: T.Label {
                id: linkLabel

                text: turnOffLink.text
                verticalAlignment: Text.AlignVCenter
                color: turnOffLink.hovered || turnOffLink.visualFocus ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA3
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                font.underline: true
            }
        }

        // the countdown line: BG/B2 track, the accent part is the time left
        Rectangle {
            x: root._pad
            width: root._cardWidth - 2 * root._pad
            y: full.height - root._pad + VLCStyle.dp(3, VLCStyle.scale) - height
            height: root._lineHeight
            radius: height / 2
            visible: !root._still
            // during the credits there is no countdown yet (the card keeps its height)
            opacity: root._waiting ? 0 : 1
            color: VLCStyle.palette.rdBgB2

            Rectangle {
                width: parent.width * shownState.countdownProgress
                height: parent.height
                radius: height / 2
                color: VLCStyle.palette.rdAccentMain

                // one second per step while the card shows; a new countdown starts full at once
                Behavior on width {
                    enabled: root.opacity >= 1
                    NumberAnimation { duration: 1000; easing.type: Easing.Linear }
                }
            }
        }
    }

    // ------------------------------------------------------- Variant C, the compact pill
    Item {
        id: pill

        anchors.fill: parent
        visible: root.compact

        readonly property real _padSide: VLCStyle.dp(10, VLCStyle.scale)
        readonly property real _gap: VLCStyle.dp(12, VLCStyle.scale)
        readonly property real _buttonsWidth: pillPlay.implicitWidth + VLCStyle.dp(10, VLCStyle.scale) + pillClose.implicitWidth
        readonly property real _thumbWidth: root._still ? 0 : VLCStyle.dp(64, VLCStyle.scale) + _gap
        // the line of text up to 320 px, then elided
        readonly property real _textWidth: Math.min(Math.max(pillHeading.implicitWidth, pillEpisode.implicitWidth),
                                                    VLCStyle.dp(320, VLCStyle.scale))

        readonly property real minimumWidth: 2 * _padSide + _thumbWidth + VLCStyle.dp(80, VLCStyle.scale)
                                             + VLCStyle.dp(16, VLCStyle.scale) + _buttonsWidth

        implicitWidth: 2 * _padSide + _thumbWidth + _textWidth + VLCStyle.dp(28, VLCStyle.scale) + _buttonsWidth
        implicitHeight: VLCStyle.dp(60, VLCStyle.scale)

        Rectangle {
            id: pillThumb

            x: pill._padSide
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -VLCStyle.dp(1, VLCStyle.scale)
            width: VLCStyle.dp(64, VLCStyle.scale)
            height: VLCStyle.dp(36, VLCStyle.scale)
            visible: !root._still
            radius: VLCStyle.rd_radius_small
            color: "black"
            clip: true

            Image {
                anchors.fill: parent
                source: shownState.nextThumbnail
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
        }

        Column {
            x: pill._padSide + pill._thumbWidth
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -VLCStyle.dp(1, VLCStyle.scale)
            width: pill.width - x - VLCStyle.dp(28, VLCStyle.scale) - pill._buttonsWidth - pill._padSide
            spacing: VLCStyle.dp(1, VLCStyle.scale)

            T.Label {
                id: pillHeading

                width: parent.width
                text: root._still ? qsTr("Still watching?")
                                  : (root._waiting ? qsTr("Up next") : qsTr("Up next in %1 s").arg(shownState.secondsLeft))
                elide: Text.ElideRight
                color: VLCStyle.palette.rdAccentMain
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_toggle
                font.weight: Font.DemiBold
            }

            T.Label {
                id: pillEpisode

                width: parent.width
                text: shownState.cardLine
                elide: Text.ElideRight
                color: VLCStyle.palette.rdFg2
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_time
            }
        }

        Row {
            x: pill.width - pill._padSide - width
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -VLCStyle.dp(1, VLCStyle.scale)
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Widgets.RdButton {
                id: pillPlay

                anchors.verticalCenter: parent.verticalCenter
                style: Widgets.RdButton.Style.Primary
                rdIcon: root._still ? "" : "play"
                text: root._playText
                onClicked: root._primary()

                Navigation.parentItem: root
                Navigation.rightItem: pillClose
            }

            // the resume toast's dark 44x32 close button
            T.Button {
                id: pillClose

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: VLCStyle.dp(44, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                focusPolicy: Qt.StrongFocus

                Accessible.name: root._still ? qsTr("Stop") : qsTr("Cancel")

                onClicked: root._secondary()

                Navigation.parentItem: root
                Navigation.leftItem: pillPlay
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => pillClose.Navigation.defaultKeyAction(event)

                background: Rectangle {
                    radius: VLCStyle.rd_radius_normal
                    color: pillClose.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA1
                    border.width: pillClose.visualFocus ? VLCStyle.dp(1) : 0
                    border.color: VLCStyle.palette.rdFg2
                }

                contentItem: Item {
                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "close"
                        color: VLCStyle.palette.rdFgA2
                    }
                }
            }
        }

        // the 2 px countdown line inside the pill's foot
        Rectangle {
            x: VLCStyle.dp(16, VLCStyle.scale)
            width: pill.width - 2 * x
            y: pill.height - VLCStyle.dp(6, VLCStyle.scale)
            height: VLCStyle.dp(2, VLCStyle.scale)
            radius: height / 2
            visible: !root._still && !root._waiting
            color: VLCStyle.palette.rdBgB2

            Rectangle {
                width: parent.width * shownState.countdownProgress
                height: parent.height
                radius: height / 2
                color: VLCStyle.palette.rdAccentMain

                // one second per step while the card shows; a new countdown starts full at once
                Behavior on width {
                    enabled: root.opacity >= 1
                    NumberAnimation { duration: 1000; easing.type: Easing.Linear }
                }
            }
        }
    }
}
