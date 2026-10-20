import QtQuick
// the countdown line: 3 px, BG/B2 track, accent fill that shrinks to the left as time runs out
Rectangle {
    property real progress: 0.5   // part of the countdown left
    height: 3; radius: 1.5; color: T.bgB2
    Rectangle { width: parent.width * parent.progress; height: parent.height; radius: 1.5; color: T.accent }
}
