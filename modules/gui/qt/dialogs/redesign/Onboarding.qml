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

// redesign (W8.3, video 19:47-19:54, Figma "Onboarding" 1899:3055, 1902:3670, 1902:6770): the
// first-run onboarding that replaces VLC's first-run wizard. Figma's frames are the whole
// 1090 x 759 window (its corners and shadow are the window's), so it fills the window, which
// grows to that size when it is smaller, with three screens:
//   1. welcome and the media folder for the media library (only with the media library)
//   2. theme (Light / Dark / System) and accent color, applied live (Decision 9) over a picture
//      of the player that follows the choices
//   3. the basic keyboard shortcuts, with the user's own VLC keys (Decision 22)
// Next / Back switch screens instantly, like the Figma prototype; Finish saves the choices.
// Escape closes it like the wizard's close button: the theme and color stay as chosen, no media
// folder is added. Opened by DialogsProvider.firstRunDialog() through showOnboarding().
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs
import VLC.Player

T.Popup {
    id: root

    // closed, after the settings were written
    signal done()

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // 0: welcome, 1: theme and color, 2: shortcuts
    property int page: 0
    property string mediaFolder: ""

    property bool _finished: false
    property bool _holdsModal: false
    // item to give the keyboard focus back to when the onboarding closes
    property Item _restoreFocusItem: null

    // the client-side frame's shadow around the window
    readonly property real _outerMargin: MainCtx.windowExtendedMargin
    // the screens keep the Figma size; only a window that cannot grow enough scales them down
    readonly property real _fit: Math.max(0.1, Math.min(1, card.width / VLCStyle.rd_onboardingWidth,
                                                        card.height / VLCStyle.rd_onboardingHeight))

    function dp(px) {
        return VLCStyle.dp(px, VLCStyle.scale)
    }

    function openOnboarding() {
        if (visible)
            return
        helper.fitWindow(VLCStyle.rd_onboardingWidth + 2 * _outerMargin,
                         VLCStyle.rd_onboardingHeight + 2 * _outerMargin)
        mediaFolder = helper.defaultMediaFolder()
        page = 0
        const window = MainCtx.intfMainWindow
        _restoreFocusItem = (window && window.activeFocusItem) ? window.activeFocusItem : null
        open()
    }

    function next() {
        if (page < 2) {
            page += 1
            return
        }
        _finished = true
        helper.finish(MainCtx.mediaLibraryAvailable ? mediaFolder : "")
        close()
    }

    function back() {
        if (page > 0)
            page -= 1
    }

    function browse() {
        const folder = helper.browseMediaFolder(mediaFolder)
        if (folder !== "")
            mediaFolder = folder
    }

    OnboardingHelper {
        id: helper
        ctx: MainCtx
    }

    parent: T.Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    padding: 0
    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape

    // while open, keys go to the onboarding instead of VLC's hotkeys (RdPanels.modalCount)
    onAboutToShow: {
        if (!_holdsModal) {
            RdPanels.acquireModal()
            _holdsModal = true
        }
    }

    onOpened: nextButton.forceActiveFocus(Qt.OtherFocusReason)

    // the player takes the keyboard focus when its media starts, which can be after the onboarding
    // opened (first start with a file): the keys (Enter, Escape) stay here while it is open
    function _keepFocus() {
        const window = contentItem.Window.window
        if (opened && window && window.activeFocusItem && !contentItem.activeFocus)
            nextButton.forceActiveFocus(Qt.OtherFocusReason)
    }

    Connections {
        target: root.contentItem.Window.window
        enabled: root.opened

        function onActiveFocusItemChanged() {
            Qt.callLater(root._keepFocus)
        }
    }

    onAboutToHide: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
        // closed with Escape: the first-run wizard's close button
        if (!_finished) {
            _finished = true
            helper.skip()
        }
    }

    onClosed: {
        if (_restoreFocusItem && _restoreFocusItem.visible)
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
        _restoreFocusItem = null
        done()
    }

    Component.onDestruction: {
        if (_holdsModal)
            RdPanels.releaseModal()
    }

    onPageChanged: {
        if (!nextButton.activeFocus && !(page > 0 && backButton.activeFocus))
            nextButton.forceActiveFocus(Qt.OtherFocusReason)
    }

    // Motion (Decision 32 and the Figma prototype): no animation, every change is instant

    // no dim behind the dialog (Decision 41: the video and Figma show none); the transparent
    // overlay still takes the clicks outside the dialog
    T.Overlay.modal: Item { }

    background: null

    contentItem: FocusScope {
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Welcome")

        // Enter activates the focused control (Next / Finish by default)
        Keys.onPressed: (event) => {
            if ((event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                    || (event.modifiers & ~Qt.KeypadModifier))
                return
            event.accepted = true
            // holding Enter must not run through the screens
            if (event.isAutoRepeat)
                return
            const item = root.contentItem.Window.activeFocusItem
            if (item && item.visible && item.enabled && typeof item.clicked === "function")
                item.clicked()
            else
                root.next()
        }

        // Figma "Onboarding": the 1090 x 759 window in BG/B1 (its radius 14 and drop shadow are
        // the window's own frame)
        Rectangle {
            id: card

            anchors.fill: parent
            anchors.margins: root._outerMargin

            color: root.rdPalette.rdBgB1

            // it covers the title bar: with client-side decorations, dragging its background
            // moves the window and a double click maximizes it, like the title bar
            Loader {
                anchors.fill: parent
                active: MainCtx.clientSideDecoration
                source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"
            }

            // the screens at the Figma size, in the middle of a larger window
            Item {
                anchors.centerIn: parent
                width: VLCStyle.rd_onboardingWidth
                height: VLCStyle.rd_onboardingHeight
                scale: root._fit

                Loader {
                    anchors.fill: parent
                    visible: root.page === 0
                    sourceComponent: welcomePage
                }

                Loader {
                    anchors.fill: parent
                    visible: root.page === 1
                    // built in the background while the welcome screen shows; finished at once when shown
                    active: root.visible
                    asynchronous: root.page !== 1
                    sourceComponent: themePage
                }

                Loader {
                    anchors.fill: parent
                    visible: root.page === 2
                    active: root.visible
                    asynchronous: root.page !== 2
                    sourceComponent: shortcutsPage
                }
            }

            // Figma "Frame 140" / "Frame 141": 100 x 32, 8 apart, 62 from the window's right
            // edge and 56 from its bottom (x 820 / 928, y 671 of 1090 x 759), Inter 600 16
            Widgets.RdButton {
                id: backButton

                anchors.right: nextButton.left
                anchors.rightMargin: root.dp(8)
                anchors.bottom: nextButton.bottom
                visible: root.page > 0

                text: qsTr("Back")
                fontPixelSize: VLCStyle.rd_fontSize_header

                // RdButton's navigation takes Escape: close like the popup's Escape
                Navigation.cancelAction: () => root.close()

                onClicked: root.back()
            }

            Widgets.RdButton {
                id: nextButton

                anchors.right: parent.right
                anchors.rightMargin: root.dp(62) * root._fit
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.dp(56) * root._fit

                style: Widgets.RdButton.Style.Primary
                text: root.page === 2 ? qsTr("Finish") : qsTr("Next")
                fontPixelSize: VLCStyle.rd_fontSize_header

                Navigation.cancelAction: () => root.close()

                onClicked: root.next()
            }
        }
    }

    // ---------------------------------------------------------------- screen 1 (Figma 1899:3055)

    Component {
        id: welcomePage

        Item {
            Widgets.RdIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.dp(116)
                size: root.dp(141)
                name: Brand.logoIconLarge
                accentColor: root.rdPalette.rdAccentLogo
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.dp(286)
                height: root.dp(39)
                verticalAlignment: Text.AlignVCenter

                text: Brand.welcomeTitle
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_display
                font.weight: Font.Light
                color: root.rdPalette.rdFg1
            }

            Text {
                id: about

                x: root.dp(248)
                y: root.dp(362)
                width: root.dp(595)
                // Figma centers each line in its 28 px; Qt puts the extra space under it
                topPadding: Math.max(0, Math.round((lineHeight - aboutMetrics.height) / 2))

                text: Brand.welcomeText
                wrapMode: Text.WordWrap
                // Figma's unhinted widths: its first line is 590 of the 595 px
                font.hintingPreference: Font.PreferNoHinting
                lineHeightMode: Text.FixedHeight
                lineHeight: root.dp(28)
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                font.weight: Font.Light
                color: root.rdPalette.rdFgA1

                FontMetrics {
                    id: aboutMetrics
                    font: about.font
                }
            }

            // the media folder needs the media library
            Item {
                x: root.dp(248)
                y: root.dp(500)
                width: root.dp(595)
                height: root.dp(69)
                visible: MainCtx.mediaLibraryAvailable

                Text {
                    width: parent.width
                    height: root.dp(17)
                    verticalAlignment: Text.AlignVCenter

                    text: qsTr("Choose a Media Folder to get started with")
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: root.rdPalette.rdFgA2
                }

                // Figma "Frame 86": 471 x 36, BG/B2, 2 px BG/A4 border, radius 6, padding 12 / 18;
                // shows the folder, a click or Enter / Space opens the folder picker like Browse
                T.AbstractButton {
                    id: folderField

                    // the pointing hand over the clickable controls
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    y: root.dp(33)
                    width: root.dp(471)
                    height: root.dp(36)

                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: true

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Media folder: %1").arg(root.mediaFolder)
                    Accessible.onPressAction: folderField.clicked()

                    onClicked: root.browse()

                    background: Rectangle {
                        radius: VLCStyle.rd_radius_normal
                        color: root.rdPalette.rdBgB2
                        border.width: root.dp(2)
                        // accent only for keyboard focus, like RdTextField
                        border.color: folderField.visualFocus ? root.rdPalette.rdAccentMain
                                                              : (folderField.hovered ? root.rdPalette.rdDividerBright
                                                                                     : root.rdPalette.rdBgA4)
                    }

                    contentItem: Text {
                        leftPadding: root.dp(12)
                        rightPadding: root.dp(18)
                        verticalAlignment: Text.AlignVCenter

                        text: root.mediaFolder
                        elide: Text.ElideMiddle
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_header
                        color: root.rdPalette.rdFg2
                    }
                }

                // Figma "Frame 141": 114 x 35, BG/A3, Inter 400 16 FG/A2
                Widgets.RdButton {
                    x: root.dp(481)
                    y: root.dp(33.5)
                    width: root.dp(114)
                    height: root.dp(35)

                    text: qsTr("Browse")
                    fontPixelSize: VLCStyle.rd_fontSize_header
                    fontWeight: Font.Normal

                    Navigation.cancelAction: () => root.close()

                    onClicked: root.browse()
                }
            }
        }
    }

    // ---------------------------------------------------------------- screen 2 (Figma 1902:3670)

    component ThemeTile: T.AbstractButton {
        id: tile

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        // 0: light picture, 1: dark picture, 2: split (system)
        property int picture: 0

        implicitWidth: VLCStyle.dp(116, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(157, VLCStyle.scale)

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        Accessible.role: Accessible.RadioButton
        Accessible.name: tile.text
        Accessible.checked: tile.checked
        Accessible.onPressAction: tile.clicked()

        background: null

        contentItem: Item {
            // 116 x 116 frame, radius 19; selected: 4 px accent ring outside it
            Item {
                id: frame

                width: parent.width
                height: width

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -VLCStyle.dp(4, VLCStyle.scale)
                    visible: tile.checked
                    radius: VLCStyle.dp(23, VLCStyle.scale)
                    color: "transparent"
                    border.width: VLCStyle.dp(4, VLCStyle.scale)
                    border.color: VLCStyle.palette.rdAccentMain
                }

                // keyboard focus
                Rectangle {
                    anchors.fill: parent
                    visible: tile.visualFocus
                    radius: VLCStyle.dp(19, VLCStyle.scale)
                    color: "transparent"
                    border.width: VLCStyle.dp(1, VLCStyle.scale)
                    border.color: VLCStyle.palette.rdFg2
                }

                // 100 x 100 picture, radius 12
                Rectangle {
                    id: picture

                    anchors.centerIn: parent
                    width: VLCStyle.dp(100, VLCStyle.scale)
                    height: width
                    radius: VLCStyle.dp(12, VLCStyle.scale)
                    color: tile.picture === 0 ? VLCStyle.rd_themeTileLight : VLCStyle.rd_themeTileDark

                    // System: light right of a diagonal from 15.9 % of the top edge to 75.9 % of the
                    // bottom edge (Figma gradient with a hard stop at 50 %), drawn as the straight
                    // right part with the rounded corners plus an antialiased rotated rectangle cut
                    // to the triangle between the diagonal and that part
                    Item {
                        id: split

                        readonly property real angle: Math.atan(0.6)
                        readonly property real lineTop: picture.width * 0.159
                        readonly property real rightPart: Math.round(picture.width * 0.759)

                        anchors.fill: parent
                        visible: tile.picture === 2

                        Item {
                            x: split.rightPart
                            width: picture.width - x
                            height: picture.height
                            clip: true

                            Rectangle {
                                x: -split.rightPart
                                width: picture.width
                                height: picture.height
                                radius: picture.radius
                                color: VLCStyle.rd_themeTileLight
                            }
                        }

                        Item {
                            x: Math.floor(split.lineTop)
                            width: split.rightPart - x
                            height: picture.height
                            clip: true

                            Rectangle {
                                x: split.lineTop - parent.x
                                width: picture.width * 2
                                height: picture.height * 2
                                rotation: -split.angle * 180 / Math.PI
                                transformOrigin: Item.TopLeft
                                antialiasing: true
                                color: VLCStyle.rd_themeTileLight
                            }
                        }
                    }
                }
            }

            // label: 22 px under the frame, Inter 300 16, FG/A2
            Text {
                anchors.bottom: parent.bottom
                width: parent.width
                height: VLCStyle.dp(19, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                text: tile.text
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                font.weight: Font.Light
                color: VLCStyle.palette.rdFgA2
            }
        }
    }

    component Swatch: T.AbstractButton {
        id: swatch

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        property color swatchColor
        // the Custom swatch before a custom color exists: the spectrum (Cone extra)
        property bool spectrum: false

        implicitWidth: VLCStyle.dp(64, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(64, VLCStyle.scale)

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        Accessible.role: Accessible.RadioButton
        Accessible.name: swatch.text
        Accessible.checked: swatch.checked
        Accessible.onPressAction: swatch.clicked()

        background: null

        contentItem: Item {
            // Figma: the others at 50 % opacity; selected: 4 px ring of the color at 30 % (inside)
            Item {
                anchors.fill: parent
                opacity: swatch.checked ? 1 : 0.5

                Rectangle {
                    anchors.fill: parent
                    visible: swatch.checked
                    radius: width / 2
                    color: "transparent"
                    border.width: VLCStyle.dp(4, VLCStyle.scale)
                    border.color: Qt.alpha(swatch.swatchColor, 0.3)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(40, VLCStyle.scale)
                    height: width
                    radius: width / 2
                    color: swatch.swatchColor
                    gradient: swatch.spectrum ? spectrumGradient : null

                    Gradient {
                        id: spectrumGradient

                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#E15032" }
                        GradientStop { position: 0.25; color: "#C49E23" }
                        GradientStop { position: 0.5; color: "#19A234" }
                        GradientStop { position: 0.75; color: "#185DD3" }
                        GradientStop { position: 1.0; color: "#F052B3" }
                    }
                }
            }

            // keyboard focus
            Rectangle {
                anchors.fill: parent
                visible: swatch.visualFocus
                radius: width / 2
                color: "transparent"
                border.width: VLCStyle.dp(1, VLCStyle.scale)
                border.color: VLCStyle.palette.rdFg2
            }
        }
    }

    Component {
        id: themePage

        Item {
            // the player picture (Figma "Player" 1056 x 594 at 17, 19)
            OnboardingPreview {
                x: root.dp(17)
                y: root.dp(19)
                width: root.dp(1056)
                height: root.dp(594)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.dp(173)
                height: root.dp(42)
                verticalAlignment: Text.AlignVCenter

                text: qsTr("Select your preferred theme and color.")
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_title
                font.weight: Font.Light
                color: root.rdPalette.rdFgA1
            }

            // Light / Dark / System: VLC's color schemes Day / Night / System
            Row {
                id: tiles

                anchors.horizontalCenter: parent.horizontalCenter
                y: root.dp(286)
                spacing: root.dp(40)

                Repeater {
                    id: tileRepeater

                    model: [
                        { text: qsTr("Light"), scheme: ColorSchemeModel.Day },
                        { text: qsTr("Dark"), scheme: ColorSchemeModel.Night },
                        { text: qsTr("System"), scheme: ColorSchemeModel.System }
                    ]

                    ThemeTile {
                        required property var modelData
                        required property int index

                        picture: index
                        text: modelData.text
                        checked: helper.colorScheme === modelData.scheme

                        onClicked: helper.colorScheme = modelData.scheme

                        Keys.onLeftPressed: (event) => {
                            const item = tileRepeater.itemAt(index - 1)
                            if (item)
                                item.forceActiveFocus(Qt.TabFocusReason)
                        }
                        Keys.onRightPressed: (event) => {
                            const item = tileRepeater.itemAt(index + 1)
                            if (item)
                                item.forceActiveFocus(Qt.TabFocusReason)
                        }
                    }
                }
            }

            // the 9 accent colors (Decision 15): 64 x 64 from x 41, y 655; Figma's 16 px gaps are
            // 13 here, so the Custom swatch after them (Cone extra, CUSTOM_ACCENT_NOTES.md) still
            // ends 20 px before Back (x 820)
            Row {
                x: root.dp(41)
                y: root.dp(655)
                spacing: root.dp(13)

                Repeater {
                    id: swatchRepeater

                    model: VLCStyle.rd_accentOptions

                    Swatch {
                        required property var modelData
                        required property int index

                        swatchColor: modelData
                        text: [qsTr("Orange"), qsTr("Red"), qsTr("Olive"), qsTr("Green"), qsTr("Teal"),
                               qsTr("Blue"), qsTr("Purple"), qsTr("Pink"), qsTr("Gray")][index]
                        // no saved accent ("default") is the first color, VLC's orange
                        checked: MainCtx.accentColor.valid ? Qt.colorEqual(MainCtx.accentColor, modelData)
                                                           : index === 0

                        onClicked: MainCtx.accentColor = modelData

                        Keys.onLeftPressed: (event) => {
                            const item = swatchRepeater.itemAt(index - 1)
                            if (item)
                                item.forceActiveFocus(Qt.TabFocusReason)
                        }
                        Keys.onRightPressed: (event) => {
                            const item = swatchRepeater.itemAt(index + 1) ?? customSwatch
                            item.forceActiveFocus(Qt.TabFocusReason)
                        }
                    }
                }

                // Cone extra: the custom color, as in Settings (SettingsAccentPicker)
                Swatch {
                    id: customSwatch

                    property string lastCustom: String(MainCtx.settingValue(customEditor.lastCustomKey, ""))
                    readonly property bool custom: MainCtx.accentColor.valid
                                                   && !VLCStyle.rd_accentOptions.some((c) => Qt.colorEqual(MainCtx.accentColor, c))

                    swatchColor: custom ? MainCtx.accentColor : (lastCustom !== "" ? lastCustom : "transparent")
                    spectrum: !custom && lastCustom === ""
                    text: qsTr("Custom color")
                    checked: custom

                    onClicked: {
                        if (!custom && lastCustom !== "")
                            MainCtx.accentColor = lastCustom
                        if (!customEditor.opened)
                            customEditor.open()
                    }

                    Keys.onLeftPressed: (event) => {
                        swatchRepeater.itemAt(swatchRepeater.count - 1).forceActiveFocus(Qt.TabFocusReason)
                    }

                    // above the swatch: the row is near the window's bottom edge
                    Widgets.RdAccentEditor {
                        id: customEditor

                        x: (customSwatch.width - width) / 2
                        y: -height - VLCStyle.dp(8)

                        onCustomColorChanged: (value) => {
                            customSwatch.lastCustom = String(value).toUpperCase()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- screen 3 (Figma 1902:6770)

    // Figma keycap: 42 px tall, radius 12, BG/A3, 3 px Divider/Bright border, Inter 300 16 FG/1,
    // padding 20 (12 for arrows and punctuation) plus the border, drop shadow #5C5C5C 25% 6 px down
    component Keycap: Item {
        id: keycap

        property string text

        readonly property bool _symbol: text.length === 1 && !/[0-9A-Za-z]/.test(text)

        implicitWidth: label.implicitWidth + 2 * VLCStyle.dp(_symbol ? 15 : 23, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(42, VLCStyle.scale)

        Rectangle {
            y: VLCStyle.dp(6, VLCStyle.scale)
            width: parent.width
            height: parent.height
            radius: VLCStyle.dp(12, VLCStyle.scale)
            color: VLCStyle.palette.rdKeyShadow
        }

        Rectangle {
            anchors.fill: parent
            radius: VLCStyle.dp(12, VLCStyle.scale)
            color: VLCStyle.palette.rdBgA3
            border.width: VLCStyle.dp(3, VLCStyle.scale)
            border.color: VLCStyle.palette.rdDividerBright
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: keycap.text
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            font.weight: Font.Light
            color: VLCStyle.palette.rdFg1
        }
    }

    // keys of one row: groups of keycaps (4 px apart) separated by " / " (10 px each side)
    component KeyRow: Row {
        id: keyRow

        property var groups: []

        spacing: VLCStyle.dp(10, VLCStyle.scale)

        Repeater {
            model: keyRow.groups

            Row {
                required property var modelData
                required property int index

                spacing: VLCStyle.dp(10, VLCStyle.scale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: index > 0
                    text: "/"
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_header
                    font.weight: Font.Light
                    color: VLCStyle.palette.rdFgA1
                }

                Row {
                    spacing: VLCStyle.dp(4, VLCStyle.scale)

                    Repeater {
                        model: modelData

                        Keycap {
                            required property string modelData
                            text: modelData
                        }
                    }
                }
            }
        }
    }

    Component {
        id: shortcutsPage

        Item {
            id: shortcuts

            // keycap groups of a row: one key, or two keys shown as "A / B"; two keys with the
            // same modifiers show them once ("SHIFT ← / →")
            function groups(row) {
                if (row.key !== undefined)
                    return [helper.keycapsForKey(row.key)]
                const first = helper.keycaps(row.options[0])
                const second = row.options.length > 1 ? helper.keycaps(row.options[1]) : []
                if (first.length > 1 && first.length === second.length
                        && first.slice(0, -1).join("+") === second.slice(0, -1).join("+"))
                    return [first, second.slice(-1)]
                // an action without a key is left out
                return [first, second].filter((keys) => keys.length > 0)
            }

            // the rows of the design with VLC's actions; "Show / Hide Queue" is VLC's play queue
            // shortcut (Ctrl + L, menus/qml/GlobalShortcuts.qml)
            readonly property var leftRows: [
                { label: qsTr("Play / Pause"), options: ["key-play-pause"] },
                { label: qsTr("Seek Backward / Forward"), options: ["key-jump-extrashort", "key-jump+extrashort"] },
                { label: qsTr("Previous / Next Item"), options: ["key-prev", "key-next"] },
                { label: qsTr("Previous / Next Frame"), options: ["key-frame-previous", "key-frame-next"] },
                { label: qsTr("Cycle Subtitle Track"), options: ["key-subtitle-track"] },
                { label: qsTr("Cycle Audio Track"), options: ["key-audio-track"] }
            ]
            readonly property var rightRows: [
                { label: qsTr("Toggle Fullscreen"), options: ["key-toggle-fullscreen"] },
                { label: qsTr("Increase / Decrease Volume"), options: ["key-vol-up", "key-vol-down"] },
                { label: qsTr("Show / Hide Queue"), key: "Ctrl+l" },
                { label: qsTr("Mute / Unmute"), options: ["key-vol-mute"] },
                { label: qsTr("Take a Snapshot"), options: ["key-snapshot"] },
                { label: qsTr("Record"), options: ["key-record"] }
            ]

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.dp(60)
                height: root.dp(42)
                verticalAlignment: Text.AlignVCenter

                text: qsTr("Learn the basic keyboard shortcuts.")
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_title
                color: root.rdPalette.rdFgA1
            }

            // two blocks from x 62 (Figma "Frame 204"): label column 220, 20, keys column 153,
            // 150 between the blocks; wider keys or labels take the space between the blocks first
            Row {
                id: blocks

                readonly property real available: shortcuts.width - 2 * root.dp(62)

                x: root.dp(62)
                y: root.dp(154)
                spacing: {
                    let used = 0
                    for (let i = 0; i < blockRepeater.count; ++i) {
                        const item = blockRepeater.itemAt(i)
                        if (item)
                            used += item.implicitWidth
                    }
                    return Math.max(root.dp(40), Math.min(root.dp(150), available - used))
                }

                Repeater {
                    id: blockRepeater

                    model: 2

                    Row {
                        id: block

                        required property int index

                        readonly property var rows: index === 0 ? shortcuts.leftRows : shortcuts.rightRows

                        spacing: root.dp(20)

                        Column {
                            id: labels

                            readonly property real widest: {
                                let w = 0
                                for (let i = 0; i < labelRepeater.count; ++i) {
                                    const item = labelRepeater.itemAt(i)
                                    if (item)
                                        w = Math.max(w, item.implicitWidth)
                                }
                                return w
                            }

                            y: root.dp(7)
                            width: Math.max(root.dp(220), widest)
                            spacing: root.dp(54)

                            Repeater {
                                id: labelRepeater

                                model: block.rows

                                Text {
                                    required property var modelData

                                    height: root.dp(28)
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.label
                                    font.family: VLCStyle.rd_fontFamily
                                    font.pixelSize: VLCStyle.rd_fontSize_header
                                    font.weight: Font.Light
                                    color: root.rdPalette.rdFgA1
                                }
                            }
                        }

                        Column {
                            spacing: root.dp(40)

                            readonly property real widest: {
                                let w = root.dp(153)
                                for (let i = 0; i < keyRepeater.count; ++i) {
                                    const item = keyRepeater.itemAt(i)
                                    if (item)
                                        w = Math.max(w, item.implicitWidth)
                                }
                                return w
                            }

                            width: widest

                            Repeater {
                                id: keyRepeater

                                model: block.rows

                                KeyRow {
                                    required property var modelData

                                    height: root.dp(42)
                                    groups: shortcuts.groups(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                x: root.dp(62)
                y: root.dp(671)
                width: root.dp(700)
                height: root.dp(28)
                verticalAlignment: Text.AlignVCenter

                text: qsTr("Find the full list in the menu.")
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: root.rdPalette.rdFgA3
            }
        }
    }
}
