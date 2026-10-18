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

#include "hotkeys_model.hpp"

#include <QKeyEvent>
#include <QStringList>

#include <algorithm>
#include <cstdlib>
#include <cstring>

#include <vlc_common.h>
#include <vlc_actions.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include "qt.hpp"
#include "dialogs/dialogs/dialogmodel.hpp"
#include "util/brand.hpp"
#include "util/vlchotkeyconverter.hpp"

namespace {

enum Group
{
    GroupBasic,
    GroupPlayback,
    GroupJumps,
    GroupAudio,
    GroupSubtitles,
    GroupVideo,
    GroupDiscMenus,
    GroupQueueBookmarks,
    GroupOther,
};

QString groupName(int group)
{
    switch (group)
    {
    case GroupBasic: return qtr("Basic");
    case GroupPlayback: return qtr("Playback");
    case GroupJumps: return qtr("Jumps, Chapters & Titles");
    case GroupAudio: return qtr("Audio");
    case GroupSubtitles: return qtr("Subtitles");
    case GroupVideo: return qtr("Video");
    case GroupDiscMenus: return qtr("Disc Menus");
    case GroupQueueBookmarks: return qtr("Play Queue Bookmarks");
    default: return qtr("Other");
    }
}

/* Order and groups of the actions. The first rows of Basic and Playback and their labels are
 * the ones of the design (video 15:57-16:01, Figma "Keyboard Shortcuts"); every other action
 * keeps VLC's own name. Actions missing here are listed under "Other". */
struct ActionInfo
{
    const char* name;
    int group;
    const char* label;
};

const ActionInfo actionTable[] = {
    { "key-toggle-fullscreen", GroupBasic, N_("Toggle fullscreen") },
    { "key-leave-fullscreen", GroupBasic, N_("Exit fullscreen / close dialog") },
    { "key-position", GroupBasic, N_("Show playback position and time") },
    { "key-intf-show", GroupBasic, N_("Show interface controls in fullscreen") },
    { "key-intf-popup-menu", GroupBasic, nullptr },
    { "key-intf-boss", GroupBasic, nullptr },
    { "key-wallpaper", GroupBasic, nullptr },
    { "key-quit", GroupBasic, nullptr },

    { "key-play-pause", GroupPlayback, N_("Play / pause") },
    { "key-stop", GroupPlayback, N_("Stop playback") },
    { "key-next", GroupPlayback, N_("Next track") },
    { "key-prev", GroupPlayback, N_("Previous track") },
    { "key-program-sid-next", GroupPlayback, N_("Next program / Service ID") },
    { "key-program-sid-prev", GroupPlayback, nullptr },
    { "key-play", GroupPlayback, nullptr },
    { "key-pause", GroupPlayback, nullptr },
    { "key-faster", GroupPlayback, nullptr },
    { "key-slower", GroupPlayback, nullptr },
    { "key-rate-normal", GroupPlayback, nullptr },
    { "key-rate-faster-fine", GroupPlayback, nullptr },
    { "key-rate-slower-fine", GroupPlayback, nullptr },
    { "key-frame-next", GroupPlayback, nullptr },
    { "key-frame-previous", GroupPlayback, nullptr },
    { "key-loop", GroupPlayback, nullptr },
    { "key-random", GroupPlayback, nullptr },
    { "key-record", GroupPlayback, nullptr },
    { "key-clear-playlist", GroupPlayback, nullptr },

    { "key-jump-extrashort", GroupJumps, nullptr },
    { "key-jump+extrashort", GroupJumps, nullptr },
    { "key-jump-short", GroupJumps, nullptr },
    { "key-jump+short", GroupJumps, nullptr },
    { "key-jump-medium", GroupJumps, nullptr },
    { "key-jump+medium", GroupJumps, nullptr },
    { "key-jump-long", GroupJumps, nullptr },
    { "key-jump+long", GroupJumps, nullptr },
    { "key-chapter-prev", GroupJumps, nullptr },
    { "key-chapter-next", GroupJumps, nullptr },
    { "key-title-prev", GroupJumps, nullptr },
    { "key-title-next", GroupJumps, nullptr },

    { "key-vol-up", GroupAudio, nullptr },
    { "key-vol-down", GroupAudio, nullptr },
    { "key-vol-mute", GroupAudio, nullptr },
    { "key-audio-track", GroupAudio, nullptr },
    { "key-audiodevice-cycle", GroupAudio, nullptr },
    { "key-audiodelay-up", GroupAudio, nullptr },
    { "key-audiodelay-down", GroupAudio, nullptr },

    { "key-subtitle-track", GroupSubtitles, nullptr },
    { "key-subtitle-revtrack", GroupSubtitles, nullptr },
    { "key-subtitle-toggle", GroupSubtitles, nullptr },
    { "key-subtitle-control-secondary", GroupSubtitles, nullptr },
    { "key-subdelay-up", GroupSubtitles, nullptr },
    { "key-subdelay-down", GroupSubtitles, nullptr },
    { "key-subpos-up", GroupSubtitles, nullptr },
    { "key-subpos-down", GroupSubtitles, nullptr },
    { "key-subtitle-text-scale-up", GroupSubtitles, nullptr },
    { "key-subtitle-text-scale-down", GroupSubtitles, nullptr },
    { "key-subtitle-text-scale-normal", GroupSubtitles, nullptr },
    { "key-subsync-markaudio", GroupSubtitles, nullptr },
    { "key-subsync-marksub", GroupSubtitles, nullptr },
    { "key-subsync-apply", GroupSubtitles, nullptr },
    { "key-subsync-reset", GroupSubtitles, nullptr },

    { "key-snapshot", GroupVideo, nullptr },
    { "key-aspect-ratio", GroupVideo, nullptr },
    { "key-crop", GroupVideo, nullptr },
    { "key-toggle-autoscale", GroupVideo, nullptr },
    { "key-incr-scalefactor", GroupVideo, nullptr },
    { "key-decr-scalefactor", GroupVideo, nullptr },
    { "key-zoom-quarter", GroupVideo, nullptr },
    { "key-zoom-half", GroupVideo, nullptr },
    { "key-zoom-original", GroupVideo, nullptr },
    { "key-zoom-double", GroupVideo, nullptr },
    { "key-zoom", GroupVideo, nullptr },
    { "key-unzoom", GroupVideo, nullptr },
    { "key-deinterlace", GroupVideo, nullptr },
    { "key-deinterlace-mode", GroupVideo, nullptr },
    { "key-crop-top", GroupVideo, nullptr },
    { "key-uncrop-top", GroupVideo, nullptr },
    { "key-crop-left", GroupVideo, nullptr },
    { "key-uncrop-left", GroupVideo, nullptr },
    { "key-crop-bottom", GroupVideo, nullptr },
    { "key-uncrop-bottom", GroupVideo, nullptr },
    { "key-crop-right", GroupVideo, nullptr },
    { "key-uncrop-right", GroupVideo, nullptr },
    /* VLC declares this one without a name */
    { "key-projection-toggle", GroupVideo, N_("Toggle 360° projection") },
    { "key-viewpoint-fov-in", GroupVideo, nullptr },
    { "key-viewpoint-fov-out", GroupVideo, nullptr },
    { "key-viewpoint-roll-clock", GroupVideo, nullptr },
    { "key-viewpoint-roll-anticlock", GroupVideo, nullptr },

    { "key-disc-menu", GroupDiscMenus, nullptr },
    { "key-nav-activate", GroupDiscMenus, nullptr },
    { "key-nav-up", GroupDiscMenus, nullptr },
    { "key-nav-down", GroupDiscMenus, nullptr },
    { "key-nav-left", GroupDiscMenus, nullptr },
    { "key-nav-right", GroupDiscMenus, nullptr },

    { "key-set-bookmark1", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark1", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark2", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark2", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark3", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark3", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark4", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark4", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark5", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark5", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark6", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark6", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark7", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark7", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark8", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark8", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark9", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark9", GroupQueueBookmarks, nullptr },
    { "key-set-bookmark10", GroupQueueBookmarks, nullptr },
    { "key-play-bookmark10", GroupQueueBookmarks, nullptr },
};

const int actionTableSize = static_cast<int>(sizeof(actionTable) / sizeof(actionTable[0]));

int actionIndex(const char* name)
{
    for (int i = 0; i < actionTableSize; ++i)
        if (strcmp(actionTable[i].name, name) == 0)
            return i;
    return -1;
}

QString configKeys(const char* name)
{
    char* value = config_GetPsz(name);
    const QString keys = qfu(value);
    free(value);
    return keys;
}

QStringList splitKeys(const QString& keys)
{
    return keys.split(QLatin1Char('\t'), Qt::SkipEmptyParts);
}

// localized modifier name without VLC's trailing "+" ("Ctrl+" -> "Ctrl")
QString modifierName(const char* text)
{
    QString name = qfut(text);
    if (name.endsWith(QLatin1Char('+')))
        name.chop(1);
    return name;
}

QString formatKey(uint_fast32_t code)
{
    QStringList parts;
    if (code & KEY_MODIFIER_CTRL)
        parts << modifierName(N_("Ctrl+"));
    if (code & KEY_MODIFIER_ALT)
        parts << modifierName(N_("Alt+"));
    if (code & KEY_MODIFIER_SHIFT)
        parts << modifierName(N_("Shift+"));
    if (code & KEY_MODIFIER_META)
        parts << modifierName(N_("Meta+"));
    if (code & KEY_MODIFIER_COMMAND)
        parts << modifierName(N_("Command+"));

    // letters are drawn as on the keyboard: "F", not VLC's "f"
    QString name = VLCKeyToString(static_cast<unsigned>(code & ~KEY_MODIFIER), true);
    if (name.size() == 1)
        name = name.toUpper();
    parts << name;
    return parts.join(QStringLiteral(" + "));
}

} // namespace

HotkeysModel::HotkeysModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int HotkeysModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return getCount();
}

