import QtQuick
// Settings side panel, Playback tab (Figma Controls "playback": 400 wide, radius 10, BG/B1,
// 50 px tab bar BG/B2, rows: label Inter 14 FG/A3 at x 24, toggle 68x32 at x 312).
// New row under Sleep Timer: "Autoplay this show" with the show's folder under the label.
Rectangle {
    id: pp
    property int autoplay: 1          // 1 on, 0 off, -1 hidden (not a show)
    property string showName: "The Wand"
    property string sleep: "Off"
    property bool sleepOpen: false
    property string note: ""
    width: 400; height: 640; radius: 10; color: T.bgB1; clip: true
    Rectangle { width: 400; height: 50; color: T.bgB2; radius: 10
        Rectangle { y: 40; width: 400; height: 10; color: T.bgB2 }
        Row { x: 14; y: 13; spacing: 18
            Repeater { model: [["playback_two-tone-yes","Playback"],["video","Video"],["audio","Audio"],["subtitles","Subtitles"]]
                Row { required property var modelData; required property int index; spacing: 8
                    Ico { name: modelData[0]; c1: index === 0 ? T.fgA2 : T.fgA3; c2: T.accent }
                    Txt { text: modelData[1]; font.pixelSize: 12; color: index === 0 ? T.fgA2 : T.fgA3; anchors.verticalCenter: parent.verticalCenter } } } }
        Rectangle { x: 14; y: 48; width: 92; height: 2; color: T.accent } }
    Column {
        y: 51; width: 400
        Repeater { model: ["Show Waveform on Seekbar", "Show Metadata", "Show Statistics"]
            Item { required property var modelData; width: 400; height: 52
                Txt { x: 24; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: T.fgA3 }
                Toggle { x: 312; anchors.verticalCenter: parent.verticalCenter; on: false } } }
        Item { width: 400; height: 78
            Txt { x: 24; y: 25; text: "Sleep Timer"; color: T.fgA3 }
            Dropdown { x: 160; y: 14; width: 220; text: pp.sleep } }
        Item {
            visible: pp.autoplay >= 0
            width: 400; height: 62
            Column { x: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                Txt { text: "Autoplay this show"; color: T.fgA3 }
                Row { spacing: 6
                    Ico { name: "tv"; size: 16; c1: T.fgA4; c2: T.accentDim }
                    Txt { text: pp.showName; font.pixelSize: 12; color: T.fgA4; anchors.verticalCenter: parent.verticalCenter } } }
            Toggle { x: 312; anchors.verticalCenter: parent.verticalCenter; on: pp.autoplay === 1 } }
        Item { width: 400; height: 68
            Txt { x: 24; y: 25; text: "Audio Visualizer"; color: T.fgA3 }
            Dropdown { x: 160; y: 10; width: 220; text: "Disabled" } }
        Item { width: 400; height: 126
            Txt { x: 24; y: 13; text: "Speed"; color: T.fgA3 }
            Rectangle { x: 230; y: 0; width: 150; height: 44; radius: 6; color: T.bgB2
                Txt { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "1x"; color: T.fgA3 } }
            Rectangle { x: 20; y: 62; width: 360; height: 16; radius: 2; color: T.bgB2
                Rectangle { x: 2; y: 2; width: 150; height: 12; radius: 4; color: T.bgAccentBright }
                Rectangle { x: 148; y: -4; width: 8; height: 24; radius: 4; color: T.accentDim } }
            Row { x: 22; y: 92; spacing: 24
                Repeater { model: ["0.25","0.5","0.75","1","1.25","1.5","1.75","2"]
                    Txt { required property var modelData; text: modelData; font.pixelSize: 12; color: T.fgA3; width: 21 } } } }
    }
    Dropdown { visible: pp.sleepOpen; x: 160; y: 51 + 3 * 52 + 14; width: 220; open: true; current: 0; hover: 2
               options: ["Off", "15 min", "30 min", "45 min", "60 min", "End of current file"] }
    Txt { x: 24; y: parent.height - 30; text: pp.note; font.pixelSize: 12; color: T.fgA3 }
}
