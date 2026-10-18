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
#ifndef VLC_QT_BRAND_HPP
#define VLC_QT_BRAND_HPP

/**
 * redesign: brand layer, the one definition of the app's name and logo inside the interface
 * (redesign/BUILD_NOTES.md "Brand layer (vlc / public profiles)").
 *
 * One build input picks the profile: configure --with-brand=vlc|public (meson -Dbrand=...,
 * extras/package/win32/build.sh -B, the build-windows workflow's "brand" input). The "public"
 * profile defines VLC_BRAND_PUBLIC in config.h.
 * - vlc (default): VLC's name and cone, exactly what the interface showed before this layer.
 * - public: "Cone" with StickyGonzales' logo (pixmaps/brand/public). Layout, colors, fonts, the accent
 *   and the cone-shaped volume slider are the same in both profiles.
 *
 * The texts are macros so qtr() keeps looking up VLC's exact source strings, and so their VLC
 * translations, in the vlc profile. The packaging side (exe name, version info, installer) is
 * set by configure.ac / meson.build from the same input.
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#ifdef VLC_BRAND_PUBLIC

# define BRAND_NAME             "Cone"
# define BRAND_SHORT_NAME       "Cone"
/* top bar title without media (MainDisplay.qml) */
# define BRAND_TITLE            "Cone"
# define BRAND_TRAY_HIDE        "&Hide Cone in taskbar"
# define BRAND_TRAY_SHOW        "Sho&w Cone"
# define BRAND_MENU_ABOUT       "About Cone"
# define BRAND_MENU_QUIT        "Quit Cone"
/* settings catalog group of the core options that have no category */
# define BRAND_CORE_GROUP       "Cone"
# define BRAND_WELCOME_TITLE    "Welcome to Cone!"
# define BRAND_WELCOME_TEXT     "Cone is a free and open source media player based on VLC. It plays most " \
                                "video and audio files as well as DVDs, Audio CDs, VCDs and various " \
                                "streaming protocols."
/* About dialog (help.cpp closes the last paragraph) */
# define BRAND_ABOUT_TEXT       "<p>Cone, based on <a href=\"https://www.videolan.org/vlc/\"><span style=\" text-decoration: underline; color:#0057ae;\">VLC media player</span></a> by VideoLAN. " \
                                "Design by <a href=\"https://www.figma.com/community/file/1691465999134370980/vlc-redesign\"><span style=\" text-decoration: underline; color:#0057ae;\">Juxtopposed</span></a> " \
                                "(<a href=\"https://creativecommons.org/licenses/by/4.0/\"><span style=\" text-decoration: underline; color:#0057ae;\">CC BY 4.0</span></a>). " \
                                "Built by StickyGonzales.</p><p>Cone is not affiliated with VideoLAN or Juxtopposed."
/* VLC's seasonal cones (Christmas, April fools) are VLC logos: none in Cone */
# define BRAND_SEASONAL_LOGOS   0
/* About dialog: "Cone 0.1.0" as the title, "based on VLC <version>" under it (Decision 58;
 * BRAND_VERSION comes from configure --with-brand-version / meson -Dbrand-version) */
# define BRAND_ABOUT_TITLE      "Cone " BRAND_VERSION
# define BRAND_VERSION_TEXT     "based on VLC " VERSION

/* logo for the redesign's icon path (widgets/qml/RdIcon.qml loads qrc:///rd/<name>.svg): one
 * path filled with #FF8800, the colorizer's accent slot (util/color_svg_image_provider.cpp
 * COLOR_ACCENT_KEY), so it follows Accent/Logo live like the cone; small variants have wider
 * bands */
# define BRAND_LOGO_ICON_SMALL  "cone-logo-16"
# define BRAND_LOGO_ICON        "cone-logo-24"
# define BRAND_LOGO_ICON_LARGE  "cone-logo"
# define BRAND_LOGO_SVG         "qrc:///rd/cone-logo.svg"

/* where the app keeps its settings, apart from an installed VLC's: the folder in %APPDATA%
 * (src/win32/dirs.c APP_DIR_NAME), the Qt settings' organization (vlc-qt-interface.ini in it)
 * and the registry key of the interface language (bin/winvlc.c reads it at startup) */
# define BRAND_CONFIG_DIR       "Cone"
# define BRAND_REGISTRY_KEY     "Software\\Cone\\"
/* the installer's ProgID prefix and registered application name, and its install key
 * (extras/package/win32/NSIS, configure BRAND_PROGID / BRAND_REGKEY): the file association
 * dialog of the preferences uses them */
# define BRAND_PROGID           "Cone"
# define BRAND_INSTALL_REGKEY   "Software\\Cone"

#else

