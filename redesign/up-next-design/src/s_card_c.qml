import QtQuick
import "lib"
// Variant C over the player (the resume toast's place family): bottom right, 24 px above the bar
PlayerFrame {
    id: p
    CardC { id: card; x: p.width - width - 24; y: p.height - 54 - 24 - height }
    Shadow { source: card; anchors.fill: card; z: -1 }
}
