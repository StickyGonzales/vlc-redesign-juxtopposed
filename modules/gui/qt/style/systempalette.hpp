/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
#ifndef VLC_SYSTEMPALETTE_H
#define VLC_SYSTEMPALETTE_H

#include <QObject>
#include <QColor>
#include <QPalette>
#include <QQuickImageProvider>
#include <QQuickItem>
#include <QPointer>
#include <QtQml/QQmlParserStatus>

#include "qt.hpp"
#include "util/color_scheme_model.hpp"

#include "qtthemeprovider.hpp"

#include "colorcontext.hpp"

class SystemPalette;
class ColorProperty;
class ColorContextState;

Q_MOC_INCLUDE("maininterface/mainctx.hpp")

class CSDMetrics : public QObject {
    Q_OBJECT

    Q_PROPERTY(int interNavButtonSpacing MEMBER interNavButtonSpacing CONSTANT FINAL)

    Q_PROPERTY(int csdFrameMarginLeft MEMBER csdFrameMarginLeft CONSTANT FINAL)
    Q_PROPERTY(int csdFrameMarginRight MEMBER csdFrameMarginRight CONSTANT FINAL)
    Q_PROPERTY(int csdFrameMarginTop MEMBER csdFrameMarginTop CONSTANT FINAL)
    Q_PROPERTY(int csdFrameMarginBottom MEMBER csdFrameMarginBottom CONSTANT FINAL)

public:
    int interNavButtonSpacing = 0;

    int csdFrameMarginLeft = 0;
    int csdFrameMarginRight = 0;
    int csdFrameMarginTop = 0;
    int csdFrameMarginBottom = 0;
};

class ExternalPaletteImpl : public QObject
{
    Q_OBJECT
public:
    ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent = nullptr);

    ~ExternalPaletteImpl();

    bool init();

    bool isThemeDark() const;

    QImage getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight);
    CSDMetrics* getCSDMetrics() const;

    bool hasCSDImages() const;

    int update();
    void updateMetrics(vlc_qt_theme_image_type type);

signals:
    void paletteChanged();
    void CSDMetricsChanged();

public:
    SystemPalette& m_palette;
    MainCtx* m_ctx = nullptr;
    module_t* m_module = nullptr;
    vlc_qt_theme_provider_t* m_provider = nullptr;
    std::unique_ptr<CSDMetrics> m_csdMetrics;
};

