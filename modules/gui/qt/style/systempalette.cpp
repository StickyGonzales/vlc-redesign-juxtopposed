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
#include "systempalette.hpp"

#include <algorithm>
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QFile>
#include <QTimer>
#include <maininterface/mainctx.hpp>
#include <vlc_modules.h>
#include <vlc_picture.h>

namespace {

QColor setColorAlpha(const QColor& c1, float alpha)
{
    QColor c(c1);
    c.setAlphaF(alpha);
    return c;
}

#ifndef _WIN32
/**
 * function taken from QtBase gui/platform/unix/qgenericunixservices.cpp
 */
static inline QByteArray detectLinuxDesktopEnvironment()
{
    const QByteArray xdgCurrentDesktop = qgetenv("XDG_CURRENT_DESKTOP");
    if (!xdgCurrentDesktop.isEmpty())
        return xdgCurrentDesktop.toUpper(); // KDE, GNOME, UNITY, LXDE, MATE, XFCE...

    // Classic fallbacks
    if (!qEnvironmentVariableIsEmpty("KDE_FULL_SESSION"))
        return QByteArrayLiteral("KDE");
    if (!qEnvironmentVariableIsEmpty("GNOME_DESKTOP_SESSION_ID"))
        return QByteArrayLiteral("GNOME");

    // Fallback to checking $DESKTOP_SESSION (unreliable)
    QByteArray desktopSession = qgetenv("DESKTOP_SESSION");

    // This can be a path in /usr/share/xsessions
    int slash = desktopSession.lastIndexOf('/');
    if (slash != -1) {
        QSettings desktopFile(QFile::decodeName(desktopSession + ".desktop"), QSettings::IniFormat);
        desktopFile.beginGroup(QStringLiteral("Desktop Entry"));
        QByteArray desktopName = desktopFile.value(QStringLiteral("DesktopNames")).toByteArray();
        if (!desktopName.isEmpty())
            return desktopName;

        // try decoding just the basename
        desktopSession = desktopSession.mid(slash + 1);
    }

    if (desktopSession == "gnome")
        return QByteArrayLiteral("GNOME");
    else if (desktopSession == "xfce")
        return QByteArrayLiteral("XFCE");
    else if (desktopSession == "kde")
        return QByteArrayLiteral("KDE");

    return QByteArrayLiteral("UNKNOWN");
}

bool isGTKBasedEnvironment()
{
    QList<QByteArray> gtkBasedEnvironments{
        "GNOME",
        "X-CINNAMON",
        "UNITY",
        "MATE",
        "XFCE",
        "LXDE"
    };
    const QList<QByteArray> desktopNames = detectLinuxDesktopEnvironment().split(':');
    for (const QByteArray& desktopName: desktopNames)
    {
        if (gtkBasedEnvironments.contains(desktopName))
            return true;
    }
    return false;
}
#endif


static void PaletteChangedCallback(vlc_qt_theme_provider_t*, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    emit priv->paletteChanged();
}

static void MetricsChangedCallback(vlc_qt_theme_provider_t*, vlc_qt_theme_image_type type, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    assert(priv);
    priv->updateMetrics(type);
}


static void ReleaseVLCPictureCb(void* data)
{
    auto pic = static_cast<picture_t*>(data);
    if (pic)
        picture_Release(pic);
}


static void setColorRBGAInt(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    int r, int g, int b, int a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

static void setColorRBGAFloat(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    double r, double g, double b, double a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color;
    color.setRgbF(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

}

//ExternalPaletteImpl

ExternalPaletteImpl::ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent)
    : QObject(parent)
    , m_palette(palette)
    , m_ctx(ctx)
{
}

ExternalPaletteImpl::~ExternalPaletteImpl()
{
    if (m_provider)
    {
        if (m_provider->close)
            m_provider->close(m_provider);
        if (m_module)
            module_unneed(m_provider, m_module);
        vlc_object_delete(m_provider);
    }
}

bool ExternalPaletteImpl::init()
{
    QString preferedProvider;
#ifndef _WIN32
    if (isGTKBasedEnvironment())
        preferedProvider = "qt-themeprovider-gtk";
#endif

    m_provider = vlc_object_create<vlc_qt_theme_provider_t>(m_ctx->getIntf());
    if (!m_provider)
        return false;


    m_provider->paletteUpdated = PaletteChangedCallback;
    m_provider->paletteUpdatedData = this;

    m_provider->metricsUpdated = MetricsChangedCallback;
    m_provider->metricsUpdatedData = this;

    m_provider->setColorF = setColorRBGAFloat;
    m_provider->setColorInt = setColorRBGAInt;
    m_provider->setColorData = &m_palette;

    m_module = module_need(m_provider, "qt theme provider",
                           preferedProvider.isNull() ? nullptr : qtu(preferedProvider),
                           true);
    if (!m_module)
        return false;
    return true;
}

bool ExternalPaletteImpl::isThemeDark() const
{
    if (!m_provider->isThemeDark)
        return false;
    return m_provider->isThemeDark(m_provider);
}

bool ExternalPaletteImpl::hasCSDImages() const
{
    if (!m_provider->supportThemeImage)
        return false;
    return m_provider->supportThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON);
}


QImage ExternalPaletteImpl::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!m_provider->getThemeImage)
        return {};
    vlc_qt_theme_image_setting imageSettings;
    imageSettings.windowScaleFactor = m_ctx->intfMainWindow()->devicePixelRatio();
    imageSettings.userScaleFacor = m_ctx->getIntfUserScaleFactor();
    imageSettings.u.csdButton.buttonType = type;
    imageSettings.u.csdButton.state = state;
    imageSettings.u.csdButton.maximized = maximized;
    imageSettings.u.csdButton.active = active;
    imageSettings.u.csdButton.bannerHeight = bannerHeight;
    picture_t* pic = m_provider->getThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &imageSettings);
    if (!pic)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    switch (pic->format.i_chroma)
    {
    case VLC_CODEC_ARGB:
        format = QImage::Format_ARGB32_Premultiplied;
        break;
    case VLC_CODEC_RGBA:
        format = QImage::Format_RGBA8888_Premultiplied;
        break;
    case VLC_CODEC_RGB24:
        format = QImage::Format_RGB888;
        break;
    default:
        msg_Err(m_ctx->getIntf(), "unexpected image format from theme provider");
        break;
    }

    return QImage(pic->p[0].p_pixels,
            pic->format.i_visible_width, pic->format.i_visible_height, pic->p[0].i_pitch,
            format,
            ReleaseVLCPictureCb, pic
            );
}

