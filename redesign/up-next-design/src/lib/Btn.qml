import QtQuick
// RdButton: 32 high, radius 6, Inter 600 14, 8 px side padding, min width 100
Rectangle {
    id: b
    property string text
    property bool primary: false
    property bool hovered: false
    property bool focused: false
    // on a BG/A3 card (toast, Up Next): BG/A1 like the resume toast's close button
    property bool onCard: false
    property string icon: ""
    property int minWidth: 100
    implicitWidth: Math.max(minWidth, row.implicitWidth + 2 * 12)
    implicitHeight: 32
    width: implicitWidth; height: implicitHeight
    radius: 6
    color: primary ? (hovered ? T.accentBright : T.accent)
                   : (T.isDark ? (hovered ? T.bgA2 : (onCard ? T.bgA1 : T.bgA3)) : (hovered ? T.fgA1 : T.fgA2))
    border.width: focused ? 1 : 0
    border.color: T.isDark ? T.fg2 : T.accent
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Ico { visible: b.icon !== ""; name: b.icon; size: 20; anchors.verticalCenter: parent.verticalCenter
              c1: b.primary ? T.fgB1 : (T.isDark ? T.fgA2 : T.bgA1); c2: c1 }
        Txt { text: b.text; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
              color: b.primary ? T.fgB1 : (T.isDark ? T.fgA2 : T.bgA1) }
    }
}
