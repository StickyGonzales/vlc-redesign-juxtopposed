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

#include "rd_effects.hpp"

#include <QLocale>
#include <QMetaObject>

#include <algorithm>
#include <cfloat>
#include <cstdint>
#include <cstring>
#include <utility>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_player.h>
#include <vlc_plugin.h>
#include <vlc_vout.h>

#include "player/player_controller.hpp"
#include "util/brand.hpp"
#include "../../../audio_filter/equalizer_presets.h"

namespace {

// at most one apply of the pending changes per frame (60 Hz)
constexpr int applyInterval = 16;
// the configuration file is written once a burst of changes (a slider drag) is over
constexpr int saveDelay = 500;

QString makeKey(const char* kind, const QString& name)
{
    QString key = QString::fromLatin1(kind);
    key += QLatin1Char('/');
    key += name;
    return key;
}

QString equalizerPresetKey() { return QStringLiteral("equalizerPreset"); }
QString equalizerBandsKey() { return QStringLiteral("equalizerBands"); }
QString subtitleTextScaleKey() { return QStringLiteral("subtitleTextScale"); }
QString subtitleDurationFactorKey() { return QStringLiteral("subtitleDurationFactor"); }

QStringList splitChain(const QString& chain)
{
    return chain.split(':', Qt::SkipEmptyParts);
}

QString readConfigString(const char* name)
{
    char* value = config_GetPsz(name);
    const QString result = qfu(value ? value : "");
    free(value);
    return result;
}

QVariant readVar(vlc_object_t* obj, const char* name, int type)
{
    switch (type & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        return QVariant(var_GetBool(obj, name));
    case VLC_VAR_INTEGER:
        return QVariant(static_cast<qlonglong>(var_GetInteger(obj, name)));
    case VLC_VAR_FLOAT:
        return QVariant(static_cast<double>(var_GetFloat(obj, name)));
    case VLC_VAR_STRING:
    {
        char* value = var_GetString(obj, name);
        const QString result = qfu(value ? value : "");
        free(value);
        return QVariant(result);
    }
    default:
        return QVariant();
    }
}

// a value converted the way the configuration stores it (what reading it back gives)
QVariant configTyped(const char* name, const QVariant& value)
{
    switch (config_GetType(name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        return QVariant(value.toLongLong() != 0);
    case VLC_VAR_INTEGER:
        return QVariant(value.toLongLong());
    case VLC_VAR_FLOAT:
        return QVariant(static_cast<double>(value.toFloat()));
    case VLC_VAR_STRING:
        return QVariant(value.toString());
    default:
        return value;
    }
}

void writeConfig(const char* name, const QVariant& value)
{
    switch (config_GetType(name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
    case VLC_VAR_INTEGER:
        config_PutInt(name, value.toLongLong());
        break;
    case VLC_VAR_FLOAT:
        config_PutFloat(name, value.toFloat());
        break;
    case VLC_VAR_STRING:
        config_PutPsz(name, qtu(value.toString()));
        break;
    default:
        break;
    }
}

void writeVar(vlc_object_t* obj, const char* name, const QVariant& value)
{
    int type = var_Type(obj, name);
    if (type == 0)
        type = config_GetType(name);

    vlc_value_t val;
    QByteArray text;
    switch (type & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        val.b_bool = value.toBool();
        break;
    case VLC_VAR_INTEGER:
        val.i_int = value.toLongLong();
        break;
    case VLC_VAR_FLOAT:
        val.f_float = value.toFloat();
        break;
    case VLC_VAR_STRING:
        text = value.toString().toUtf8();
        val.psz_string = text.data();
        break;
    default:
        return;
    }
    var_SetChecked(obj, name, type & VLC_VAR_CLASS, val);
}

QString floatList(const QVariantList& values)
{
    QStringList parts;
    for (const QVariant& v : values)
        parts << QLocale(QLocale::C).toString(v.toFloat());
    return parts.join(' ');
}

QVariantList parseBands(const QString& bands)
{
    QVariantList gains;
    for (const QString& part : bands.split(' ', Qt::SkipEmptyParts))
        gains << static_cast<double>(QLocale(QLocale::C).toFloat(part));
    while (gains.size() < EQZ_BANDS_MAX)
        gains << 0.;
    return gains.mid(0, EQZ_BANDS_MAX);
}

} // namespace

RdEffects::RdEffects(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
    , m_values(new QQmlPropertyMap(this))
{
    m_applyTimer.setSingleShot(true);
    connect(&m_applyTimer, &QTimer::timeout, this, &RdEffects::applyPending);
    m_lastApply.start();

    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(saveDelay);
    connect(&m_saveTimer, &QTimer::timeout, this, &RdEffects::save);

    // one save at a time (config_SaveConfigFile is serialized anyway)
    m_savePool.setMaxThreadCount(1);

    // a new video output starts from the configuration: read the values again
    connect(m_player, &PlayerController::voutListChanged, this, &RdEffects::refresh);

    readKeys({ equalizerPresetKey(), equalizerBandsKey(), subtitleTextScaleKey(),
               subtitleDurationFactorKey() });
}

RdEffects::~RdEffects()
{
    // the last changes still reach VLC (the player outlives the interface); the file itself
    // is written by VLC when it quits, as the configuration is marked as changed
    m_applyTimer.stop();
    m_saveTimer.stop();
    runPending();
    m_savePool.waitForDone();
    for (auto it = m_pendingStrings.cbegin(); it != m_pendingStrings.cend(); ++it)
        config_PutPsz(it.key().constData(), qtu(it.value()));
}

/* cache */

QString RdEffects::ensure(const QString& key)
{
    if (!m_values->contains(key))
        readKeys({ key });
    return key;
}

void RdEffects::readKeys(const QStringList& keys)
{
    if (keys.isEmpty())
        return;

    const SharedVOutThread vout = m_player->getVout();
    const SharedAOut aout = m_player->getAout();
    for (const QString& key : keys)
        store(key, readKey(key, vout.get(), aout.get()));
}

QVariant RdEffects::readKey(const QString& key, vout_thread_t* vout, audio_output_t* aout)
{
    if (key == equalizerPresetKey())
        return QVariant(readEqualizerPreset(aout));
    if (key == equalizerBandsKey())
        return QVariant(readEqualizerBands(aout));
    if (key == subtitleTextScaleKey())
    {
        vlc_player_locker lock{ m_intf->p_player };
        return QVariant(static_cast<int>(vlc_player_GetSubtitleTextScale(m_intf->p_player)));
    }
    if (key == subtitleDurationFactorKey())
    {
        if (!readVideoFilterEnabled(QStringLiteral("subsdelay"), vout))
            return QVariant(0.);
        return QVariant(readVideoValue(QStringLiteral("subsdelay-factor"), vout).toDouble());
    }

    const qsizetype slash = key.indexOf(QLatin1Char('/'));
    if (slash < 0)
        return QVariant();
    const QString kind = key.left(slash);
    const QString name = key.mid(slash + 1);
    const QByteArray name8 = name.toUtf8();

    if (kind == QLatin1String("option"))
        return configValue(name8.constData());

    if (kind == QLatin1String("audio"))
    {
        if (aout && var_Type(aout, name8.constData()) != 0)
            return QVariant(static_cast<double>(var_GetFloat(aout, name8.constData())));
        if (!config_FindConfig(name8.constData()))
            return QVariant(0.);
        return QVariant(static_cast<double>(config_GetFloat(name8.constData())));
    }

    if (kind == QLatin1String("audioFlag"))
    {
        if (aout && var_Type(aout, name8.constData()) != 0)
            return QVariant(static_cast<bool>(var_GetBool(aout, name8.constData())));
        return QVariant(config_FindConfig(name8.constData()) && config_GetInt(name8.constData()) != 0);
    }

    if (kind == QLatin1String("audioFilter"))
        return QVariant(splitChain(audioChain(aout)).contains(name));

    if (kind == QLatin1String("video"))
        return readVideoValue(name, vout);

    if (kind == QLatin1String("videoFilter"))
        return QVariant(readVideoFilterEnabled(name, vout));

    return QVariant();
}

bool RdEffects::store(const QString& key, const QVariant& value)
{
    // an unchanged value notifies nothing: no binding re-evaluates
    if (m_values->contains(key) && m_values->value(key) == value)
        return false;
    m_values->insert(key, value);
    return true;
}

void RdEffects::setCached(const QString& key, const QVariant& value)
{
    store(key, value);
    touch(key);
}

void RdEffects::touch(const QString& key)
{
    // read back from VLC after the next apply, with the values computed from it
    m_touched.insert(key);
    if (key == makeKey("audioFilter", QStringLiteral("equalizer")))
        m_touched.insert(equalizerPresetKey());
    else if (key == makeKey("videoFilter", QStringLiteral("subsdelay"))
             || key == makeKey("video", QStringLiteral("subsdelay-factor")))
        m_touched.insert(subtitleDurationFactorKey());
}

void RdEffects::touchIfCached(const QString& key)
{
    if (m_values->contains(key))
        touch(key);
}

QString RdEffects::optionKey(const QString& name)
{
    return ensure(makeKey("option", name));
}

QString RdEffects::audioKey(const QString& name)
{
    return ensure(makeKey("audio", name));
}

QString RdEffects::audioFlagKey(const QString& name)
{
    return ensure(makeKey("audioFlag", name));
}

QString RdEffects::audioFilterKey(const QString& module)
{
    return ensure(makeKey("audioFilter", module));
}

QString RdEffects::videoKey(const QString& name)
{
    return ensure(makeKey("video", name));
}

QString RdEffects::videoFilterKey(const QString& module)
{
    return ensure(makeKey("videoFilter", module));
}

void RdEffects::refresh()
{
    // pending changes reach VLC first, so reading it does not undo them
    applyPending();
    readKeys(m_values->keys());
    ++m_revision;
    emit changed();
}

void RdEffects::discardPending()
{
    m_applyTimer.stop();
    m_pending.clear();
    m_touched.clear();
    // strings waiting for a save in progress: the save that follows writes the reset values
    m_pendingStrings.clear();
}

/* values as VLC has them */

QString RdEffects::configString(const char* name) const
{
    const auto pending = m_pendingStrings.constFind(QByteArray(name));
    if (pending != m_pendingStrings.constEnd())
        return *pending;
    return readConfigString(name);
}

QVariant RdEffects::configValue(const char* name) const
{
    switch (config_GetType(name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        return QVariant(config_GetInt(name) != 0);
    case VLC_VAR_INTEGER:
        return QVariant(static_cast<qlonglong>(config_GetInt(name)));
    case VLC_VAR_FLOAT:
        return QVariant(static_cast<double>(config_GetFloat(name)));
    case VLC_VAR_STRING:
        return QVariant(configString(name));
    default:
        return QVariant();
    }
}

QString RdEffects::audioChain(audio_output_t* aout) const
{
    if (!aout)
        return configString("audio-filter");
    char* value = var_GetNonEmptyString(aout, "audio-filter");
    const QString chain = qfu(value ? value : "");
    free(value);
    return chain;
}

QString RdEffects::videoChain(const QString& type, vout_thread_t* vout) const
{
    // the video output has no "video-splitter" variable: a splitter is chosen when the output
    // is created, from the configuration
    if (vout && type != QLatin1String("video-splitter"))
    {
        char* value = var_GetString(vout, qtu(type));
        const QString chain = qfu(value ? value : "");
        free(value);
        return chain;
    }
    return configString(qtu(type));
}

QString RdEffects::videoFilterType(const QString& module) const
{
    // the answer never changes for a module: look it up once
    const auto cached = m_filterTypes.constFind(module);
    if (cached != m_filterTypes.constEnd())
        return *cached;

    QString type;
    if (module_t* obj = module_find(qtu(module)))
    {
        if (module_provides(obj, "video splitter"))
            type = QStringLiteral("video-splitter");
        else if (module_provides(obj, "video filter"))
            type = QStringLiteral("video-filter");
        else if (module_provides(obj, "sub source"))
            type = QStringLiteral("sub-source");
        else if (module_provides(obj, "sub filter"))
            type = QStringLiteral("sub-filter");
    }
    else
        msg_Err(m_intf, "Unable to find filter module \"%s\".", qtu(module));

    m_filterTypes.insert(module, type);
    return type;
}

int RdEffects::readEqualizerPreset(audio_output_t* aout) const
{
    if (!splitChain(audioChain(aout)).contains(QStringLiteral("equalizer")))
        return -1;

    QString preset;
    if (aout)
    {
        char* value = var_GetNonEmptyString(aout, "equalizer-preset");
        preset = qfu(value ? value : "");
        free(value);
    }
    if (preset.isEmpty())
        preset = configString("equalizer-preset");

    for (int i = 0; i < NB_PRESETS; ++i)
        if (preset == QLatin1String(preset_list[i]))
            return i;
    return 0;
}

QVariantList RdEffects::readEqualizerBands(audio_output_t* aout) const
{
    QString bands;
    if (aout && (var_Type(aout, "equalizer-bands") & VLC_VAR_CLASS) == VLC_VAR_STRING)
    {
        char* value = var_GetString(aout, "equalizer-bands");
        bands = qfu(value ? value : "");
        free(value);
    }
    if (bands.isEmpty())
        bands = configString("equalizer-bands");
    return parseBands(bands);
}

bool RdEffects::readVideoFilterEnabled(const QString& module, vout_thread_t* vout) const
{
    const QString type = videoFilterType(module);
    if (type.isEmpty())
        return false;
    return splitChain(videoChain(type, vout)).contains(module);
}

QVariant RdEffects::readVideoValue(const QString& name, vout_thread_t* vout) const
{
    const QByteArray name8 = name.toUtf8();
    if (vout)
    {
        const int type = var_Type(vout, name8.constData());
        if (type != 0)
            return readVar(VLC_OBJECT(vout), name8.constData(), type);
    }
    return configValue(name8.constData());
}

/* applying changes */

void RdEffects::schedule(const QString& id, std::function<void()> apply)
{
    // a change that replaces the one just before it (the next step of a drag) takes its place
    if (!m_pending.isEmpty() && m_pending.last().first == id)
        m_pending.last().second = std::move(apply);
    else
        m_pending.append(qMakePair(id, std::move(apply)));

    if (!m_applyTimer.isActive())
    {
        const qint64 wait = applyInterval - m_lastApply.elapsed();
        m_applyTimer.start(static_cast<int>(std::clamp<qint64>(wait, 0, applyInterval)));
    }
}

void RdEffects::runPending()
{
    // in call order: a change may depend on the ones before it (a filter chain, a restart)
    const auto pending = std::exchange(m_pending, {});
    for (const auto& change : pending)
        change.second();
}

void RdEffects::applyPending()
{
    m_applyTimer.stop();
    if (m_pending.isEmpty() && m_touched.isEmpty())
        return;

    const bool wrote = !m_pending.isEmpty();
    runPending();
    m_lastApply.restart();

    // the cache shows what VLC has now (ranges, rounding, filters that failed to start)
    readKeys(std::exchange(m_touched, {}).values());
    ++m_revision;
    emit changed();

    if (wrote)
        m_saveTimer.start();
}

void RdEffects::putConfig(const char* name, const QVariant& value)
{
    const int type = config_GetType(name) & VLC_VAR_CLASS;
    // config_PutPsz waits for the file being written (it reads the strings under RCU): keep
    // the string until the save is over
    if (m_saving && type == VLC_VAR_STRING)
        m_pendingStrings.insert(QByteArray(name), value.toString());
    else
        writeConfig(name, value);

    // the cached values that read this option
    const QString key = qfu(name);
    touchIfCached(makeKey("option", key));
    touchIfCached(makeKey("audio", key));
    touchIfCached(makeKey("audioFlag", key));
    touchIfCached(makeKey("video", key));
    // the audio filter list typed as text (Settings > Audio): the filter toggles read it while
    // no audio output runs
    if (key == QLatin1String("audio-filter"))
    {
        const QString prefix = makeKey("audioFilter", QString());
        const QStringList keys = m_values->keys();
        for (const QString& cached : keys)
        {
            if (cached.startsWith(prefix))
                touch(cached);
        }
    }
}

void RdEffects::save()
{
    if (m_saving)
    {
        m_saveAgain = true;
        return;
    }
    m_saving = true;

    // config_SaveConfigFile is thread safe (serialized by its own lock, values read atomically
    // under RCU); the destructor waits for it
    libvlc_int_t* libvlc = vlc_object_instance(m_intf);
    m_savePool.start([this, libvlc]() {
        config_SaveConfigFile(libvlc);
        QMetaObject::invokeMethod(this, [this]() { onSaved(); }, Qt::QueuedConnection);
    });
}

void RdEffects::onSaved()
{
    m_saving = false;
    if (!m_pendingStrings.isEmpty())
    {
        for (auto it = m_pendingStrings.cbegin(); it != m_pendingStrings.cend(); ++it)
            config_PutPsz(it.key().constData(), qtu(it.value()));
        m_pendingStrings.clear();
        m_saveAgain = true;
    }
    if (m_saveAgain)
    {
        m_saveAgain = false;
        m_saveTimer.start();
    }
}

/* options */

QVariant RdEffects::option(const QString& name)
{
    return m_values->value(optionKey(name));
}

void RdEffects::setOption(const QString& name, const QVariant& value)
{
    const QByteArray name8 = name.toUtf8();
    const QString key = makeKey("option", name);
    setCached(key, configTyped(name8.constData(), value));
    schedule(key, [this, name8, value]() {
        putConfig(name8.constData(), value);

        // the player copies the preferred languages from the configuration only when it is
        // created: it takes them from here for the next file
        const bool audio = name8 == "audio-language";
        if (audio || name8 == "sub-language")
        {
            vlc_player_locker lock{ m_intf->p_player };
            vlc_player_SelectCategoryLanguage(m_intf->p_player, audio ? AUDIO_ES : SPU_ES,
                                              qtu(value.toString()));
        }
    });
}

QVariantList RdEffects::optionChoices(const QString& name) const
{
    QVariantList choices;
    const QByteArray key = name.toUtf8();

    if ((config_GetType(key.constData()) & VLC_VAR_CLASS) == VLC_VAR_STRING)
    {
        char** values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetPszChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices << QVariantMap{ { QStringLiteral("value"), qfu(values[i]) },
                                    { QStringLiteral("text"), brand::engineText(qfu(texts[i])) } };
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else
    {
        int64_t* values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetIntChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices << QVariantMap{ { QStringLiteral("value"), static_cast<qlonglong>(values[i]) },
                                    { QStringLiteral("text"), brand::engineText(qfu(texts[i])) } };
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    return choices;
}

QVariantMap RdEffects::optionRange(const QString& name) const
{
    const module_config_t* config = config_FindConfig(qtu(name));
    if (!config)
        return {};

    // options declared without a range report the type's limits: no usable range
    if (IsConfigIntegerType(config->i_type))
    {
        if (config->min.i == INT64_MIN || config->max.i == INT64_MAX)
            return {};
        return { { QStringLiteral("min"), static_cast<qlonglong>(config->min.i) },
                 { QStringLiteral("max"), static_cast<qlonglong>(config->max.i) },
                 { QStringLiteral("default"), static_cast<qlonglong>(config->orig.i) } };
    }
    if (IsConfigFloatType(config->i_type))
    {
        if (config->min.f <= -FLT_MAX || config->max.f >= FLT_MAX)
            return {};
        return { { QStringLiteral("min"), static_cast<double>(config->min.f) },
                 { QStringLiteral("max"), static_cast<double>(config->max.f) },
                 { QStringLiteral("default"), static_cast<double>(config->orig.f) } };
    }
    return {};
}

QString RdEffects::optionDescription(const QString& name) const
{
    const module_config_t* config = config_FindConfig(qtu(name));
    if (!config)
        return {};
    if (config->psz_longtext && *config->psz_longtext)
        return brand::engineText(qfut(config->psz_longtext));
    if (config->psz_text && *config->psz_text)
        return brand::engineText(qfut(config->psz_text));
    return {};
}

/* audio */

bool RdEffects::audioFilterEnabled(const QString& module)
{
    return m_values->value(audioFilterKey(module)).toBool();
}

void RdEffects::setAudioFilterEnabled(const QString& module, bool enabled)
{
    if (!module_exists(qtu(module)))
    {
        msg_Err(m_intf, "Unable to find filter module \"%s\".", qtu(module));
        return;
    }

    const QString key = makeKey("audioFilter", module);
    setCached(key, enabled);
    // the preset follows at once (-1 while the equalizer is off), not only after the apply
    if (module == QLatin1String("equalizer"))
    {
        int preset = -1;
        if (enabled)
        {
            const QString name = configString("equalizer-preset");
            preset = 0;
            for (int i = 0; i < NB_PRESETS; ++i)
                if (name == QLatin1String(preset_list[i]))
                    preset = i;
        }
        store(equalizerPresetKey(), preset);
    }
    schedule(key, [this, module, enabled]() {
        QStringList chain = splitChain(configString("audio-filter"));
        chain.removeAll(module);
        if (enabled)
            chain << module;
        putConfig("audio-filter", chain.join(':'));

        vlc_player_aout_EnableFilter(m_intf->p_player, qtu(module), enabled);
    });
}

double RdEffects::audioValue(const QString& name)
{
    return m_values->value(audioKey(name)).toDouble();
}

void RdEffects::setAudioValue(const QString& name, double value)
{
    const QString key = makeKey("audio", name);
    setCached(key, static_cast<double>(static_cast<float>(value)));
    const QByteArray name8 = name.toUtf8();
    schedule(key, [this, name8, value]() {
        if (SharedAOut aout = m_player->getAout())
            var_SetFloat(aout.get(), name8.constData(), value);
        putConfig(name8.constData(), value);
    });
}

bool RdEffects::audioFlag(const QString& name)
{
    return m_values->value(audioFlagKey(name)).toBool();
}

void RdEffects::setAudioFlag(const QString& name, bool value)
{
    const QString key = makeKey("audioFlag", name);
    setCached(key, value);
    const QByteArray name8 = name.toUtf8();
    schedule(key, [this, name8, value]() {
        if (SharedAOut aout = m_player->getAout())
            var_SetBool(aout.get(), name8.constData(), value);
        putConfig(name8.constData(), value);
    });
}

/* equalizer */

QStringList RdEffects::equalizerPresetNames() const
{
    QStringList names;
    for (int i = 0; i < NB_PRESETS; ++i)
        names << qfut(preset_list_text[i]);
    return names;
}

QVariantList RdEffects::equalizerPresetBands(int preset) const
{
    QVariantList bands;
    if (preset < 0 || preset >= NB_PRESETS)
        return bands;
    for (int i = 0; i < eqz_preset_10b[preset].i_band; ++i)
        bands << static_cast<double>(eqz_preset_10b[preset].f_amp[i]);
    return bands;
}

QStringList RdEffects::equalizerBandNames() const
{
    if (var_InheritBool(m_intf, "equalizer-vlcfreqs"))
        return { qtr("60 Hz"), qtr("170 Hz"), qtr("310 Hz"), qtr("600 Hz"), qtr("1 KHz"),
                 qtr("3 KHz"), qtr("6 KHz"), qtr("12 KHz"), qtr("14 KHz"), qtr("16 KHz") };
    return { qtr("31 Hz"), qtr("63 Hz"), qtr("125 Hz"), qtr("250 Hz"), qtr("500 Hz"),
             qtr("1 KHz"), qtr("2 KHz"), qtr("4 KHz"), qtr("8 KHz"), qtr("16 KHz") };
}

int RdEffects::equalizerPreset()
{
    return m_values->value(equalizerPresetKey()).toInt();
}

void RdEffects::setEqualizerPreset(int preset)
{
    if (preset < 0 || preset >= NB_PRESETS)
    {
        setAudioFilterEnabled(QStringLiteral("equalizer"), false);
        return;
    }

    const QString bands = floatList(equalizerPresetBands(preset));
    const float preamp = eqz_preset_10b[preset].f_preamp;
    setCached(equalizerPresetKey(), preset);
    setCached(equalizerBandsKey(), parseBands(bands));
    setCached(makeKey("audio", QStringLiteral("equalizer-preamp")), static_cast<double>(preamp));
    schedule(equalizerPresetKey(), [this, preset, bands, preamp]() {
        if (SharedAOut aout = m_player->getAout())
        {
            var_SetString(aout.get(), "equalizer-preset", preset_list[preset]);
            var_SetFloat(aout.get(), "equalizer-preamp", preamp);
            var_SetString(aout.get(), "equalizer-bands", qtu(bands));
        }
        putConfig("equalizer-preset", QString::fromLatin1(preset_list[preset]));
        putConfig("equalizer-preamp", static_cast<double>(preamp));
        putConfig("equalizer-bands", bands);
    });

    if (!audioFilterEnabled(QStringLiteral("equalizer")))
        setAudioFilterEnabled(QStringLiteral("equalizer"), true);
}

QVariantList RdEffects::equalizerBands()
{
    return m_values->value(equalizerBandsKey()).toList();
}

void RdEffects::setEqualizerBand(int band, double gain)
{
    if (band < 0 || band >= EQZ_BANDS_MAX)
        return;

    QVariantList gains = equalizerBands();
    gains[band] = gain;
    const QString bands = floatList(gains);
    setCached(equalizerBandsKey(), parseBands(bands));
    schedule(equalizerBandsKey(), [this, bands]() {
        if (SharedAOut aout = m_player->getAout())
            var_SetString(aout.get(), "equalizer-bands", qtu(bands));
        putConfig("equalizer-bands", bands);
    });
}

/* video */

bool RdEffects::videoFilterEnabled(const QString& module)
{
    return m_values->value(videoFilterKey(module)).toBool();
}

void RdEffects::setVideoFilterEnabled(const QString& module, bool enabled)
{
    const QString type = videoFilterType(module);
    if (type.isEmpty())
        return;

    const QString key = makeKey("videoFilter", module);
    if (type == QLatin1String("video-splitter"))
    {
        // one splitter at a time: the others are off now
        const QStringList keys = m_values->keys();
        for (const QString& other : keys)
        {
            if (other != key && other.startsWith(QLatin1String("videoFilter/"))
                && videoFilterType(other.mid(other.indexOf(QLatin1Char('/')) + 1)) == type)
                setCached(other, false);
        }
    }
    setCached(key, enabled);
    schedule(key, [this, module, type, enabled]() {
        applyVideoFilter(module, type, enabled);
    });
}

void RdEffects::applyVideoFilter(const QString& module, const QString& type, bool enabled)
{
    if (type == QLatin1String("video-splitter"))
    {
        // one splitter at a time; it applies to the next video output
        putConfig("video-splitter", enabled ? module : QString());
        return;
    }

    // a filter already in the chain keeps its place: moving it would rebuild the chain
    const SharedVOutThread vout = m_player->getVout();
    QStringList chain = splitChain(videoChain(type, vout.get()));
    if (enabled && !chain.contains(module))
        chain << module;
    else if (!enabled)
        chain.removeAll(module);
    const QString result = chain.join(':');

    putConfig(qtu(type), result);
    // setting a chain rebuilds it, even unchanged (the sub-source / sub-filter chains do not
    // compare): only the outputs whose chain differs get it
    for (const SharedVOutThread& v : m_player->getVouts())
    {
        if (videoChain(type, v.get()) != result)
            var_SetString(v.get(), qtu(type), qtu(result));
    }
}

void RdEffects::restartVideoFilter(const QString& module)
{
    schedule(makeKey("restart", module), [this, module]() {
        // filter options that are read when the filter starts: rebuild the chain without and
        // with the filter (the video output ignores an unchanged chain)
        const QString type = videoFilterType(module);
        if (type.isEmpty() || type == QLatin1String("video-splitter"))
            return;

        const SharedVOutThread vout = m_player->getVout();
        QStringList without = splitChain(videoChain(type, vout.get()));
        if (!without.contains(module))
            return;
        const QString with = without.join(':');
        without.removeAll(module);
        for (const SharedVOutThread& v : m_player->getVouts())
        {
            var_SetString(v.get(), qtu(type), qtu(without.join(':')));
            var_SetString(v.get(), qtu(type), qtu(with));
        }
    });
}

QVariant RdEffects::videoValue(const QString& name)
{
    return m_values->value(videoKey(name));
}

void RdEffects::setVideoValue(const QString& name, const QVariant& value)
{
    const QString key = makeKey("video", name);

    // shown at once with the type VLC reads it with
    QVariant shown = value;
    const QVariant previous = m_values->value(key);
    if (previous.isValid() && previous.metaType() != value.metaType())
    {
        QVariant converted = value;
        if (converted.convert(previous.metaType()))
            shown = converted;
    }
    // float vout variables read back float-rounded: cache that value, so the read-back after
    // the apply does not notify a second time per frame during a drag
    if (shown.metaType() == QMetaType::fromType<double>())
        shown = QVariant(double(float(shown.toDouble())));
    setCached(key, shown);

    const QByteArray name8 = name.toUtf8();
    schedule(key, [this, name8, value]() {
        for (const SharedVOutThread& vout : m_player->getVouts())
            writeVar(VLC_OBJECT(vout.get()), name8.constData(), value);
        putConfig(name8.constData(), value);
    });
}

/* subtitles */

int RdEffects::subtitleTextScale()
{
    return m_values->value(subtitleTextScaleKey()).toInt();
}

void RdEffects::setSubtitleTextScale(int percent)
{
    // the core accepts 10 % to 500 %
    const int scale = qBound(10, percent, 500);
    setCached(subtitleTextScaleKey(), scale);
    schedule(subtitleTextScaleKey(), [this, scale]() {
        {
            vlc_player_locker lock{ m_intf->p_player };
            vlc_player_SetSubtitleTextScale(m_intf->p_player, static_cast<unsigned>(scale));
        }
        putConfig("sub-text-scale", scale);
    });
}

double RdEffects::subtitleDurationFactor()
{
    return m_values->value(subtitleDurationFactorKey()).toDouble();
}

void RdEffects::setSubtitleDurationFactor(double factor)
{
    const QString key = makeKey("video", QStringLiteral("subsdelay-factor"));
    const double shown = static_cast<double>(static_cast<float>(factor));
    setCached(key, shown);
    setCached(subtitleDurationFactorKey(), factor > 0 ? shown : 0.);
    schedule(key, [this, factor]() {
        for (const SharedVOutThread& vout : m_player->getVouts())
            var_SetFloat(vout.get(), "subsdelay-factor", factor);
        putConfig("subsdelay-factor", factor);
    });

    // the filter runs while the factor is not 0
    if (videoFilterEnabled(QStringLiteral("subsdelay")) != (factor > 0))
        setVideoFilterEnabled(QStringLiteral("subsdelay"), factor > 0);
}
