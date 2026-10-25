import QtQuick
// Variant C: the resume toast's pill (radius 16, BG/A3, 52 high): small thumbnail, one line of
// text, Play now and a dark close button (44x32, like the toast's), countdown line inside the foot.
Rectangle {
    id: c
    property string episode: "S01E02 · The Second Spark"
    property int seconds: 8
    property int total: 10
    property url thumb: ASSETS + "thumb_ep2.png"
    width: row.implicitWidth + 10 + 10; height: 60
    radius: 16; color: T.bgA3
    Row {
        id: row
        x: 10; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -1; spacing: 12
        Rectangle { width: 64; height: 36; radius: 4; color: "black"; clip: true; anchors.verticalCenter: parent.verticalCenter
            Image { anchors.fill: parent; source: c.thumb; fillMode: Image.PreserveAspectCrop } }
        Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Txt { text: "Up next in " + c.seconds + " s"; font.pixelSize: 12; font.weight: Font.DemiBold; color: T.accent }
            Txt { text: c.episode; font.pixelSize: 15; color: T.fg2 }
        }
        Item { width: 28; height: 1 }
        Btn { primary: true; icon: "play"; text: "Play now"; minWidth: 112; anchors.verticalCenter: parent.verticalCenter }
        Rectangle { width: 44; height: 32; radius: 6; color: T.bgA1; anchors.verticalCenter: parent.verticalCenter
            Ico { anchors.centerIn: parent; name: "close"; c1: T.fgA2 } }
    }
    CountLine { x: 16; width: c.width - 32; y: c.height - 6; height: 2; progress: c.seconds / c.total }
}
