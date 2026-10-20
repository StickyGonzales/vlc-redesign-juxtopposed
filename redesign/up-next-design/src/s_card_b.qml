import QtQuick
import "lib"
// Variant B over the player, no subtitle on screen: 24 px above the control bar, 24 px from the right
PlayerFrame {
    id: p
    CardB { id: card; x: p.width - width - 24; y: p.height - 54 - 24 - height }
    Shadow { source: card; anchors.fill: card; z: -1 }
}
