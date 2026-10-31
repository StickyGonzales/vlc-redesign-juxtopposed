import QtQuick
import "lib"
// Variant A over the player: a subtitle is on screen, so the card sits above the subtitle band
PlayerFrame {
    id: p
    subtitle: "Then we'll meet again where the river bends."
    CardA { id: card; x: p.width - width - 24; y: p.subBandTop - height - 16 }
    Shadow { source: card; anchors.fill: card; z: -1 }
}
