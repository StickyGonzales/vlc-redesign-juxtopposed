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
#ifndef RD_PROFILES_HPP
#define RD_PROFILES_HPP

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QThreadPool>
#include <QVariantMap>

#include "qt.hpp"

Q_MOC_INCLUDE("player/player_controlbar_model.hpp")

class MainCtx;
class ControlbarProfileModel;
class PlayerControlbarModel;

/**
 * redesign (W8.1b / W8.2, video 19:20-19:36, Figma "Player - customize", "Profiles"; Decisions
 * 25 and 29): VLC's layout profiles as the design's profiles.
 *
 * Top bar layout. Every profile also holds the player's top bar, as one more player layout of
 * VLC's profile storage (identifier `topBarIdentifier`, the same "id|left|center|right" record
 * the video, audio and mini player layouts use; VLC's own interface keeps such a record and
 * ignores it). A profile without one (VLC's defaults, profiles saved by stock VLC) gets the
 * design's top bar: main menu, library toggle, divider, folder chip | title | fullscreen.
 *
 * Settings. A profile also holds VLC's settings: the options that differ from VLC's defaults
 * (every module's options except passwords and a few states that are not settings), and the
 * color scheme. They are kept in `<VLC user data folder>/rd-profiles.json` by profile name.
 * - select(): the bars switch at once; the current settings are kept in the profile being
 *   left, and the selected profile's settings are written to VLC's configuration, which is
 *   saved. A profile that has no settings yet keeps the current ones.
 * - create(): "+ New": a copy of the current profile's layouts and of the current settings
 *   (Decision 25), selected.
 * - rename(), removeCurrent(): VLC's profile list and the settings follow.
 * The configuration is read, written and saved on a worker thread; `busy` while it runs.
 *
 * Restart notice (Decision 29). Some settings only apply later: `applied` lists, after a
 * switch, whether options changed that apply from the next media (the input, decoders and
 * outputs read them when a media opens) and which ones only apply after VLC restarts (the
 * interface, hotkeys, VLC's startup options). The interface's own live options (accent
 * color, color scheme, fullscreen bars, seek bar options ...) apply at once (MainCtx reads
 * them again; RdEffects is refreshed by the caller).
 */
class RdProfiles : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int topBarIdentifier READ topBarIdentifier CONSTANT FINAL)
    // the top bar layout of the selected profile
    Q_PROPERTY(PlayerControlbarModel* topBarModel READ topBarModel NOTIFY topBarModelChanged FINAL)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)

public:
    static constexpr int kTopBarIdentifier = 3;

    RdProfiles(qt_intf_t* intf, MainCtx* ctx, QObject* parent = nullptr);
    ~RdProfiles() override;

    int topBarIdentifier() const { return kTopBarIdentifier; }
    PlayerControlbarModel* topBarModel() const;
    QString currentName() const;
    int count() const;
    bool busy() const { return m_busy; }

    Q_INVOKABLE void select(int index);
    Q_INVOKABLE void create(const QString& name);
    Q_INVOKABLE void rename(int index, const QString& name);
    // removes the selected profile (VLC's profile list removes the selected one); the profile
    // that takes its place is applied. The last profile cannot be removed.
    Q_INVOKABLE void removeCurrent();

    // `base` if no profile has that name, else "base (2)", "base (3)" ... (for the "+ New" field)
    Q_INVOKABLE QString uniqueName(const QString& base) const;

signals:
    void topBarModelChanged();
    void currentChanged();
    void countChanged();
    void busyChanged();

    // after a switch to `profile`: options changed that apply from the next media
    // (`nextMedia`) or only after a restart (`restartOptions`, their names)
    void applied(const QString& profile, bool nextMedia, const QStringList& restartOptions);

private:
    using Settings = QVariantMap;

    ControlbarProfileModel* model() const;
    void ensureTopBars();
    void onProfilesChanged();

    void setBusy(bool busy);
    void loadStore();
    void saveStore();
    void apply(const QString& leaving, const QString& target);

    int colorSchemeIndex() const;
    void setColorSchemeIndex(int index);

    qt_intf_t* m_intf = nullptr;
    QPointer<MainCtx> m_ctx;

    // one worker thread: configuration reads, writes and saves, the store file; in order
    QThreadPool m_worker;
    QString m_storePath;
    QHash<QString, Settings> m_store;

    bool m_busy = false;
    QPointer<PlayerControlbarModel> m_topBarModel;
    QString m_currentName;
};

#endif // RD_PROFILES_HPP
