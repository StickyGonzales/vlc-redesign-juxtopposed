/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

// redesign: mouse wheel fine-tuning of a slider (Decision 54). Over its area (the slider's bar and
// label row) one wheel notch is one step: `stepped(steps)`, positive to increase (wheel up or
// right; on a mirrored horizontal slider right decreases, like the arrow keys). Takes no clicks.
// The slider moves its value as for a drag or a key step (RdSliderCommit paces what reaches
// VLC); stepSlider(slider, steps) does it for a plain T.Slider.
// - Who gets the wheel: in a view that can scroll (an enclosing Flickable / ListView / ScrollView
//   whose content is taller than it, `inScrollingView`, read live: a window resize or an expander
//   can change it) the wheel scrolls the view and never moves a slider the pointer only passes
//   over. There the slider takes it only while `armed`: a click on the slider or on its value
//   row arms it (arm(); the owner calls it), and it is released when the pointer leaves the
//   slider's zone (`zoneHovered`: the bar and label row, or with a value row the row and the
//   slider), when the window loses focus, or when the slider hides or is disabled. `holding` is
//   true while an armed slider keeps the wheel from a scrolling view: the slider shows a subtle
//   focus state; meanwhile its value row takes the wheel too (take()). In a view that cannot
//   scroll, or outside any view, hovering is enough.
// - Every wheel event the slider takes is taken also at its ends, so it never scrolls the list or
//   reaches the player behind it; one it leaves goes on to the view.
// - High-resolution wheels and touchpads send fractions of a notch: they add up to whole steps
//   (angleDelta, 120 per notch; pixelDelta, `pixelsPerStep` per step, where only that is sent);
//   a remainder is dropped after `gestureGap` ms without a wheel event or on a change of direction.
// - Natural scrolling reported by the system (`inverted`: macOS, Linux) is turned back to the
//   finger direction; on Windows a touchpad follows the scroll direction set in Windows, as for a
//   wheel.
import QtQuick

MouseArea {
    id: root

    // a mirrored horizontal slider (right to left)
    property bool mirrored: false
    // a scroll that only reports pixels: this many pixels make one step
    property real pixelsPerStep: 24
    // ms between two events of one wheel gesture
    property int gestureGap: 400
    // the slider holds the wheel in a scrolling view (see above)
    property bool armed: false
    // the pointer is over the slider's zone: the slider itself by default; an owner with a value
    // row binds the hover of the row and the slider together
    property bool zoneHovered: pointerOver
    // the pointer is over the slider (its bar and label row)
    readonly property alias pointerOver: hover.hovered
    // a view holding the slider can scroll: its content is taller than the view
    readonly property bool inScrollingView: _views.some((view) => view.contentHeight > view.height + 0.5)
    readonly property bool takesWheel: armed || !inScrollingView
    // armed in a scrolling view: the slider shows its focus state
    readonly property bool holding: armed && inScrollingView

    signal stepped(int steps)

    // notches not used yet (less than a step)
    property real _accum: 0
    property double _lastTaken: 0
    // the views (Flickable, ListView, a ScrollView's Flickable) holding the slider
    property var _views: []

    acceptedButtons: Qt.NoButton

    function arm() {
        _updateViews()
        armed = true
    }

    // moves a T.Slider `steps` times by its stepSize, as its arrow keys do (the value's binding
    // stays), and reports the move with its moved() signal
    function stepSlider(slider, steps) {
        const old = slider.value
        for (let i = 0; i < Math.abs(steps); ++i) {
            if (steps > 0)
                slider.increase()
            else
                slider.decrease()
        }
        if (slider.value !== old)
            slider.moved()
    }

    function _findViews() {
        const views = []
        for (let p = root.parent; p; p = p.parent) {
            if (p.contentY !== undefined && p.moving !== undefined)
                views.push(p)
        }
        return views
    }

    // the bindings on the views are only evaluated again when the views changed
    function _updateViews() {
        const views = _findViews()
        if (views.length !== _views.length || views.some((view, i) => view !== _views[i]))
            _views = views
    }

    Component.onCompleted: _updateViews()
    onParentChanged: _updateViews()

    onZoneHoveredChanged: {
        if (!zoneHovered)
            armed = false
    }

    onVisibleChanged: {
        if (!visible)
            armed = false
    }

    onEnabledChanged: {
        if (!enabled)
            armed = false
    }

    Window.onActiveChanged: {
        if (!Window.active)
            armed = false
    }

    // passive: the slider keeps its own hover (thumb color). On a child item: a pointer handler
    // on this MouseArea itself would make it take the slider's presses
    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
        }
    }

    onWheel: (wheel) => {
        _updateViews()
        if (takesWheel)
            take(wheel)
        else
            wheel.accepted = false
    }

    // turns a wheel event into steps; also for a wheel event over the slider's value row while
    // the slider holds the wheel (RdParamSlider)
    function take(wheel) {
        wheel.accepted = true

        let x = wheel.angleDelta.x
        let y = wheel.angleDelta.y
        let unit = 120
        if (x === 0 && y === 0) {
            x = wheel.pixelDelta.x
            y = wheel.pixelDelta.y
            unit = pixelsPerStep
        }
        // natural scrolling (see above): back to the direction the fingers moved
        if (wheel.inverted) {
            x = -x
            y = -y
        }
        // up increases; a positive x is a scroll to the left
        const delta = Math.abs(y) >= Math.abs(x) ? y : (mirrored ? x : -x)
        if (delta === 0)
            return

        // a new gesture or a change of direction starts from a whole notch
        const now = Date.now()
        if (now - _lastTaken > gestureGap || (delta > 0) !== (_accum > 0))
            _accum = 0
        _lastTaken = now

        _accum += delta / unit
        const steps = Math.trunc(_accum + (_accum > 0 ? 1e-6 : -1e-6))
        if (steps === 0)
            return
        _accum -= steps
        root.stepped(steps)
    }
}
