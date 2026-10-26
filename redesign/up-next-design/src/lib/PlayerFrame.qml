import QtQuick
// Cone's player (Figma "Player", 1920x1080): 40 px top bar, video, 54 px control bar.
// Overlays (the Up Next card, the prompt) go into `overlay`, positioned over the video area.
Rectangle {
    id: root
    width: 1920; height: 1080
    color: T.bgB1
    property string folderName: "Season 1"
    property string title: "The Wand S01E01"
    property string subtitle: ""
    property real position: 0.962
    property string time: "00:24:42"
    property string duration: "00:25:40"
    property url frame: ASSETS + "frame_ep1.png"
    property bool showBars: true
    // the subtitle band: 2 lines at the subtitle size above the control bar (sub margin)
    readonly property int subBandTop: videoArea.y + videoArea.height - 40 - 2 * 58
    readonly property alias videoArea: videoArea
    default property alias overlay: overlayLayer.data

    Rectangle {
        id: videoArea
        x: 0; y: showBars ? 40 : 0
        width: parent.width; height: parent.height - (showBars ? 94 : 0)
        color: "black"
        Image { anchors.fill: parent; source: root.frame; fillMode: Image.PreserveAspectCrop }
        // VLC's subtitles: white, outlined, centred, above the control bar
        Text {
            visible: root.subtitle !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 40
            width: parent.width * 0.7
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            text: root.subtitle
            font.family: "Inter"; font.pixelSize: 48; font.weight: Font.Medium
            color: "white"; style: Text.Outline; styleColor: "black"
        }
    }

    // top bar (Figma "topbar": 40 px, BG/A3)
    Rectangle {
        visible: root.showBars
        width: parent.width; height: 40; color: T.bgA3
        Ico { x: 16; y: 8; name: "cone"; c1: T.accent }
        Ico { x: 52; y: 8; name: "more"; c1: T.fgA2 }
        Ico { x: 90; y: 8; name: "sidebar_direction-left"; c1: T.fgA2 }
        Rectangle { x: 128; y: 10; width: 1; height: 20; color: T.divBright }
        Ico { x: 142; y: 8; name: "folder"; c1: T.fgA2 }
        Txt { x: 172; anchors.verticalCenter: parent.verticalCenter; text: root.folderName; color: T.fgA2 }
        Txt { anchors.centerIn: parent; text: root.title; color: T.fgA2 }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Ico { name: "minimize"; c1: T.fgA2 } Ico { name: "maximize"; c1: T.fgA2 }
            Ico { name: "fullscreen"; c1: T.fgA2 } Ico { name: "close"; c1: T.fgA2 }
        }
    }

    // control bar (Figma Controls "default": 1920x54)
    Rectangle {
        id: bar
        visible: root.showBars
        y: parent.height - 54; width: parent.width; height: 54; color: T.bgA3
        Ico { x: 23; y: 15; name: "previous"; c1: T.fgA2 }
        Rectangle { x: 58; y: 13; width: 54; height: 28; radius: 6; color: T.accent
            Ico { anchors.centerIn: parent; name: "pause"; c1: T.fgB1; size: 20 } }
        Ico { x: 123; y: 15; name: "next"; c1: T.fgA2 }
        Txt { x: 172; anchors.verticalCenter: parent.verticalCenter; text: root.time; font.pixelSize: 15; color: T.fgA2 }
        Rectangle {
            id: seek
            x: 254; y: 13; width: 1236; height: 28; radius: 4; color: T.bgB2
            Rectangle { x: 2; y: 2; width: (seek.width - 4) * root.position; height: 24; radius: 4; color: T.bgAccentBright }
            Rectangle { x: 2 + (seek.width - 4) * root.position - 4; y: 2; width: 8; height: 24; radius: 4; color: T.accent }
        }
        Txt { x: 1505; anchors.verticalCenter: parent.verticalCenter; text: root.duration; font.pixelSize: 15; color: T.fgA2 }
        Ico { x: 1598; y: 15; name: "volume_value-high"; c1: T.fgA2 }
        Rectangle { x: 1630; y: 17; width: 88; height: 20; radius: 3; color: T.bgB2
            Rectangle { width: 40; height: 20; radius: 3; color: T.fgA4 } }
        Ico { x: 1744; y: 15; name: "audio"; c1: T.fgA2 }
        Ico { x: 1788; y: 15; name: "subtitles"; c1: T.fgA2 }
        Ico { x: 1832; y: 15; name: "settings"; c1: T.fgA2 }
        Ico { x: 1876; y: 15; name: "queue"; c1: T.fgA2 }
    }

    Item { id: overlayLayer; anchors.fill: parent }
}
