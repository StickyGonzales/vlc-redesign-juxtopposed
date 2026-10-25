import QtQuick
import "lib"
// the one-time prompt: centred like the resume toast, but above the subtitle band when a subtitle
// is on screen (the same rule as the Up Next card), early in the first episode Cone recognises
PlayerFrame {
    id: p
    position: 0.02; time: "00:00:31"
    subtitle: "Where did you find that wand?"
    ShowPrompt { id: pr; anchors.horizontalCenter: parent.horizontalCenter; y: p.subBandTop - height - 16 }
    Shadow { source: pr; anchors.fill: pr; z: -1 }
}
