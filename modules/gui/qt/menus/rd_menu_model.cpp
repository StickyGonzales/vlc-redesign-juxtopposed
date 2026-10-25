/*****************************************************************************
 * rd_menu_model.cpp : VLC's menus as list models for the redesigned QML menus
 *****************************************************************************
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

#include "rd_menu_model.hpp"

#include <vlc_common.h>
#include <vlc_actions.h>
#include <vlc_intf_strings.h>

#include "menus/menus.hpp"
#include "util/brand.hpp"
#include "menus/custom_menus.hpp"
#include "maininterface/mainctx.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "dialogs/toolbar/controlbar_profile.hpp"
#include "dialogs/toolbar/controlbar_profile_model.hpp"
#include "player/player_controller.hpp"
#include "playlist/playlist_controller.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlrecentmediamodel.hpp"
#include "util/vlchotkeyconverter.hpp"

#include <QAction>
#include <QActionGroup>
#include <QEvent>
#include <QKeySequence>
#include <QMenu>
#include <QQmlEngine>
#include <QWidgetAction>

#include <algorithm>

using namespace vlc::playlist;

namespace {

// "&Audio" -> "Audio", "Rock && Roll" -> "Rock & Roll"
QString stripMnemonic(const QString& text)
{
    QString out;
    out.reserve(text.size());
    for (qsizetype i = 0; i < text.size(); ++i)
    {
        if (text[i] == QLatin1Char('&'))
        {
            if (i + 1 < text.size() && text[i + 1] == QLatin1Char('&'))
                out += QLatin1Char('&');
            else
                continue;
            ++i;
            continue;
        }
        out += text[i];
    }
    return out;
}

// the redesign writes shortcuts with spaces and upper case keys: "Ctrl+o" -> "Ctrl + O"
QString spacedShortcut(const QString& keys)
{
    QStringList parts;
    QString current;
    for (const QChar c : keys)
    {
        if (c == QLatin1Char('+') && !current.isEmpty())
        {
            parts << current;
            current.clear();
        }
        else
            current += c;
    }
    if (!current.isEmpty())
        parts << current;

    for (QString& part : parts)
        if (part.size() == 1)
            part = part.toUpper();
    return parts.join(QLatin1String(" + "));
}

// a row the menu draws: visible, no embedded widget, a separator or a labelled entry
bool isDrawn(const QAction* action)
{
    if (!action->isVisible() || qobject_cast<const QWidgetAction*>(action))
        return false;
    return action->isSeparator() || !stripMnemonic(action->text()).isEmpty();
}

bool hasEntries(const QMenu* menu)
{
    const QList<QAction*> actions = menu->actions();
    for (const QAction* action : actions)
        if (isDrawn(action) && !action->isSeparator())
            return true;
    return false;
}

QString shortcutText(const QKeySequence& sequence)
{
    if (sequence.isEmpty())
        return {};
    return spacedShortcut(sequence.toString(QKeySequence::NativeText));
}

} // namespace

RdMenuModel::RdMenuModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_root(this)
{
}

RdMenuModel::RdMenuModel(QMenu* menu, RdMenuModel* root, QObject* parent)
    : QAbstractListModel(parent)
    , m_ctx(root->m_ctx)
    , m_root(root)
{
    setMenu(menu);
}

RdMenuModel::~RdMenuModel()
{
    // the submenu models are children of this model
    if (m_menu)
        m_menu->removeEventFilter(this);
    for (const QPointer<QMenu>& submenu : std::as_const(m_watchedSubmenus))
        if (submenu)
            submenu->removeEventFilter(this);

    // members die in reverse order: m_submenus would be gone while the owned menu deletes its
    // submenus, whose destroyed() handlers use it; empty it, then delete the menu first
    m_submenus.clear();
    m_ownedMenu.reset();
}

void RdMenuModel::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

void RdMenuModel::setKind(const QString& kind)
{
    if (m_kind == kind)
        return;
    m_kind = kind;
    emit kindChanged();
}

void RdMenuModel::setUiHidden(bool hidden)
{
    if (m_uiHidden == hidden)
        return;
    m_uiHidden = hidden;
    emit uiHiddenChanged();
}

int RdMenuModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_rows.size();
}

QVariant RdMenuModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const QAction* action = m_rows.at(index.row());
    if (!action)
        return {};

    switch (role)
    {
    case LabelRole:
        return stripMnemonic(action->text());
    case IconNameRole:
        return action->property("rdIcon").toString();
    case IconAccentRole:
        return action->property("rdIconAccent").toBool();
    case ShortcutRole:
    {
        const QVariant custom = action->property("rdShortcut");
        if (custom.isValid())
            return custom.toString();
        return shortcutText(action->shortcut());
    }
    case CheckableRole:
        return action->isCheckable();
    case CheckedRole:
        return action->isChecked();
    case ActionEnabledRole:
        // a submenu without entries (no chapters, no subtitle tracks ...) cannot be opened
        return action->isEnabled() && (!action->menu() || hasEntries(action->menu()));
    case SeparatorRole:
        return action->isSeparator();
    case HasSubmenuRole:
        return action->menu() != nullptr;
    default:
        return {};
    }
}

QHash<int, QByteArray> RdMenuModel::roleNames() const
{
    return {
        { LabelRole, "label" },
        { IconNameRole, "iconName" },
        { IconAccentRole, "iconAccent" },
        { ShortcutRole, "shortcut" },
        { CheckableRole, "checkable" },
        { CheckedRole, "checked" },
        { ActionEnabledRole, "actionEnabled" },
        { SeparatorRole, "separator" },
        { HasSubmenuRole, "hasSubmenu" },
    };
}

void RdMenuModel::build()
{
    // only the root model builds; submenus follow the menu they wrap
    if (m_root != this || !m_ctx || !m_ctx->getIntf())
        return;

    auto menu = std::make_unique<QMenu>();
    if (m_kind == QLatin1String("main"))
        buildMainMenu(menu.get());
    else if (m_kind == QLatin1String("player"))
        buildPlayerMenu(menu.get());

    // the previous menu (and its submenus) go away with their models
    clearSubmenus();
    if (m_menu)
        m_menu->removeEventFilter(this);
    m_menu = nullptr;
    m_ownedMenu = std::move(menu);
    setMenu(m_ownedMenu.get());
}

void RdMenuModel::trigger(int row)
{
    if (row < 0 || row >= m_rows.size())
        return;
    QAction* action = m_rows.at(row);
    if (!action || action->menu() || action->isSeparator() || !action->isEnabled())
        return;
    action->trigger();
}

RdMenuModel* RdMenuModel::submenu(int row)
{
    if (row < 0 || row >= m_rows.size())
        return nullptr;
    QAction* action = m_rows.at(row);
    if (!action || !action->menu())
        return nullptr;

    QMenu* menu = action->menu();
    RdMenuModel* model = m_submenus.value(menu, nullptr);
    if (!model)
    {
        model = new RdMenuModel(menu, m_root, this);
        QQmlEngine::setObjectOwnership(model, QQmlEngine::CppOwnership);
        m_submenus.insert(menu, model);
        // the key must not outlive its menu (a new menu may get the same address)
        connect(menu, &QObject::destroyed, this, [this, menu]() {
            RdMenuModel* stale = m_submenus.take(menu);
            if (stale)
                stale->deleteLater();
        });
    }
    return model;
}

void RdMenuModel::aboutToShow()
{
    if (m_menu)
        emit m_menu->aboutToShow();
}

bool RdMenuModel::eventFilter(QObject* watched, QEvent* event)
{
    // the menu itself, or a row's submenu (its entries decide whether the row is enabled)
    const bool isSubmenu = std::any_of(m_watchedSubmenus.cbegin(), m_watchedSubmenus.cend(),
                                       [watched](const QPointer<QMenu>& submenu) {
        return submenu.data() == watched;
    });
    if (watched == m_menu.data() || isSubmenu)
    {
        switch (event->type())
        {
        case QEvent::ActionAdded:
        case QEvent::ActionRemoved:
        case QEvent::ActionChanged:
            scheduleRefresh();
            break;
        default:
            break;
        }
    }
    return QAbstractListModel::eventFilter(watched, event);
}

void RdMenuModel::setMenu(QMenu* menu)
{
    m_menu = menu;
    if (m_menu)
        m_menu->installEventFilter(this);
    m_refreshPending = false;
    refresh();
}

void RdMenuModel::clearSubmenus()
{
    // the submenu models may still be referenced from QML until the menu is drawn again
    for (RdMenuModel* model : std::as_const(m_submenus))
        model->deleteLater();
    m_submenus.clear();
}

void RdMenuModel::scheduleRefresh()
{
    if (m_refreshPending)
        return;
    m_refreshPending = true;
    QMetaObject::invokeMethod(this, [this]() {
        if (!m_refreshPending)
            return;
        m_refreshPending = false;
        refresh();
    }, Qt::QueuedConnection);
}

void RdMenuModel::refresh()
{
    // the visible rows, like QMenu draws them: no hidden actions, no embedded widgets, no
    // leading, trailing or doubled separators
    QVector<QPointer<QAction>> rows;
    if (m_menu)
    {
        const QList<QAction*> actions = m_menu->actions();
        for (QAction* action : actions)
        {
            if (!isDrawn(action))
                continue;
            if (action->isSeparator() && (rows.isEmpty() || rows.last()->isSeparator()))
                continue;
            rows.append(action);
        }
        while (!rows.isEmpty() && rows.last()->isSeparator())
            rows.removeLast();
    }

    if (rows == m_rows)
    {
        if (!m_rows.isEmpty())
            emit dataChanged(index(0), index(m_rows.size() - 1));
        watchSubmenus();
        updateLabels();
        return;
    }

    beginResetModel();
    m_rows = rows;
    m_separatorCount = 0;
    for (const QPointer<QAction>& action : std::as_const(m_rows))
        if (action->isSeparator())
            ++m_separatorCount;
    endResetModel();
    watchSubmenus();
    updateLabels();
    emit countChanged();
}

void RdMenuModel::watchSubmenus()
{
    QVector<QPointer<QMenu>> submenus;
    for (const QPointer<QAction>& action : std::as_const(m_rows))
        if (action && action->menu())
            submenus.append(action->menu());

    for (const QPointer<QMenu>& submenu : std::as_const(m_watchedSubmenus))
        if (submenu && !submenus.contains(submenu))
            submenu->removeEventFilter(this);
    for (const QPointer<QMenu>& submenu : std::as_const(submenus))
        if (!m_watchedSubmenus.contains(submenu))
            submenu->installEventFilter(this);
    m_watchedSubmenus = submenus;
}

// the widest entries by length, so QML sizes a panel without creating every row
void RdMenuModel::updateLabels()
{
    QString label;
    QString shortcut;
    for (int row = 0; row < m_rows.size(); ++row)
    {
        const QString text = data(index(row), LabelRole).toString();
        if (text.size() > label.size())
            label = text;
        const QString keys = data(index(row), ShortcutRole).toString();
        if (keys.size() > shortcut.size())
            shortcut = keys;
    }
    if (label == m_longestLabel && shortcut == m_longestShortcut)
        return;
    m_longestLabel = label;
    m_longestShortcut = shortcut;
    emit labelsChanged();
}

QAction* RdMenuModel::addRequest(QMenu* menu, const QString& text, const char* icon,
                                 const QString& id, const QString& shortcut)
{
    QAction* action = menu->addAction(text);
    if (icon)
        action->setProperty("rdIcon", QString::fromLatin1(icon));
    if (!shortcut.isEmpty())
        action->setProperty("rdShortcut", shortcut);
    RdMenuModel* root = m_root;
    connect(action, &QAction::triggered, root, [root, id]() {
        emit root->requested(id);
    });
    return action;
}

// the first key VLC's hotkey `name` is bound to ("key-stop" -> "S"), as the user configured it
QString RdMenuModel::hotkeyText(const char* name) const
{
    qt_intf_t* p_intf = m_ctx->getIntf();
    char* keys = var_InheritString(p_intf, name);
    if (!keys)
        return {};

    QString text;
    const QString first = qfu(keys).section(QLatin1Char('\t'), 0, 0);
    free(keys);

    const uint_fast32_t code = vlc_str2keycode(qtu(first));
    if (code != KEY_UNSET)
        text = spacedShortcut(VLCKeyToString(static_cast<unsigned>(code), true));
    return text;
}

namespace {

template<typename Functor>
QAction* addEntry(QMenu* menu, const QString& text, const char* icon, const QString& shortcut,
                  Functor functor)
{
    QAction* action = menu->addAction(text);
    QObject::connect(action, &QAction::triggered, menu, functor);
    if (icon)
        action->setProperty("rdIcon", QString::fromLatin1(icon));
    if (!shortcut.isEmpty())
        action->setProperty("rdShortcut", shortcut);
    return action;
}

QMenu* addSubmenu(QMenu* menu, const QString& title, const char* icon)
{
    QMenu* submenu = new QMenu(title, menu);
    QAction* action = menu->addMenu(submenu);
    if (icon)
        action->setProperty("rdIcon", QString::fromLatin1(icon));
    return submenu;
}

} // namespace

/*
 * Main "..." menu, Figma "menu" (Decision 2): the open entries, Convert, Open Recent, then
 * Profile (name), Keyboard Shortcuts, Customize Player, Settings and About. The shortcuts are
 * the ones GlobalShortcuts.qml handles.
 */
