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

#include "rd_profiles.hpp"
#include "rd_profile_settings.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QSaveFile>
#include <QSet>

#include <vlc_common.h>
#include <vlc_configuration.h>

#include <array>

#include "dialogs/toolbar/controlbar_profile.hpp"
#include "dialogs/toolbar/controlbar_profile_model.hpp"
#include "maininterface/mainctx.hpp"
#include "player/control_list_model.hpp"
#include "player/player_controlbar_model.hpp"
#include "util/color_scheme_model.hpp"

namespace {

// the store file (`<VLC user data folder>/rd-profiles.json`)
constexpr int kStoreVersion = 1;
const QString kColorSchemeKey = QStringLiteral("@color-scheme");

// the design's top bar (Figma "topbar"): "...", library toggle, divider, folder chip | title |
// fullscreen; the cone and the window buttons are not part of it
const std::array<QVector<int>, 3>& defaultTopBar()
{
    static const std::array<QVector<int>, 3> layout {
        QVector<int> { ControlListModel::RD_MAIN_MENU_BUTTON, ControlListModel::RD_LIBRARY_BUTTON,
                       ControlListModel::RD_DIVIDER, ControlListModel::RD_FOLDER_CHIP },
        QVector<int> { ControlListModel::RD_MEDIA_TITLE },
        QVector<int> { ControlListModel::FULLSCREEN_BUTTON },
    };
    return layout;
}

} // namespace

