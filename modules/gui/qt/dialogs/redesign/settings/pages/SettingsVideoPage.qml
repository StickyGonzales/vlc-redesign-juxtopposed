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
// redesign: Settings > Video ("Video Defaults", video 18:02-18:05, Figma "Settings - video" /
// "Settings - video-1"); rows: P8-10. The picture sliders are the settings sidebar's (the
// "adjust" filter through RdEffects): they apply to the playing video and are kept.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    function _option(name) {
        return RdEffects.values[RdEffects.optionKey(name)]
    }

    readonly property var _pictureValues: ["hue", "brightness", "contrast", "saturation", "gamma"]

    // the built-in ratios, then the user's own ones that are not among them
    function _ratioChoices(none, builtIn, customOption) {
        const custom = String(_option(customOption) ?? "").split(",").map((r) => r.trim())
                       .filter((r) => r !== "" && builtIn.indexOf(r) < 0)
        return [{ value: "", text: none }].concat(
                    builtIn.concat(custom.filter((r, i) => custom.indexOf(r) === i))
                    .map((r) => ({ value: r, text: r })))
    }

    SettingsSection {
        title: qsTr("Output")

        SettingsOption {
            option: "video"
            text: qsTr("Enable video")
        }

        SettingsOption {
            option: "fullscreen"
            text: qsTr("Start videos in fullscreen")
        }

        // VLC: never (0), always (1), in fullscreen (2)
        SettingsRow {
            text: qsTr("Stop the screensaver during playback")
            description: RdEffects.optionDescription("disable-screensaver")
            keywords: "disable-screensaver"
            shown: SettingsCatalog.exists("disable-screensaver")

            Widgets.RdToggle {
                checked: Number(root._option("disable-screensaver")) !== 0
                Accessible.name: qsTr("Stop the screensaver during playback")
                onToggled: RdEffects.setOption("disable-screensaver", checked ? 1 : 0)
            }
        }

        SettingsOption {
            option: "video-wallpaper"
            text: qsTr("Play video as desktop wallpaper")
        }
    }

    SettingsSection {
        title: qsTr("Picture")

        Repeater {
            model: [
                { name: "hue", label: qsTr("Hue") },
                { name: "brightness", label: qsTr("Brightness") },
                { name: "contrast", label: qsTr("Contrast") },
                { name: "saturation", label: qsTr("Saturation") },
                { name: "gamma", label: qsTr("Gamma") }
            ]

            delegate: SettingsRow {
                id: pictureRow

                required property var modelData

                readonly property var range: RdEffects.optionRange(modelData.name)

                text: modelData.label
                description: RdEffects.optionDescription(modelData.name)
                keywords: modelData.name + " adjust picture"

                // RdEndlessSlider with its limits at the range is a plain RdSlider that also
                // takes a value an accessibility tool writes (UI Automation's RangeValue SetValue)
                Widgets.RdEndlessSlider {
                    implicitWidth: VLCStyle.dp(320)
                    rangeFrom: pictureRow.range.min ?? 0
                    rangeTo: pictureRow.range.max ?? 1
                    // a hundred steps (the keyboard moves by one); hue in whole degrees
                    step: pictureRow.modelData.name === "hue" ? 1 : (rangeTo - rangeFrom) / 100
                    current: Number(RdEffects.values[RdEffects.videoKey(pictureRow.modelData.name)] ?? 0)
                    Accessible.name: pictureRow.text
                    onValueMoved: (v) => {
                        RdEffects.setVideoValue(pictureRow.modelData.name, v)
                        if (!RdEffects.videoFilterEnabled("adjust"))
                            RdEffects.setVideoFilterEnabled("adjust", true)
                    }
                }
            }
        }

        SettingsRow {
            text: qsTr("Reset picture")
            description: qsTr("Puts hue, brightness, contrast, saturation and gamma back to normal.")
            keywords: "adjust picture reset"

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                text: qsTr("Reset")
                onClicked: {
                    for (const name of root._pictureValues) {
                        const range = RdEffects.optionRange(name)
                        if (range.default !== undefined)
                            RdEffects.setVideoValue(name, range.default)
                    }
                    RdEffects.setVideoFilterEnabled("adjust", false)
                }
            }
        }
    }

    SettingsSection {
        title: qsTr("Deinterlacing")

        SettingsOption {
            option: "deinterlace"
            text: qsTr("Deinterlacing")
        }

        SettingsOption {
            option: "deinterlace-mode"
            text: qsTr("Method")
            // VLC names its "auto" method "Auto"; Figma "Settings - video": "Automatic", like the row above
            choices: RdEffects.optionChoices(option).map((c) => c.value === "auto" ? { value: c.value, text: qsTr("Automatic") } : c)
            available: Number(root._option("deinterlace")) !== 0
        }
    }

    SettingsSection {
        title: qsTr("Framing")

        SettingsOption {
            option: "aspect-ratio"
            text: qsTr("Aspect ratio")
            choices: root._ratioChoices(qsTr("Automatic"),
                                        ["16:9", "4:3", "1:1", "16:10", "2.21:1", "2.35:1", "2.39:1", "5:4"],
                                        "custom-aspect-ratios")
        }

        SettingsOption {
            option: "crop"
            text: qsTr("Crop")
            choices: root._ratioChoices(qsTr("None"),
                                        ["16:10", "16:9", "4:3", "1.85:1", "2.21:1", "2.35:1", "2.39:1", "5:3", "5:4", "1:1"],
                                        "custom-crop-ratios")
        }

        SettingsOption {
            option: "autoscale"
            text: qsTr("Scale video to the window")
        }

        SettingsOption {
            option: "fit"
            text: qsTr("Zoom")
            available: root._option("autoscale") === true
            choices: [
                { value: 1, text: qsTr("Fit") },
                { value: 2, text: qsTr("Fill") },
                { value: 3, text: qsTr("Fit width") },
                { value: 4, text: qsTr("Fit height") }
            ]
        }

        SettingsOption {
            option: "align"
            text: qsTr("Position in the window")
        }
    }

    SettingsSection {
        title: qsTr("Snapshots")

        SettingsOption {
            option: "snapshot-path"
            controlHeight: VLCStyle.dp(32)
            text: qsTr("Save to")
            kind: "directory"
        }

        SettingsOption {
            option: "snapshot-prefix"
            controlHeight: VLCStyle.dp(32)
            text: qsTr("File name prefix")
        }

        SettingsOption {
            option: "snapshot-format"
            text: qsTr("Format")
            choices: [
                { value: "png", text: qsTr("PNG") },
                { value: "jpg", text: qsTr("JPEG") },
                { value: "tiff", text: qsTr("TIFF") },
                { value: "webp", text: qsTr("WebP") }
            ]
        }

        // VLC keeps a width and a height (src/misc/picture.c picture_Export): -1 keeps the
        // video's, 0 follows the other one's proportions
        SettingsRow {
            text: qsTr("Size")
            description: qsTr("The size of the saved picture. A width keeps the video's proportions.")
            keywords: "snapshot-width snapshot-height"

            Widgets.RdDropdown {
                readonly property var widths: [3840, 1920, 1280, 640]
                readonly property int width_: Number(root._option("snapshot-width") ?? -1)
                readonly property int height_: Number(root._option("snapshot-height") ?? -1)
                // -1: another size set elsewhere
                readonly property int _index: {
                    if (width_ < 0 && height_ < 0)
                        return 0
                    const i = widths.indexOf(width_)
                    return height_ === 0 && i >= 0 ? i + 1 : -1
                }

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: {
                    const list = [qsTr("Same as video"), qsTr("3840 wide"), qsTr("1920 wide"),
                                  qsTr("1280 wide"), qsTr("640 wide")]
                    if (_index < 0)
                        list.push(qsTr("%1 x %2").arg(width_).arg(height_))
                    return list
                }
                currentIndex: _index >= 0 ? _index : widths.length + 1
                Accessible.name: qsTr("Size")
                onActivated: (index) => {
                    if (index > widths.length)
                        return
                    RdEffects.setOption("snapshot-width", index === 0 ? -1 : widths[index - 1])
                    RdEffects.setOption("snapshot-height", index === 0 ? -1 : 0)
                }
            }
        }

        SettingsOption {
            option: "snapshot-sequential"
            text: qsTr("Number files sequentially")
        }

        SettingsOption {
            option: "snapshot-preview"
            text: qsTr("Show a preview after capture")
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "custom-aspect-ratios"
                controlHeight: VLCStyle.dp(32)
                text: qsTr("Custom aspect ratios")
                placeholder: "21:9,32:9"
            }

            SettingsOption {
                option: "custom-crop-ratios"
                controlHeight: VLCStyle.dp(32)
                text: qsTr("Custom crop ratios")
                placeholder: "21:9,32:9"
            }

            SettingsOption {
                option: "monitor-par"
                controlHeight: VLCStyle.dp(32)
                text: qsTr("Monitor pixel aspect ratio")
                placeholder: "1:1"
            }
        },

        SettingsMoreOptions {
            category: "video"
        }
    ]
}