CSDMetrics* ExternalPaletteImpl::getCSDMetrics() const
{
    return m_csdMetrics.get();
}

int ExternalPaletteImpl::update()
{
    if (m_provider->updatePalette)
        return m_provider->updatePalette(m_provider);
    return VLC_EGENERIC;
}

void ExternalPaletteImpl::updateMetrics(vlc_qt_theme_image_type type)
{
    if (m_provider->getThemeMetrics)
    {
        if (type == VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON)
        {
            m_csdMetrics.reset();
            [&](){
                if (!m_provider->getThemeMetrics)
                    return;
                vlc_qt_theme_metrics metrics;
                memset(&metrics, 0, sizeof(metrics));
                bool ret = m_provider->getThemeMetrics(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &metrics);
                if (!ret)
                    return;
                m_csdMetrics = std::make_unique<CSDMetrics>();
                m_csdMetrics->interNavButtonSpacing = metrics.u.csd.interNavButtonSpacing;

                m_csdMetrics->csdFrameMarginLeft = metrics.u.csd.csdFrameMarginLeft;
                m_csdMetrics->csdFrameMarginRight = metrics.u.csd.csdFrameMarginRight;
                m_csdMetrics->csdFrameMarginTop = metrics.u.csd.csdFrameMarginTop;
                m_csdMetrics->csdFrameMarginBottom = metrics.u.csd.csdFrameMarginBottom;
            }();
            emit CSDMetricsChanged();
        }
    }
}

SystemPalette::SystemPalette(QObject* parent)
    : QObject(parent)
{

}

