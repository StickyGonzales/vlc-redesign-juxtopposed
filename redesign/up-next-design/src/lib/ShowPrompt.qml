import QtQuick
// "Looks like a show" prompt: the resume toast's look (radius 16, BG/A3, padding 10/10/10/20,
// Inter 16 FG/2, 60 px to the buttons, Yes primary + No), with the show icon and the show name.
Rectangle {
    id: p
    property string showName: "The Wand"
    property bool yesFocused: true
    width: row.implicitWidth + 20 + 10; height: 64
    radius: 16; color: T.bgA3
    Row {
        id: row
        x: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 14
        Ico { name: "tv"; c1: T.accent; c2: T.accentDim; anchors.verticalCenter: parent.verticalCenter }
        Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Txt { text: "Looks like a show. Play episodes in a row?"; font.pixelSize: 16; color: T.fg2 }
            Txt { text: p.showName + " · you can change this in the Playback tab"; font.pixelSize: 13; color: T.fgA3 }
        }
        Item { width: 46; height: 1 }
        Btn { primary: true; text: "Yes"; minWidth: 72; focused: p.yesFocused; anchors.verticalCenter: parent.verticalCenter }
        Btn { onCard: true; text: "No"; minWidth: 72; anchors.verticalCenter: parent.verticalCenter }
    }
}