void RdMenuModel::buildMainMenu(QMenu* menu)
{
    buildOpenMenu(menu, true);

    menu->addSeparator();

    buildProfileMenu(menu);

    addRequest(menu, qtr("Keyboard Shortcuts"), "hotkeys_two-tone-yes",
               QStringLiteral("keyboardShortcuts"));
    addRequest(menu, qtr("Customize Player"), "paint_two-tone-yes",
               QStringLiteral("customizePlayer"));
    addEntry(menu, qtr("Settings"), "settings_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+P"))),
             []() { THEDP->prefsDialog(); });
    addEntry(menu, qtr(BRAND_MENU_ABOUT), "info_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Shift+F1"))),
             []() { THEDP->aboutDialog(); });
}

/*
 * "Profile (Movies)" (W8.2, video 19:29-19:36, Figma "Profiles"): the profiles, the selected one
 * checked, a divider and "+ New" (Decision 25: a name, then a copy of the current settings);
 * then Rename and Delete for the selected profile (Decision 21: Figma's submenu has no place to
 * rename or delete one). The QML menu (RdMainMenu.qml) runs them through RdProfiles: "profile:N",
 * "newProfile", "renameProfile", "deleteProfile".
 */
void RdMenuModel::buildProfileMenu(QMenu* menu)
{
    ControlbarProfileModel* profiles = m_ctx->controlbarProfileModel();
    if (!profiles)
        return;

    const ControlbarProfile* current = profiles->currentModel();
    const QString currentName = current ? current->name() : QString();
    QMenu* submenu = addSubmenu(menu, qtr("Profile (%1)").arg(currentName), "profile_two-tone-yes");

    const int count = profiles->rowCount();
    for (int i = 0; i < count; ++i)
    {
        const ControlbarProfile* profile = profiles->getProfile(i);
        if (!profile)
            continue;
        QAction* action = addRequest(submenu, profile->name(), nullptr,
                                     QStringLiteral("profile:%1").arg(i));
        action->setCheckable(true);
        action->setChecked(i == profiles->selectedProfile());
    }

    submenu->addSeparator();

    addRequest(submenu, qtr("New"), "add", QStringLiteral("newProfile"));
    addRequest(submenu, qtr("Rename Profile"), "edit", QStringLiteral("renameProfile"));
    QAction* remove = addRequest(submenu, qtr("Delete Profile"), "remove", QStringLiteral("deleteProfile"));
    remove->setEnabled(count > 1);
}

