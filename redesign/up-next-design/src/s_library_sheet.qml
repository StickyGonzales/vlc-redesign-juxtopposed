import QtQuick
import "lib"
Rectangle {
    width: 940; height: 620; color: T.isDark ? "#2A2A2A" : "#F2F2F2"
    component Cap: Txt { font.pixelSize: 13; color: T.isDark ? "#9A9A9A" : "#555555" }
    Cap { x: 30; y: 20; text: "Compact library, name order: E04 playing, E05 tagged \"Up next\"" }
    LibraryPanel { x: 30; y: 48 }
    Cap { x: 483; y: 20; text: "\"Unwatched first\" (10:46): the next episode comes first" }
    LibraryPanel { x: 483; y: 48; unwatchedFirst: true }
}
