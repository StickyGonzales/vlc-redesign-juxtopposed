import QtQuick
import QtQuick.Effects
// effect "bg blur + shadow" without the blur (opaque popups): drop shadow #000 46%, y 8, blur 15
MultiEffect {
    shadowEnabled: true
    shadowColor: T.isDark ? "#75000000" : "#40000000"
    shadowVerticalOffset: 8
    shadowBlur: 0.6
    blurMax: 32
    autoPaddingEnabled: true
}
