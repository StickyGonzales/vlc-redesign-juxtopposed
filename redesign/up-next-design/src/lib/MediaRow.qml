import QtQuick
// Figma "media" row: 32x32 thumbnail (radius 2) with an accent progress line along its foot, the
// file name at x 42: watched FG/A3, unwatched FG/A1, the playing one in the accent.
// New: the next episode gets an "Up next" tag on the right.
Item {
    id: r
    property string name
    property int thumb: 0
    property real progress: 0      // 0 unwatched, 1 watched
    property bool playing: false
    property bool next: false
    width: 337; height: 32
    Rectangle { width: 32; height: 32; radius: 2; color: "#303030"; clip: true
        Image { anchors.fill: parent; source: ASSETS + "t" + r.thumb + ".png"; fillMode: Image.PreserveAspectCrop }
        Rectangle { visible: r.progress > 0; anchors.bottom: parent.bottom; width: parent.width * r.progress; height: 3; color: T.accent } }
    Txt { x: 42; anchors.verticalCenter: parent.verticalCenter; text: r.name
          color: r.playing ? T.accent : (r.progress >= 1 ? T.fgA3 : T.fgA1) }
    Ico { visible: r.playing; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          name: "volume_value-high"; c1: T.accent; size: 20 }
    Rectangle {
        visible: r.next
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        height: 22; width: tag.implicitWidth + 14; radius: 4; color: T.bgAccentBright
        Txt { id: tag; anchors.centerIn: parent; text: "Up next"; font.pixelSize: 12; font.weight: Font.DemiBold; color: T.accent }
    }
}
