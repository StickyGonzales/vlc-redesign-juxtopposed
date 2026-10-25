import QtQuick
import "lib"
Rectangle {
    width: 900; height: 420; color: T.isDark ? "#2A2A2A" : "#F2F2F2"
    component Cap: Txt { font.pixelSize: 13; color: T.isDark ? "#9A9A9A" : "#555555" }
    Cap { x: 30; y: 22; text: "Mini player · Up Next strip on the video's foot" }
    MiniPlayer { id: m1; x: 30; y: 50 }
    Shadow { source: m1; anchors.fill: m1; z: -1 }
    Cap { x: 460; y: 22; text: "Mini player · strip cancelled / not a show" }
    MiniPlayer { id: m2; x: 460; y: 50; upNext: false }
    Shadow { source: m2; anchors.fill: m2; z: -1 }
}