namespace {
// redesign: one Figma color style set (redesign/reference/figma/styles.txt)
struct RdThemeColors
{
    const char* fg1; const char* fg2;
    const char* fgA1; const char* fgA2; const char* fgA3; const char* fgA4; const char* fgB1;
    const char* accentMain; const char* accentBright; const char* accentDim; const char* accentLogo;
    const char* bgAccentBright; const char* bgAccentDark;
    const char* bgA1; const char* bgA2; const char* bgA3; const char* bgA4; const char* bgA5;
    const char* bgB1; const char* bgB2;
    QRgb bgA3Transparent; QRgb bgB1Transparent; QRgb bgB2Transparent;
    const char* dividerBright; const char* dividerDim;
    QRgb hoverOverlay;
    const char* fgDestructive; const char* bgDestructive; QRgb swatchStroke;
    const char* volumeEmpty; QRgb volumeTint;
};

const RdThemeColors rdDarkColors = {
    "#EAEAEA", "#C6C6C6",
    "#969696", "#8F8F8F", "#6B6B6B", "#404040", "#161616",
    "#D37918", "#FC9729", "#AB6314", "#D37918",
    "#371F06", "#1A1611",
    "#222222", "#1F1F1F", "#1B1B1B", "#191919", "#151515",
    "#0E0E0E", "#090909",
    qRgba(0x19, 0x19, 0x19, 242), qRgba(0x0E, 0x0E, 0x0E, 242), qRgba(0x00, 0x00, 0x00, 204),
    "#373737", "#222222",
    // Figma "Icon Wrapper" hover
    qRgba(0xFF, 0xFF, 0xFF, 15),
    // Figma "Settings - global-1" red button; swatch stroke #FFFFFF 21 %
    "#D33718", "#1A1111", qRgba(0xFF, 0xFF, 0xFF, 54),
    // Figma "Player" volume: BG/B2 and the #000000 20 % tint
    "#090909", qRgba(0x00, 0x00, 0x00, 51),
};

// Every value is the Figma "Light" style of the same name, except:
// - Light/FG/1 and Light/FG/2, which repeat the dark values in the Figma file: #111111 and
//   #222222 instead (Decision 33, Sticky 2026-10-14)
// - Light/FG/A4 (placeholders, disabled text): #8A8A8A instead of the file's #3B3B3B, which read
//   almost like typed text (Decision 44, Sticky 2026-10-15)
// - BG/B2 Transparent and the hover tint, which the file only has in Dark: B2 at 80 %, like the
//   other light Transparent styles, and #000000 6 %, the dark #FFFFFF 6 % mirrored
const RdThemeColors rdLightColors = {
    "#111111", "#222222",
    "#3C3C3C", "#2E2E2E", "#6B6B6B", "#8A8A8A", "#161616",
    "#E8851A", "#FFA13B", "#965916", "#C2711A",
    "#D8BA9A", "#C6AB89",
    "#EDEDED", "#DDDDDD", "#D5D5D5", "#B3B3B3", "#888888",
    "#E7E7E7", "#DEDEDE",
    qRgba(0xD5, 0xD5, 0xD5, 191), qRgba(0xE7, 0xE7, 0xE7, 204), qRgba(0xDE, 0xDE, 0xDE, 204),
    "#9B9B9B", "#ACACAC",
    qRgba(0x00, 0x00, 0x00, 15),
    // the red button exists in the dark frames only: light buttons are dark (RdButton), so the
    // dark tint over the light Standard button's FG/A2 with the red lightened to 4.4:1 (the dark
    // pair is 3.8:1); the swatch stroke mirrored (#000000 21 %)
    "#E8604A", "#2F2626", qRgba(0x00, 0x00, 0x00, 54),
    // Figma "Player - Light" volume: BG/A5 and the #FFFFFF 20 % tint
    "#888888", qRgba(0xFF, 0xFF, 0xFF, 51),
};

// derive an accent shade for a user accent: keep its hue and scale saturation and
// value the way the theme's reference set scales them from its own main accent
QColor deriveAccentShade(const QColor& main, const QColor& refMain, const QColor& refShade)
{
    float h, s, v, a;
    main.getHsvF(&h, &s, &v, &a);
    if (h < 0)
        h = 0;
    const float satRatio = refMain.hsvSaturationF() > 0 ? refShade.hsvSaturationF() / refMain.hsvSaturationF() : 1.f;
    const float valRatio = refMain.valueF() > 0 ? refShade.valueF() / refMain.valueF() : 1.f;
    return QColor::fromHsvF(h, std::min(1.f, s * satRatio), std::min(1.f, v * valRatio));
}

// a color with a layer of `layer` at `opacity` painted over it
QColor overlayColor(const QColor& base, const QColor& layer, float opacity)
{
    return QColor::fromRgbF(base.redF() + (layer.redF() - base.redF()) * opacity,
                            base.greenF() + (layer.greenF() - base.greenF()) * opacity,
                            base.blueF() + (layer.blueF() - base.blueF()) * opacity);
}
}

