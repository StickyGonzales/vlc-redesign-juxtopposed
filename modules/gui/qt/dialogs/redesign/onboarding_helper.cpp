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

#include "onboarding_helper.hpp"

#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QScreen>
#include <QSettings>
#include <QUrl>
#include <QWindow>

#include <algorithm>
#include <cstdlib>

#include <vlc_common.h>
#include <vlc_actions.h>
#include <vlc_configuration.h>
#include <vlc_cxx_helpers.hpp>
#include <vlc_media_library.h>

#include "qt.hpp"
#include "medialibrary/medialib.hpp"
#include "util/color_scheme_model.hpp"
#include "util/vlchotkeyconverter.hpp"

namespace {

QString userDir(vlc_userdir_t type)
{
    auto dir = vlc::wrap_cptr(config_GetUserDir(type));
    if (!dir)
        return {};
    const QString path = qfu(dir.get());
    return QFileInfo(path).isDir() ? QDir::toNativeSeparators(path) : QString();
}

// localized modifier name as printed on a keycap: "Shift+" -> "SHIFT"
QString modifierCap(const char* text)
{
    QString name = qfut(text);
    if (name.endsWith(QLatin1Char('+')))
        name.chop(1);
    return name.toUpper();
}

bool sameFolder(const QString& a, const QString& b)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(a))
            .compare(QDir::cleanPath(QDir::fromNativeSeparators(b)), Qt::CaseInsensitive) == 0;
}

} // namespace

OnboardingHelper::OnboardingHelper(QObject* parent)
    : QObject(parent)
{
}

void OnboardingHelper::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    if (m_ctx)
        disconnect(m_ctx->getColorScheme(), nullptr, this, nullptr);
    m_ctx = ctx;
    if (m_ctx)
        connect(m_ctx->getColorScheme(), &ColorSchemeModel::currentChanged,
                this, &OnboardingHelper::colorSchemeChanged);
    emit ctxChanged();
    emit colorSchemeChanged();
}

int OnboardingHelper::getColorScheme() const
{
    if (!m_ctx)
        return ColorSchemeModel::Night;
    return m_ctx->getColorScheme()->currentScheme();
}

void OnboardingHelper::setColorScheme(int scheme)
{
    if (!m_ctx)
        return;
    ColorSchemeModel* model = m_ctx->getColorScheme();
    const QVector<ColorSchemeModel::Item> schemes = model->getSchemes();
    for (int i = 0; i < schemes.size(); ++i)
    {
        if (schemes.at(i).scheme == scheme)
        {
            model->setCurrentIndex(i);
            return;
        }
    }
}

QString OnboardingHelper::defaultMediaFolder() const
{
    return userDir(VLC_VIDEOS_DIR);
}

QString OnboardingHelper::browseMediaFolder(const QString& current) const
{
    const QString start = current.isEmpty() ? QDir::homePath() : QDir::fromNativeSeparators(current);
    const QString dir = QFileDialog::getExistingDirectory(nullptr,
                                                          qtr("Choose a folder to add to the Media Library"),
                                                          start, QFileDialog::ShowDirsOnly);
    return dir.isEmpty() ? QString() : QDir::toNativeSeparators(dir);
}

QStringList OnboardingHelper::keycaps(const QString& option) const
{
    char* value = config_GetPsz(qtu(option));
    const QString keys = qfu(value);
    free(value);

    // the first key of the option; others are alternatives such as media keys
    return keycapsForKey(keys.section(QLatin1Char('\t'), 0, 0, QString::SectionSkipEmpty));
}

