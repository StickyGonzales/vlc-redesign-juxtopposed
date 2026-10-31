import QtQuick
// a redesign icon (pixmaps/redesign/<name>.svg): c1 = main color (#FF00FF), c2 = two-tone part (#00FFFF)
Image {
    property string name
    property color c1: T.fgA2
    property color c2: T.accentDim
    property int size: 24
    function hx(c) { const s = c.toString(); return s.substring(s.length - 6) }
    width: size; height: size
    sourceSize: Qt.size(size * 3, size * 3)
    source: "image://icon/" + name + "/" + hx(c1) + "/" + hx(c2)
    smooth: true; mipmap: true
}
