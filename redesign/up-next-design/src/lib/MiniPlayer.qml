import QtQuick
// Cone's mini player (RdMiniPlayer.qml): card 391 wide, picture 375x211 at 8,8, radius 14, BG/A3; video inset 8 with radius 10, seek bar,
// title, folder row. The compact Up Next strip sits on the video's foot.
Rectangle {
    id: m
    property bool upNext: true
    property int seconds: 6
    property int total: 10
    width: 391; height: 330; radius: 14; color: T.bgA3
    Rectangle {
        id: vid
        x: 8; y: 8; width: 375; height: 211; radius: 10; color: "black"; clip: true
        Image { anchors.fill: parent; source: ASSETS + "frame_ep1.png"; fillMode: Image.PreserveAspectCrop }
        Rectangle {
            visible: m.upNext
            x: 8; width: parent.width - 16; height: 52; y: parent.height - height - 8; radius: 8
            color: T.bgA3
            Row {
                x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Rectangle { width: 64; height: 36; radius: 4; clip: true; color: "black"; anchors.verticalCenter: parent.verticalCenter
                    Image { anchors.fill: parent; source: ASSETS + "thumb_ep2.png"; fillMode: Image.PreserveAspectCrop } }
                Column {
                    width: 177; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Txt { text: "Up next in " + m.seconds + " s"; font.pixelSize: 12; font.weight: Font.DemiBold; color: T.accent }
                    Txt { text: "S01E02 · The Second Spark"; font.pixelSize: 13; color: T.fg2; elide: Text.ElideRight; width: parent.width }
                }
                Rectangle { width: 32; height: 32; radius: 6; color: T.accent; anchors.verticalCenter: parent.verticalCenter
                    Ico { anchors.centerIn: parent; name: "play"; size: 20; c1: T.fgB1 } }
                Rectangle { width: 32; height: 32; radius: 6; color: T.bgA1; anchors.verticalCenter: parent.verticalCenter
                    Ico { anchors.centerIn: parent; name: "close"; size: 20; c1: T.fgA2 } }
            }
            CountLine { x: 8; width: parent.width - 16; y: parent.height - 4; height: 2; progress: m.seconds / m.total }
        }
    }
    Rectangle { x: 8; y: 227; width: 375; height: 16; radius: 4; color: T.bgB2
        Rectangle { x: 2; y: 2; width: 360; height: 12; radius: 3; color: T.bgAccentBright } }
    Txt { x: 16; y: 258; text: "The Wand S01E01"; font.pixelSize: 16; color: T.fgA2 }
    Row { x: 16; y: 290; spacing: 8
        Ico { name: "folder"; c1: T.fgA2 } Txt { text: "Season 1"; color: T.fgA2; anchors.verticalCenter: parent.verticalCenter } }
    Ico { x: 351; y: 290; name: "queue"; c1: T.fgA2 }
}