void SystemPalette::applyRdColors()
{
    const RdThemeColors& t = m_isDark ? rdDarkColors : rdLightColors;
    rdFg1 = QColor(t.fg1);
    rdFg2 = QColor(t.fg2);
    rdFgA1 = QColor(t.fgA1);
    rdFgA2 = QColor(t.fgA2);
    rdFgA3 = QColor(t.fgA3);
    rdFgA4 = QColor(t.fgA4);
    rdFgB1 = QColor(t.fgB1);
    rdBgA1 = QColor(t.bgA1);
    rdBgA2 = QColor(t.bgA2);
    rdBgA3 = QColor(t.bgA3);
    rdBgA4 = QColor(t.bgA4);
    rdBgA5 = QColor(t.bgA5);
    rdBgB1 = QColor(t.bgB1);
    rdBgB2 = QColor(t.bgB2);
    rdBgA3Transparent = QColor::fromRgba(t.bgA3Transparent);
    rdBgB1Transparent = QColor::fromRgba(t.bgB1Transparent);
    rdBgB2Transparent = QColor::fromRgba(t.bgB2Transparent);
    rdDividerBright = QColor(t.dividerBright);
    rdDividerDim = QColor(t.dividerDim);
    rdHoverOverlay = QColor::fromRgba(t.hoverOverlay);
    rdFgDestructive = QColor(t.fgDestructive);
    rdBgDestructive = QColor(t.bgDestructive);
    rdSwatchStroke = QColor::fromRgba(t.swatchStroke);
    // selected text on Accent/DIm (Figma shows no text selection): FG/1 in Dark; in Light FG/1
    // (#111111) on #965916 reads badly (3.4:1), BG/A1 gives 4.8:1
    rdSelectionText = m_isDark ? rdFg1 : rdBgA1;
    // the BG/A5 input fields: in Light BG/A5 (#888888) is darker than every other surface and
    // the FG/A4 placeholder (#8A8A8A, Decision 44) vanishes on it; BG/A3 sits a little darker
    // than the light pages, as BG/A5 sits a little lighter than the dark ones
    rdBgField = m_isDark ? rdBgA5 : rdBgA3;
    rdVolumeEmpty = QColor(t.volumeEmpty);
    rdVolumeTint = QColor::fromRgba(t.volumeTint);

    // accent: the user's choice (qt-accent-color, live from MainCtx), else the theme's own
    QColor main;
    if (m_ctx && m_ctx->accentColor().isValid())
        main = m_ctx->accentColor();
    else if (m_ctx)
    {
        char* accentColor = var_InheritString(m_ctx->getIntf(), "qt-accent-color");
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        if (accentColor && !strcmp(accentColor, "system"))
        {
            assert(qApp);
            main = qApp->palette().color(QPalette::Normal, QPalette::Accent);
        }
#endif
        free(accentColor);
    }

    const QColor refMain(t.accentMain);
    // the default accent (Dark/Accent/Main) maps to each theme's exact Figma set
    if (!main.isValid() || main == QColor(rdDarkColors.accentMain))
        main = refMain;

    rdAccentMain = orange500 = main;
    if (main == refMain)
    {
        rdAccentBright = orange800 = QColor(t.accentBright);
        rdAccentDim = QColor(t.accentDim);
        rdAccentLogo = QColor(t.accentLogo);
        rdBgAccentBright = QColor(t.bgAccentBright);
        rdBgAccentDark = QColor(t.bgAccentDark);
    }
    else
    {
        rdAccentBright = orange800 = deriveAccentShade(main, refMain, QColor(t.accentBright));
        rdAccentDim = deriveAccentShade(main, refMain, QColor(t.accentDim));
        rdAccentLogo = deriveAccentShade(main, refMain, QColor(t.accentLogo));
        rdBgAccentBright = deriveAccentShade(main, refMain, QColor(t.bgAccentBright));
        rdBgAccentDark = deriveAccentShade(main, refMain, QColor(t.bgAccentDark));
    }

    // the subtitle timeline's blocks: the surface under them with 9 % white (Dark) or black
    // (Light) over it (video 7:00-7:04: #4A331D over the #331902 fill); they follow the accent
    const QColor blockLayer = m_isDark ? QColor(Qt::white) : QColor(Qt::black);
    rdSeekBlockPlayed = overlayColor(rdBgAccentBright, blockLayer, 0.09f);
    // Dark: exactly BG/A2 (video #1F1F1F); Light BG/A2 is as light as the track
    rdSeekBlockUnplayed = m_isDark ? rdBgA2 : overlayColor(rdBgB2, blockLayer, 0.09f);
}

void SystemPalette::componentComplete()
{
    assert(m_ctx);
    updatePalette();
}

ColorSchemeModel::ColorScheme SystemPalette::source() const
{
    return m_source;
}

