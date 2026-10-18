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

// redesign: resume toast near the playback controls (video 13:55-14:10, Figma "continue":
// a pill hugging its content, 552x52 with the English sentence, radius 16, BG/A3 95%, padding
// 10/10/10/20, Inter 16 FG/2 text with the time in Inter 600, 60 px to the buttons, "Continue
// Watching" primary button 146x32, 10 px, dark 44x32 close button).
// The text is never cut: the toast hugs it up to the room it is given; with less room the sentence
// wraps onto more lines, and in a very narrow room the buttons move under the sentence.
import QtQuick
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

FocusScope {
    id: resumePanel

    // the widest the toast may get (Player.qml: the video area left of an open panel)
    property real maxWidth: Number.POSITIVE_INFINITY

    readonly property real _padLeft: VLCStyle.dp(20, VLCStyle.scale)
    readonly property real _padRight: VLCStyle.dp(10, VLCStyle.scale)
    readonly property real _padVertical: VLCStyle.dp(10, VLCStyle.scale)
    // Figma: 60 px between the sentence and the buttons, 10 px between the buttons
    readonly property real _textGap: VLCStyle.dp(60, VLCStyle.scale)
    readonly property real _buttonSpacing: VLCStyle.dp(10, VLCStyle.scale)
    // stacked: 10 px between the sentence and the buttons under it
    readonly property real _stackGap: VLCStyle.dp(10, VLCStyle.scale)

    readonly property real _buttonsWidth: continueBtn.implicitWidth + _buttonSpacing + closeBtn.implicitWidth
    readonly property real _buttonsHeight: Math.max(continueBtn.implicitHeight, closeBtn.implicitHeight)

    // the sentence on one line (Text's implicitWidth ignores the wrapping width)
    readonly property real _textNaturalWidth: Math.ceil(label.implicitWidth)
    // a longer sentence (a translation, the question without a time) wraps rather than stretching
    // the toast across the player
    readonly property real _textMaxWidth: VLCStyle.dp(480, VLCStyle.scale)
    // below this sentence column the buttons move under the sentence
    readonly property real _textMinWidth: VLCStyle.dp(160, VLCStyle.scale)

    // the sentence column next to the buttons
    readonly property real _sideColumnWidth: maxWidth - _padLeft - _textGap - _buttonsWidth - _padRight

    // stacked when the column beside the buttons is too narrow or would need more than two lines
    // (1.85: word wrapping leaves room at the line ends)
    readonly property bool _stacked: _sideColumnWidth < Math.min(_textNaturalWidth, _textMinWidth)
                                     || _textNaturalWidth > 1.85 * _sideColumnWidth

    // stacked, the toast is never narrower than its buttons (hidden below that, Player.qml)
    readonly property real _textWidth: Math.max(0, Math.min(_textNaturalWidth, _textMaxWidth,
                                                            _stacked ? Math.max(maxWidth - _padLeft - _padRight, _buttonsWidth)
                                                                     : _sideColumnWidth))

    implicitWidth: _stacked ? _padLeft + Math.max(_textWidth, _buttonsWidth) + _padRight
                            : _padLeft + _textWidth + _textGap + _buttonsWidth + _padRight
    // one line: Figma's 52 px (rounded once, not per padding; the buttons are centered in it)
    implicitHeight: _stacked ? 2 * _padVertical + label.height + _stackGap + _buttonsHeight
                             : Math.max(VLCStyle.dp(52, VLCStyle.scale), 2 * _padVertical + label.height)

    // the narrowest toast: the buttons, with the sentence wrapped above them
    readonly property real minimumWidth: _padLeft + _buttonsWidth + _padRight

    baselineOffset: label.y + label.baselineOffset

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    // a file watched to its last 20 seconds starts over without asking (Sticky, 2026-10-13); the
    // length is often only known once playback has started
    readonly property bool _watchedToEnd: _lengthKnown && Player.restoreProgress > 0
                                          && (1 - Player.restoreProgress) * Player.length.toSeconds() < 20

    // Player.length still holds the previous file's length until the new one is reported
    property bool _lengthKnown: false

    Connections {
        target: Player
        // only the "cleared" emissions (media change, stop) reset the length: the positive
        // answer can come from the media library thread after lengthChanged
        function onPlaybackRestoreQueried() {
            if (!Player.canRestorePlayback)
                resumePanel._lengthKnown = false
        }
        function onLengthChanged() {
            resumePanel._lengthKnown = Player.length.valid()
        }
    }

    on_WatchedToEndChanged: {
        if (_watchedToEnd && visible)
            hideResumePanel()
    }

    function showResumePanel ()
    {
        if (_watchedToEnd)
            return
        resumePanel.visible = true
        continueBtn.forceActiveFocus()
        resumeTimeout.start()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        resumePanel.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.visible = false
            hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.rd_radius_toast
        // opaque: the bg blur cannot run over the native video (Decision: opaque popups)
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

        // the wheel over the toast does not reach the video (volume, Decision 54)
        Widgets.RdWheelSink {
            anchors.fill: parent
        }
    }

    // Figma 1922:9584: Inter 400 16 FG/2 with the time in Inter 600 (StyledText has no 600 weight,
    // so rich text). Side by side it is centered on the buttons; stacked it sits above them.
    T.Label {
        id: label

        // the saved progress times the file length (known once playback starts)
        readonly property bool _hasRestoreTime: resumePanel._lengthKnown && Player.restoreProgress > 0
        readonly property string _time: _hasRestoreTime
                                        ? Player.length.scale(Player.restoreProgress).formatHHMMSS() : ""

        function _escaped(str) {
            return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        }

        x: resumePanel._padLeft
        y: resumePanel._stacked ? resumePanel._padVertical
                                : Math.round((resumePanel.height - height) / 2)
        width: resumePanel._textWidth

        textFormat: Text.RichText
        wrapMode: Text.Wrap
        color: VLCStyle.palette.rdFg2
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_header

        text: _hasRestoreTime
              ? _escaped(qsTr("You already watched till %1"))
                    .arg("<span style=\"font-weight:600\">" + _time + "</span>")
              : _escaped(qsTr("Do you want to restart the playback where you left off?"))

        Accessible.name: _hasRestoreTime ? qsTr("You already watched till %1").arg(_time)
                                         : qsTr("Do you want to restart the playback where you left off?")
    }

    Row {
        id: buttons

        x: resumePanel.width - resumePanel._padRight - width
        y: resumePanel._stacked ? label.y + label.height + resumePanel._stackGap
                                : Math.round((resumePanel.height - height) / 2)
        spacing: resumePanel._buttonSpacing

        Widgets.RdButton {
            id: continueBtn

            anchors.verticalCenter: parent.verticalCenter

            style: Widgets.RdButton.Style.Primary
            text: qsTr("Continue Watching")

            AccessibleCompat.id: "resumeContinueButton"

            focus: true
            onClicked: {
                Player.restorePlaybackPos()
                hideResumePanel()
            }

            Navigation.parentItem: resumePanel
            Navigation.rightItem: closeBtn
        }

        T.Button {
            id: closeBtn

            // the pointing hand over the clickable controls
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(44, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            AccessibleCompat.id: "resumeDismissButton"
            Accessible.name: qsTr("Dismiss")

            onClicked: hideResumePanel()

            Navigation.parentItem: resumePanel
            Navigation.leftItem: continueBtn
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => closeBtn.Navigation.defaultKeyAction(event)

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: closeBtn.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA1
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
}