/*
 * the open entries of the main menu (Figma "menu", final order of video 13:08 / 19:33);
 * the right-click "Open Media" submenu lists the same ones
 */
void RdMenuModel::buildOpenMenu(QMenu* menu, bool withRecent)
{
    addEntry(menu, qtr("Open File(s)"), "file_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+O"))),
             []() { THEDP->simpleOpenDialog(); });
    addEntry(menu, qtr("Open Folder"), "folder_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+F"))),
             []() { THEDP->PLOpenDir(); });
    addEntry(menu, qtr("Open Network Stream"), "streaming_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+N"))),
             []() { THEDP->openNetDialog(); });
    addEntry(menu, qtr("Open Disc"), "disc_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+D"))),
             []() { THEDP->openDiscDialog(); });
    addEntry(menu, qtr("Open Capture Device"), "capture-device_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+C"))),
             []() { THEDP->openCaptureDialog(); });

    if (!withRecent)
        return;

    addEntry(menu, qtr("Convert"), "swap_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+R"))),
             []() { THEDP->openAndTranscodingDialogs(); });

    // VLC's recent media menu (FileMenu), kept by the media library
    qt_intf_t* p_intf = m_ctx->getIntf();
    if (var_InheritBool(p_intf, "save-recentplay") && m_ctx->hasMediaLibrary())
    {
        MLRecentMediaModel* recentModel = new MLRecentMediaModel(nullptr);
        recentModel->setMl(m_ctx->getMediaLibrary());
        recentModel->setLimit(10);
        QMenu* recentsMenu = new RecentMenu(recentModel, m_ctx->getMediaLibrary(), menu);
        recentsMenu->setTitle(qtr("Open Recent"));
        recentModel->setParent(recentsMenu);
        QAction* action = menu->addMenu(recentsMenu);
        action->setProperty("rdIcon", QStringLiteral("recent_two-tone-yes"));
    }
    else
    {
        QAction* action = addSubmenu(menu, qtr("Open Recent"), "recent_two-tone-yes")->menuAction();
        action->setEnabled(false);
    }
}

