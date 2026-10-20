import QtQuick
// Figma "Dropdown": 364x48 radius 6 BG/B2 frame, 360x44 option radius 4 BG/A4, Inter 14 FG/A2, chevron
Rectangle {
    id: dd
    property string text
    property var options: []
    property int current: 0
    property int hover: -1
    property bool open: false
    width: 364; height: open ? options.length * 46 + 4 : 48
    radius: 6; color: T.bgB2
    Column {
        x: 2; y: 2; spacing: 2
        Repeater {
            model: dd.open ? dd.options : [dd.text]
            Rectangle {
                required property int index
                required property var modelData
                width: dd.width - 4; height: 44; radius: 4
                color: dd.open ? (index === dd.hover ? T.bgA2 : T.bgA4) : T.bgA4
                Txt { x: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: T.fgA2
                      font.weight: (dd.open && index === dd.current) ? Font.DemiBold : Font.Normal }
                Ico { visible: !dd.open || index === dd.current; anchors.right: parent.right; anchors.rightMargin: 12
                      anchors.verticalCenter: parent.verticalCenter
                      name: dd.open ? "check_state-selected" : "chevron_direction-down"
                      c1: dd.open ? T.accent : T.fgA2 }
            }
        }
    }
}