QVariant HotkeysModel::data(const QModelIndex& index, int role) const
{
    const Entry* entry = entryAt(index.row());
    if (!index.isValid() || !entry)
        return {};

    switch (role)
    {
    case ActionRole:
        return entry->action;
    case DescriptionRole:
        return entry->description;
    case GroupRole:
        return groupName(entry->group);
    case HotkeyRole:
        return displayKeys(entry->keys);
    case GlobalHotkeyRole:
        return displayKeys(entry->globalKeys);
    case HotkeyIsDefaultRole:
        return entry->keys == entry->defaultKeys;
    case GlobalHotkeyIsDefaultRole:
        return entry->globalKeys == entry->defaultGlobalKeys;
    case HasGlobalRole:
        return !entry->globalConfigName.isEmpty();
    default:
        return {};
    }
}

QHash<int, QByteArray> HotkeysModel::roleNames() const
{
    return {
        { ActionRole, "action" },
        { DescriptionRole, "description" },
        { GroupRole, "group" },
        { HotkeyRole, "hotkey" },
        { GlobalHotkeyRole, "globalHotkey" },
        { HotkeyIsDefaultRole, "hotkeyIsDefault" },
        { GlobalHotkeyIsDefaultRole, "globalHotkeyIsDefault" },
        { HasGlobalRole, "hasGlobal" },
    };
}

