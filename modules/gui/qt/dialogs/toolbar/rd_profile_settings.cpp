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

#include "rd_profile_settings.hpp"

#include <QSet>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include <cstring>
#include <vector>

namespace {

// options that are not settings of a profile: the first-run question, the play queue's
// shuffle and repeat (states the interface writes on every click of its buttons, which would
// otherwise follow the profile and ask for a restart), and the last volume of each audio output
// (a state, kept per output)
const QSet<QByteArray>& excludedOptions()
{
    static const QSet<QByteArray> names {
        "qt-privacy-ask", "random", "loop", "repeat", "mmdevice-volume", "waveout-volume", "directx-volume", "alsa-gain",
        "pulse-volume", "auhal-volume", "sndio-volume", "oss-volume", "jack-gain",
    };
    return names;
}

// options of the interface that apply at once: MainCtx reads them again (reloadPrefs) or
// the QML reads them through RdEffects
const QSet<QByteArray>& liveOptions()
{
    static const QSet<QByteArray> names {
        "qt-accent-color", "qt-fs-sensitivity", "qt-pin-controls", "qt-fs-opacity",
        "qt-smooth-scrolling", "qt-max-volume", "qt-safe-area", "qt-video-double-click",
        "qt-cast-discovery", "qt-seek-thumbnails", "qt-seek-waveform", "mouse-hide-timeout",
    };
    return names;
}

enum class Applies { Live, NextMedia, Restart };

struct Option
{
    QByteArray name;
    int type;          // CONFIG_ITEM_BOOL, _INTEGER, _FLOAT or a string type
    QVariant fallback; // VLC's default
    Applies applies;
};

using Catalog = std::vector<Option>;

QVariant defaultValue(const module_config_t& item)
{
    switch (CONFIG_CLASS(item.i_type))
    {
    case CONFIG_ITEM_BOOL:
        return QVariant(item.orig.i != 0);
    case CONFIG_ITEM_INTEGER:
        return QVariant(static_cast<qlonglong>(item.orig.i));
    case CONFIG_ITEM_FLOAT:
        return QVariant(static_cast<double>(item.orig.f));
    default:
        return QVariant(item.orig.psz ? QString::fromUtf8(item.orig.psz) : QString());
    }
}

Applies appliesOf(const module_config_t& item, int subcat, const char* capability, bool core)
{
    if (liveOptions().contains(QByteArray(item.psz_name)))
        return Applies::Live;
    // hotkeys, interfaces, loggers, VLC's startup and play queue options are read when VLC
    // starts
    if (item.i_type == CONFIG_ITEM_KEY)
        return Applies::Restart;
    if (subcat >= SUBCAT_INTERFACE_GENERAL && subcat <= SUBCAT_INTERFACE_HOTKEYS)
        return Applies::Restart;
    if (subcat == SUBCAT_ADVANCED_MISC || subcat == SUBCAT_PLAYLIST_GENERAL
        || subcat == SUBCAT_PLAYLIST_SD)
        return Applies::Restart;
    if (!core && capability
        && (!strcmp(capability, "interface") || !strcmp(capability, "logger")))
        return Applies::Restart;
    // the input, decoders, filters and outputs read their options when a media opens
    return Applies::NextMedia;
}

// every module's options, read once (on the worker thread: it walks all the plugins)
const Catalog& catalog()
{
    static const Catalog options = []() {
        Catalog list;
        QSet<QByteArray> seen;

        size_t count = 0;
        module_t** modules = module_list_get(&count);
        for (size_t m = 0; m < count; ++m)
        {
            const module_t* module = modules[m];
            const bool core = module_is_main(module);
            const char* capability = module_get_capability(module);

            unsigned size = 0;
            module_config_t* config = module_config_get(module, &size);
            if (!config)
                continue;

            int subcat = SUBCAT_UNKNOWN;
            for (unsigned i = 0; i < size; ++i)
            {
                const module_config_t& item = config[i];
                if (item.i_type == CONFIG_SUBCATEGORY)
                {
                    subcat = static_cast<int>(item.value.i);
                    continue;
                }
                // options, not hints; obsolete options have no text; no passwords in the store
                if (!CONFIG_ITEM(item.i_type) || !item.psz_name || !item.psz_text
                    || item.i_type == CONFIG_ITEM_PASSWORD)
                    continue;
                const QByteArray name(item.psz_name);
                if (excludedOptions().contains(name) || seen.contains(name))
                    continue;
                seen.insert(name);
                list.push_back({ name, CONFIG_CLASS(item.i_type), defaultValue(item),
                                 appliesOf(item, subcat, capability, core) });
            }
            module_config_free(config);
        }
        module_list_free(modules);
        return list;
    }();
    return options;
}

QVariant currentValue(const Option& option)
{
    switch (option.type)
    {
    case CONFIG_ITEM_BOOL:
        return QVariant(config_GetInt(option.name.constData()) != 0);
    case CONFIG_ITEM_INTEGER:
        return QVariant(static_cast<qlonglong>(config_GetInt(option.name.constData())));
    case CONFIG_ITEM_FLOAT:
        return QVariant(static_cast<double>(config_GetFloat(option.name.constData())));
    default:
    {
        char* value = config_GetPsz(option.name.constData());
        const QString text = value ? QString::fromUtf8(value) : QString();
        free(value);
        return QVariant(text);
    }
    }
}

// a stored value in the option's type (JSON numbers come back as doubles)
QVariant typed(const Option& option, const QVariant& value)
{
    switch (option.type)
    {
    case CONFIG_ITEM_BOOL:
        return QVariant(value.toBool());
    case CONFIG_ITEM_INTEGER:
        return QVariant(value.toLongLong());
    case CONFIG_ITEM_FLOAT:
        return QVariant(value.toDouble());
    default:
        return QVariant(value.toString());
    }
}

void putValue(const Option& option, const QVariant& value)
{
    switch (option.type)
    {
    case CONFIG_ITEM_BOOL:
        config_PutInt(option.name.constData(), value.toBool() ? 1 : 0);
        break;
    case CONFIG_ITEM_INTEGER:
        config_PutInt(option.name.constData(), value.toLongLong());
        break;
    case CONFIG_ITEM_FLOAT:
        config_PutFloat(option.name.constData(), static_cast<float>(value.toDouble()));
        break;
    default:
        config_PutPsz(option.name.constData(), value.toString().toUtf8().constData());
        break;
    }
}

} // namespace

// the options that differ from VLC's defaults, as VLC has them now
QVariantMap RdProfileSettings::capture()
{
    QVariantMap settings;
    for (const Option& option : catalog())
    {
        const QVariant value = currentValue(option);
        if (value != option.fallback)
            settings.insert(QString::fromLatin1(option.name), value);
    }
    return settings;
}

// writes `target` (missing options: VLC's defaults) where VLC differs, and saves
RdProfileSettings::ApplyResult RdProfileSettings::write(libvlc_int_t* libvlc, const QVariantMap& target)
{
    ApplyResult result;
    for (const Option& option : catalog())
    {
        const QString key = QString::fromLatin1(option.name);
        const QVariant wanted = target.contains(key) ? typed(option, target.value(key)) : option.fallback;
        if (currentValue(option) == wanted)
            continue;
        putValue(option, wanted);
        if (option.applies == Applies::NextMedia)
            result.nextMedia = true;
        else if (option.applies == Applies::Restart)
            result.restart.append(key);
    }
    config_SaveConfigFile(libvlc);
    return result;
}