QImage SystemPalette::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!hasCSDImage())
        return QImage();
    assert(m_palettePriv);
    return m_palettePriv->getCSDImage(type, state, maximized, active, bannerHeight);

}

CSDMetrics* SystemPalette::getCSDMetrics() const
{
    if (!m_palettePriv)
        return nullptr;
    return m_palettePriv->getCSDMetrics();
}

bool SystemPalette::hasCSDImage() const
{
    if (!m_palettePriv)
        return false;
    return m_palettePriv->hasCSDImages();
}

void SystemPalette::setSource(ColorSchemeModel::ColorScheme source)
{
    if (m_source == source)
        return;
    m_source = source;

    updatePalette();
    emit sourceChanged();
}

void SystemPalette::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    disconnect(m_accentConnection);
    m_ctx = ctx;
    if (m_ctx)
    {
        // redesign: live accent recolor (Decision 9 / 15)
        m_accentConnection = connect(m_ctx, &MainCtx::accentColorChanged,
                                     this, &SystemPalette::updatePalette);
    }
    emit ctxChanged();
    updatePalette();
}

void SystemPalette::updatePalette()
{
    // redesign: a theme or accent switch recolors everything in one frame (P8-41): the flag
    // holds the color animations off until the next event loop pass
    if (!m_switching)
    {
        m_switching = true;
        emit switchingChanged();
        QTimer::singleShot(0, this, [this]() {
            m_switching = false;
            emit switchingChanged();
        });
    }

    m_palettePriv.reset();
    switch(m_source)
    {
    case ColorSchemeModel::System:
        makeSystemPalette();
        break;
    case ColorSchemeModel::Day:
        makeLightPalette();
        break;
    case ColorSchemeModel::Night:
        makeDarkPalette();
        break;
    default:
        break;
    }

    if (m_palettePriv)
    {
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::paletteChanged,
            this, &SystemPalette::updatePalette);
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::CSDMetricsChanged,
            this, &SystemPalette::CSDMetricsChanged);
    }
    emit paletteChanged();

    bool hasCSDImage = m_palettePriv && m_palettePriv->hasCSDImages();
    if (m_hasCSDImage != hasCSDImage)
    {
        m_hasCSDImage = hasCSDImage;
        emit hasCSDImageChanged();
    }
}

static quint64 makeKey(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                       ColorContext::ColorName name, ColorContext::ColorState state)
{
    static_assert(VQTC_STATE_COUNT < (1<<4), "");
    static_assert(VQTC_SECTION_COUNT < (1<<4), "");
    static_assert(VQTC_NAME_COUNT < (1<<8), "");
    static_assert(VQTC_SET_COUNT < (1<<16), "");
    return  (colorSet << 16)
        + (name << 8)
        + (section << 4)
        + state;
}

void SystemPalette::setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                             ColorContext::ColorName name, ColorContext::ColorState state, QColor color)
{

    quint64 key = makeKey(colorSet, section, name, state);
    m_colorMap[key] = color;
}


QColor SystemPalette::getColor(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                               ColorContext::ColorName name, ColorContext::ColorState state) const
{
    typedef ColorContext C;

    quint64 key = makeKey(colorSet, section, name, state);
    auto it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the normal state
    key = makeKey(colorSet, section, name, C::Normal);
    it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the colorSet View
    //TODO do we want finer hierarchy?
    if (colorSet != C::View)
    {
        return getColor(C::View, section, name, state);
    }
    else
    {
        //nothing matches, that's probably an issue, return an ugly color
        return Qt::magenta;
    }
}


void SystemPalette::makeLightPalette()
{
    // redesign: the Figma "Light" color styles, mapped to VLC's color sets like the dark ones
    m_isDark = false;
    applyRdColors();
    makeRdColorSets();
}

void SystemPalette::makeDarkPalette()
{
    // redesign: values are the Figma "Dark" color styles (redesign/reference/figma/styles.txt).
    // The accent follows orange500 / orange800 so qt-accent-color keeps working.
    m_isDark = true;
    applyRdColors();
    makeRdColorSets();
}