void HotkeysModel::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

void HotkeysModel::setSearchText(const QString& text)
{
    if (text == m_searchText)
        return;
    m_searchText = text;
    emit searchTextChanged();
    updateFilter();
}

void HotkeysModel::setSearchField(int field)
{
    if (field == m_searchField)
        return;
    m_searchField = field;
    emit searchFieldChanged();
    updateFilter();
}

QString HotkeysModel::getFirstGroup() const
{
    if (m_visible.isEmpty())
        return {};
    return groupName(m_entries.at(m_visible.first()).group);
}

void HotkeysModel::reload()
{
    /* later opens: re-read the keys in place, so the view keeps its delegates (a reset
     * would destroy and rebuild every visible row on each open) */
    if (!m_entries.isEmpty())
    {
        for (Entry& entry : m_entries)
        {
            entry.keys = entry.savedKeys = configKeys(qtu(entry.configName));
            if (!entry.globalConfigName.isEmpty())
                entry.globalKeys = entry.savedGlobalKeys = configKeys(qtu(entry.globalConfigName));
        }
        updateFilter();
        if (rowCount() > 0)
            emit dataChanged(index(0), index(rowCount() - 1));
        updateDirty();
        return;
    }

    beginResetModel();

    m_entries.clear();

    module_t* mainModule = module_get_main();
    unsigned confsize = 0;
    module_config_t* config = module_config_get(mainModule, &confsize);

    QHash<QString, int> byName;
    QVector<const module_config_t*> globalItems;

    for (unsigned i = 0; i < confsize; ++i)
    {
        const module_config_t* item = config + i;
        if (item->i_type != CONFIG_ITEM_KEY || item->psz_name == nullptr)
            continue;

        /* global keys are matched to their action afterwards */
        if (strncmp(item->psz_name, "global-", 7) == 0)
        {
            globalItems.append(item);
            continue;
        }

        Entry entry;
        entry.configName = qfu(item->psz_name);

        const int info = actionIndex(item->psz_name);
        entry.group = info >= 0 ? actionTable[info].group : GroupOther;
        entry.order = info >= 0 ? info : actionTableSize + static_cast<int>(i);
        if (info >= 0 && actionTable[info].label)
            entry.action = qfut(actionTable[info].label);
        else if (item->psz_text && *item->psz_text)
            entry.action = brand::engineText(qfut(item->psz_text));
        else
            entry.action = entry.configName;
        if (item->psz_longtext && *item->psz_longtext)
            entry.description = brand::engineText(qfut(item->psz_longtext));

        entry.defaultKeys = qfu(item->orig.psz);
        entry.keys = entry.savedKeys = configKeys(item->psz_name);

        byName.insert(entry.configName, static_cast<int>(m_entries.size()));
        m_entries.append(entry);
    }

    for (const module_config_t* item : globalItems)
    {
        const auto it = byName.constFind(qfu(item->psz_name + 7));
        if (it == byName.constEnd())
            continue;

        Entry& entry = m_entries[it.value()];
        entry.globalConfigName = qfu(item->psz_name);
        entry.defaultGlobalKeys = qfu(item->orig.psz);
        entry.globalKeys = entry.savedGlobalKeys = configKeys(item->psz_name);
    }

    module_config_free(config);

    std::stable_sort(m_entries.begin(), m_entries.end(), [](const Entry& a, const Entry& b) {
        return a.group != b.group ? a.group < b.group : a.order < b.order;
    });

    m_visible.clear();
    for (int i = 0; i < m_entries.size(); ++i)
        if (matches(m_entries.at(i)))
            m_visible.append(i);

    endResetModel();
    emit countChanged();
    updateDirty();
}

