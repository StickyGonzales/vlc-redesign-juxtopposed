import QtQuick
// Figma "Toggle": 68x32 radius 6 BG/B2; ON: label box 33x26 BG/Accent Bright + knob 26x26 Accent/DIm
Rectangle {
    property bool on: false
    width: 68; height: 32; radius: 6; color: T.bgB2
    Rectangle { x: on ? 3 : 32; y: 3; width: 33; height: 26; radius: 3
                color: on ? T.bgAccentBright : T.bgA4
                Txt { anchors.centerIn: parent; text: on ? "ON" : "OFF"; font.pixelSize: 12
                      color: on ? T.accent : T.fgA3 } }
    Rectangle { x: on ? 39 : 3; y: 3; width: 26; height: 26; radius: 3
                color: on ? T.accentDim : T.fgA4 }
}
