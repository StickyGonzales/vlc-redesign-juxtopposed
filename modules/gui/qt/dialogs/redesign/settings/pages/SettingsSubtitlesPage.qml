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
// redesign: Settings > Subtitles ("Subtitle Defaults", video 18:09-18:14 and 7:29-7:40, Figma
// "Settings - subtitles" / "Settings - subtitles-1"); rows: P8-12, P7-17, P8-01, P3-22.
// Values in words instead of numbers (video 17:03-17:33), and the font size both in words and
// as an exact value (7:29-7:40: exact font sizes were hidden in the advanced preferences).
// The text style options are the freetype text renderer's; the size is VLC's subtitle text
// scale, applied at once (the settings sidebar's).
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

    readonly property bool _autodetect: _option("sub-autodetect-file") === true
    readonly property bool _shadow: Number(_option("freetype-shadow-opacity") ?? 0) > 0
    readonly property bool _background: Number(_option("freetype-background-opacity") ?? 0) > 0
    readonly property bool _title: _option("video-title-show") === true
    readonly property bool _osd: _option("osd") !== false

    // the size in words (percent of VLC's default size)
    readonly property var _sizes: [
        { value: 60, text: qsTr("Smaller") },
        { value: 80, text: qsTr("Small") },
        { value: 100, text: qsTr("Automatic") },
        { value: 125, text: qsTr("Large") },
        { value: 160, text: qsTr("Larger") }
    ]
    readonly property int _scale: Number(RdEffects.values.subtitleTextScale ?? 100)
    // "Precise" shows the exact value; a value without a word opens on it (decided once, so
    // typing an exact value never swaps the control under the user)
    property bool _precise: false
    Component.onCompleted: _precise = !_sizes.some((s) => s.value === _scale)

    SettingsSection {
        title: qsTr("Tracks & Languages")

        SettingsOption {
            option: "spu"
            text: qsTr("Enable subtitles")
        }

        SettingsLanguageOption {
            option: "sub-language"
            text: qsTr("Preferred language")
            // Figma reads "System language"; VLC's empty value does not follow the system
            // language, so it stays "Automatic" (Decisions (Claude), WEB_FIXES_1_NOTES.md)
            note: qsTr("Automatic picks the subtitle track the file marks as its default. Applies from the next file.")
        }

        // VLC's empty value ("Default (Windows-1252)") reads the encoding a file declares, then
        // detects UTF-8, and only then falls back to the language's usual code page: Figma's
        // "Automatic" (SHEET_CONFIRMATIONS, P8-12)
        SettingsOption {
            option: "subsdec-encoding"
            text: qsTr("Text encoding")
            choices: RdEffects.optionChoices(option).map((c) =>
                c.value === "" ? { value: c.value, text: qsTr("Automatic") } : c)
            note: qsTr("Automatic uses the encoding a subtitle file declares, recognizes UTF-8, and otherwise reads the file in the usual encoding of the interface language.")
        }
    }

    SettingsSection {
        title: qsTr("Loading Subtitles")

        SettingsOption {
            option: "sub-autodetect-file"
            text: qsTr("Load subtitle files automatically")
        }

        // VLC's explanation lists the numbers the video replaces with words, so this row
        // explains the choice itself
        SettingsOption {
            option: "sub-autodetect-fuzzy"
            text: qsTr("File name matching")
            description: qsTr("How closely the name of a subtitle file has to match the name of the video for the subtitles to load automatically.")
            keywords: "sub-autodetect-fuzzy fuzziness"
            available: root._autodetect
            choices: [
                { value: 0, text: qsTr("Off") },
                { value: 1, text: qsTr("Any title") },
                { value: 2, text: qsTr("Contains title") },
                { value: 3, text: qsTr("Title with extra characters") },
                { value: 4, text: qsTr("Exact title match") }
            ]
        }
    }

    // the OpenSubtitles account of the Add Subtitles dialog (W6.5)
    SettingsOpenSubtitlesSection { }

    SettingsSection {
        title: qsTr("Appearance")

        SettingsOption {
            option: "freetype-font"
            minimumLineHeight: VLCStyle.dp(38)
            text: qsTr("Font")
            placeholder: qsTr("System, sans-serif")
        }

        // Figma "Values" (2): words, or the exact value
        SettingsRow {
            text: qsTr("Size values")
            minimumLineHeight: VLCStyle.dp(38)
            description: qsTr("Relative sizes are in words, from Smaller to Larger. Precise sets the exact size, in percent of %1's normal size.").arg(Brand.shortName)
            keywords: "sub-text-scale font size relative precise"

            Widgets.RdSegmented {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Relative"), qsTr("Precise")]
                currentIndex: root._precise ? 1 : 0
                Accessible.name: qsTr("Size values")
                onActivated: (index) => {
                    root._precise = index === 1
                    // a value without a word becomes the nearest word
                    if (!root._precise && !root._sizes.some((s) => s.value === root._scale)) {
                        const nearest = root._sizes.reduce((a, b) => Math.abs(b.value - root._scale) < Math.abs(a.value - root._scale) ? b : a)
                        RdEffects.setSubtitleTextScale(nearest.value)
                    }
                }
            }
        }

        SettingsRow {
            text: qsTr("Font size")
            description: RdEffects.optionDescription("sub-text-scale")
            keywords: "sub-text-scale font size"

            // one control at a time, so the row's control slot is the size of the shown one
            Loader {
                sourceComponent: root._precise ? preciseSize : relativeSize
            }

            Component {
                id: relativeSize

                Widgets.RdDropdown {
                    implicitWidth: VLCStyle.dp(320)
                    implicitHeight: VLCStyle.dp(36)
                    model: root._sizes.map((s) => s.text)
                    currentIndex: root._sizes.findIndex((s) => s.value === root._scale)
                    Accessible.name: qsTr("Font size")
                    onActivated: (index) => RdEffects.setSubtitleTextScale(root._sizes[index].value)
                }
            }

            Component {
                id: preciseSize

                Widgets.RdValueBox {
                    implicitWidth: VLCStyle.dp(320)
                    text: root._scale + "%"
                    Accessible.name: qsTr("Font size")
                    onEdited: (text) => {
                        const v = parseInt(text)
                        if (isNaN(v))
                            return
                        root._precise = true
                        RdEffects.setSubtitleTextScale(Math.max(10, Math.min(500, v)))
                    }
                }
            }
        }

        SettingsOption {
            option: "freetype-bold"
            text: qsTr("Bold")
        }

        SettingsOption {
            option: "freetype-color"
            text: qsTr("Text color")
        }

        // VLC's opacities are 0 to 255
        SettingsOption {
            option: "freetype-opacity"
            tickStep: 10
            text: qsTr("Text opacity")
            kind: "slider"
            valueScale: 2.55
            from: 0
            to: 100
            step: 1
            labels: [qsTr("0%"), qsTr("50%"), qsTr("100%")]
        }

        SettingsOption {
            option: "freetype-outline-thickness"
            text: qsTr("Outline thickness")
        }

        SettingsOption {
            option: "freetype-outline-color"
            text: qsTr("Outline color")
        }

        SettingsRow {
            text: qsTr("Shadow")
            description: RdEffects.optionDescription("freetype-shadow-opacity")
            keywords: "freetype-shadow-opacity"
            shown: SettingsCatalog.exists("freetype-shadow-opacity")

            Widgets.RdToggle {
                checked: root._shadow
                Accessible.name: qsTr("Shadow")
                onToggled: RdEffects.setOption("freetype-shadow-opacity", checked ? 128 : 0)
            }
        }

        SettingsOption {
            option: "freetype-shadow-color"
            text: qsTr("Shadow color")
            available: root._shadow
        }

        SettingsOption {
            option: "freetype-shadow-distance"
            text: qsTr("Shadow distance")
            available: root._shadow
            choices: [
                { value: 0.04, text: qsTr("Small") },
                { value: 0.06, text: qsTr("Medium") },
                { value: 0.1, text: qsTr("Large") }
            ]
        }

        SettingsRow {
            text: qsTr("Background")
            description: RdEffects.optionDescription("freetype-background-opacity")
            keywords: "freetype-background-opacity box"
            shown: SettingsCatalog.exists("freetype-background-opacity")

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("None"), qsTr("Box")]
                currentIndex: root._background ? 1 : 0
                Accessible.name: qsTr("Background")
                onActivated: (index) => RdEffects.setOption("freetype-background-opacity", index === 1 ? 128 : 0)
            }
        }

        SettingsOption {
            option: "freetype-background-color"
            text: qsTr("Background color")
            available: root._background
        }

        // at 0 the box is off (Background "None"): the row stays usable while its slider is
        // dragged there, so it does not turn itself off under the mouse
        SettingsOption {
            id: backgroundOpacityRow

            option: "freetype-background-opacity"
            tickStep: 10
            text: qsTr("Background opacity")
            kind: "slider"
            valueScale: 2.55
            from: 0
            to: 100
            step: 1
            labels: [qsTr("0%"), qsTr("50%"), qsTr("100%")]
            available: root._background || backgroundOpacityRow._dragging
        }

        // VLC's "sub-margin" lifts the subtitles from the bottom, in pixels
        SettingsOption {
            option: "sub-margin"
            text: qsTr("Vertical position")
            choices: [
                { value: 0, text: qsTr("Bottom") },
                { value: 50, text: qsTr("Raised") },
                { value: 100, text: qsTr("Higher") }
            ]
        }
    }

    SettingsSection {
        title: qsTr("Timing")

        // VLC counts tenths of a second and declares no range; the slider scrolls on past
        // -5 / +5 s up to the -600 to 600 s of VLC's own Synchronization panel
        // (dialogs/extended/extended_panels.cpp, SyncWidget), 5 s per second (Decision 47)
        SettingsOption {
            option: "sub-delay"
            text: qsTr("Subtitle delay")
            kind: "slider"
            bipolar: true
            valueScale: 10
            from: -5
            to: 5
            limitFrom: -600
            limitTo: 600
            scrollSpeed: 5
            step: 0.1
            decimals: 1
            labelStep: 5
            labelText: (v) => {
                const s = Math.round(v * 10) / 10
                return qsTr("%1 s").arg((s > 0 ? "+" : "") + s)
            }
        }
    }

    SettingsSection {
        title: qsTr("On-Screen Messages")

        // VLC's on-screen messages; in the Cone build a message caused by a shortcut also names
        // the key ("Pressed C", modules/control/hotkeys.c, video 15:23-15:28)
        SettingsOption {
            option: "osd"
            text: qsTr("Show feedback for shortcuts")
        }

        // Figma "Frame 146": 0.5 s to 5 s, ten ticks; the messages' time on the video (a core
        // option of the Cone build, src/video_output/video_text.c)
        SettingsOption {
            option: "osd-duration"
            text: qsTr("Show feedback for")
            kind: "slider"
            valueScale: 1000
            from: 0.5
            to: 5
            step: 0.1
            decimals: 1
            tickStep: 0.5
            labelStep: 4.5
            labelAnchor: 0.5
            labelText: (v) => qsTr("%1 s").arg(Math.round(v * 10) / 10)
            available: root._osd
        }

        SettingsOption {
            option: "video-title-show"
            text: qsTr("Show filename when a video starts")
        }

        // VLC declares no range (milliseconds): the slider scrolls on past 10 s, up to a minute
        // (Decision 47)
        SettingsOption {
            option: "video-title-timeout"
            text: qsTr("Show filename for")
            kind: "slider"
            valueScale: 1000
            from: 1
            to: 10
            limitTo: 60
            step: 0.5
            labelStep: 9
            labelAnchor: 1
            labelText: (v) => qsTr("%1 s").arg(Math.round(v * 10) / 10)
            available: root._title
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "sub-autodetect-path"
                minimumLineHeight: VLCStyle.dp(38)
                text: qsTr("Load subtitles from these folders")
                available: root._autodetect
            }

            SettingsOption {
                option: "freetype-shadow-angle"
                minimumLineHeight: VLCStyle.dp(38)
                text: qsTr("Shadow angle")
                unit: "°"
                available: root._shadow
            }

            SettingsOption {
                option: "freetype-text-direction"
                text: qsTr("Text direction")
                choices: [
                    { value: 2, text: qsTr("Automatic") },
                    { value: 0, text: qsTr("Left to right") },
                    { value: 1, text: qsTr("Right to left") }
                ]
            }

            SettingsOption {
                option: "freetype-monofont"
                minimumLineHeight: VLCStyle.dp(38)
                text: qsTr("Monospace font")
                placeholder: qsTr("System monospace")
            }
        },

        SettingsMoreOptions {
            category: "subtitles"
        }
    ]
}