bool HotkeysModel::save()
{
    qt_intf_t* intf = m_ctx ? m_ctx->getIntf() : nullptr;
    if (!intf)
        return false;

    for (Entry& entry : m_entries)
    {
        if (entry.keys != entry.savedKeys)
        {
            config_PutPsz(qtu(entry.configName), qtu(entry.keys));
            entry.savedKeys = entry.keys;
        }
        if (!entry.globalConfigName.isEmpty() && entry.globalKeys != entry.savedGlobalKeys)
        {
            config_PutPsz(qtu(entry.globalConfigName), qtu(entry.globalKeys));
            entry.savedGlobalKeys = entry.globalKeys;
        }
    }
    updateDirty();

    bool saved = true;
    if (config_SaveConfigFile(intf) != 0)
    {
        saved = false;
        if (DialogErrorModel* errors = DialogErrorModel::getInstance<false>())
            errors->pushError(qtr("Cannot save Configuration"),
                              qtr("Preferences file could not be saved"));
    }

    m_ctx->reloadPrefs();
    return saved;
}

QString HotkeysModel::keyFromEvent(int key, int modifiers) const
{
    switch (key)
    {
    case Qt::Key_Shift:
    case Qt::Key_Control:
    case Qt::Key_Meta:
    case Qt::Key_Alt:
    case Qt::Key_AltGr:
    case Qt::Key_CapsLock:
    case Qt::Key_NumLock:
    case Qt::Key_unknown:
        return {};
    default:
        break;
    }

    QKeyEvent event(QEvent::KeyPress, key, Qt::KeyboardModifiers::fromInt(modifiers));
    return keyFromCode(qtEventToVLCKey(&event));
}

QString HotkeysModel::keyFromCode(int code) const
{
    const unsigned vlcKey = static_cast<unsigned>(code);
    if ((vlcKey & ~KEY_MODIFIER) == KEY_UNSET)
        return {};
    return VLCKeyToString(vlcKey, false);
}

QString HotkeysModel::displayKeys(const QString& keys) const
{
    QStringList shown;
    for (const QString& key : splitKeys(keys))
    {
        const uint_fast32_t code = vlc_str2keycode(qtu(key));
        shown << (code == KEY_UNSET ? key : formatKey(code));
    }
    return shown.join(QStringLiteral(", "));
}

QString HotkeysModel::conflictingAction(int row, bool global, const QString& keys) const
{
    const Entry* self = entryAt(row);
    if (!self)
        return {};

    const QStringList wanted = splitKeys(keys);
    for (const Entry& entry : m_entries)
    {
        if (&entry == self || (global && entry.globalConfigName.isEmpty()))
            continue;

        const QStringList used = splitKeys(keysOf(entry, global));
        for (const QString& key : wanted)
            if (used.contains(key))
                return entry.action;
    }
    return {};
}

QString HotkeysModel::defaultKeys(int row, bool global) const
{
    const Entry* entry = entryAt(row);
    if (!entry)
        return {};
    return global ? entry->defaultGlobalKeys : entry->defaultKeys;
}

