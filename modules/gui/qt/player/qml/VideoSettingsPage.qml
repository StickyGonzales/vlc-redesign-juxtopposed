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

// redesign: settings sidebar, Video tab (video 8:56-9:06 final version; Figma "video settings",
// "Video - Essential", "Video - Crop", "Video - Colors"). Defaults: flip and rotate (VLC's
// transform / rotate filters), zoom, aspect ratio and crop (VLC's video variables), HDR mode
// and resolution (options), renderer (VLC's renderer menu). Filters: VLC's video effects grouped
// like VLC's "Adjustments and Effects" tabs; Geometry, Overlay and Advanced have no Figma frame
// and follow the Essential / Colors cards (Decision 21).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanelPage {
    id: root

    key: "videoSettings"

    // values may have changed elsewhere (VLC's effects dialog, hotkeys) while the page was hidden
    onActiveChanged: {
        if (active)
            RdEffects.refresh()
    }
    // a page created while its tab is already selected starts active
    Component.onCompleted: {
        if (active)
            RdEffects.refresh()
    }

    function parseNumber(text) {
        return parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
    }

    function colorText(value) {
        return "#" + ("000000" + Number(value).toString(16)).slice(-6).toUpperCase()
    }

    // a binding reading RdEffects.values[key] follows only that value
    readonly property string _flip: RdEffects.values[RdEffects.videoFilterKey("transform")]
                                    ? String(RdEffects.values[RdEffects.videoKey("transform-type")]) : ""
    readonly property real _rotation: RdEffects.values[RdEffects.videoFilterKey("rotate")]
                                      ? Number(RdEffects.values[RdEffects.videoKey("rotate-angle")]) : 0

    Widgets.RdSettingsSection {
        title: qsTr("Defaults")
        showDivider: false

        // Figma "Frame 106" / "Frame 61" (6114:13496): the label 26 px under the header (row 29 at
        // 20), 14 px to the segments (63 under the header)
        Widgets.RdSettingRow {
            text: qsTr("Flip")
            Layout.topMargin: VLCStyle.dp(10)
            rowHeight: VLCStyle.dp(29)
            spacing: VLCStyle.dp(14)

            below: Widgets.RdSegmented {
                width: parent.width
                model: [qsTr("None"), qsTr("Horizontal"), qsTr("Vertical")]
                currentIndex: root._flip === "hflip" ? 1 : root._flip === "vflip" ? 2 : 0
                Accessible.name: qsTr("Flip")
                onActivated: (index) => {
                    if (index === 0) {
                        RdEffects.setVideoFilterEnabled("transform", false)
                        return
                    }
                    RdEffects.setVideoValue("transform-type", index === 1 ? "hflip" : "vflip")
                    // the transform filter reads its type when it starts
                    if (RdEffects.videoFilterEnabled("transform"))
                        RdEffects.restartVideoFilter("transform")
                    else
                        RdEffects.setVideoFilterEnabled("transform", true)
                }
            }
        }

        // "Frame 110": 21 px under the segments
        Widgets.RdSettingRow {
            text: qsTr("Rotate")
            Layout.topMargin: VLCStyle.dp(16)

            Widgets.RdValueBox {
                text: Math.round(root._rotation) + " " + qsTr("deg")
                Accessible.name: qsTr("Rotate")
                onEdited: (value) => {
                    const deg = root.parseNumber(value)
                    if (isNaN(deg))
                        return
                    const angle = ((Math.round(deg) % 360) + 360) % 360
                    RdEffects.setVideoValue("rotate-angle", angle)
                    RdEffects.setVideoFilterEnabled("rotate", angle !== 0)
                }
            }
        }

        DropdownRow {
            text: qsTr("Zoom")

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.zoom
                Accessible.name: qsTr("Zoom")
            }
        }

        DropdownRow {
            text: qsTr("HDR")
            visible: hdr.count > 0

            OptionDropdown {
                id: hdr

                option: "d3d11-hdr-mode"
                // Figma "HDR Options" (2372:8733) names VLC's "never" mode "Off" (VLC's text has
                // a typo: "Never out HDR")
                displayNames: ({ [qsTr("Never out HDR")]: qsTr("Off") })
                Accessible.name: qsTr("HDR")
            }
        }

        DropdownRow {
            text: qsTr("Resolution")

            OptionDropdown {
                option: "preferred-resolution"
                // Figma video settings (498:2965): "Best Available"
                displayNames: ({ [qsTr("Best available")]: qsTr("Best Available") })
                Accessible.name: qsTr("Resolution")
            }
        }

        DropdownRow {
            text: qsTr("Aspect Ratio")

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.aspectRatio
                Accessible.name: qsTr("Aspect Ratio")
            }
        }

        DropdownRow {
            text: qsTr("Crop")

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.crop
                Accessible.name: qsTr("Crop")
            }
        }

        // "Render: Local" is VLC's renderer / cast picker (Decision 24)
        DropdownRow {
            text: qsTr("Render")

            T.AbstractButton {
                id: renderButton

                // the pointing hand over the clickable controls
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                implicitWidth: VLCStyle.dp(220)
                implicitHeight: VLCStyle.dp(48)

                Accessible.role: Accessible.ComboBox
                Accessible.name: qsTr("Render")

                onClicked: rendererMenu.popup(renderButton.mapToGlobal(0, renderButton.height))

                background: Rectangle {
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdBgB2

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: VLCStyle.dp(2)
                        radius: VLCStyle.rd_radius_small
                        color: renderButton.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA4
                        border.width: renderButton.visualFocus ? VLCStyle.dp(1) : 0
                        border.color: VLCStyle.palette.rdFgA3
                    }
                }

                contentItem: Item {
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(16)
                        anchors.right: chevron.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: Player.rendererManager.useRenderer ? qsTr("Casting") : qsTr("Local")
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: VLCStyle.palette.rdFgA2
                    }

                    Widgets.RdIcon {
                        id: chevron

                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.dp(16)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_direction-down"
                        color: VLCStyle.palette.rdFgA2
                    }
                }

                QmlRendererMenu {
                    id: rendererMenu

                    ctx: MainCtx
                }
            }
        }
    }

    // Figma 536:1772: the Filters header, then one block per group, divided by lines
    FilterGroup {
        first: true
        label: qsTr("Essential")
        entries: [
            { kind: "slider", module: "adjust", name: "hue", label: qsTr("Hue"), decimals: 0 },
            { kind: "slider", module: "adjust", name: "brightness", label: qsTr("Brightness"), decimals: 2 },
            { kind: "slider", module: "adjust", name: "contrast", label: qsTr("Contrast"), decimals: 2 },
            { kind: "slider", module: "adjust", name: "saturation", label: qsTr("Saturation"), decimals: 2 },
            { kind: "slider", module: "adjust", name: "gamma", label: qsTr("Gamma"), decimals: 2 },
            { kind: "toggle", module: "sharpen", label: qsTr("Sharpen") },
            { kind: "slider", module: "sharpen", name: "sharpen-sigma", label: qsTr("Sharpen Sigma"), decimals: 2 },
            { kind: "toggle", module: "gradfun", label: qsTr("Banding Removal") },
            { kind: "slider", module: "gradfun", name: "gradfun-radius", label: qsTr("Banding Removal Radius"), decimals: 0 },
            { kind: "toggle", module: "grain", label: qsTr("Film Grain") },
            { kind: "slider", module: "grain", name: "grain-variance", label: qsTr("Film Grain Variance"), decimals: 1 }
        ]
    }

    // VLC's live crop of the video output, in pixels
    FilterGroup {
        label: qsTr("Crop")
        cropGrid: true
        entries: [
            { name: "crop-top", label: qsTr("Top") },
            { name: "crop-bottom", label: qsTr("Bottom") },
            { name: "crop-left", label: qsTr("Left") },
            { name: "crop-right", label: qsTr("Right") }
        ]
    }

    // Figma "Video - Colors" expanded (614:1435): block paddings [top, bottom, gap]
    FilterGroup {
        label: qsTr("Colors")
        blockPadding: ({
            extract: [6, 20], colorthres: [20, 20], invert: [20, 10], posterize: [10, 10],
            gradient: [15, 15, 15], sepia: [10, 10]
        })
        entries: [
            { kind: "toggle", module: "extract", label: qsTr("Color Extraction") },
            { kind: "color", module: "extract", name: "extract-component", label: qsTr("Color") },
            { kind: "toggle", module: "colorthres", label: qsTr("Color Threshold") },
            { kind: "color", module: "colorthres", name: "colorthres-color", label: qsTr("Color") },
            { kind: "slider", module: "colorthres", name: "colorthres-saturationthres", label: qsTr("Saturation"), decimals: 0, from: 0, to: 100 },
            { kind: "slider", module: "colorthres", name: "colorthres-similaritythres", label: qsTr("Similarity"), decimals: 0, from: 0, to: 100 },
            { kind: "toggle", module: "invert", label: qsTr("Negate Colors") },
            { kind: "toggle", module: "posterize", label: qsTr("Posterize") },
            { kind: "slider", module: "posterize", name: "posterize-level", label: qsTr("Posterize Level"), decimals: 0 },
            { kind: "toggle", module: "gradient", label: qsTr("Gradient") },
            { kind: "choice", module: "gradient", name: "gradient-mode", label: qsTr("Gradient") },
            { kind: "flag", module: "gradient", name: "gradient-color", label: qsTr("Color") },
            { kind: "flag", module: "gradient", name: "gradient-cartoon", label: qsTr("Cartoon") },
            { kind: "toggle", module: "sepia", label: qsTr("Sepia") },
            // Figma 673:1697: ticks at thirds
            { kind: "slider", module: "sepia", name: "sepia-intensity", label: qsTr("Sepia Intensity"), decimals: 0, ticks: 3 }
        ]
    }

    FilterGroup {
        label: qsTr("Geometry")
        entries: [
            { kind: "toggle", module: "magnify", label: qsTr("Interactive Zoom") },
            { kind: "toggle", module: "wall", label: qsTr("Wall") },
            { kind: "number", module: "wall", name: "wall-cols", label: qsTr("Columns") },
            { kind: "number", module: "wall", name: "wall-rows", label: qsTr("Rows") },
            { kind: "toggle", module: "puzzle", label: qsTr("Puzzle Game") },
            { kind: "number", module: "puzzle", name: "puzzle-cols", label: qsTr("Columns") },
            { kind: "number", module: "puzzle", name: "puzzle-rows", label: qsTr("Rows") }
        ]
    }

    FilterGroup {
        label: qsTr("Overlay")
        entries: [
            { kind: "toggle", module: "logo", label: qsTr("Logo") },
            { kind: "text", module: "logo", name: "logo-file", label: qsTr("Logo File") },
            { kind: "slider", module: "logo", name: "logo-opacity", label: qsTr("Opacity"), decimals: 0 },
            { kind: "toggle", module: "marq", label: qsTr("Marquee") },
            { kind: "text", module: "marq", name: "marq-marquee", label: qsTr("Text") },
            { kind: "toggle", module: "erase", label: qsTr("Logo Erase") },
            { kind: "text", module: "erase", name: "erase-mask", label: qsTr("Mask File") }
        ]
    }

    FilterGroup {
        label: qsTr("Advanced")
        entries: [
            { kind: "toggle", module: "anaglyph", label: qsTr("Anaglyph 3D") },
            { kind: "toggle", module: "mirror", label: qsTr("Mirror") },
            { kind: "toggle", module: "psychedelic", label: qsTr("Psychedelic") },
            { kind: "toggle", module: "wave", label: qsTr("Waves") },
            { kind: "toggle", module: "ripple", label: qsTr("Water Effect") },
            { kind: "toggle", module: "motiondetect", label: qsTr("Motion Detect") },
            { kind: "toggle", module: "gaussianblur", label: qsTr("Spatial Blur") },
            // read when the filter starts (not a command variable of gaussianblur)
            { kind: "slider", module: "gaussianblur", name: "gaussianblur-sigma", label: qsTr("Sigma"), decimals: 1, live: false },
            { kind: "toggle", module: "motionblur", label: qsTr("Motion Blur") },
            { kind: "slider", module: "motionblur", name: "blur-factor", label: qsTr("Factor"), decimals: 0 },
            { kind: "toggle", module: "antiflicker", label: qsTr("Anti-Flickering") },
            { kind: "slider", module: "antiflicker", name: "antiflicker-softening-size", label: qsTr("Softening"), decimals: 0 },
            { kind: "toggle", module: "hqdn3d", label: qsTr("Denoiser") },
            { kind: "slider", module: "hqdn3d", name: "hqdn3d-luma-spat", label: qsTr("Spatial Luma Strength"), decimals: 1 },
            { kind: "slider", module: "hqdn3d", name: "hqdn3d-luma-temp", label: qsTr("Temporal Luma Strength"), decimals: 1 },
            { kind: "slider", module: "hqdn3d", name: "hqdn3d-chroma-spat", label: qsTr("Spatial Chroma Strength"), decimals: 1 },
            { kind: "slider", module: "hqdn3d", name: "hqdn3d-chroma-temp", label: qsTr("Temporal Chroma Strength"), decimals: 1 },
            { kind: "toggle", module: "clone", label: qsTr("Clone") },
            { kind: "number", module: "clone", name: "clone-count", label: qsTr("Number of Clones") }
        ]
    }

    // label on the left, a 220 px dropdown on the right (Figma "Frame 112" / "Frame 115": the
    // 48 px dropdown 20 px under the row above, 68 px apart; 15 + the 5 px row spacing)
    component DropdownRow: Widgets.RdSettingRow {
        Layout.topMargin: VLCStyle.dp(15)
    }

    // dropdown over the choices VLC declares for an option
    component OptionDropdown: Widgets.RdDropdown {
        property string option

        readonly property var _choices: RdEffects.optionChoices(option)
        readonly property var _current: RdEffects.values[RdEffects.optionKey(option)]

        implicitWidth: VLCStyle.dp(220)
        model: _choices.map((c) => c.text)
        currentIndex: _choices.findIndex((c) => String(c.value) === String(_current))
        onActivated: (index) => RdEffects.setOption(option, _choices[index].value)
    }

    // one filter group (Figma "Frame 72"... 1065:3941): its own block under a divider (the first
    // one under the "Filters" header): padding 10,20,20,20, a 37 px name row, 10 px, then the
    // group's settings in an "Expand Settings" card. Inside the card the settings of one filter
    // form a block, with a Divider/Dim line across the card between blocks ("Video - Colors"
    // 614:1435): toggle rows 32 px, sliders 37 + 5 + 24, 6 px from a toggle to its first slider
    // and 10 between sliders; block padding from Figma where it has the block (blockPadding:
    // module -> [top, bottom, gap]), else 20 / 20 around a toggle block (6 at the top of the
    // card) and 10 / 10 around a block of sliders only (0 at the top of the card).
    component FilterGroup: Widgets.RdSettingsSection {
        id: group

        property string label
        property bool first: false
        property var entries: []
        property var blockPadding: ({})
        // Crop: the four values as a 2x2 grid of boxes with a link button per row
        property bool cropGrid: false

        // (inline components cannot use the page's functions)
        function parseNumber(text) {
            return parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
        }

        function colorText(value) {
            return "#" + ("000000" + Number(value).toString(16)).slice(-6).toUpperCase()
        }

        readonly property var blocks: {
            const out = []
            for (const e of group.entries) {
                const last = out.length > 0 ? out[out.length - 1] : null
                const lastRow = last ? last.rows[last.rows.length - 1] : null
                // a filter's colour goes on its toggle row (Figma "Color Extraction")
                if (e.kind === "color" && lastRow && lastRow.kind === "toggle" && lastRow.module === e.module) {
                    last.rows[last.rows.length - 1] = Object.assign({}, lastRow, { color: e })
                    continue
                }
                if (!last || (e.module ?? "") !== last.module)
                    out.push({ module: e.module ?? "", rows: [] })
                out[out.length - 1].rows.push(e)
            }
            return out.map((b, index) => {
                const sliderOnly = b.rows.every((r) => r.kind === "slider")
                const pad = group.blockPadding[b.module]
                const top = pad ? pad[0] : (index === 0 ? (sliderOnly ? 0 : 6) : (sliderOnly ? 10 : 20))
                const bottom = pad ? pad[1] : (sliderOnly ? 10 : 20)
                const gap = pad && pad.length > 2 ? pad[2] : 10
                const hasToggle = b.rows.some((r) => r.kind === "toggle")
                const rows = b.rows.map((r, i) => Object.assign({}, r, {
                    gapBefore: i === 0 ? 0 : (r.kind === "slider" && b.rows[i - 1].kind !== "slider" ? 6 : gap),
                    hasToggle: hasToggle
                }))
                return { module: b.module, rows: rows, top: top, bottom: bottom, divider: index > 0 }
            })
        }

        title: first ? qsTr("Filters") : ""
        rowSpacing: VLCStyle.dp(10)

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(37)
            leftPadding: VLCStyle.dp(4)
            verticalAlignment: Text.AlignVCenter
            text: group.label
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Widgets.RdExpander {
            Layout.fillWidth: true
            // the blocks carry their own padding; the card adds its 10 px
            bottomPadding: group.cropGrid ? VLCStyle.dp(16) : VLCStyle.dp(10)

            Loader {
                width: parent.width
                sourceComponent: group.cropGrid ? cropContent : blockContent
            }
        }

        // Figma "Video - Crop" expanded (543:995): rows padded 6,16,10,16 and 6,16,6,16, each with
        // two 141x33 boxes 8 px apart and a 30x32 link button
        Component {
            id: cropContent

            Column {
                topPadding: VLCStyle.dp(6)
                spacing: VLCStyle.dp(16)

                Repeater {
                    model: [[group.entries[0], group.entries[1]], [group.entries[2], group.entries[3]]]

                    delegate: Row {
                        id: cropRow

                        required property var modelData
                        required property int index

                        // Figma "link" toggle: while linked, an edit of one side keeps the ratio the
                        // two sides had when the link was turned on (both equal when one was 0,
                        // VLC's "synchronize" crop); the state is kept across sessions
                        readonly property string _settingKey: "rd/cropLinked/" + index
                        property bool linked: false
                        // second side / first side
                        property real _ratio: 1

                        function cropValue(entry) {
                            return Math.max(0, Number(RdEffects.values[RdEffects.videoKey(entry.name)]) || 0)
                        }

                        function takeRatio() {
                            const first = cropValue(modelData[0])
                            const second = cropValue(modelData[1])
                            _ratio = (first > 0 && second > 0) ? second / first : 1
                        }

                        function setLinked(on) {
                            if (on)
                                takeRatio()
                            linked = on
                            MainCtx.setSettingValue(_settingKey, on)
                        }

                        function edit(entryIndex, value) {
                            RdEffects.setVideoValue(modelData[entryIndex].name, value)
                            if (!linked)
                                return
                            const other = entryIndex === 0 ? value * _ratio : value / _ratio
                            RdEffects.setVideoValue(modelData[1 - entryIndex].name, Math.max(0, Math.round(other)))
                        }

                        Component.onCompleted: {
                            const saved = MainCtx.settingValue(_settingKey, false)
                            if (saved === true || saved === "true")
                                setLinked(true)
                        }

                        spacing: VLCStyle.dp(8)

                        Repeater {
                            model: cropRow.modelData

                            delegate: Widgets.RdValueBox {
                                required property var modelData
                                required property int index

                                implicitWidth: VLCStyle.dp(141)
                                implicitHeight: VLCStyle.dp(33)
                                framed: false
                                prefix: modelData.label
                                suffix: qsTr("px")
                                text: String(Number(RdEffects.values[RdEffects.videoKey(modelData.name)]) || 0)
                                Accessible.name: modelData.label
                                onEdited: (value) => {
                                    const n = Math.round(group.parseNumber(value))
                                    if (isNaN(n))
                                        return
                                    cropRow.edit(index, Math.max(0, n))
                                }
                            }
                        }

                        Widgets.IconToolButton {
                            anchors.verticalCenter: parent.verticalCenter
                            rdMinimumWidth: VLCStyle.rd_iconButtonWidth
                            rdMinimumHeight: VLCStyle.rd_iconButtonHeight
                            // Figma "link" default (FG/A2 1.5) and active (Accent/Main 2, with the bar)
                            rdIcon: "link"
                            rdIconChecked: "link_state-active"
                            font.pixelSize: VLCStyle.rd_iconSize
                            text: "link"
                            description: cropRow.linked ? qsTr("Unlink the two sides")
                                                        : qsTr("Link the two sides (keep their ratio)")
                            checkable: true
                            checked: cropRow.linked
                            onClicked: cropRow.setLinked(checked)
                        }
                    }
                }
            }
        }

        Component {
            id: blockContent

            ColumnLayout {
                spacing: 0

                Repeater {
                    model: group.blocks

                    delegate: ColumnLayout {
                        id: block

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        // across the whole card, 0 px tall like Figma's line
                        Item {
                            visible: block.modelData.divider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 0

                            Rectangle {
                                x: -VLCStyle.dp(16)
                                width: parent.width + 2 * VLCStyle.dp(16)
                                height: VLCStyle.dp(1)
                                color: VLCStyle.palette.rdDividerDim
                            }
                        }

                        Repeater {
                            model: block.modelData.rows

                            delegate: Loader {
                                required property var modelData
                                required property int index

                                readonly property var entry: modelData

                                Layout.fillWidth: true
                                Layout.topMargin: (index === 0 ? block.modelData.top : entry.gapBefore)
                                Layout.bottomMargin: index === block.modelData.rows.length - 1 ? block.modelData.bottom : 0
                                sourceComponent: {
                                    switch (entry.kind) {
                                    case "toggle": return toggleEntry
                                    case "slider": return sliderEntry
                                    case "color": return colorEntry
                                    case "choice": return choiceEntry
                                    case "flag": return flagEntry
                                    case "text": return textEntry
                                    case "number": return numberEntry
                                    default: return null
                                    }
                                }

                    // a filter on / off, with its colour box when it has one (Figma "Frame 85")
                    Component {
                        id: toggleEntry

                        Widgets.RdSettingRow {
                            text: entry.label
                            textInset: 0
                            rowHeight: VLCStyle.dp(32)

                            Row {
                                spacing: VLCStyle.dp(8)

                                Widgets.RdValueBox {
                                    readonly property string hex: entry.color
                                                                  ? group.colorText(RdEffects.values[RdEffects.videoKey(entry.color.name)])
                                                                  : ""

                                    visible: !!entry.color
                                    implicitWidth: VLCStyle.dp(116)
                                    framed: false
                                    textColor: VLCStyle.palette.rdFgA3
                                    text: hex
                                    showSwatch: true
                                    swatch: hex
                                    Accessible.name: entry.color ? entry.label + " " + entry.color.label : ""
                                    onEdited: (value) => {
                                        const v = parseInt(String(value).replace("#", "").trim(), 16)
                                        if (!isNaN(v))
                                            RdEffects.setVideoValue(entry.color.name, v & 0xFFFFFF)
                                    }
                                }

                                Widgets.RdToggle {
                                    checked: RdEffects.values[RdEffects.videoFilterKey(entry.module)]
                                    Accessible.name: entry.label
                                    onToggled: RdEffects.setVideoFilterEnabled(entry.module, checked)
                                }
                            }
                        }
                    }

                    // a numeric parameter; moving it turns its filter on. A parameter the filter
                    // reads only when it starts ("live: false") restarts the whole filter chain
                    // on every change: it is applied when the slider is released. While its
                    // filter is off the slider is grey (Figma "Frame 78" 614:1472: luminosity).
                    Component {
                        id: sliderEntry

                        Widgets.RdParamSlider {
                            id: paramSlider

                            readonly property var range: RdEffects.optionRange(entry.name)
                            readonly property real current: Number(RdEffects.values[RdEffects.videoKey(entry.name)])
                            readonly property bool live: entry.live ?? true
                            readonly property real shown: live ? current : restartCommit.shown

                            readonly property RdSliderCommit restartCommit: RdSliderCommit {
                                pressed: paramSlider.pressed
                                current: paramSlider.current
                                keyDelay: 300
                                tolerance: Math.pow(10, -(entry.decimals ?? 1)) / 2
                                onCommit: (v) => paramSlider.apply(v)
                            }

                            function apply(v) {
                                RdEffects.setVideoValue(entry.name, v)
                                if (!RdEffects.videoFilterEnabled(entry.module))
                                    RdEffects.setVideoFilterEnabled(entry.module, true)
                            }

                            text: entry.label
                            textInset: 0
                            // Figma's video filter rows show only the name (536:1865, 614:1473, 673:1692)
                            valueText: ""
                            dimmed: entry.hasToggle && !RdEffects.values[RdEffects.videoFilterKey(entry.module)]
                            from: entry.from ?? range.min ?? 0
                            to: entry.to ?? range.max ?? 1
                            stepSize: (entry.decimals ?? 1) === 0 ? 1 : Math.pow(10, -(entry.decimals ?? 1))
                            showTicks: entry.ticks !== undefined
                            tickIntervals: entry.ticks ?? 0
                            value: shown
                            onMoved: (v) => {
                                if (live)
                                    apply(v)
                                else
                                    restartCommit.push(v)
                            }
                        }
                    }
                    Component {
                        id: colorEntry
                        Widgets.RdSettingRow {
                            text: entry.label
                            textInset: 0
                            rowHeight: VLCStyle.dp(32)
                            Widgets.RdValueBox {
                                readonly property string hex: group.colorText(RdEffects.values[RdEffects.videoKey(entry.name)])
                                implicitWidth: VLCStyle.dp(116)
                                framed: false
                                textColor: VLCStyle.palette.rdFgA3
                                text: hex
                                showSwatch: true
                                swatch: hex
                                Accessible.name: entry.label
                                onEdited: (value) => {
                                    const v = parseInt(String(value).replace("#", "").trim(), 16)
                                    if (!isNaN(v))
                                        RdEffects.setVideoValue(entry.name, v & 0xFFFFFF)
                                }
                            }
                        }
                    }
                    // full-width list without a label (Figma "Gradient" 673:1670)
                    Component {
                        id: choiceEntry
                        Widgets.RdDropdown {
                            readonly property var _choices: RdEffects.optionChoices(entry.name)
                            readonly property var _current: RdEffects.values[RdEffects.videoKey(entry.name)]
                            frameless: true
                            model: _choices.map((c) => c.text)
                            currentIndex: _choices.findIndex((c) => String(c.value) === String(_current))
                            Accessible.name: entry.label
                            onActivated: (index) => RdEffects.setVideoValue(entry.name, _choices[index].value)
                        }
                    }
                    // a boolean (or 0 / 1) option of a filter
                    Component {
                        id: flagEntry
                        Widgets.RdSettingRow {
                            text: entry.label
                            textInset: 0
                            rowHeight: VLCStyle.dp(32)
                            Widgets.RdToggle {
                                checked: !!Number(RdEffects.values[RdEffects.videoKey(entry.name)])
                                Accessible.name: entry.label
                                onToggled: RdEffects.setVideoValue(entry.name, checked ? 1 : 0)
                            }
                        }
                    }
                    Component {
                        id: textEntry
                        Widgets.RdSettingRow {
                            text: entry.label
                            textInset: 0
                            rowHeight: VLCStyle.dp(36)
                            Widgets.RdValueBox {
                                implicitWidth: VLCStyle.dp(200)
                                text: String(RdEffects.values[RdEffects.videoKey(entry.name)])
                                Accessible.name: entry.label
                                onEdited: (value) => RdEffects.setVideoValue(entry.name, value)
                            }
                        }
                    }
                    Component {
                        id: numberEntry
                        Widgets.RdSettingRow {
                            text: entry.label
                            textInset: 0
                            rowHeight: VLCStyle.dp(36)
                            Widgets.RdValueBox {
                                text: String(RdEffects.values[RdEffects.videoKey(entry.name)])
                                Accessible.name: entry.label
                                onEdited: (value) => {
                                    const n = Math.round(group.parseNumber(value))
                                    if (!isNaN(n))
                                        RdEffects.setVideoValue(entry.name, n)
                                }
                            }
                        }
                    }
                            }
                        }
                    }
                }
            }
        }
    }
}
