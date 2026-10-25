/*****************************************************************************
 * rd_menu_model.hpp : VLC's menus as list models for the redesigned QML menus
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

#ifndef RD_MENU_MODEL_HPP
#define RD_MENU_MODEL_HPP

#include <QAbstractListModel>
#include <QHash>
#include <QPointer>
#include <QVector>

#include <memory>

#include "qt.hpp"

Q_MOC_INCLUDE("maininterface/mainctx.hpp")

class QAction;
class QMenu;
class MainCtx;

/**
 * redesign: the main "..." menu (video 5:05-5:16, 12:56-13:09, 19:29-19:36; Figma "menu") and the
 * right-click menu (video 5:14-5:30; Figma "right-click menu") are drawn in QML in the redesign
 * style. Native QMenus cannot take that style, so this model exposes a QMenu built with VLC's
 * own menu functions (VLCMenuBar, DialogsProvider slots, the player and play queue
 * controllers) as a list model: QML draws the rows and calls trigger(), so every entry keeps
 * VLC's behaviour. Submenus are models too (submenu()).
 *
 * The rows follow the wrapped QMenu live (track lists, recent media, renderers ...).
 */
class RdMenuModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    // which menu build() creates: "main" (the "..." menu) or "player" (the right-click menu);
    // empty for submenus
    Q_PROPERTY(QString kind READ getKind WRITE setKind NOTIFY kindChanged FINAL)
    // the player's UI is hidden (Hide UI): the right-click menu then offers "Show UI"
    Q_PROPERTY(bool uiHidden READ isUiHidden WRITE setUiHidden NOTIFY uiHiddenChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    // the panel's size without creating every row (long chapter or track lists load lazily)
    Q_PROPERTY(int separatorCount READ separatorCount NOTIFY countChanged FINAL)
    Q_PROPERTY(QString longestLabel READ longestLabel NOTIFY labelsChanged FINAL)
    Q_PROPERTY(QString longestShortcut READ longestShortcut NOTIFY labelsChanged FINAL)

public:
    enum Roles {
        LabelRole = Qt::UserRole + 1,
        IconNameRole,
        IconAccentRole,
        ShortcutRole,
        CheckableRole,
        CheckedRole,
        ActionEnabledRole,
        SeparatorRole,
        HasSubmenuRole
    };

    explicit RdMenuModel(QObject* parent = nullptr);
    ~RdMenuModel() override;

    MainCtx* getCtx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    QString getKind() const { return m_kind; }
    void setKind(const QString& kind);
    bool isUiHidden() const { return m_uiHidden; }
    void setUiHidden(bool hidden);
    int count() const { return m_rows.size(); }
    int separatorCount() const { return m_separatorCount; }
    QString longestLabel() const { return m_longestLabel; }
    QString longestShortcut() const { return m_longestShortcut; }

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // (re)creates the menu of `kind`; VLC's menus are rebuilt before every popup
    Q_INVOKABLE void build();
    Q_INVOKABLE void trigger(int row);
    // model of the submenu of `row` (owned by this model), null when the row has none
    Q_INVOKABLE RdMenuModel* submenu(int row);
    // the submenu is about to be shown (VLC's renderer menu starts its discovery then)
    Q_INVOKABLE void aboutToShow();

signals:
    void ctxChanged();
    void kindChanged();
    void uiHiddenChanged();
    void countChanged();
    void labelsChanged();
    // entries handled by the QML side: "hideUi", "showQueue", "keyboardShortcuts", "customizePlayer"
    void requested(const QString& id);

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    RdMenuModel(QMenu* menu, RdMenuModel* root, QObject* parent);

    void setMenu(QMenu* menu);
    void clearSubmenus();
    void watchSubmenus();
    void updateLabels();
    void scheduleRefresh();
    void refresh();

    void buildMainMenu(QMenu* menu);
    void buildProfileMenu(QMenu* menu);
    void buildPlayerMenu(QMenu* menu);
    void buildPlaybackMenu(QMenu* menu);
    void buildMoreSettingsMenu(QMenu* menu);
    void buildPlaylistMenu(QMenu* menu);
    void buildOpenMenu(QMenu* menu, bool withRecent);

    QAction* addRequest(QMenu* menu, const QString& text, const char* icon, const QString& id,
                        const QString& shortcut = {});
    QString hotkeyText(const char* name) const;

    MainCtx* m_ctx = nullptr;
    QString m_kind;
    bool m_uiHidden = false;

    std::unique_ptr<QMenu> m_ownedMenu;     // root models own their menu
    QPointer<QMenu> m_menu;
    RdMenuModel* m_root = nullptr;          // model whose requested() signal the entries emit
    QVector<QPointer<QAction>> m_rows;
    QHash<QMenu*, RdMenuModel*> m_submenus;
    // the submenus of the rows: a row's enabled state follows whether its submenu has entries
    QVector<QPointer<QMenu>> m_watchedSubmenus;
    bool m_refreshPending = false;
    int m_separatorCount = 0;
    QString m_longestLabel;
    QString m_longestShortcut;
};

#endif // RD_MENU_MODEL_HPP