void HotkeysModel::assign(int row, bool global, const QString& keys)
{
    Entry* self = entryAt(row);
    if (!self || (global && self->globalConfigName.isEmpty()))
        return;

    /* a key belongs to one action per column (KeySelectorControl::reassign_key) */
    const QStringList wanted = splitKeys(keys);
    for (Entry& entry : m_entries)
    {
        if (&entry == self)
            continue;

        QStringList used = splitKeys(keysOf(entry, global));
        bool changed = false;
        for (const QString& key : wanted)
            changed |= used.removeAll(key) > 0;
        if (changed)
            keysOf(entry, global) = used.join(QLatin1Char('\t'));
    }

    keysOf(*self, global) = wanted.join(QLatin1Char('\t'));

    notifyAllRowsChanged();
    updateDirty();
}

void HotkeysModel::clear(int row, bool global)
{
    Entry* entry = entryAt(row);
    if (!entry || (global && entry->globalConfigName.isEmpty()))
        return;

    keysOf(*entry, global).clear();

    notifyAllRowsChanged();
    updateDirty();
}

void HotkeysModel::resetAll()
{
    for (Entry& entry : m_entries)
    {
        entry.keys = entry.defaultKeys;
        if (!entry.globalConfigName.isEmpty())
            entry.globalKeys = entry.defaultGlobalKeys;
    }

    notifyAllRowsChanged();
    updateDirty();
}

HotkeysModel::Entry* HotkeysModel::entryAt(int row)
{
    if (row < 0 || row >= m_visible.size())
        return nullptr;
    return &m_entries[m_visible.at(row)];
}

const HotkeysModel::Entry* HotkeysModel::entryAt(int row) const
{
    if (row < 0 || row >= m_visible.size())
        return nullptr;
    return &m_entries.at(m_visible.at(row));
}

QString& HotkeysModel::keysOf(Entry& entry, bool global) const
{
    return global ? entry.globalKeys : entry.keys;
}

const QString& HotkeysModel::keysOf(const Entry& entry, bool global) const
{
    return global ? entry.globalKeys : entry.keys;
}

bool HotkeysModel::matches(const Entry& entry) const
{
    const QString pattern = m_searchText.trimmed();
    if (pattern.isEmpty())
        return true;

    const auto has = [&pattern](const QString& text) {
        return text.contains(pattern, Qt::CaseInsensitive);
    };
    const bool inAction = has(entry.action);
    const bool inHotkey = has(displayKeys(entry.keys)) || has(entry.keys);
    const bool inGlobal = has(displayKeys(entry.globalKeys)) || has(entry.globalKeys);

    switch (m_searchField)
    {
    case 1: return inAction;
    case 2: return inHotkey;
    case 3: return inGlobal;
    default: return inAction || inHotkey || inGlobal;
    }
}

void HotkeysModel::updateFilter()
{
    QVector<int> wanted;
    for (int i = 0; i < m_entries.size(); ++i)
        if (matches(m_entries.at(i)))
            wanted.append(i);

    /* both lists are in entry order: remove and insert only the rows that change, so the
     * view keeps the delegates of the rows that stay while the user types */
    const QVector<int> previous = m_visible;
    int row = 0;
    int i = 0;
    int j = 0;
    while (i < previous.size() || j < wanted.size())
    {
        if (i < previous.size() && j < wanted.size() && previous.at(i) == wanted.at(j))
        {
            ++i;
            ++j;
            ++row;
        }
        else if (j >= wanted.size() || (i < previous.size() && previous.at(i) < wanted.at(j)))
        {
            beginRemoveRows({}, row, row);
            m_visible.removeAt(row);
            endRemoveRows();
            ++i;
        }
        else
        {
            beginInsertRows({}, row, row);
            m_visible.insert(row, wanted.at(j));
            endInsertRows();
            ++j;
            ++row;
        }
    }

    emit countChanged();
}

void HotkeysModel::updateDirty()
{
    bool dirty = false;
    for (const Entry& entry : m_entries)
    {
        if (entry.keys != entry.savedKeys || entry.globalKeys != entry.savedGlobalKeys)
        {
            dirty = true;
            break;
        }
    }

    if (dirty == m_dirty)
        return;
    m_dirty = dirty;
    emit dirtyChanged();
}

void HotkeysModel::notifyAllRowsChanged()
{
    if (m_visible.isEmpty())
        return;
    emit dataChanged(index(0), index(getCount() - 1));
}
