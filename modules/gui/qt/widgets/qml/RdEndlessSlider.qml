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

// redesign: a slider that goes past its normal range up to the values VLC accepts (Decision 47,
// "endless sliders"). rangeFrom..rangeTo is the normal (Figma) range; limitFrom..limitTo VLC's.
// With the limits equal to the range (the default) it is a plain RdSlider.
// - Inside the normal range it looks and works like RdSlider (zero anchor in view).
// - Held past either end, the thumb stays at that end and the scale (ticks, labels, zero) scrolls
//   under it at a fixed speed (scrollSpeed, value units per second) one step at a time, as long as
//   the pointer stays past the end; the scroll runs only then (no idle timer).
// - Back inside, the thumb moves within the scrolled window; holding past the other end scrolls
//   back the same way. Released, the window stays, unless the value is in the normal range: then
//   it slides back to the normal view.
// - Arrow keys step by `step` past the range; a value set from outside (typed, VLC) scrolls the
//   window to show it.
// - The mouse wheel over the bar or the labels steps by `wheelStep` (Decision 54), past the range
//   like the keys.
// The window always starts on a step (rangeFrom + n steps), so ticks, labels and arrow-key steps
// land on the same values as in the normal view (a drag is not snapped, as in RdSlider).
//
//     RdEndlessSlider {
//         rangeFrom: -10; rangeTo: 10; limitFrom: -600; limitTo: 600; step: 0.05
//         current: delay.shown
//         onValueMoved: (v) => delay.push(v)
//     }
import QtQuick

import VLC.Style