/*
 * Right-click menu, Figma "right-click menu" (video 5:21-5:30): VLC's play queue entries, Hide UI,
 * the Playback / Video / Audio / Subtitle menus, then More Settings (VLC's Tools and View menus),
 * Playlist, Open Media and Quit.
 */
void RdMenuModel::buildPlayerMenu(QMenu* menu)
{
    qt_intf_t* p_intf = m_ctx->getIntf();
    PlayerController* player = THEMIM;
    PlaylistController* playlist = THEMPL;
    const bool hasInput = player->hasInput();
    QAction* action;

    // same behaviour as VLC's PopupMenuPlaylistEntries
    if (!hasInput || player->getPlayingState() != PlayerController::PLAYING_STATE_PLAYING)
    {
        action = addEntry(menu, qtr("Play"), "playback_two-tone-yes", hotkeyText("key-play-pause"),
                          [playlist]() {
            if (playlist->isEmpty())
                THEDP->openFileDialog();
            else
                playlist->togglePlayPause();
        });
    }
    else
    {
        action = addEntry(menu, qtr("Pause"), "pause", hotkeyText("key-play-pause"),
                          [playlist]() { playlist->togglePlayPause(); });
        action->setProperty("rdIconAccent", true);
    }

    action = addEntry(menu, qtr("Stop"), "stop_two-tone-yes", hotkeyText("key-stop"),
                      [playlist]() { playlist->stop(); });
    action->setEnabled(hasInput);

    const bool emptyQueue = playlist->isEmpty();
    action = addEntry(menu, qtr("Previous Item"), "previous_two-tone-yes", hotkeyText("key-prev"),
                      [playlist]() { playlist->prev(); });
    action->setEnabled(!emptyQueue);
    connect(playlist, &PlaylistController::isEmptyChanged, action, &QAction::setDisabled);

    action = addEntry(menu, qtr("Next Item"), "next_two-tone-yes", hotkeyText("key-next"),
                      [playlist]() { playlist->next(); });
    action->setEnabled(!emptyQueue);
    connect(playlist, &PlaylistController::isEmptyChanged, action, &QAction::setDisabled);

    action = addEntry(menu, qtr("Record"), "record_two-tone-yes", hotkeyText("key-record"),
                      [player]() { player->toggleRecord(); });
    action->setEnabled(hasInput);

    menu->addSeparator();

    addRequest(menu, m_uiHidden ? qtr("Show UI") : qtr("Hide UI"), "ui", QStringLiteral("hideUi"),
               shortcutText(QKeySequence(QStringLiteral("Ctrl+\\"))));

    menu->addSeparator();

    QMenu* submenu = addSubmenu(menu, qtr("Playback"), "playback_state-selected_two-tone-yes");
    buildPlaybackMenu(submenu);
    submenu->menuAction()->setEnabled(hasInput);

    submenu = addSubmenu(menu, qtr("Video"), "video_two-tone-yes");
    VLCMenuBar::VideoMenu(p_intf, submenu);
    submenu->menuAction()->setEnabled(hasInput);

    submenu = addSubmenu(menu, qtr("Audio"), "audio_two-tone-yes");
    VLCMenuBar::AudioMenu(p_intf, submenu);
    submenu->menuAction()->setEnabled(hasInput);

    submenu = addSubmenu(menu, qtr("Subtitle"), "subtitles_two-tone-yes");
    VLCMenuBar::SubtitleMenu(p_intf, submenu, true);
    submenu->menuAction()->setEnabled(hasInput);

    menu->addSeparator();

    buildMoreSettingsMenu(addSubmenu(menu, qtr("More Settings"), "settings_two-tone-yes"));
    buildPlaylistMenu(addSubmenu(menu, qtr("Playlist"), "playlist_two-tone-yes"));
    buildOpenMenu(addSubmenu(menu, qtr("Open Media"), "file_two-tone-yes"), false);

    addEntry(menu, qtr(BRAND_MENU_QUIT), "quit_two-tone-yes", hotkeyText("key-quit"),
             []() { THEDP->quit(); });
}