# define BRAND_NAME             "VLC media player"
# define BRAND_SHORT_NAME       "VLC"
# define BRAND_TITLE            "VLC Media Player"
# define BRAND_TRAY_HIDE        "&Hide VLC media player in taskbar"
# define BRAND_TRAY_SHOW        "Sho&w VLC media player"
# define BRAND_MENU_ABOUT       "About VLC"
# define BRAND_MENU_QUIT        "Quit VLC"
# define BRAND_CORE_GROUP       "VLC"
# define BRAND_WELCOME_TITLE    "Welcome to VLC!"
# define BRAND_WELCOME_TEXT     "VLC is a free and open source cross-platform multimedia player and framework " \
                                "that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and " \
                                "various streaming protocols."
# define BRAND_ABOUT_TEXT       "<p>VLC media player is a free and open source media player, encoder, and streamer made by the volunteers of the <a href=\"https://www.videolan.org/\"><span style=\" text-decoration: underline; color:#0057ae;\">VideoLAN</span></a> community.</p><p>VLC uses its internal codecs, works on essentially every popular platform, and can read almost all files, CDs, DVDs, network streams, capture cards and other media formats!</p><p><a href=\"https://www.videolan.org/contribute/\"><span style=\" text-decoration: underline; color:#0057ae;\">Help and join us!</span></a>"
# define BRAND_SEASONAL_LOGOS   1
# define BRAND_ABOUT_TITLE      BRAND_NAME
# define BRAND_VERSION_TEXT     VERSION_MESSAGE

/* the Figma "vlc" icon (pixmaps/redesign/vlc.svg) at every size, and VLC's cone */
# define BRAND_LOGO_ICON_SMALL  "vlc"
# define BRAND_LOGO_ICON        "vlc"
# define BRAND_LOGO_ICON_LARGE  "vlc"
# define BRAND_LOGO_SVG         "qrc:///misc/cone.svg"

# define BRAND_CONFIG_DIR       "vlc"
# define BRAND_REGISTRY_KEY     "Software\\VideoLAN\\VLC\\"
# define BRAND_PROGID           "VLC"
# define BRAND_INSTALL_REGKEY   "Software\\VideoLAN\\VLC"

#endif

#include <QObject>
#include <QIcon>
#include <QPixmap>
#include <QString>

struct qt_intf_t;

namespace brand
{
/* window and taskbar icon (qt.cpp) */
QIcon windowIcon(qt_intf_t* intf);
/* system tray icon (dialogs/systray) */
QIcon trayIcon(bool seasonal);
/* 16 px icon of the tray menu's Hide / Show entries */
QIcon trayMenuIcon();
/* About dialog logo; null keeps the one of dialogs/help/about.ui */
QPixmap aboutLogo(qt_intf_t* intf);
/* extension without an icon of its own (dialogs/plugins) */
QPixmap extensionFallbackIcon();
/* a text of the engine (option, choice, plugin and hotkey texts, already translated) as the
 * redesign's Settings show it: in the public profile the app's name replaces VLC's ("VLC media
 * player" and "VLC", but not "VLC" before a version number such as "VLC 3.0"), so the text keeps
 * its translation; the vlc profile returns the text unchanged */
QString engineText(const QString& text);
}

/**
 * The brand for QML, registered as the "Brand" singleton of VLC.MainInterface.
 * isPublic tells the QML spots that draw the logo as a plain image (NoMedialibHome, MinimalView,
 * BannerCone, UpdatePane) to colorize logoSvg with Accent/Logo instead of VLC's cone.
 */
class BrandInfo : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool isPublic READ isPublic CONSTANT FINAL)
    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(QString shortName READ shortName CONSTANT FINAL)
    Q_PROPERTY(QString title READ title CONSTANT FINAL)
    Q_PROPERTY(QString welcomeTitle READ welcomeTitle CONSTANT FINAL)
    Q_PROPERTY(QString welcomeText READ welcomeText CONSTANT FINAL)
    Q_PROPERTY(QString logoIconSmall READ logoIconSmall CONSTANT FINAL)
    Q_PROPERTY(QString logoIcon READ logoIcon CONSTANT FINAL)
    Q_PROPERTY(QString logoIconLarge READ logoIconLarge CONSTANT FINAL)
    Q_PROPERTY(QString logoSvg READ logoSvg CONSTANT FINAL)

public:
    explicit BrandInfo(QObject* parent = nullptr);

    bool isPublic() const;
    QString name() const;
    QString shortName() const;
    QString title() const;
    QString welcomeTitle() const;
    QString welcomeText() const;
    QString logoIconSmall() const;
    QString logoIcon() const;
    QString logoIconLarge() const;
    QString logoSvg() const;
};

#endif // VLC_QT_BRAND_HPP
