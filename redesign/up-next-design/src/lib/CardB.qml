import QtQuick
// Variant B: thumbnail first, 320 wide, radius 14; the countdown sits on the picture
// ("Up next" chip top left, line along the picture's foot), text and two equal buttons under it.
Rectangle {
    id: c
    property string showName: "The Wand"
    property string episode: "S01E02 · The Second Spark"
    property int seconds: 8
    property int total: 10
    property url thumb: ASSETS + "thumb_ep2.png"
    width: 320; height: 10 + 168 + 12 + info.implicitHeight + 14 + 32 + 10
    radius: 14; color: T.bgA3
    Rectangle {
        id: pic
        x: 10; y: 10; width: 300; height: 168; radius: 10; color: "black"; clip: true
        Image { anchors.fill: parent; source: c.thumb; fillMode: Image.PreserveAspectCrop }
        Rectangle { x: 10; y: 10; height: 24; width: chip.implicitWidth + 16; radius: 4; color: "#CC090909"
            Txt { id: chip; anchors.centerIn: parent; text: "Up next · " + c.seconds + " s"; font.pixelSize: 12
                  font.weight: Font.DemiBold; color: "#FC9729" } }
        CountLine { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    progress: c.seconds / c.total; radius: 0 }
    }
    Column {
        id: info
        x: 14; y: pic.y + pic.height + 12; width: 292; spacing: 3
        Txt { text: c.showName; color: T.fgA2 }
        Txt { text: c.episode; font.pixelSize: 16; font.weight: Font.Medium; color: T.fg2; elide: Text.ElideRight; width: parent.width }
    }
    Row {
        x: 10; y: info.y + info.implicitHeight + 14; spacing: 10
        Btn { primary: true; icon: "play"; text: "Play now"; minWidth: 145 }
        Btn { onCard: true; text: "Cancel"; minWidth: 145 }
    }
}