RdProfiles::RdProfiles(qt_intf_t* intf, MainCtx* ctx, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_ctx(ctx)
{
    m_worker.setMaxThreadCount(1);

    if (char* dir = config_GetUserDir(VLC_USERDATA_DIR))
    {
        m_storePath = QString::fromUtf8(dir) + QStringLiteral("/rd-profiles.json");
        free(dir);
    }

    ControlbarProfileModel* profiles = model();
    if (profiles)
    {
        // a profile without a top bar gets the design's (VLC's defaults, stock VLC's profiles,
        // a profile reloaded by Customize Player's Cancel)
        connect(profiles, &QAbstractItemModel::rowsInserted, this, &RdProfiles::onProfilesChanged);
        connect(profiles, &QAbstractItemModel::rowsRemoved, this, &RdProfiles::onProfilesChanged);
        connect(profiles, &QAbstractItemModel::modelReset, this, &RdProfiles::onProfilesChanged);
        connect(profiles, &QAbstractItemModel::dataChanged, this, &RdProfiles::onProfilesChanged);
        connect(profiles, &ControlbarProfileModel::selectedProfileChanged, this, &RdProfiles::onProfilesChanged);
        onProfilesChanged();
    }

    loadStore();
}

RdProfiles::~RdProfiles()
{
    // a configuration write or a store save in progress ends before the interface goes
    m_worker.waitForDone();
}

ControlbarProfileModel* RdProfiles::model() const
{
    return m_ctx ? m_ctx->controlbarProfileModel() : nullptr;
}

PlayerControlbarModel* RdProfiles::topBarModel() const
{
    return m_topBarModel;
}

QString RdProfiles::currentName() const
{
    return m_currentName;
}

int RdProfiles::count() const
{
    ControlbarProfileModel* profiles = model();
    return profiles ? profiles->rowCount() : 0;
}

void RdProfiles::ensureTopBars()
{
    ControlbarProfileModel* profiles = model();
    if (!profiles)
        return;
    const int rows = profiles->rowCount();
    for (int i = 0; i < rows; ++i)
    {
        ControlbarProfile* profile = profiles->getProfile(i);
        if (!profile || profile->getModel(kTopBarIdentifier))
            continue;
        // VLC's other styles have a fullscreen button in the control bar: not a second one
        std::array<QVector<int>, 3> topBar = defaultTopBar();
        const auto videoBar = profile->getModelData(PlayerControlbarModel::Videoplayer);
        for (const QVector<int>& zone : videoBar)
        {
            if (zone.contains(ControlListModel::FULLSCREEN_BUTTON))
                topBar[2].removeAll(ControlListModel::FULLSCREEN_BUTTON);
        }
        profile->setModelData(kTopBarIdentifier, topBar);
        // the design's default is no change of the user's
        if (PlayerControlbarModel* topBar = profile->getModel(kTopBarIdentifier))
            topBar->setDirty(false);
    }
}

void RdProfiles::onProfilesChanged()
{
    ensureTopBars();

    ControlbarProfileModel* profiles = model();
    ControlbarProfile* current = profiles ? profiles->currentModel() : nullptr;

    PlayerControlbarModel* topBar = current ? current->getModel(kTopBarIdentifier) : nullptr;
    if (topBar != m_topBarModel)
    {
        m_topBarModel = topBar;
        emit topBarModelChanged();
    }

    const QString name = current ? current->name() : QString();
    if (name != m_currentName)
    {
        m_currentName = name;
        emit currentChanged();
    }
    emit countChanged();
}

QString RdProfiles::uniqueName(const QString& base) const
{
    ControlbarProfileModel* profiles = model();
    const QString trimmed = base.trimmed();
    if (!profiles || trimmed.isEmpty())
        return trimmed;

    QSet<QString> names;
    for (int i = 0; i < profiles->rowCount(); ++i)
    {
        if (ControlbarProfile* profile = profiles->getProfile(i))
            names.insert(profile->name());
    }
    if (!names.contains(trimmed))
        return trimmed;
    for (int n = 2; ; ++n)
    {
        const QString candidate = QStringLiteral("%1 (%2)").arg(trimmed).arg(n);
        if (!names.contains(candidate))
            return candidate;
    }
}

void RdProfiles::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void RdProfiles::select(int index)
{
    ControlbarProfileModel* profiles = model();
    if (!profiles || m_busy || index == profiles->selectedProfile())
        return;
    ControlbarProfile* target = profiles->getProfile(index);
    if (!target)
        return;

    const QString leaving = m_currentName;
    // the bars switch at once, the settings follow from the worker
    profiles->setSelectedProfile(index);
    profiles->save(false);
    apply(leaving, target->name());
}

void RdProfiles::create(const QString& name)
{
    ControlbarProfileModel* profiles = model();
    if (!profiles || m_busy || !profiles->currentModel())
        return;

    const QString unique = uniqueName(name);
    if (unique.isEmpty())
        return;

    // the current layouts (cloneSelectedProfile keeps every player's, the top bar too)
    profiles->cloneSelectedProfile(unique);
    const int index = profiles->rowCount() - 1;
    ControlbarProfile* created = profiles->getProfile(index);
    if (!created)
        return;
    const QString createdName = created->name();
    profiles->setSelectedProfile(index);
    profiles->save(false);

    // and the current settings (Decision 25): nothing changes, they are only kept
    setBusy(true);
    const int scheme = colorSchemeIndex();
    QPointer<RdProfiles> self(this);
    m_worker.start([self, createdName, scheme]() {
        QVariantMap settings = RdProfileSettings::capture();
        settings.insert(kColorSchemeKey, scheme);
        if (!self)
            return;
        QMetaObject::invokeMethod(self, [self, createdName, settings]() {
            if (!self)
                return;
            self->m_store.insert(createdName, settings);
            self->saveStore();
            self->setBusy(false);
        }, Qt::QueuedConnection);
    });
}

void RdProfiles::rename(int index, const QString& name)
{
    ControlbarProfileModel* profiles = model();
    ControlbarProfile* profile = profiles ? profiles->getProfile(index) : nullptr;
    // a switch in progress stores the settings under the profile's name when it ends
    if (!profile || m_busy)
        return;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed == profile->name())
        return;

    const QString oldName = profile->name();
    const QString newName = uniqueName(trimmed);
    profiles->setData(profiles->index(index, 0), newName, Qt::DisplayRole);
    profiles->save(false);

    if (m_store.contains(oldName))
    {
        m_store.insert(newName, m_store.take(oldName));
        saveStore();
    }
}

void RdProfiles::removeCurrent()
{
    ControlbarProfileModel* profiles = model();
    if (!profiles || m_busy || profiles->rowCount() <= 1 || !profiles->currentModel())
        return;

    const QString removed = m_currentName;
    profiles->deleteSelectedProfile();
    profiles->save(false);

    m_store.remove(removed);
    saveStore();

    // the profile that took its place: its settings, nothing kept for the removed one
    ControlbarProfile* current = profiles->currentModel();
    if (current)
        apply(QString(), current->name());
}

