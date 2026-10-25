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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "brand.hpp"

#include "qt.hpp"

#include <QDate>
#include <QRegularExpression>

#include <initializer_list>

#ifdef VLC_BRAND_PUBLIC
namespace
{
/* the approved logo bitmaps (pixmaps/brand/public/cone-<size>.png, brand_public.qrc); they are
 * the entries of extras/package/win32/brand/public/cone.ico (16 to 256) and cone-tray.ico (16 to
 * 48): VLC's Qt has no ICO reader, so the interface loads the same images as PNG */
QIcon logoIcon(std::initializer_list<int> sizes)
{
    QIcon icon;
    for (const int size : sizes)
        icon.addFile(QStringLiteral(":/brand/cone-%1.png").arg(size), QSize(size, size));
    return icon;
}
}
#endif

namespace brand
{

QIcon windowIcon(qt_intf_t* intf)
{
#ifdef VLC_BRAND_PUBLIC
    VLC_UNUSED(intf);
    return logoIcon({16, 24, 32, 48, 64, 128, 256});
#else
    if( QDate::currentDate().dayOfYear() >= QT_XMAS_JOKE_DAY && var_InheritBool( intf, "qt-icon-change" ) )
        return QIcon::fromTheme( "vlc-xmas", QIcon( ":/logo/vlc128-xmas.png" ) );
    return QIcon::fromTheme( "vlc", QIcon( ":/logo/vlc256.png" ) );
#endif
}

QIcon trayIcon(bool seasonal)
{
#ifdef VLC_BRAND_PUBLIC
    VLC_UNUSED(seasonal);
    return logoIcon({16, 24, 32, 48});
#else
    if( seasonal )
        return QIcon::fromTheme( "vlc-xmas", QIcon( ":/logo/vlc128-xmas.png" ) );
    return QIcon::fromTheme( "vlc", QIcon( ":/logo/vlc256.png" ) );
#endif
}

QIcon trayMenuIcon()
{
#ifdef VLC_BRAND_PUBLIC
    return logoIcon({16, 24, 32});
#else
    return QIcon( ":/logo/vlc16.png" );
#endif
}

QPixmap aboutLogo(qt_intf_t* intf)
{
#ifdef VLC_BRAND_PUBLIC
    VLC_UNUSED(intf);
    return QPixmap( ":/brand/cone-256.png" );
#else
    const QDate today = QDate::currentDate();
    if( today.month() == 4 && today.day() == 1
            && var_InheritBool( intf, "qt-icon-change" ) )
        return QPixmap( ":/logo/vlc128-aprilfools.png" );
    return QPixmap();
#endif
}

QPixmap extensionFallbackIcon()
{
#ifdef VLC_BRAND_PUBLIC
    return QPixmap( ":/brand/cone-48.png" );
#else
    return QPixmap( ":/logo/vlc48.png" );
#endif
}

QString engineText(const QString& text)
{
#ifdef VLC_BRAND_PUBLIC
    static const QRegularExpression vlcName(
        QStringLiteral("\\bVLC(?: media player)?+\\b(?!\\s*\\d)"));
    QString result = text;
    result.replace(vlcName, qtr(BRAND_SHORT_NAME));
    return result;
#else
    return text;
#endif
}

}

BrandInfo::BrandInfo(QObject* parent)
    : QObject(parent)
{
}

bool BrandInfo::isPublic() const
{
#ifdef VLC_BRAND_PUBLIC
    return true;
#else
    return false;
#endif
}

QString BrandInfo::name() const { return qtr(BRAND_NAME); }
QString BrandInfo::shortName() const { return qtr(BRAND_SHORT_NAME); }
QString BrandInfo::title() const { return qtr(BRAND_TITLE); }
QString BrandInfo::welcomeTitle() const { return qtr(BRAND_WELCOME_TITLE); }
QString BrandInfo::welcomeText() const { return qtr(BRAND_WELCOME_TEXT); }
QString BrandInfo::logoIconSmall() const { return QStringLiteral(BRAND_LOGO_ICON_SMALL); }
QString BrandInfo::logoIcon() const { return QStringLiteral(BRAND_LOGO_ICON); }
QString BrandInfo::logoIconLarge() const { return QStringLiteral(BRAND_LOGO_ICON_LARGE); }
QString BrandInfo::logoSvg() const { return QStringLiteral(BRAND_LOGO_SVG); }