RdSlider {
    id: control

    // the normal range: the window while the value is inside it
    property real rangeFrom: 0
    property real rangeTo: 1
    // the values VLC accepts
    property real limitFrom: rangeFrom
    property real limitTo: rangeTo
    property real step: 0
    // the value to show (VLC's), anywhere in limitFrom..limitTo
    property real current: 0
    // value units per second while the pointer is held past an end
    property real scrollSpeed: (rangeTo - rangeFrom) * VLCStyle.rd_sliderScrollRate
    // one mouse wheel notch (Decision 54): the step unless the slider sets a finer one
    property real wheelStep: step

    readonly property bool endless: limitFrom < rangeFrom || limitTo > rangeTo

    // the user moved the value: dragged, scrolled past an end or stepped with the keys
    signal valueMoved(real value)

    // the window: from.._windowFrom + _span
    property real _windowFrom: rangeFrom
    // the value shown, in limitFrom..limitTo
    property real _shown: 0
    // scroll distance not used yet (less than a step)
    property real _accum: 0
    // created: the window only slides home after that
    property bool _ready: false

    readonly property real _span: rangeTo - rangeFrom
    readonly property real _eps: step > 0 ? step * 1e-3 : Math.abs(_span) * 1e-6
    // the lowest and highest start of the window: the steps that show the limits
    readonly property real _lowest: Math.min(rangeFrom, _gridFloor(limitFrom))
    readonly property real _highest: Math.max(rangeFrom, _gridCeil(limitTo) - _span)

    // the pointer held past an end: -1 the low end, 1 the high end (mirrored: the high end is
    // on the left)
    readonly property int _edge: {
        if (!endless || !pressed || !pointer.active)
            return 0
        const x = pointer.point.position.x
        const side = x < 0 ? -1 : (x > width ? 1 : 0)
        return mirrored ? -side : side
    }
    readonly property bool _scrolling: _edge > 0 ? _shown < limitTo - _eps
                                                 : (_edge < 0 && _shown > limitFrom + _eps)

    from: _windowFrom
    to: _windowFrom + _span
    stepSize: step
    // T.Slider clamps the value to from..to: read again whenever the window moves
    value: _clamped(from, to)
    scaleScrolls: endless
    scrolled: endless && Math.abs(_windowFrom - rangeFrom) > _eps
    labelMin: limitFrom
    labelMax: limitTo

    // the arrow keys step past the window (T.Slider stops at its ends)
    Keys.priority: endless ? Keys.BeforeItem : Keys.AfterItem
    Keys.onLeftPressed: (event) => _keyStep(event, mirrored ? 1 : -1)
    Keys.onRightPressed: (event) => _keyStep(event, mirrored ? -1 : 1)

    // the wheel moves on the wheel step's values and, like the keys, past the window
    customWheel: true
    onWheelStepped: (steps) => _wheelMove(steps)

    function _clamped(lo, hi) {
        return Math.max(lo, Math.min(hi, _shown))
    }

    function _limit(v) {
        return Math.max(limitFrom, Math.min(limitTo, v))
    }

    function _gridFloor(x) {
        return step > 0 ? rangeFrom + Math.floor((x - rangeFrom) / step + 1e-6) * step : x
    }

    function _gridCeil(x) {
        return step > 0 ? rangeFrom + Math.ceil((x - rangeFrom) / step - 1e-6) * step : x
    }

    function _gridRound(x) {
        return step > 0 ? rangeFrom + Math.round((x - rangeFrom) / step) * step : x
    }

    // the window that shows `v`: the normal one while `v` is in the normal range (not while the
    // pointer is down: the scale never jumps under it), else the current one moved just enough
    function _windowFor(v) {
        if (!endless || (!pressed && v >= rangeFrom - _eps && v <= rangeTo + _eps))
            return rangeFrom
        let start = _windowFrom
        if (v < start - _eps)
            start = _gridFloor(v)
        else if (v > start + _span + _eps)
            start = _gridCeil(v) - _span
        return Math.max(_lowest, Math.min(_highest, start))
    }

    function _show(v) {
        const start = _windowFor(v)
        // already sliding there (VLC confirming the released value): the slide is never restarted
        const sliding = snapBack.running && start === snapBack.to
        if (!sliding && _ready && visible && endless && !pressed && start === rangeFrom
                && Math.abs(start - _windowFrom) > _eps
                && v >= _windowFrom - _eps && v <= _windowFrom + _span + _eps) {
            // back to the normal view from a window that shows the value: the scale slides home
            // under it (a value from elsewhere jumps there)
            snapBack.to = start
            snapBack.restart()
        } else if (!snapBack.running || start !== rangeFrom) {
            snapBack.stop()
            _windowFrom = start
        }
        _shown = v
    }

    function _relayout() {
        _show(endless ? _limit(current) : current)
    }

    function _keyStep(event, direction) {
        if (!endless) {
            event.accepted = false
            return
        }
        // on a step: a typed value off the steps lands on the nearest one in that direction
        const v = _limit(_gridRound(_shown + direction * (step > 0 ? step : _span / 100)))
        if (Math.abs(v - _shown) <= _eps / 2)
            return
        _show(v)
        valueMoved(v)
    }

    // `steps` wheel notches from the value shown, on the multiples of the wheel step from
    // rangeFrom: a value between two of them goes to the next one in that direction first. A value
    // within 5 % of a step of a multiple counts as on it: VLC hands values back as 32-bit floats
    // (2.1x reads 2.0999999) or rounded (Background Opacity 38.25 is stored as 38)
    function _wheelMove(steps) {
        const quantum = wheelStep > 0 ? wheelStep : (step > 0 ? step : _span / 100)
        const n = (_shown - rangeFrom) / quantum
        const near = Math.round(n)
        const base = Math.abs(n - near) < 0.05 ? near : (steps > 0 ? Math.floor(n) : Math.ceil(n))
        // rounded: no floating point residue in the value box or the stored value
        const target = Math.round((rangeFrom + (base + steps) * quantum) * 1e9) / 1e9
        const v = endless ? _limit(target) : Math.max(rangeFrom, Math.min(rangeTo, target))
        if (Math.abs(v - _shown) <= _eps / 2)
            return
        _show(v)
        valueMoved(v)
    }

    function _scroll(seconds) {
        _accum += scrollSpeed * seconds
        const quantum = step > 0 ? step : _accum
        const steps = quantum > 0 ? Math.floor(_accum / quantum + 1e-6) : 0
        if (steps < 1)
            return
        _accum = Math.max(0, _accum - steps * quantum)
        _windowFrom = Math.max(_lowest, Math.min(_highest, _gridRound(_windowFrom + _edge * steps * quantum)))
        const v = _limit(_edge > 0 ? _windowFrom + _span : _windowFrom)
        _shown = v
        valueMoved(v)
    }

    onMoved: {
        const v = endless ? _limit(value) : value
        _shown = v
        valueMoved(v)
    }

    onPressedChanged: {
        if (pressed)
            snapBack.complete()
        else
            _show(_shown)
    }

    onCurrentChanged: _relayout()
    onRangeFromChanged: _relayout()
    onRangeToChanged: _relayout()
    onLimitFromChanged: _relayout()
    onLimitToChanged: _relayout()
    onStepChanged: _relayout()
    Component.onCompleted: {
        _relayout()
        _ready = true
    }

    // follows the pointer while it is held, also outside the slider (T.Slider only reports the
    // position clamped to its ends)
    PointHandler {
        id: pointer

        enabled: control.endless
    }

    // the scroll clock: runs only while the pointer is held past an end, one tick per frame
    FrameAnimation {
        running: control._scrolling
        onRunningChanged: control._accum = 0
        onTriggered: control._scroll(frameTime)
    }

    NumberAnimation {
        id: snapBack

        target: control
        property: "_windowFrom"
        duration: VLCStyle.duration_long
        easing.type: Easing.OutCubic
    }
}