QStringList OnboardingHelper::keycapsForKey(const QString& key) const
{
    if (key.isEmpty())
        return {};

    const uint_fast32_t code = vlc_str2keycode(qtu(key));
    if (code == KEY_UNSET)
        return { key };

    QStringList caps;
#ifdef __APPLE__
    // redesign (macOS, issue #69): the Mac's own modifier symbols, in Apple's order (Control,
    // Option, Shift, Command), as macOS menus show them; spelled out ("COMMAND", "CTRL") they
    // pushed the key caps of the shortcuts screen past its right edge
    if (code & KEY_MODIFIER_CTRL)
        caps << QString(QChar(0x2303));
    if (code & KEY_MODIFIER_ALT)
        caps << QString(QChar(0x2325));
    if (code & KEY_MODIFIER_SHIFT)
        caps << QString(QChar(0x21E7));
    if (code & KEY_MODIFIER_META)
        caps << modifierCap(N_("Meta+"));
    if (code & KEY_MODIFIER_COMMAND)
        caps << QString(QChar(0x2318));
#else
    if (code & KEY_MODIFIER_CTRL)
        caps << modifierCap(N_("Ctrl+"));
    if (code & KEY_MODIFIER_ALT)
        caps << modifierCap(N_("Alt+"));
    if (code & KEY_MODIFIER_SHIFT)
        caps << modifierCap(N_("Shift+"));
    if (code & KEY_MODIFIER_META)
        caps << modifierCap(N_("Meta+"));
    if (code & KEY_MODIFIER_COMMAND)
        caps << modifierCap(N_("Command+"));
#endif

    // arrow keys are drawn as arrows (Figma "Onboarding" shortcuts screen)
    switch (code & ~KEY_MODIFIER)
    {
    case KEY_LEFT:
        caps << QString(QChar(0x2190));
        break;
    case KEY_RIGHT:
        caps << QString(QChar(0x2192));
        break;
    case KEY_UP:
        caps << QString(QChar(0x2191));
        break;
    case KEY_DOWN:
        caps << QString(QChar(0x2193));
        break;
    default:
    {
        // letters as on the keyboard: "F", not VLC's "f"
        QString name = VLCKeyToString(static_cast<unsigned>(code & ~KEY_MODIFIER), true);
        if (name.size() == 1)
            name = name.toUpper();
        caps << name;
        break;
    }
    }
    return caps;
}

void OnboardingHelper::fitWindow(int width, int height) const
{
    if (!m_ctx)
        return;
    QWindow* window = m_ctx->intfMainWindow();
    if (!window || window->visibility() != QWindow::Windowed || !window->screen())
        return;

    const QRect available = window->screen()->availableGeometry();
    const QMargins frame = window->frameMargins();
    const int maxWidth = available.width() - frame.left() - frame.right();
    const int maxHeight = available.height() - frame.top() - frame.bottom();

    const QSize size(std::max(window->width(), std::min(width, maxWidth)),
                     std::max(window->height(), std::min(height, maxHeight)));
    if (size == window->size())
        return;

    window->resize(size);
    window->setPosition(available.x() + frame.left() + (maxWidth - size.width()) / 2,
                        available.y() + frame.top() + (maxHeight - size.height()) / 2);
}

void OnboardingHelper::finish(const QString& mediaFolder)
{
    if (!m_ctx || m_done)
        return;
    m_done = true;

    applyDefaults();

    if (MediaLib* medialib = m_ctx->getMediaLibrary())
    {
        QStringList folders;
        if (QFileInfo(mediaFolder).isDir())
            folders << mediaFolder;

        // kept at the proposed Videos folder: also VLC's other default, the Music folder,
        // like the first-run wizard's default list
        const QString videos = defaultMediaFolder();
        if (!videos.isEmpty() && sameFolder(mediaFolder, videos))
        {
            const QString music = userDir(VLC_MUSIC_DIR);
            if (!music.isEmpty())
                folders << music;
        }

        for (const QString& folder : folders)
        {
            const QString mrl = QUrl::fromLocalFile(QDir::fromNativeSeparators(folder))
                                    .toString(QUrl::FullyEncoded);
            medialib->runOnMLThread(medialib, [mrl](vlc_medialibrary_t* ml) {
                vlc_ml_add_folder(ml, qtu(mrl));
            });
        }
        medialib->reload();
    }

    save();
}

void OnboardingHelper::skip()
{
    if (!m_ctx || m_done)
        return;
    m_done = true;

    applyDefaults();
    if (MediaLib* medialib = m_ctx->getMediaLibrary())
        medialib->reload();
    save();
}

void OnboardingHelper::applyDefaults()
{
    // the first-run wizard's preselected choices that the onboarding does not show:
    // metadata network access on, modern layout (no menu bar, client-side decoration,
    // video controls not pinned)
    config_PutInt("metadata-network-access", 1);
    config_PutInt("qt-privacy-ask", 0);
    config_PutInt("qt-menubar", 0);
    config_PutInt("qt-titlebar", 0);
    config_PutInt("qt-pin-controls", 0);
}

void OnboardingHelper::save()
{
    qt_intf_t* p_intf = m_ctx->getIntf();

    // MainCtx stores the color scheme when it closes; store it now as well, so the
    // choice survives even if VLC does not close normally
    getSettings()->setValue("MainWindow/color-scheme-index", m_ctx->getColorScheme()->currentIndex());

    m_ctx->reloadPrefs();
    config_SaveConfigFile(p_intf);
}
