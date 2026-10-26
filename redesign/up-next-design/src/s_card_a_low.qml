import QtQuick
import "lib"
// Variant A, no subtitle: 24 px above the control bar
PlayerFrame {
    id: p
    CardA { id: card; x: p.width - width - 24; y: p.height - 54 - 24 - height }
    Shadow { source: card; anchors.fill: card; z: -1 }
}