#define COLOR_DEFINITION(name, value) \
    Q_PROPERTY(QColor name READ get_##name NOTIFY paletteChanged FINAL) \
public: \
    inline QColor get_## name() const { return name; } \
private: \
    QColor name {value}



class SystemPalette : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
public:
    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(ColorSchemeModel::ColorScheme  source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    Q_PROPERTY(bool isDark MEMBER m_isDark NOTIFY paletteChanged FINAL)
    // redesign: true while a theme or accent switch recolors the interface (until the next
    // event loop pass): color animations stay off then, so the switch is instant (P8-41)
    Q_PROPERTY(bool switching READ isSwitching NOTIFY switchingChanged FINAL)
    Q_PROPERTY(bool hasCSDImage READ hasCSDImage NOTIFY hasCSDImageChanged FINAL)
    Q_PROPERTY(CSDMetrics* csdMetrics READ getCSDMetrics NOTIFY CSDMetricsChanged FINAL)

    //standard color definitions used by light/dark themes
    // redesign: accent defaults to Dark/Accent/Main and Dark/Accent/Bright (redesign/reference/figma/styles.txt)
    COLOR_DEFINITION(orange500, "#D37918");
    COLOR_DEFINITION(orange800, "#FC9729");

    // redesign: Figma color styles of the current theme, exposed to QML as palette.rd*
    // (set by applyRdColors() from redesign/reference/figma/styles.txt)
    COLOR_DEFINITION(rdFg1, "#EAEAEA");
    COLOR_DEFINITION(rdFg2, "#C6C6C6");
    COLOR_DEFINITION(rdFgA1, "#969696");
    COLOR_DEFINITION(rdFgA2, "#8F8F8F");
    COLOR_DEFINITION(rdFgA3, "#6B6B6B");
    COLOR_DEFINITION(rdFgA4, "#404040");
    COLOR_DEFINITION(rdFgB1, "#161616");
    COLOR_DEFINITION(rdAccentMain, "#D37918");
    COLOR_DEFINITION(rdAccentBright, "#FC9729");
    COLOR_DEFINITION(rdAccentDim, "#AB6314");
    COLOR_DEFINITION(rdAccentLogo, "#D37918");
    COLOR_DEFINITION(rdBgAccentBright, "#371F06");
    COLOR_DEFINITION(rdBgAccentDark, "#1A1611");
    COLOR_DEFINITION(rdBgA1, "#222222");
    COLOR_DEFINITION(rdBgA2, "#1F1F1F");
    COLOR_DEFINITION(rdBgA3, "#1B1B1B");
    COLOR_DEFINITION(rdBgA4, "#191919");
    COLOR_DEFINITION(rdBgA5, "#151515");
    COLOR_DEFINITION(rdBgB1, "#0E0E0E");
    COLOR_DEFINITION(rdBgB2, "#090909");
    COLOR_DEFINITION(rdBgA3Transparent, QColor(0x19, 0x19, 0x19, 242)); // #191919 95%
    COLOR_DEFINITION(rdBgB1Transparent, QColor(0x0E, 0x0E, 0x0E, 242)); // #0E0E0E 95%
    COLOR_DEFINITION(rdBgB2Transparent, QColor(0x00, 0x00, 0x00, 204)); // #000000 80%
    COLOR_DEFINITION(rdDividerBright, "#373737");
    COLOR_DEFINITION(rdDividerDim, "#222222");
    COLOR_DEFINITION(rdHoverOverlay, QColor(0xFF, 0xFF, 0xFF, 15)); // hover tint over any background
    // Figma "Settings - global-1" "Reset all settings": red text on a red-tinted button (raw
    // fills, dark frames only)
    COLOR_DEFINITION(rdFgDestructive, "#D33718");
    COLOR_DEFINITION(rdBgDestructive, "#1A1111");
    // Figma color swatch stroke (Text Color, Shadow Color...): #FFFFFF 21 %, 1.5 px
    COLOR_DEFINITION(rdSwatchStroke, QColor(0xFF, 0xFF, 0xFF, 54));
    // selected text on the Accent/DIm selection (no Figma style): FG/1 in Dark, BG/A1 in Light
    COLOR_DEFINITION(rdSelectionText, "#EAEAEA");
    // the BG/A5 input fields (search fields, Add Subtitles fields and dropdowns): BG/A5 in Dark,
    // BG/A3 in Light, where BG/A5 #888888 is a dark block that hides the FG/A4 placeholder
    COLOR_DEFINITION(rdBgField, "#151515");
    COLOR_DEFINITION(rdShadow, QColor(0x00, 0x00, 0x00, 117)); // Figma effect drop shadow #000000 46%
    COLOR_DEFINITION(rdCardShadow, QColor(0x00, 0x00, 0x00, 97)); // Figma onboarding drop shadow #000000 38% (y 4, blur 11.8)
    COLOR_DEFINITION(rdKeyShadow, QColor(0x5C, 0x5C, 0x5C, 64)); // Figma onboarding keycap drop shadow #5C5C5C 25% (y 6, no blur)
    COLOR_DEFINITION(rdListShadow, QColor(0x00, 0x00, 0x00, 89)); // Figma open dropdown list drop shadow #000000 35% (y 4, blur 13.8)    // Figma "volume" component fills of each theme's Player frame: the cone's empty part and the
    // tint over its gradient (Dark: BG/B2 and #000000 20 %, Light: BG/A5 and #FFFFFF 20 %)
    COLOR_DEFINITION(rdVolumeEmpty, "#090909");
    COLOR_DEFINITION(rdVolumeTint, QColor(0x00, 0x00, 0x00, 51));
    // Figma library media fills (unnamed fills of the library frames, only drawn in Dark; media
    // placeholders and shades, the same in both themes): thumbnail / mini player picture base,
    // full library card base, the 20 % shade over card pictures, the playing row's shade and
    // tint, the mini player's hover dim, its card shadow and the music cover's glow
    COLOR_DEFINITION(rdMediaBase, "#303030");
    COLOR_DEFINITION(rdCardBase, "#171717");
    COLOR_DEFINITION(rdFolderCardBase, "#1E1E1E");
    COLOR_DEFINITION(rdCardShade, QColor(0x00, 0x00, 0x00, 51));
    COLOR_DEFINITION(rdPlayingShade, QColor(0x00, 0x00, 0x00, 179));
    COLOR_DEFINITION(rdPlayingTint, QColor(0x95, 0x80, 0x69, 51));
    COLOR_DEFINITION(rdMiniPlayerDim, QColor(0x00, 0x00, 0x00, 153));
    COLOR_DEFINITION(rdMiniPlayerShadow, QColor(0x00, 0x00, 0x00, 97));
    COLOR_DEFINITION(rdCoverGlow, QColor(0xFF, 0xFF, 0xFF, 8));
    // the dashed border of the New Playlist drop zone (Figma "new playlist": #2D2D2D)
    COLOR_DEFINITION(rdDropZoneDash, "#2D2D2D");
    // the subtitle timeline's blocks on the seek bar (video 7:00-7:04, no Figma style): the
    // surface under them with 9 % white (Dark) or black (Light) over it. Played side: over
    // BG/Accent Bright (the played fill), #4A331D in the video; the rest: over BG/B2 (the
    // track), which is BG/A2 in Dark
    COLOR_DEFINITION(rdSeekBlockPlayed, "#49331C");
    COLOR_DEFINITION(rdSeekBlockUnplayed, "#1F1F1F");

    COLOR_DEFINITION(orange400, "#f89a06"); //FIXME name have been chosen randomly by me
    COLOR_DEFINITION(orange200, "#e29a06"); //FIXME name have been chosen randomly by me

    COLOR_DEFINITION(darkGrey200, "#1E1E1E");
    COLOR_DEFINITION(darkGrey300, "#212121");
    COLOR_DEFINITION(darkGrey400, "#242424");
    COLOR_DEFINITION(darkGrey500, "#272727");
    COLOR_DEFINITION(darkGrey600, "#2A2A2A");
    COLOR_DEFINITION(darkGrey700, "#2D2D2D");
    COLOR_DEFINITION(darkGrey800, "#303030");

    COLOR_DEFINITION(lightGrey100, "#FAFAFA");
    COLOR_DEFINITION(lightGrey200, "#F6F6F6");
    COLOR_DEFINITION(lightGrey300, "#F2F2F2");
    COLOR_DEFINITION(lightGrey400, "#EDEDED");
    COLOR_DEFINITION(lightGrey500, "#E9E9E9");
    COLOR_DEFINITION(lightGrey600, "#E5E5E5");
    COLOR_DEFINITION(lightGrey700, "#E0E0E0");

    COLOR_DEFINITION(red500, "#FF0000");

public:
    SystemPalette(QObject* parent = nullptr);

    ColorSchemeModel::ColorScheme source() const;
    QImage getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight);
    CSDMetrics* getCSDMetrics() const;

    inline MainCtx* getCtx() const { return m_ctx; }
    inline bool isSwitching() const { return m_switching; }
    bool hasCSDImage() const;

    void setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                  ColorContext::ColorName name, ColorContext::ColorState state, QColor color);
    QColor getColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                    ColorContext::ColorName name, ColorContext::ColorState state) const;

    void classBegin() override { }
    void componentComplete() override;

public slots:
    void setSource(ColorSchemeModel::ColorScheme source);
    void setCtx(MainCtx* ctx);


signals:
    void sourceChanged();
    void paletteChanged();
    void switchingChanged();
    void hasCSDImageChanged();
    void ctxChanged();
    void CSDMetricsChanged();

private:
    void updatePalette();
    void applyRdColors();

    void makeLightPalette();
    void makeDarkPalette();
    void makeRdColorSets();
    void makeSystemPalette();

private:
    MainCtx* m_ctx = nullptr;
    QMetaObject::Connection m_accentConnection; // redesign: live accent

    ColorSchemeModel::ColorScheme m_source = ColorSchemeModel::ColorScheme::Day;
    bool m_isDark = false;
    bool m_switching = false;
    bool m_hasCSDImage = false;

    std::unique_ptr<ExternalPaletteImpl> m_palettePriv;

    QMap<quint64, QColor> m_colorMap;

};

#undef COLOR_PROPERTY
#undef COLOR_DEFINITION

#endif // VLC_SYSTEMPALETTE_H
