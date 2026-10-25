import QtQuick
// Settings dialog, Playback page (Figma "Settings - playback": 1048 wide, 50 px header BG/B2,
// nav 216, content x 240, headings Inter 16 500 FG/2, labels Inter 14 FG/A2, dropdown 320x36 at
// x 704, toggle 68x32 at x 956, info icon after the label). New section "Episodes" after "Order".
Rectangle {
    id: sp
    property string mode: "Ask for each show"
    property bool modeOpen: false
    property real depOpacity: mode === "Off" ? 0.3 : 1
    width: 1048; height: 865; radius: 14; color: T.bgB1; clip: true
    Rectangle { width: 1048; height: 50; color: T.bgB2
        Rectangle { x: 8; y: 8; width: 200; height: 34; radius: 6; color: T.isDark ? "#151515" : T.bgA2
            Ico { x: 10; y: 5; name: "search"; c1: T.fgA4 } Txt { x: 42; anchors.verticalCenter: parent.verticalCenter; text: "Search"; color: T.fgA4 } }
        Txt { x: 240; anchors.verticalCenter: parent.verticalCenter; text: "Playback Preferences"; font.pixelSize: 16; color: T.fgA1 }
        Ico { x: 1012; y: 13; name: "close"; c1: T.fgA2 } }
    Rectangle { x: 8; y: 58; width: 200; height: 799; radius: 6; color: T.bgA4
        Column { x: 0; y: 10; spacing: 0
            Repeater { model: [["","App"],["preferences","General"],["interface","Interface"],["privacy","Privacy"],["hotkeys","Controls"],["","Media"],
                               ["playback","Playback"],["video","Video"],["audio","Audio"],["subtitles","Subtitles"],["folder","Library"],["","System"],
                               ["streaming","Network"],["preferences","Performance"],["record","Recording"],["plugins","Extensions"]]
                Item { required property var modelData; width: 200; height: 48
                    Rectangle { visible: modelData[1] === "Playback"; x: 6; y: 4; width: 188; height: 40; radius: 2; color: T.bgA1 }
                    Ico { visible: modelData[0] !== ""; x: 16; anchors.verticalCenter: parent.verticalCenter; name: modelData[0]
                          c1: modelData[1] === "Playback" ? T.accent : T.fgA2 }
                    Txt { x: modelData[0] === "" ? 16 : 50; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]
                          color: modelData[0] === "" ? T.fgA3 : (modelData[1] === "Playback" ? T.fg1 : T.fgA2) } } } } }
    component Label: Row { property string text; spacing: 8
        Txt { text: parent.text; color: T.fgA2; anchors.verticalCenter: parent.verticalCenter }
        Ico { name: "info"; size: 18; c1: T.fgA3; anchors.verticalCenter: parent.verticalCenter } }
    component DD: Rectangle { property string text; width: 320; height: 36; radius: 6; color: T.bgB2
        Rectangle { x: 2; y: 2; width: 316; height: 32; radius: 4; color: T.bgA4
            Txt { x: 14; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.text; color: T.fgA2 }
            Ico { x: 284; anchors.verticalCenter: parent.verticalCenter; name: "chevron_direction-down"; c1: T.fgA2; size: 20 } } }
    Item {
        x: 240; y: 50; width: 784; height: 815
        Txt { y: 30; text: "Order"; font.pixelSize: 16; font.weight: Font.Medium; color: T.fg2 }
        Label { y: 70; text: "Repeat" }                       DD { x: 464; y: 61; text: "Off" }
        Label { y: 116; text: "Shuffle" }                     Toggle { x: 716; y: 108 }
        Label { y: 162; text: "Stop after each item" }        Toggle { x: 716; y: 154 }
        Label { y: 208; text: "When playback finishes" }      DD { x: 464; y: 199; text: "Stop" }
        Txt { y: 270; text: "Episodes"; font.pixelSize: 16; font.weight: Font.Medium; color: T.fg2 }
        Label { y: 310; text: "Autoplay next episode" }       DD { id: modeDD; x: 464; y: 301; text: sp.mode }
        Txt { y: 334; width: 440; wrapMode: Text.Wrap; font.pixelSize: 12; color: T.fgA3
              text: "Plays the next episode of a show folder when one ends. Single videos, clips and music are never treated as shows." }
        Item { opacity: sp.depOpacity; y: 0; width: 784; height: 815
            Label { y: 386; text: "Countdown" }                    DD { x: 464; y: 377; text: "10 seconds" }
            Label { y: 432; text: "Show Up Next" }                 DD { x: 464; y: 423; text: "At the end of the episode" }
            Label { y: 478; text: "Ask if I'm still watching after 3 episodes" } Toggle { x: 716; y: 470; on: true }
            Label { y: 524; text: "Remembered shows" }
            Row { x: 464; y: 515; spacing: 10
                Txt { text: "4 shows: 3 autoplay, 1 never"; color: T.fgA3; anchors.verticalCenter: parent.verticalCenter }
                Btn { onCard: true; text: "Forget all"; minWidth: 100 } }
        }
        Txt { y: 590; text: "Seeking"; font.pixelSize: 16; font.weight: Font.Medium; color: T.fg2 }
        Label { y: 630; text: "Seek precisely" }              Toggle { x: 716; y: 622; on: true }
        Label { y: 676; text: "Show thumbnail while scrubbing" } Toggle { x: 716; y: 668; on: true }
        Rectangle { visible: sp.modeOpen; x: 464; y: 301; width: 320; height: 3 * 34 + 4; radius: 6; color: T.bgB2
            Column { x: 2; y: 2; spacing: 0
                Repeater { model: ["Off", "Ask for each show", "Always"]
                    Rectangle { required property var modelData; required property int index; width: 316; height: 34; radius: 4
                        color: index === 2 ? T.bgA2 : T.bgA4
                        Txt { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: T.fgA2
                              font.weight: modelData === sp.mode ? Font.DemiBold : Font.Normal }
                        Ico { visible: modelData === sp.mode; x: 284; anchors.verticalCenter: parent.verticalCenter
                              name: "check_state-selected"; c1: T.accent; size: 20 } } } } }
    }
}