/* VLC's Playback menu (NavigMenu) without the play queue entries the right-click menu already has */
void RdMenuModel::buildPlaybackMenu(QMenu* menu)
{
    qt_intf_t* p_intf = m_ctx->getIntf();
    PlayerController* player = THEMIM;

    menu->addMenu(new CheckableListMenu(qtr("T&itle"), player->getTitles(),
                                        QActionGroup::ExclusionPolicy::Exclusive, menu));
    menu->addMenu(new CheckableListMenu(qtr("&Chapter"), player->getChapters(),
                                        QActionGroup::ExclusionPolicy::Exclusive, menu));
    menu->addMenu(new CheckableListMenu(qtr("&Program"), player->getPrograms(),
                                        QActionGroup::ExclusionPolicy::Exclusive, menu));

    if (m_ctx->hasMediaLibrary())
    {
        BookmarkMenu* bookmarks = new BookmarkMenu(m_ctx->getMediaLibrary(), p_intf->p_player, menu);
        bookmarks->setTitle(qfut(I_MENU_BOOKMARK));
        menu->addMenu(bookmarks);
    }

    menu->addSeparator();

    if (!VLCMenuBar::rendererMenu)
        VLCMenuBar::rendererMenu = new RendererMenu(nullptr, p_intf, player);
    menu->addMenu(VLCMenuBar::rendererMenu);

    menu->addSeparator();

    VLCMenuBar::PopupMenuControlEntries(menu, p_intf);

    QAction* action = menu->addAction(qtr("Previous Title"), player, &PlayerController::titlePrev);
    action->setVisible(player->hasTitles());
    connect(player, &PlayerController::hasTitlesChanged, action, &QAction::setVisible);

    action = menu->addAction(qtr("Next Title"), player, &PlayerController::titleNext);
    action->setVisible(player->hasTitles());
    connect(player, &PlayerController::hasTitlesChanged, action, &QAction::setVisible);

    action = menu->addAction(qtr("Previous Chapter"), player, &PlayerController::chapterPrev);
    action->setVisible(player->hasChapters());
    connect(player, &PlayerController::hasChaptersChanged, action, &QAction::setVisible);

    action = menu->addAction(qtr("Next Chapter"), player, &PlayerController::chapterNext);
    action->setVisible(player->hasChapters());
    connect(player, &PlayerController::hasChaptersChanged, action, &QAction::setVisible);
}

