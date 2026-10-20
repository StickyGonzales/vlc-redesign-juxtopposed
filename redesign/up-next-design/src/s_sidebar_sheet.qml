import QtQuick
import "lib"
Rectangle {
    width: 1320; height: 720; color: T.isDark ? "#2A2A2A" : "#F2F2F2"
    component Cap: Txt { font.pixelSize: 13; color: T.isDark ? "#9A9A9A" : "#555555" }
    Cap { x: 30; y: 20; text: "Playback tab, a show is playing: autoplay ON for this folder" }
    PlaybackPanel { x: 30; y: 48; autoplay: 1 }
    Cap { x: 460; y: 20; text: "Same show, switched OFF (remembered as \"No\")" }
    PlaybackPanel { x: 460; y: 48; autoplay: 0 }
    Cap { x: 890; y: 20; text: "Not a show (single video, clip, music): no row" }
    PlaybackPanel { x: 890; y: 48; autoplay: -1 }
}
