/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
pragma Singleton
import QtQuick

import VLC.MainInterface
import VLC.Style

QtObject {
    id: vlc_style

    readonly property real scale: MainCtx.intfScaleFactor

    readonly property FontMetrics fontMetrics_xxsmall  : FontMetrics { font.pixelSize: MainCtx.dp(6, scale);  }
    readonly property FontMetrics fontMetrics_xsmall   : FontMetrics { font.pixelSize: MainCtx.dp(8, scale);  }
    readonly property FontMetrics fontMetrics_small    : FontMetrics { font.pixelSize: MainCtx.dp(10, scale); }
    readonly property FontMetrics fontMetrics_normal   : FontMetrics { font.pixelSize: MainCtx.dp(12, scale); }
    readonly property FontMetrics fontMetrics_large    : FontMetrics { font.pixelSize: MainCtx.dp(14, scale); }
    readonly property FontMetrics fontMetrics_xlarge   : FontMetrics { font.pixelSize: MainCtx.dp(16, scale); }
    readonly property FontMetrics fontMetrics_xxlarge  : FontMetrics { font.pixelSize: MainCtx.dp(20, scale); }
    readonly property FontMetrics fontMetrics_xxxlarge : FontMetrics { font.pixelSize: MainCtx.dp(24, scale); }

    readonly property SystemPalette palette:  SystemPalette {
        objectName: "themePalette"
        source: MainCtx.colorScheme.scheme
        ctx: MainCtx
    }

    readonly property SystemPalette darkPalette: SystemPalette {
        objectName: "darkPalette"
        source: ColorSchemeModel.Night
        ctx: MainCtx
    }

    readonly property real highPixelDensityThreshold: 5.9 // 150 dpi (dpmm)

    // Sizes
    readonly property double margin_xxxsmall: MainCtx.dp(2, scale);
    readonly property double margin_xxsmall: MainCtx.dp(4, scale);
    readonly property double margin_xsmall: MainCtx.dp(8, scale);
    readonly property double margin_small: MainCtx.dp(12, scale);
    readonly property double margin_normal: MainCtx.dp(16, scale);
    readonly property double margin_large: MainCtx.dp(24, scale);
    readonly property double margin_xlarge: MainCtx.dp(32, scale);
    readonly property double margin_xxlarge: MainCtx.dp(36, scale);

    readonly property real resizeHandleWidth: (scrollBarInteractingSize / 2)

    readonly property real touchHandlerMargin: margin_large

    // Borders
    readonly property int border: MainCtx.dp(1, scale)
    readonly property int focus_border: border

    readonly property int fontSize_xsmall: fontMetrics_xsmall.font.pixelSize
    readonly property int fontSize_small:  fontMetrics_small.font.pixelSize
    readonly property int fontSize_normal: fontMetrics_normal.font.pixelSize
    readonly property int fontSize_large:  fontMetrics_large.font.pixelSize
    readonly property int fontSize_xlarge: fontMetrics_xlarge.font.pixelSize
    readonly property int fontSize_xxlarge: fontMetrics_xxlarge.font.pixelSize
    readonly property int fontSize_xxxlarge: fontMetrics_xxxlarge.font.pixelSize

    readonly property int fontHeight_xsmall: Math.ceil(fontMetrics_xsmall.lineSpacing)
    readonly property int fontHeight_small:  Math.ceil(fontMetrics_small.lineSpacing)
    readonly property int fontHeight_normal: Math.ceil(fontMetrics_normal.lineSpacing)
    readonly property int fontHeight_large:  Math.ceil(fontMetrics_large.lineSpacing)
    readonly property int fontHeight_xlarge: Math.ceil(fontMetrics_xlarge.lineSpacing)
    readonly property int fontHeight_xxlarge: Math.ceil(fontMetrics_xxlarge.lineSpacing)
    readonly property int fontHeight_xxxlarge: Math.ceil(fontMetrics_xxxlarge.lineSpacing)


    readonly property int heightAlbumCover_xsmall: MainCtx.dp(32, scale);
    readonly property int heightAlbumCover_small: MainCtx.dp(64, scale);
    readonly property int heightAlbumCover_normal: MainCtx.dp(128, scale);
    readonly property int heightAlbumCover_large: MainCtx.dp(255, scale);
    readonly property int heightAlbumCover_xlarge: MainCtx.dp(512, scale);

    readonly property int listAlbumCover_height: MainCtx.dp(32, scale)
    readonly property int listAlbumCover_width: listAlbumCover_height * 16.0/9
    readonly property int listAlbumCover_radius: MainCtx.dp(3, scale)
    readonly property int trackListAlbumCover_width: MainCtx.dp(32, scale)
    readonly property int trackListAlbumCover_heigth: MainCtx.dp(32, scale)
    readonly property int trackListAlbumCover_radius: MainCtx.dp(3, scale)

    readonly property int tableCoverRow_height: Math.max(listAlbumCover_height, fontHeight_normal) + margin_xsmall * 2
    readonly property int tableRow_height: fontHeight_normal + margin_small * 2

    readonly property int icon_xsmall: MainCtx.dp(8, scale);
    readonly property int icon_small: MainCtx.dp(12, scale);
    readonly property int icon_normal: MainCtx.dp(24, scale);
    readonly property int icon_medium: MainCtx.dp(48, scale);
    readonly property int icon_large: MainCtx.dp(64, scale);
    readonly property int icon_xlarge: MainCtx.dp(128, scale);

    readonly property int icon_dragItem: MainCtx.dp(32, scale);
    readonly property int icon_topbar: icon_normal
    readonly property int icon_toolbar: icon_normal
    readonly property int icon_audioPlayerButton: MainCtx.dp(32, scale)
    readonly property int icon_playlist: icon_normal
    readonly property int icon_track: icon_normal
    readonly property int icon_tableHeader: icon_normal
    readonly property int icon_playlistHeader: icon_normal
    readonly property int icon_banner: MainCtx.dp(28, scale)
    readonly property int icon_play: MainCtx.dp(28, scale)
    readonly property int icon_addressBar: icon_normal
    readonly property int icon_actionButton: icon_normal
    readonly property int icon_PIP: icon_normal
    readonly property int icon_CSD: icon_small
    readonly property int icon_playlistArt: MainCtx.dp(32, scale)

    readonly property int play_cover_small: MainCtx.dp(24, scale)
    readonly property int play_cover_normal: MainCtx.dp(48, scale)

    readonly property int cover_xxsmall: MainCtx.dp(32, scale);
    readonly property int cover_xsmall: MainCtx.dp(64, scale);
    readonly property int cover_small: MainCtx.dp(96, scale);
    readonly property int cover_normal: MainCtx.dp(128, scale);
    readonly property int cover_large: MainCtx.dp(160, scale);
    readonly property int cover_xlarge: MainCtx.dp(192, scale);

    readonly property int heightBar_xxxsmall: MainCtx.dp(2, scale);
    readonly property int heightBar_xxsmall: MainCtx.dp(4, scale);
    readonly property int heightBar_xsmall: MainCtx.dp(8, scale);
    readonly property int heightBar_small: MainCtx.dp(16, scale);
    readonly property int heightBar_normal: MainCtx.dp(32, scale);
    readonly property int heightBar_medium: MainCtx.dp(48, scale);
    readonly property int heightBar_large: MainCtx.dp(64, scale);
    readonly property int heightBar_xlarge: MainCtx.dp(128, scale);
    readonly property int heightBar_xxlarge: MainCtx.dp(256, scale);

    readonly property int minWindowWidth: MainCtx.dp(500, scale);
    readonly property int maxWidthPlaylist: MainCtx.dp(400, scale);
    readonly property int defaultWidthPlaylist: MainCtx.dp(300, scale);
    readonly property int closedWidthPlaylist: MainCtx.dp(20, scale);

    readonly property int expandNavigationPaneWidth: MainCtx.dp(160, scale);
    readonly property int buttonHeightNavigationPane: MainCtx.dp(35, scale);

    readonly property int widthSearchInput: MainCtx.dp(200, scale);
    readonly property int widthSortBox: MainCtx.dp(150, scale);
    readonly property int widthTeletext: MainCtx.dp(280, scale);
    readonly property int widthExtendedSpacer: MainCtx.dp(128, scale);
    readonly property int heightInput: MainCtx.dp(22, scale);

    readonly property real network_normal: MainCtx.dp(100, scale)

    readonly property int expandAlbumTracksHeight: MainCtx.dp(200, scale)

    //combobox
    readonly property int combobox_width_small: MainCtx.dp(64, scale)
    readonly property int combobox_width_normal: MainCtx.dp(96, scale)
    readonly property int combobox_width_large: MainCtx.dp(128, scale)

    readonly property int combobox_height_small: MainCtx.dp(16, scale)
    readonly property int combobox_height_normal: MainCtx.dp(24, scale)
    readonly property int combobox_height_large: MainCtx.dp(30, scale)

    //button
    readonly property int button_width_small: MainCtx.dp(64, scale)
    readonly property int button_width_normal: MainCtx.dp(96, scale)
    readonly property int button_width_large: MainCtx.dp(128, scale)

    readonly property real button_radius: MainCtx.dp(4, scale)

    readonly property int contextButton_width: icon_normal
    readonly property int contextButton_margin: margin_xxsmall

    readonly property int checkButton_width: MainCtx.dp(56, scale)
    readonly property int checkButton_height: MainCtx.dp(32, scale)

    readonly property int checkButton_margins: MainCtx.dp(4, scale)
    readonly property int checkButton_handle_margins: MainCtx.dp(2, scale)

    readonly property int navBoxButton_radius: MainCtx.dp(8, scale)

    readonly property int table_section_width: MainCtx.dp(32, scale)
    readonly property int table_section_text_margin: MainCtx.dp(10, scale)

    readonly property int gridCover_network_width: colWidth(1)
    readonly property int gridCover_network_height: gridCover_network_width
    readonly property int gridCover_network_border: MainCtx.dp(3, scale)

    readonly property int gridCover_music_width: colWidth(1)
    readonly property int gridCover_music_height: gridCover_music_width
    readonly property int gridCover_music_border: MainCtx.dp(3, scale)

    readonly property int gridCover_video_width: colWidth(2)
    readonly property int gridCover_video_height: ( gridCover_video_width * 10.0 ) / 16
    readonly property int gridCover_video_border: MainCtx.dp(4, scale)

    readonly property int gridCover_radius: MainCtx.dp(4, scale)

    readonly property int expandCover_music_height: MainCtx.dp(171, scale)
    readonly property int expandCover_music_width: MainCtx.dp(171, scale)
    readonly property int expandCover_music_radius: gridCover_radius
    readonly property int expandDelegate_border: MainCtx.dp(1, scale)

    readonly property int artistGridCover_radius: MainCtx.dp(90, scale)

    readonly property real mainView_topLeftRadius: MainCtx.dp(8, scale)

    //GridItem
    readonly property int gridItemTitle_topMargin: margin_xsmall + margin_xxxsmall
    readonly property int gridItemTitle_height: fontHeight_normal

    readonly property int gridItemSubtitle_topMargin: margin_xsmall - margin_xxxsmall
    readonly property int gridItemSubtitle_height: fontHeight_normal

    readonly property int gridItemSelectedBorder: MainCtx.dp(8, scale)

    readonly property int gridItem_newIndicator: MainCtx.dp(8, scale)

    readonly property int column_width: MainCtx.dp(114, scale)

    // NOTE: This property should be applied on ExpandGridView and TableView. We should provision
    //       enough space to fit the TableView section labels and 'contextButton'.
    readonly property int column_margin: MainCtx.dp(32, scale)
    readonly property int column_spacing: column_margin

    // NOTE: For the grid layout, there is an additional spacing, defined by the verticalSpacing of the ExpandGridView
    readonly property int gridView_spacing: margin_small + margin_xxxsmall
    readonly property int tableView_spacing: gridView_spacing + margin_large

    readonly property int layoutTitle_top_padding: margin_large
    readonly property int layoutTitle_bottom_padding: margin_normal + margin_xxxsmall

    readonly property int layout_left_margin: margin_normal
    readonly property int layout_right_margin: layout_left_margin

    readonly property int table_cover_border: MainCtx.dp(2, scale)

    readonly property int tableHeaderText_height: fontHeight_normal

    readonly property int artistBanner_height: MainCtx.dp(200, scale)

    //global application size, updated by the root widget
    property int appWidth: 0
    property int appHeight: 0

    readonly property int smallWidth: MainCtx.dp(600, scale)
    readonly property int mediumWidth: MainCtx.dp(1000, scale)

    readonly property bool isScreenSmall: appWidth <= smallWidth
    readonly property bool isScreenReallySmall: appWidth <= MainCtx.dp(380, scale)

    //global application margin "safe area"
    readonly property int applicationHorizontalMargin: MainCtx.safeArea * appWidth / 100
    readonly property int applicationVerticalMargin: MainCtx.safeArea * appHeight / 100

    readonly property int globalToolbar_height: MainCtx.dp(40, scale)
    readonly property int localToolbar_height: MainCtx.dp(48, scale)

    readonly property int bannerTabButton_width_small: icon_banner
    readonly property int bannerTabButton_width_large: column_width

    readonly property int bannerButton_height: icon_banner
    readonly property int bannerButton_width: icon_banner

    // Drag and drop

    readonly property int dragDelta: MainCtx.dp(12, scale)

    // durations. Values are aligned on Kirigami

    //should be used for animation that benefits from a longer animation than duration_long
    readonly property int duration_veryLong: 400

    //should be used for longer animation (opening/closing panes & dialogs)
    readonly property int duration_long: 200

    //should be used for short animations (hovering, accuenting UI event)
    readonly property int duration_short: 100

    //should be used for near instant animations
    readonly property int duration_veryShort: 50

    /* human time reaction, how much time before the user should be informed that something
     * is going on, or before something should be automatically automated,
     * this should not be used for animations
     *
     * Some examples:
     *
     * - When the user types text in a search field, wait no longer than this duration after
     *   the user completes typing before starting the search
     * - When loading data which would commonly arrive rapidly enough to not require interaction,
     *   wait this long before showing a spinner
     */
    readonly property int duration_humanMoment: 2000

    //timing before showing up a tooltip
    readonly property int delayToolTipAppear: (Application?.styleHints?.toolTipWakeUpDelayAsMSec ?? 700)

    //timing for the progressbar/scanbar bouncing animation, explicitly very long
    readonly property int durationSliderBouncing: 2000

    //default arts
    readonly property url noArtAlbum: "qrc:///placeholder/noart_album.svg";
    readonly property url noArtArtist: "qrc:///placeholder/noart_artist.svg";
    readonly property url noArtArtistSmall: "qrc:///placeholder/noart_artist_small.svg";
    readonly property url noArtAlbumCover: "qrc:///placeholder/noart_albumCover.svg";
    readonly property url noArtArtistCover: "qrc:///placeholder/noart_artistCover.svg";
    readonly property url noArtVideoCover: "qrc:///placeholder/noart_videoCover.svg";

    // New indicator
    readonly property url newIndicator: "qrc:///misc/new_indicator.svg";

    // ControlBar

    readonly property int controlBarBookmarksHeight: icon_xsmall * 0.9

    // Player control layout
    readonly property int controlLayoutHeight: MainCtx.dp(64, scale)
    readonly property int controlLayoutHeightPinned: MainCtx.dp(32, scale)

    // redesign: sizes from the Figma file (redesign/FIGMA_FLOWS.md, "Exact specs"), 1x units scaled like the rest
    readonly property string rd_fontFamily: "Inter"
    // key captions (Keyboard Shortcuts dialog): DM Mono, else the first installed monospace font
    readonly property string rd_fontFamilyMono: {
        const installed = Qt.fontFamilies()
        const wanted = ["DM Mono", "Consolas", "Menlo", "DejaVu Sans Mono"]
        for (let i = 0; i < wanted.length; ++i) {
            if (installed.indexOf(wanted[i]) >= 0)
                return wanted[i]
        }
        return "monospace"
    }
    readonly property int rd_fontSize_label: MainCtx.dp(14, scale)      // Inter 400 14 / 16.9
    readonly property int rd_fontSize_time: MainCtx.dp(15, scale)       // time labels 400 15 / 18.2
    readonly property int rd_fontSize_header: MainCtx.dp(16, scale)     // section headers 500 16
    readonly property int rd_fontSize_section: MainCtx.dp(20, scale)    // full library Home section titles 400 20
    readonly property int rd_fontSize_toggle: MainCtx.dp(12, scale)     // toggle ON/OFF 400 12
    readonly property int rd_fontSize_title: MainCtx.dp(24, scale)      // onboarding titles
    readonly property int rd_fontSize_display: MainCtx.dp(32, scale)    // "Welcome to VLC!"
    readonly property int rd_radius_xsmall: MainCtx.dp(2, scale)        // setting category row, thumbnails
    readonly property int rd_radius_small: MainCtx.dp(4, scale)         // icon buttons, seek fill, option rows
    readonly property int rd_radius_normal: MainCtx.dp(6, scale)        // play button, time labels, inputs, buttons
    readonly property int rd_radius_panel: MainCtx.dp(10, scale)        // menus, side panels
    readonly property int rd_radius_large: MainCtx.dp(14, scale)        // dialogs, mini player, thumbnail card
    readonly property int rd_radius_toast: MainCtx.dp(16, scale)        // resume toast
    readonly property int rd_radius_video: MainCtx.dp(19, scale)        // inset video area
    readonly property int rd_radius_cover: MainCtx.dp(20, scale)        // music player cover (Figma "Player - Music")
    readonly property int rd_radius_card: MainCtx.dp(12, scale)         // full library card picture (Figma Player-3)
    readonly property int rd_topBarHeight: MainCtx.dp(40, scale)
    readonly property int rd_controlBarHeight: MainCtx.dp(54, scale)
    readonly property int rd_controlBarSpacing: MainCtx.dp(20, scale)
    readonly property int rd_controlBarPaddingV: MainCtx.dp(11, scale)
    readonly property int rd_seekBarHeight: MainCtx.dp(28, scale)
    readonly property int rd_seekFillHeight: MainCtx.dp(24, scale)
    readonly property int rd_seekHandleWidth: MainCtx.dp(8, scale)
    // waveform seek bar (Figma Controls "Property 1=waveform", "Frame 21"): 2 px bars every
    // 5 px, the first 6 px from the left end, 2 to 14 px tall in 2 px steps; the playhead is
    // 4x24 with 3 px free on both sides
    readonly property int rd_waveformBarWidth: MainCtx.dp(2, scale)
    readonly property int rd_waveformBarSpacing: MainCtx.dp(3, scale)
    readonly property int rd_waveformBarMinHeight: MainCtx.dp(2, scale)
    readonly property int rd_waveformBarMaxHeight: MainCtx.dp(14, scale)
    readonly property int rd_waveformBarStep: MainCtx.dp(2, scale)
    readonly property int rd_waveformPadding: MainCtx.dp(6, scale)
    readonly property int rd_waveformPlayheadWidth: MainCtx.dp(4, scale)
    readonly property int rd_waveformPlayheadGap: MainCtx.dp(3, scale)
    // narrow window: the seek bar never gets narrower than a time label
    readonly property int rd_seekBarMinimumWidth: MainCtx.dp(76, scale)
    // the buttons beside the subtitle timeline seek bar (video 7:04, no Figma frame): as tall as
    // the bar, "-" / "+" about square (20x22 in the video), "<" / ">" narrower (0.73 of the bar
    // height)
    readonly property int rd_timelineButtonWidth: MainCtx.dp(26, scale)
    readonly property int rd_timelineChevronWidth: MainCtx.dp(20, scale)
    // seek bar preview card (Figma "thumbnail" 272x189: padding 10, gap 10, picture 252x142 r4,
    // time box 17 high, card radius rd_radius_large); the prototype opens it at -132,-209 of the
    // 8x24 playhead, so its bottom edge is 18 px above the seek track
    readonly property int rd_seekPreviewPadding: MainCtx.dp(10, scale)
    readonly property int rd_seekPreviewSpacing: MainCtx.dp(10, scale)
    readonly property int rd_seekPreviewPictureWidth: MainCtx.dp(252, scale)
    readonly property int rd_seekPreviewPictureHeight: MainCtx.dp(142, scale)
    readonly property int rd_seekPreviewTimeHeight: MainCtx.dp(17, scale)
    readonly property int rd_seekPreviewGap: MainCtx.dp(18, scale)
    // near a window edge the card stops this far from it (the player frame inset)
    readonly property int rd_seekPreviewEdgeMargin: MainCtx.dp(10, scale)
    readonly property int rd_iconSize: MainCtx.dp(24, scale)
    readonly property int rd_iconButtonWidth: MainCtx.dp(30, scale)
    readonly property int rd_iconButtonHeight: MainCtx.dp(32, scale)
    readonly property int rd_iconButtonSpacing: MainCtx.dp(12, scale)   // Figma "Frame 23": track / settings buttons
    readonly property int rd_playButtonWidth: MainCtx.dp(54, scale)
    // in a window, the bars hide this long after the last mouse movement (ms, Decision 30)
    readonly property int rd_barsHideDelay: 3000
    readonly property int rd_playButtonHeight: MainCtx.dp(28, scale)
    readonly property int rd_timeLabelWidth: MainCtx.dp(76, scale)
    readonly property int rd_volumeWidth: MainCtx.dp(88, scale)
    readonly property int rd_sidePanelWidth: MainCtx.dp(400, scale)
    readonly property int rd_sidePanelTabHeight: MainCtx.dp(50, scale)
    readonly property int rd_libraryRailWidth: MainCtx.dp(50, scale)
    readonly property int rd_libraryRailFullWidth: MainCtx.dp(217, scale)  // full library rail (Figma Player-1..5)
    readonly property int rd_libraryPanelWidth: MainCtx.dp(377, scale)
    readonly property int rd_librarySlideDuration: 208                   // compact library open / close, Figma smart animate "slow"
    readonly property int rd_menuRowHeight: MainCtx.dp(48, scale)
    readonly property int rd_menuWidth: MainCtx.dp(265, scale)
    readonly property int rd_mainMenuWidth: MainCtx.dp(375, scale)
    readonly property int rd_contextMenuWidth: MainCtx.dp(292, scale)   // Figma "right-click menu"
    readonly property int rd_menuMaxWidth: MainCtx.dp(480, scale)       // submenus grow with long entries
    readonly property int rd_submenuGap: MainCtx.dp(11, scale)          // Figma "Profiles": menu to submenu
    readonly property int rd_menuPadding: MainCtx.dp(4, scale)          // Figma menus: padding 4
    readonly property int rd_menuFadeDuration: 120                       // menu fade-in, video 5:08 at 60 fps
    readonly property int rd_rowHeight: MainCtx.dp(32, scale)
    // drag ghost of a list row (IB-15, video 11:45): the row content only; its FG/1 title measures
    // about #A9A9A9 over the black video, so about 75 % opaque
    readonly property real rd_dragGhostOpacity: 0.75
    // endless sliders (Decision 47): held past an end, the scale scrolls at a fixed speed of this
    // share of the slider's normal range per second (delays: 20 s range, 5 s per second)
    readonly property real rd_sliderScrollRate: 0.25
    // Settings dialog (Figma "Settings - global" 1048x865: header 50, category column 216)
    readonly property int rd_settingsDialogWidth: MainCtx.dp(1048, scale)
    readonly property int rd_settingsDialogHeight: MainCtx.dp(865, scale)
    readonly property int rd_settingsHeaderHeight: MainCtx.dp(50, scale)
    readonly property int rd_settingsNavWidth: MainCtx.dp(216, scale)
    readonly property int rd_settingsCategoryHeight: MainCtx.dp(40, scale)
    readonly property real rd_disabledRowOpacity: 0.3                    // Figma "Settings - library" dependent rows
    readonly property real rd_blurRadius: 50                              // effect "bg blur"
    // dialogs (Figma "Keyboard Shortcuts", "Add Subtitles"): 1048x800, header 96 (title + controls), footer 72
    readonly property int rd_dialogWidth: MainCtx.dp(1048, scale)
    readonly property int rd_dialogHeight: MainCtx.dp(800, scale)
    readonly property int rd_dialogHeaderHeight: MainCtx.dp(96, scale)
    readonly property int rd_dialogFooterHeight: MainCtx.dp(72, scale)
    // onboarding (Figma "Onboarding" 1090x759, radius 14, video 19:47-19:54)
    readonly property int rd_onboardingWidth: MainCtx.dp(1090, scale)
    readonly property int rd_onboardingHeight: MainCtx.dp(759, scale)
    // accent color options in the order of the Figma onboarding dots (Decision 15)
    readonly property var rd_accentOptions: ["#D37918", "#E15032", "#C49E23", "#19A234", "#18AAD3",
                                             "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF"]
    // pictures of the light and dark themes on the onboarding theme tiles, the same in every theme
    readonly property color rd_themeTileLight: "#AFAFAF"
    readonly property color rd_themeTileDark: "#222222"
    // Customize Player (Figma "Player - customize", 1048 wide, header 94 = title row + description
    // row; palette items 86 wide, columns 24 apart, rows 38 apart; drags smart animate 50 ms)
    readonly property int rd_customizeHeaderHeight: MainCtx.dp(94, scale)
    readonly property int rd_customizeBodyPadding: MainCtx.dp(34, scale)
    readonly property int rd_customizeItemWidth: MainCtx.dp(86, scale)
    readonly property int rd_customizeColumnGap: MainCtx.dp(24, scale)
    readonly property int rd_customizeRowGap: MainCtx.dp(38, scale)
    readonly property int rd_customizeDragDuration: 50

    // Scroll bar (size means width or height, depending on the orientation):
    readonly property real scrollBarInteractingSize: MainCtx.dp(8, scale)
    readonly property real scrollBarNonInteractingSize: MainCtx.dp(2, scale)

    function dp(size: real, scale: real) : real {
        if (!scale)
            return MainCtx.dp(size, MainCtx.intfScaleFactor)
        return MainCtx.dp(size, scale)
    }

    function colWidth(nb: int) : real {
      return nb * VLCStyle.column_width + ( nb - 1 ) * VLCStyle.column_spacing;
    }

    //dynamic margins based on screen width
    function dynamicAppMargins(width : int) : int {
        if (width < smallWidth)
            return margin_normal;
        else if(width > mediumWidth)
            return margin_large;
        else
            return margin_normal + (width - smallWidth) * (margin_large - margin_normal) /
                    (mediumWidth - smallWidth);
    }
}