// keeps the current settings in `leaving` (if not empty) and writes `target`'s
void RdProfiles::apply(const QString& leaving, const QString& target)
{
    const bool hasTarget = m_store.contains(target);
    const QVariantMap targetSettings = m_store.value(target);
    const int scheme = colorSchemeIndex();

    setBusy(true);
    libvlc_int_t* libvlc = vlc_object_instance(m_intf);
    QPointer<RdProfiles> self(this);
    m_worker.start([self, libvlc, leaving, target, hasTarget, targetSettings, scheme]() {
        QVariantMap left;
        if (!leaving.isEmpty())
        {
            left = RdProfileSettings::capture();
            left.insert(kColorSchemeKey, scheme);
        }
        // a profile without settings yet keeps the current ones (and gets them)
        RdProfileSettings::ApplyResult result;
        QVariantMap kept;
        if (hasTarget)
            result = RdProfileSettings::write(libvlc, targetSettings);
        else
        {
            kept = RdProfileSettings::capture();
            kept.insert(kColorSchemeKey, scheme);
        }
        if (!self)
            return;
        QMetaObject::invokeMethod(self, [self, leaving, target, hasTarget, targetSettings, left,
                                         kept, result]() {
            if (!self)
                return;
            if (!leaving.isEmpty())
                self->m_store.insert(leaving, left);
            if (!hasTarget)
                self->m_store.insert(target, kept);
            self->saveStore();

            if (hasTarget)
            {
                const QVariant scheme = targetSettings.value(kColorSchemeKey);
                if (scheme.isValid())
                    self->setColorSchemeIndex(scheme.toInt());
                // the interface's own options (accent color, fullscreen bars ...) at once
                if (self->m_ctx)
                    self->m_ctx->reloadPrefs();
            }
            self->setBusy(false);
            emit self->applied(target, result.nextMedia, result.restart);
        }, Qt::QueuedConnection);
    });
}

int RdProfiles::colorSchemeIndex() const
{
    ColorSchemeModel* scheme = m_ctx ? m_ctx->getColorScheme() : nullptr;
    return scheme ? scheme->currentIndex() : -1;
}

void RdProfiles::setColorSchemeIndex(int index)
{
    ColorSchemeModel* scheme = m_ctx ? m_ctx->getColorScheme() : nullptr;
    if (scheme && index >= 0 && index < scheme->rowCount({}) && index != scheme->currentIndex())
        scheme->setCurrentIndex(index);
}

// busy until the stored settings are read: a switch must know them
void RdProfiles::loadStore()
{
    if (m_storePath.isEmpty())
        return;
    setBusy(true);

    const QString path = m_storePath;
    QPointer<RdProfiles> self(this);
    m_worker.start([self, path]() {
        QHash<QString, Settings> store;
        QFile file(path);
        if (file.open(QIODevice::ReadOnly))
        {
            const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
            if (root.value(QStringLiteral("version")).toInt() == kStoreVersion)
            {
                const QJsonObject profiles = root.value(QStringLiteral("profiles")).toObject();
                for (auto it = profiles.constBegin(); it != profiles.constEnd(); ++it)
                    store.insert(it.key(), it.value().toObject().toVariantMap());
            }
        }
        if (!self)
            return;
        QMetaObject::invokeMethod(self, [self, store]() {
            if (!self)
                return;
            // what the session stored before the file was read wins
            for (auto it = store.constBegin(); it != store.constEnd(); ++it)
            {
                if (!self->m_store.contains(it.key()))
                    self->m_store.insert(it.key(), it.value());
            }
            self->setBusy(false);
        }, Qt::QueuedConnection);
    });
}

void RdProfiles::saveStore()
{
    if (m_storePath.isEmpty())
        return;

    QJsonObject profiles;
    for (auto it = m_store.constBegin(); it != m_store.constEnd(); ++it)
        profiles.insert(it.key(), QJsonObject::fromVariantMap(it.value()));
    QJsonObject root;
    root.insert(QStringLiteral("version"), kStoreVersion);
    root.insert(QStringLiteral("profiles"), profiles);
    const QByteArray data = QJsonDocument(root).toJson(QJsonDocument::Compact);

    const QString path = m_storePath;
    m_worker.start([path, data]() {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QSaveFile file(path);
        if (file.open(QIODevice::WriteOnly) && file.write(data) == data.size())
            file.commit();
    });
}