/* "More Settings": VLC's Tools and View menus in one list (row P2-23) */
void RdMenuModel::buildMoreSettingsMenu(QMenu* menu)
{
    qt_intf_t* p_intf = m_ctx->getIntf();

    VLCMenuBar::ToolsMenu(p_intf, menu);
    menu->addSeparator();

    // ViewMenu() starts by deleting the actions of the menu it fills: fill a hidden holder
    // (owned by `menu`) and show its actions here
    QMenu* view = new QMenu(menu);
    VLCMenuBar::ViewMenu(p_intf, view);
    menu->addActions(view->actions());
}

/* "Playlist": the play queue's existing functions */
void RdMenuModel::buildPlaylistMenu(QMenu* menu)
{
    qt_intf_t* p_intf = m_ctx->getIntf();
    PlaylistController* playlist = THEMPL;
    QAction* action;

    addRequest(menu, qtr("Show Queue"), "queue", QStringLiteral("showQueue"));

    menu->addSeparator();

    action = menu->addAction(qtr("Shuffle"));
    action->setCheckable(true);
    action->setChecked(playlist->isRandom());
    connect(action, &QAction::triggered, playlist, &PlaylistController::setRandom);
    connect(playlist, &PlaylistController::randomChanged, action, &QAction::setChecked);

    QMenu* repeat = new QMenu(qtr("Repeat"), menu);
    QActionGroup* group = new QActionGroup(repeat);
    const struct {
        QString text;
        PlaylistController::PlaybackRepeat mode;
    } modes[] = {
        { qtr("Off"), PlaylistController::PLAYBACK_REPEAT_NONE },
        { qtr("All"), PlaylistController::PLAYBACK_REPEAT_ALL },
        { qtr("One"), PlaylistController::PLAYBACK_REPEAT_CURRENT },
    };
    for (const auto& entry : modes)
    {
        const PlaylistController::PlaybackRepeat mode = entry.mode;
        action = repeat->addAction(entry.text);
        action->setCheckable(true);
        action->setChecked(playlist->getRepeatMode() == mode);
        group->addAction(action);
        connect(action, &QAction::triggered, playlist, [playlist, mode]() {
            playlist->setRepeatMode(mode);
        });
        connect(playlist, &PlaylistController::repeatModeChanged, action, [playlist, action, mode]() {
            action->setChecked(playlist->getRepeatMode() == mode);
        });
    }
    menu->addMenu(repeat);

    menu->addSeparator();

    addEntry(menu, qfut(I_PL_SAVE), "save_two-tone-yes",
             shortcutText(QKeySequence(QStringLiteral("Ctrl+Y"))),
             []() { THEDP->savePlayingToPlaylist(); });

    action = addEntry(menu, qtr("Clear Queue"), "remove", QString(),
                      [playlist]() { playlist->clear(); });
    action->setEnabled(!playlist->isEmpty());
    connect(playlist, &PlaylistController::isEmptyChanged, action, &QAction::setDisabled);

    menu->addSeparator();

    action = menu->addAction(qtr("Quit at the end of play queue"));
    action->setCheckable(true);
    action->setChecked(playlist->getMediaStopAction() == PlaylistController::MEDIA_STOPPED_EXIT);
    connect(action, &QAction::triggered, playlist, [playlist](bool checked) {
        playlist->setMediaStopAction(checked ? PlaylistController::MEDIA_STOPPED_EXIT
                                             : PlaylistController::MEDIA_STOPPED_CONTINUE);
    });
}
