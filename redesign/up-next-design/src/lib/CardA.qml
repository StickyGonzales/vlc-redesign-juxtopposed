import QtQuick
// Variant A (recommended): side panel width (400), radius 14 (rd_radius_large, like the mini player
// and the thumbnail card), BG/A3, 12 px padding; 16:9 thumbnail 160x90 left, text right, buttons
// under, countdown line along the bottom.
Rectangle {
    id: c
    property string mode: "next"          // next | still | season
    property string showName: "The Wand"
    property string episode: "S01E02 · The Second Spark"
    property int seconds: 8
    property int total: 10
    property url thumb: ASSETS + "thumb_ep2.png"
    property bool playHovered: false
    property bool playFocused: false
    width: 400
    radius: 14; color: T.bgA3
    Row {
        id: top
        x: 12; y: 12; spacing: 14
        Rectangle {
            width: 160; height: 90; radius: 6; color: "black"; clip: true
            visible: c.mode !== "still"
            Image { anchors.fill: parent; source: c.thumb; fillMode: Image.PreserveAspectCrop }
            Rectangle { anchors.centerIn: parent; width: 36; height: 36; radius: 18; color: "#99000000"
                Ico { anchors.centerIn: parent; name: "play"; c1: "#EAEAEA"; size: 20 } }
        }
        Column {
            id: col
            width: c.mode === "still" ? 376 : 202; spacing: 4
            Txt { text: c.mode === "still" ? "Still watching?" : (c.mode === "season" ? "Up next · Season 2" : "Up next")
                  font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.4; color: T.accent }
            Txt { text: c.showName; color: T.fgA2; elide: Text.ElideRight; width: parent.width }
            Txt { text: c.episode; font.pixelSize: 16; font.weight: Font.Medium; color: T.fg2
                  wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; width: parent.width }
            Txt { text: c.mode === "still" ? "Playback paused after 3 episodes in a row."
                                           : "Playing in " + c.seconds + " s"
                  font.pixelSize: 13; color: T.fgA3; topPadding: 2 }
        }
    }
    Row {
        x: 12; y: (c.mode === "still" ? col.implicitHeight : Math.max(90, col.implicitHeight)) + 24
        spacing: 10
        Btn { primary: true; icon: c.mode === "still" ? "" : "play"; text: c.mode === "still" ? "Keep watching" : "Play now"
              hovered: c.playHovered; focused: c.playFocused; minWidth: 120 }
        Btn { onCard: true; text: c.mode === "still" ? "Stop" : "Cancel"; minWidth: 100 }
    }
    height: (c.mode === "still" ? col.implicitHeight : Math.max(90, col.implicitHeight)) + 24 + 32 + 12 + 9
    CountLine { visible: c.mode !== "still"; x: 12; width: c.width - 24; y: c.height - 9; progress: c.seconds / c.total }
}