// redesign: VLC's color sets from the rd* colors of the current theme (applyRdColors()), so
// both themes use the same Figma style roles (Decisions (Claude), W2.1)
void SystemPalette::makeRdColorSets()
{
    m_colorMap.clear();

    typedef ColorContext C;

    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA3);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);

        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFgA3);

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdBgA2);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdFg2);

        // status colors (no Figma style): VLC's own values of each theme
        setColor(CS, C::Bg, C::Negative, C::Normal, m_isDark ? QColor(Qt::darkRed) : QColor("#fde7e9"));
        setColor(CS, C::Fg, C::Negative, C::Normal, Qt::red);

        setColor(CS, C::Bg, C::Neutral, C::Normal, rdBgAccentBright);
        setColor(CS, C::Fg, C::Neutral, C::Normal, orange500);

        setColor(CS, C::Bg, C::Positive, C::Normal, m_isDark ? QColor(Qt::darkGreen) : QColor("#dff6dd"));
        setColor(CS, C::Fg, C::Positive, C::Normal, Qt::green);

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(Qt::white, 0.0) );
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, rdFg2 );

        setColor(CS, C::Decoration, C::Border, C::Normal, rdDividerBright );
        setColor(CS, C::Decoration, C::Border, C::Focused, rdFgA3 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, rdFgA3 );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::white, 0.0) );

        setColor(CS, C::Decoration, C::Shadow, C::Normal, rdShadow);

        setColor(CS, C::Decoration, C::Separator, C::Normal, rdDividerDim);

        setColor(CS, C::Decoration, C::Accent, C::Normal, orange500);
        setColor(CS, C::Fg, C::Link, C::Normal, orange500);
    }

    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA3);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdDividerDim);
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFg2);
    }

    //tab button: label FG/A3, active FG/1, accent underline drawn by the tab itself
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(rdBgB2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, rdHoverOverlay);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdHoverOverlay);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA3);
        setColor(CS, C::Fg, C::Primary, C::Focused, rdFg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFg1);
    }

    //tool button = Figma "Icon Wrapper": icon FG/A2, hover background #FFFFFF 6%
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdHoverOverlay);
        setColor(CS, C::Bg, C::Primary, C::Focused, rdHoverOverlay);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, orange500);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(rdBgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgA2);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);
    }

    //Item (list rows, menu options): hover/selected BG/A2, text FG/A1 -> FG/2 on hover
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(rdBgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgA2);

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdBgA2);
        setColor(CS, C::Bg, C::Highlight, C::Focused, rdBgA1);
        setColor(CS, C::Bg, C::Highlight, C::Hovered, rdBgA1);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdFg2);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFg2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFgA3);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, rdFgA4);
    }

    //Accent Buttons: solid accent with FG/B1 text (play button, onboarding Next, Continue Watching)
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, orange500);
        setColor(CS, C::Bg, C::Primary, C::Hovered, orange800);
        setColor(CS, C::Bg, C::Primary, C::Pressed, rdAccentDim);
        setColor(CS, C::Bg, C::Primary, C::Disabled, rdBgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgB1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons: Figma "Cancel" (BG/A3, FG/A2)
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA3);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgA1);
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //tooltip: Figma "audio value" (BG/B1 95%, FG/A1)
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB1Transparent);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA1);
    }

    //slider: track BG/B2, played part accent
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB2);
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgB2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgB2);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgAccentBright);

        setColor(CS, C::Fg, C::Primary, C::Normal, orange500);
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box: Figma "Dropdown" (BG/B2 frame, BG/A4 option, FG/A2 text)
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);
        setColor(CS, C::Bg, C::Highlight, C::Normal, rdBgA2);
    }

    //TextField: Figma inputs (BG/B2 fill, 2 px BG/A4 border, accent when focused)
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB2);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFg2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdBgA4 );
        setColor(CS, C::Decoration, C::Border, C::Focused, orange500 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, rdDividerBright );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::white, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdAccentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdSelectionText);
    }

    //Switch: Figma "Toggle" (OFF knob FG/A4 on BG/A4, ON knob Accent/DIm on BG/Accent Bright)
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA4);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdBgB2);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgAccentBright);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdAccentDim);
    }

    //Spinbox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB2);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdBgA4 );
        setColor(CS, C::Decoration, C::Border, C::Focused, orange500 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, rdDividerBright );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::white, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdAccentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdSelectionText);
    }
}

void SystemPalette::makeSystemPalette()
{
    if (!m_ctx)
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    auto palette = std::make_unique<ExternalPaletteImpl>(m_ctx, *this);
    if (!palette->init())
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    m_colorMap.clear();
    int ret = palette->update();
    if (ret != VLC_SUCCESS)
    {
        if (palette->isThemeDark())
            makeDarkPalette();
        else
            makeLightPalette();
    }
    else
    {
        m_isDark = palette->isThemeDark();
        applyRdColors();
    }

    m_palettePriv = std::move(palette);
}
