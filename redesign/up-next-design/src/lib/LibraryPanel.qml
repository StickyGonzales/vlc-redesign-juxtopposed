import QtQuick
// Compact library (Figma sidebar "videos3" + "Player - Light" list): 50 px rail + 377 px panel.
Rectangle {
    id: lib
    property bool unwatchedFirst: false
    property string caption: ""
    width: 427; height: 560; color: T.bgB1
    Rectangle { width: 50; height: parent.height; color: T.bgA4
        Column { x: 13; y: 12; spacing: 22
            Ico { name: "home"; c1: T.fgA2 } Ico { name: "videos"; c1: T.fg2 } Ico { name: "songs"; c1: T.fgA2 }
            Ico { name: "streaming"; c1: T.fgA2 } Ico { name: "playlist"; c1: T.fgA2 } Ico { name: "recent"; c1: T.fgA2 }
            Ico { name: "add"; c1: T.fgA2 } } }
    Item {
        x: 50; width: 377; height: parent.height
        Ico { x: 20; y: 20; name: "arrow_direction-left"; c1: T.fgA2 }
        Ico { x: 56; y: 20; name: "arrow_direction-right"; c1: T.fgA4 }
        Row { x: 92; y: 22; spacing: 6
            Txt { text: "…"; color: T.fgA2; font.pixelSize: 16 } Txt { text: "▸"; color: T.fgA3; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: "The Wand"; color: T.fgA2; font.pixelSize: 16 } Txt { text: "▸"; color: T.fgA3; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: "Season 1"; color: T.fgA3; font.pixelSize: 16 } }
        Ico { x: 296; y: 20; name: "more"; c1: T.fgA2 } Ico { x: 332; y: 20; name: "window"; c1: T.fgA2 }
        Txt { x: 20; y: 66; text: "9 items"; color: T.fgA3 }
        Ico { x: 260; y: 62; name: "sort"; c1: T.fgA2 }
        Rectangle { visible: lib.unwatchedFirst; x: 282; y: 61; width: 6; height: 6; radius: 3; color: T.accent }
        Ico { x: 296; y: 62; name: "view"; c1: T.fgA2 } Ico { x: 332; y: 62; name: "search"; c1: T.fgA2 }
        Rectangle { x: 20; y: 100; width: 337; height: 1; color: T.divBright }
        Column {
            x: 20; y: 116; spacing: 10
            Repeater {
                model: lib.unwatchedFirst
                       ? [["The_Wand_S01E05.mp4",4,0,0,1],["The_Wand_S01E06.mp4",5,0,0,0],["The_Wand_S01E07.mp4",0,0,0,0],["The_Wand_S01E08.mp4",1,0,0,0],["The_Wand_S01E09.mp4",2,0,0,0],
                          ["The_Wand_S01E01.mp4",0,1,0,0],["The_Wand_S01E02.mp4",1,1,0,0],["The_Wand_S01E03.mp4",2,1,0,0],["The_Wand_S01E04.mp4",3,0.97,1,0]]
                       : [["The_Wand_S01E01.mp4",0,1,0,0],["The_Wand_S01E02.mp4",1,1,0,0],["The_Wand_S01E03.mp4",2,1,0,0],["The_Wand_S01E04.mp4",3,0.97,1,0],
                          ["The_Wand_S01E05.mp4",4,0,0,1],["The_Wand_S01E06.mp4",5,0,0,0],["The_Wand_S01E07.mp4",0,0,0,0],["The_Wand_S01E08.mp4",1,0,0,0],["The_Wand_S01E09.mp4",2,0,0,0]]
                MediaRow { required property var modelData
                           name: modelData[0]; thumb: modelData[1]; progress: modelData[2]; playing: modelData[3] === 1; next: modelData[4] === 1 }
            }
        }
        Txt { x: 20; y: parent.height - 30; text: lib.caption; color: T.fgA3; font.pixelSize: 12 }
    }
}
