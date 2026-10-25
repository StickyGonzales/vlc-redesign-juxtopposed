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

#include "rd_presets.hpp"

#include "player/player_controller.hpp"
#include "player/rd_effects.hpp"
#include "util/varchoicemodel.hpp"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QPointer>
#include <QSaveFile>

#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_url.h>

#include <algorithm>
#include <cmath>
#include <memory>

namespace {

const QString defaultId = QStringLiteral("default");
// changes settle before they are kept in the selected preset (a slider being dragged)
constexpr int captureDelay = 500;

enum class Kind
{
    Option,       // VLC option (RdEffects::setOption)
    AudioValue,   // audio output value
    AudioFlag,    // audio output flag
    AudioFilter,  // audio filter on / off
    VideoValue,   // video output value
    VideoFilter,  // video filter on / off
    Equalizer,    // equalizer on / off, preset, preamp and bands together
    SubScale,     // subtitle text size
    SubDuration,  // subtitle duration factor
    Rate,         // playback speed
    SubDelay,     // subtitle delay (ms)
    SubFps,       // subtitle speed
    AudioDelay,   // audio delay (ms)
    Choice        // one of the player's choice lists, kept by its title
};

struct Entry
{
    Kind kind;
    const char* name;
    // VLC sets it again for every file (delays, speed, zoom ...): applied to each file
    bool perFile;
};

// every setting of the four sidebar tabs that belongs to a show (Decision 18), in the order
// they are applied: a filter's values come before the filter is turned on
const std::vector<Entry>& entries()
{
    static const std::vector<Entry> list = {
        // Subtitles tab
        { Kind::SubDelay, "sub-delay", true },
        { Kind::SubFps, "sub-fps", true },
        { Kind::SubDuration, "sub-duration-factor", false },
        { Kind::Option, "sub-track", false },
        { Kind::Option, "sub-language", false },
        { Kind::Option, "subsdec-formatted", false },
        { Kind::Option, "freetype-font", false },
        { Kind::Option, "freetype-color", false },
        { Kind::Option, "freetype-outline-color", false },
        { Kind::Option, "freetype-outline-thickness", false },
        { Kind::Option, "freetype-background-opacity", false },
        { Kind::SubScale, "sub-text-scale", false },
        { Kind::VideoValue, "sub-margin", false },

        // Audio tab
        { Kind::AudioDelay, "audio-delay", true },
        { Kind::Choice, "stereo-mode", true },
        { Kind::Option, "audio-track", false },
        { Kind::Option, "audio-language", false },
        { Kind::Equalizer, "equalizer", false },
        { Kind::AudioFlag, "equalizer-2pass", false },
        { Kind::AudioValue, "compressor-rms-peak", false },
        { Kind::AudioValue, "compressor-attack", false },
        { Kind::AudioValue, "compressor-release", false },
        { Kind::AudioValue, "compressor-threshold", false },
        { Kind::AudioValue, "compressor-ratio", false },
        { Kind::AudioValue, "compressor-knee", false },
        { Kind::AudioValue, "compressor-makeup-gain", false },
        { Kind::AudioFilter, "compressor", false },
        { Kind::AudioValue, "spatializer-roomsize", false },
        { Kind::AudioValue, "spatializer-width", false },
        { Kind::AudioValue, "spatializer-wet", false },
        { Kind::AudioValue, "spatializer-dry", false },
        { Kind::AudioValue, "spatializer-damp", false },
        { Kind::AudioFilter, "spatializer", false },
        { Kind::AudioValue, "stereowiden-delay", false },
        { Kind::AudioValue, "stereowiden-feedback", false },
        { Kind::AudioValue, "stereowiden-crossfeed", false },
        { Kind::AudioValue, "stereowiden-dry-mix", false },
        { Kind::AudioFilter, "stereo_widen", false },
        { Kind::AudioValue, "pitch-shift", false },
        { Kind::AudioFilter, "scaletempo_pitch", false },

        // Video tab
        { Kind::Choice, "zoom", true },
        { Kind::Choice, "aspect-ratio", true },
        { Kind::Choice, "crop", true },
        { Kind::VideoValue, "crop-top", true },
        { Kind::VideoValue, "crop-bottom", true },
        { Kind::VideoValue, "crop-left", true },
        { Kind::VideoValue, "crop-right", true },
        { Kind::Option, "d3d11-hdr-mode", false },
        { Kind::Option, "preferred-resolution", false },
        { Kind::VideoValue, "transform-type", false },
        { Kind::VideoFilter, "transform", false },
        { Kind::VideoValue, "rotate-angle", false },
        { Kind::VideoFilter, "rotate", false },
        { Kind::VideoValue, "hue", false },
        { Kind::VideoValue, "brightness", false },
        { Kind::VideoValue, "contrast", false },
        { Kind::VideoValue, "saturation", false },
        { Kind::VideoValue, "gamma", false },
        { Kind::VideoFilter, "adjust", false },
        { Kind::VideoValue, "sharpen-sigma", false },
        { Kind::VideoFilter, "sharpen", false },
        { Kind::VideoValue, "gradfun-radius", false },
        { Kind::VideoFilter, "gradfun", false },
        { Kind::VideoValue, "grain-variance", false },
        { Kind::VideoFilter, "grain", false },
        { Kind::VideoValue, "extract-component", false },
        { Kind::VideoFilter, "extract", false },
        { Kind::VideoValue, "colorthres-color", false },
        { Kind::VideoValue, "colorthres-saturationthres", false },
        { Kind::VideoValue, "colorthres-similaritythres", false },
        { Kind::VideoFilter, "colorthres", false },
        { Kind::VideoFilter, "invert", false },
        { Kind::VideoValue, "posterize-level", false },
        { Kind::VideoFilter, "posterize", false },
        { Kind::VideoValue, "gradient-mode", false },
        { Kind::VideoValue, "gradient-color", false },
        { Kind::VideoValue, "gradient-cartoon", false },
        { Kind::VideoFilter, "gradient", false },
        { Kind::VideoValue, "sepia-intensity", false },
        { Kind::VideoFilter, "sepia", false },
        { Kind::VideoFilter, "magnify", false },
        { Kind::VideoValue, "wall-cols", false },
        { Kind::VideoValue, "wall-rows", false },
        { Kind::VideoFilter, "wall", false },
        { Kind::VideoValue, "puzzle-cols", false },
        { Kind::VideoValue, "puzzle-rows", false },
        { Kind::VideoFilter, "puzzle", false },
        { Kind::VideoValue, "logo-file", false },
        { Kind::VideoValue, "logo-opacity", false },
        { Kind::VideoFilter, "logo", false },
        { Kind::VideoValue, "marq-marquee", false },
        { Kind::VideoFilter, "marq", false },
        { Kind::VideoValue, "erase-mask", false },
        { Kind::VideoFilter, "erase", false },
        { Kind::VideoFilter, "anaglyph", false },
        { Kind::VideoFilter, "mirror", false },
        { Kind::VideoFilter, "psychedelic", false },
        { Kind::VideoFilter, "wave", false },
        { Kind::VideoFilter, "ripple", false },
        { Kind::VideoFilter, "motiondetect", false },
        { Kind::VideoValue, "gaussianblur-sigma", false },
        { Kind::VideoFilter, "gaussianblur", false },
        { Kind::VideoValue, "blur-factor", false },
        { Kind::VideoFilter, "motionblur", false },
        { Kind::VideoValue, "antiflicker-softening-size", false },
        { Kind::VideoFilter, "antiflicker", false },
        { Kind::VideoValue, "hqdn3d-luma-spat", false },
        { Kind::VideoValue, "hqdn3d-luma-temp", false },
        { Kind::VideoValue, "hqdn3d-chroma-spat", false },
        { Kind::VideoValue, "hqdn3d-chroma-temp", false },
        { Kind::VideoFilter, "hqdn3d", false },
        { Kind::VideoValue, "clone-count", false },
        { Kind::VideoFilter, "clone", false },

        // Playback tab
        { Kind::Rate, "rate", true },
        { Kind::Choice, "visual", true },
    };
    return list;
}

QString keyOf(const Entry& entry)
{
    static const char* const prefixes[] = {
        "option", "audio", "audioFlag", "audioFilter", "video", "videoFilter", "equalizer",
        "subScale", "subDuration", "rate", "subDelay", "subFps", "audioDelay", "choice"
    };
    return QString::fromLatin1(prefixes[static_cast<int>(entry.kind)]) + QChar(':') + QLatin1String(entry.name);
}

bool sameValue(const QJsonValue& a, const QJsonValue& b)
{
    if (a.isDouble() && b.isDouble())
    {
        const double x = a.toDouble();
        const double y = b.toDouble();
        // VLC keeps floats in single precision
        return std::abs(x - y) <= 1e-4 * std::max({ 1.0, std::abs(x), std::abs(y) });
    }
    if (a.isArray() && b.isArray())
    {
        const QJsonArray x = a.toArray();
        const QJsonArray y = b.toArray();
        if (x.size() != y.size())
            return false;
        for (qsizetype i = 0; i < x.size(); ++i)
            if (!sameValue(x.at(i), y.at(i)))
                return false;
        return true;
    }
    if (a.isObject() && b.isObject())
    {
        const QJsonObject x = a.toObject();
        const QJsonObject y = b.toObject();
        if (x.keys() != y.keys())
            return false;
        for (auto it = x.begin(); it != x.end(); ++it)
            if (!sameValue(it.value(), y.value(it.key())))
                return false;
        return true;
    }
    return a == b;
}

QString storePath()
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return {};
    const QString path = QString::fromUtf8(dir) + QStringLiteral("/rd-presets.json");
    free(dir);
    return path;
}

// Windows paths do not tell case apart
Qt::CaseSensitivity pathCase()
{
#ifdef _WIN32
    return Qt::CaseInsensitive;
#else
    return Qt::CaseSensitive;
#endif
}

// "Default Preset" is VLC's own behavior: it keeps none of the values VLC starts again for every
// file (the delays, zoom, aspect ratio and crop), so a delay fixed for one file does not follow
// every file played after it. The speed, subtitle speed, stereo mode and visualizer VLC itself
// keeps from file to file, until it quits: so does "Default Preset" (`session` true while it
// runs; false when the presets are read at start, which begins again with VLC's values).
bool keptFromFileToFile(const Entry& entry)
{
    return entry.kind == Kind::Rate || entry.kind == Kind::SubFps
            || qstrcmp(entry.name, "stereo-mode") == 0 || qstrcmp(entry.name, "visual") == 0;
}

void stripPerFile(QJsonObject& values, bool session)
{
    for (const Entry& entry : entries())
    {
        if (entry.perFile && !(session && keptFromFileToFile(entry)))
            values.remove(keyOf(entry));
    }
}

// a value a new video or audio output starts again from VLC's default (it is kept on the output
// only): the zoom, aspect ratio and crop lists, the crop margins and the stereo mode. The
// visualizer is not one: choosing it is what restarts the audio output, which keeps the choice
bool outputValue(const Entry& entry)
{
    return (entry.kind == Kind::Choice && qstrcmp(entry.name, "visual") != 0)
            || (entry.kind == Kind::VideoValue && entry.perFile);
}

// the values "Default Preset" applies: its own, the file's delays at VLC's start values, and the
// speeds at VLC's start values while it has none of its own yet, so leaving a show's preset puts
// them back
QJsonObject defaultValues(const QJsonObject& values)
{
    QJsonObject result = values;
    result.insert(keyOf({ Kind::SubDelay, "sub-delay", true }), 0);
    result.insert(keyOf({ Kind::AudioDelay, "audio-delay", true }), 0);
    for (const Entry& speed : { Entry { Kind::Rate, "rate", true }, Entry { Kind::SubFps, "sub-fps", true } })
        if (!result.contains(keyOf(speed)))
            result.insert(keyOf(speed), 1.0);
    return result;
}

} // namespace

RdPresets::RdPresets(qt_intf_t* intf, RdEffects* effects, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_effects(effects)
    , m_player(intf->p_mainPlayerController)
{
    m_storePool.setMaxThreadCount(1);

    m_captureTimer.setSingleShot(true);
    m_captureTimer.setInterval(captureDelay);
    connect(&m_captureTimer, &QTimer::timeout, this, &RdPresets::captureIntoCurrent);

    // the lists of a new output reset one after another, and the cached values of the output
    // (RdEffects) are read again just after: the output's values go out once, after both
    m_outputsTimer.setSingleShot(true);
    m_outputsTimer.setInterval(0);
    connect(&m_outputsTimer, &QTimer::timeout, this, &RdPresets::applyToOutputs);

    // a change anywhere (sidebar, hotkeys, the Settings dialog) is kept in the selected preset
    connect(m_effects, &RdEffects::changed, this, &RdPresets::scheduleCapture);
    connect(m_player, &PlayerController::rateChanged, this, &RdPresets::scheduleCapture);
    connect(m_player, &PlayerController::subtitleDelayChanged, this, &RdPresets::scheduleCapture);
    connect(m_player, &PlayerController::audioDelayChanged, this, &RdPresets::scheduleCapture);
    connect(m_player, &PlayerController::subtitleFPSChanged, this, &RdPresets::scheduleCapture);
    for (QAbstractItemModel* model : { static_cast<QAbstractItemModel*>(m_player->getZoom()),
                                       static_cast<QAbstractItemModel*>(m_player->getAspectRatio()),
                                       static_cast<QAbstractItemModel*>(m_player->getCrop()),
                                       static_cast<QAbstractItemModel*>(m_player->getAudioStereoMode()),
                                       static_cast<QAbstractItemModel*>(m_player->getAudioVisualizations()) })
    {
        connect(model, &QAbstractItemModel::dataChanged, this, &RdPresets::scheduleCapture);
        // the video and audio outputs can come after the file starts playing: their lists fill
        // then, and the file's values that need them go out at that moment
        connect(model, &QAbstractItemModel::modelReset, &m_outputsTimer, qOverload<>(&QTimer::start));
        connect(model, &QAbstractItemModel::rowsInserted, &m_outputsTimer, qOverload<>(&QTimer::start));
    }

    connect(m_player, &PlayerController::inputChanged, this, &RdPresets::onInputChanged);
    connect(m_player, &PlayerController::playingStateChanged, this, &RdPresets::onPlayingStateChanged);

    // the presets, read in the background
    auto data = std::make_shared<QJsonObject>();
    QPointer<RdPresets> self(this);
    m_storePool.start([self, data]() {
        QFile file(storePath());
        if (file.open(QIODevice::ReadOnly))
            *data = QJsonDocument::fromJson(file.readAll()).object();
        QMetaObject::invokeMethod(self.data(), [self, data]() {
            if (self)
                self->load(*data);
        }, Qt::QueuedConnection);
    });
}

RdPresets::~RdPresets()
{
    m_storePool.waitForDone();
}

// ------------------------------------------------------------------------------------ list

RdPresets::Preset* RdPresets::find(const QString& id)
{
    for (Preset& preset : m_presets)
        if (preset.id == id)
            return &preset;
    return nullptr;
}

const RdPresets::Preset* RdPresets::find(const QString& id) const
{
    for (const Preset& preset : m_presets)
        if (preset.id == id)
            return &preset;
    return nullptr;
}

QVariantList RdPresets::presets() const
{
    // Figma "Setting Preset": the presets made by the user in order, "Default Preset" last
    QVariantList list;
    const Preset* builtin = nullptr;
    for (const Preset& preset : m_presets)
    {
        if (preset.id == defaultId)
        {
            builtin = &preset;
            continue;
        }
        list.append(QVariantMap {
            { QStringLiteral("id"), preset.id },
            { QStringLiteral("name"), preset.name },
            { QStringLiteral("builtin"), false },
            { QStringLiteral("linked"), !m_folder.isEmpty() && preset.folders.contains(m_folder, pathCase()) }
        });
    }
    if (builtin)
        list.append(QVariantMap {
            { QStringLiteral("id"), defaultId },
            { QStringLiteral("name"), qtr("Default Preset") },
            { QStringLiteral("builtin"), true },
            { QStringLiteral("linked"), !m_folder.isEmpty() && builtin->folders.contains(m_folder, pathCase()) }
        });
    return list;
}

QString RdPresets::currentName() const
{
    if (m_currentId == defaultId || m_currentId.isEmpty())
        return qtr("Default Preset");
    const Preset* preset = find(m_currentId);
    return preset ? preset->name : qtr("Default Preset");
}

QString RdPresets::folderName() const
{
    // "The Wand / S01": the last two folders, like the library's breadcrumb
    const QStringList parts = m_folder.split(QChar('/'), Qt::SkipEmptyParts);
    return parts.mid(std::max<qsizetype>(0, parts.size() - 2)).join(QStringLiteral(" / "));
}

QString RdPresets::uniqueName(const QString& base) const
{
    const auto taken = [this](const QString& name) {
        for (const Preset& preset : m_presets)
            if (preset.id != defaultId && preset.name.compare(name, Qt::CaseInsensitive) == 0)
                return true;
        return false;
    };
    // Figma: "Custom Preset 01", "Custom Preset 02" ...
    for (int n = 1; ; ++n)
    {
        const QString name = QStringLiteral("%1 %2").arg(base).arg(n, 2, 10, QChar('0'));
        if (!taken(name))
            return name;
    }
}

QString RdPresets::newId() const
{
    QString id;
    do
        id = QString::number(QDateTime::currentMSecsSinceEpoch(), 36) + QString::number(m_presets.size(), 36);
    while (find(id));
    return id;
}

// -------------------------------------------------------------------------------- actions

void RdPresets::select(const QString& id)
{
    if (!m_loaded || id == m_currentId || !find(id))
        return;

    // the changes not kept yet belong to the preset being left
    if (m_captureTimer.isActive())
    {
        m_captureTimer.stop();
        captureIntoCurrent();
    }

    m_currentId = id;
    apply(*find(id), false);
    emit currentChanged();
    save();
}

QString RdPresets::create()
{
    if (!m_loaded)
        return {};
    if (m_captureTimer.isActive())
    {
        m_captureTimer.stop();
        captureIntoCurrent();
    }

    // Decision 25: a new preset copies the current settings
    Preset preset;
    preset.id = newId();
    preset.name = uniqueName(qtr("Custom Preset"));
    preset.values = capture();
    if (const Preset* current = find(m_currentId))
    {
        // values VLC cannot read now (no video playing) come from the preset in use
        for (auto it = current->values.begin(); it != current->values.end(); ++it)
            if (!preset.values.contains(it.key()))
                preset.values.insert(it.key(), it.value());
    }
    m_presets.append(preset);
    m_currentId = preset.id;
    emit presetsChanged();
    emit currentChanged();
    save();
    return preset.id;
}

void RdPresets::rename(const QString& id, const QString& name)
{
    Preset* preset = find(id);
    const QString trimmed = name.trimmed();
    if (!preset || id == defaultId || trimmed.isEmpty() || trimmed == preset->name)
        return;
    preset->name = trimmed;
    emit presetsChanged();
    if (id == m_currentId)
        emit currentChanged();
    save();
}

QString RdPresets::duplicate(const QString& id)
{
    const Preset* source = find(id);
    if (!source)
        return {};
    if (id == m_currentId && m_captureTimer.isActive())
    {
        m_captureTimer.stop();
        captureIntoCurrent();
        source = find(id);
    }

    Preset copy;
    copy.id = newId();
    const QString name = id == defaultId ? qtr("Default Preset") : source->name;
    copy.name = qtr("%1 Copy").arg(name);
    for (int n = 2; std::any_of(m_presets.cbegin(), m_presets.cend(),
                                [&copy](const Preset& p) { return p.name.compare(copy.name, Qt::CaseInsensitive) == 0; }); ++n)
        copy.name = qtr("%1 Copy %2").arg(name).arg(n);
    copy.values = source->values;
    m_presets.append(copy);
    emit presetsChanged();
    save();
    return copy.id;
}

void RdPresets::remove(const QString& id)
{
    if (id == defaultId || !find(id))
        return;

    if (id == m_currentId)
    {
        m_captureTimer.stop();
        m_currentId = defaultId;
        apply(*find(defaultId), false);
        emit currentChanged();
    }
    m_presets.erase(std::remove_if(m_presets.begin(), m_presets.end(),
                                   [&id](const Preset& p) { return p.id == id; }),
                    m_presets.end());
    emit presetsChanged();
    save();
}

void RdPresets::setLinked(const QString& id, bool linked)
{
    if (m_folder.isEmpty() || !find(id))
        return;

    // a folder uses one preset
    for (Preset& preset : m_presets)
        preset.folders.removeIf([this](const QString& folder) {
            return folder.compare(m_folder, pathCase()) == 0;
        });
    if (linked)
        find(id)->folders.append(m_folder);
    emit presetsChanged();
    save();

    // the folder's preset is the one in use for it
    if (linked)
        select(id);
}

// ---------------------------------------------------------------------- capture and apply

QJsonObject RdPresets::capture() const
{
    QJsonObject values;
    const bool hasInput = m_player->getPlayingState() != PlayerController::PLAYING_STATE_STOPPED;

    const auto choiceModel = [this](const char* name) -> VLCVarChoiceModel* {
        const QLatin1String n(name);
        if (n == QLatin1String("zoom"))
            return m_player->getZoom();
        if (n == QLatin1String("aspect-ratio"))
            return m_player->getAspectRatio();
        if (n == QLatin1String("crop"))
            return m_player->getCrop();
        if (n == QLatin1String("stereo-mode"))
            return m_player->getAudioStereoMode();
        return m_player->getAudioVisualizations();
    };

    for (const Entry& entry : entries())
    {
        // a file's own values only exist while one plays
        if (entry.perFile && !hasInput)
            continue;

        const QString name = QString::fromLatin1(entry.name);
        QJsonValue value;
        switch (entry.kind)
        {
        case Kind::Option:
        {
            const QVariant v = m_effects->option(name);
            if (v.isValid())
                value = QJsonValue::fromVariant(v);
            break;
        }
        case Kind::AudioValue:
            value = m_effects->audioValue(name);
            break;
        case Kind::AudioFlag:
            value = m_effects->audioFlag(name);
            break;
        case Kind::AudioFilter:
            value = m_effects->audioFilterEnabled(name);
            break;
        case Kind::VideoValue:
        {
            const QVariant v = m_effects->videoValue(name);
            if (v.isValid())
                value = QJsonValue::fromVariant(v);
            break;
        }
        case Kind::VideoFilter:
            value = m_effects->videoFilterEnabled(name);
            break;
        case Kind::Equalizer:
            value = QJsonObject {
                { QStringLiteral("preset"), m_effects->equalizerPreset() },
                { QStringLiteral("preamp"), m_effects->audioValue(QStringLiteral("equalizer-preamp")) },
                { QStringLiteral("bands"), QJsonArray::fromVariantList(m_effects->equalizerBands()) }
            };
            break;
        case Kind::SubScale:
            value = m_effects->subtitleTextScale();
            break;
        case Kind::SubDuration:
            value = m_effects->subtitleDurationFactor();
            break;
        case Kind::Rate:
            value = static_cast<double>(m_player->getRate());
            break;
        case Kind::SubDelay:
            value = m_player->getSubtitleDelayMS();
            break;
        case Kind::SubFps:
            value = static_cast<double>(m_player->getSubtitleFPS());
            break;
        case Kind::AudioDelay:
            value = m_player->getAudioDelayMS();
            break;
        case Kind::Choice:
        {
            VLCVarChoiceModel* model = choiceModel(entry.name);
            const int row = model->currentRow();
            // the list is empty without a video (zoom, crop) or audio output (stereo mode)
            if (row >= 0)
                value = model->data(model->index(row), Qt::DisplayRole).toString();
            break;
        }
        }
        if (!value.isUndefined() && !value.isNull())
            values.insert(keyOf(entry), value);
    }
    return values;
}

void RdPresets::apply(const Preset& preset, bool perFileOnly, bool listsOnly)
{
    const QJsonObject values = preset.id == defaultId && !listsOnly ? defaultValues(preset.values)
                                                                    : preset.values;

    // the values this changes are not a change of the user's
    const bool wasBlocked = m_captureBlocked;
    m_captureBlocked = true;

    const QJsonObject now = capture();
    const bool hasInput = m_player->getPlayingState() != PlayerController::PLAYING_STATE_STOPPED;

    for (const Entry& entry : entries())
    {
        if ((perFileOnly && !entry.perFile)
                || (listsOnly && entry.kind != Kind::Choice && !(entry.kind == Kind::VideoValue && entry.perFile)))
            continue;
        const QString key = keyOf(entry);
        const QJsonValue stored = values.value(key);
        if (stored.isUndefined() || (now.contains(key) && sameValue(now.value(key), stored)))
            continue;
        // a file's own values need one playing; they are applied when the next one plays
        if (entry.perFile && !hasInput)
            continue;

        const QString name = QString::fromLatin1(entry.name);
        switch (entry.kind)
        {
        case Kind::Option:
            m_effects->setOption(name, stored.toVariant());
            break;
        case Kind::AudioValue:
            m_effects->setAudioValue(name, stored.toDouble());
            break;
        case Kind::AudioFlag:
            m_effects->setAudioFlag(name, stored.toBool());
            break;
        case Kind::AudioFilter:
            m_effects->setAudioFilterEnabled(name, stored.toBool());
            break;
        case Kind::VideoValue:
            m_effects->setVideoValue(name, stored.toVariant());
            break;
        case Kind::VideoFilter:
            m_effects->setVideoFilterEnabled(name, stored.toBool());
            break;
        case Kind::Equalizer:
        {
            const QJsonObject eq = stored.toObject();
            const int preset = eq.value(QStringLiteral("preset")).toInt(-1);
            if (preset < 0)
            {
                if (m_effects->equalizerPreset() >= 0)
                    m_effects->setEqualizerPreset(-1);
                break;
            }
            if (m_effects->equalizerPreset() < 0)
                m_effects->setAudioFilterEnabled(QStringLiteral("equalizer"), true);
            if (m_effects->equalizerPreset() != preset)
                m_effects->setEqualizerPreset(preset);
            const double preamp = eq.value(QStringLiteral("preamp")).toDouble();
            if (!sameValue(m_effects->audioValue(QStringLiteral("equalizer-preamp")), preamp))
                m_effects->setAudioValue(QStringLiteral("equalizer-preamp"), preamp);
            const QJsonArray bands = eq.value(QStringLiteral("bands")).toArray();
            const QVariantList current = m_effects->equalizerBands();
            for (qsizetype i = 0; i < bands.size() && i < current.size(); ++i)
                if (!sameValue(current.at(i).toDouble(), bands.at(i).toDouble()))
                    m_effects->setEqualizerBand(int(i), bands.at(i).toDouble());
            break;
        }
        case Kind::SubScale:
            m_effects->setSubtitleTextScale(stored.toInt());
            break;
        case Kind::SubDuration:
            m_effects->setSubtitleDurationFactor(stored.toDouble());
            break;
        case Kind::Rate:
            m_player->setRate(static_cast<float>(stored.toDouble()));
            break;
        case Kind::SubDelay:
            m_player->setSubtitleDelayMS(stored.toInt());
            break;
        case Kind::SubFps:
            m_player->setSubtitleFPS(static_cast<float>(stored.toDouble()));
            break;
        case Kind::AudioDelay:
            m_player->setAudioDelayMS(stored.toInt());
            break;
        case Kind::Choice:
        {
            const QLatin1String n(entry.name);
            VLCVarChoiceModel* model = n == QLatin1String("zoom") ? m_player->getZoom()
                                     : n == QLatin1String("aspect-ratio") ? m_player->getAspectRatio()
                                     : n == QLatin1String("crop") ? m_player->getCrop()
                                     : n == QLatin1String("stereo-mode") ? m_player->getAudioStereoMode()
                                     : m_player->getAudioVisualizations();
            const QString title = stored.toString();
            for (int row = 0; row < model->rowCount(); ++row)
                if (model->data(model->index(row), Qt::DisplayRole).toString() == title)
                {
                    model->setData(model->index(row), true, Qt::CheckStateRole);
                    break;
                }
            break;
        }
        }
    }

    m_captureBlocked = wasBlocked;
    // the signals of these changes arrive later: they find the values just applied
    m_captureTimer.stop();
}

void RdPresets::scheduleCapture()
{
    if (m_loaded && !m_captureBlocked)
        m_captureTimer.start();
}

void RdPresets::captureIntoCurrent()
{
    if (!m_loaded || m_captureBlocked)
        return;
    Preset* preset = find(m_currentId);
    if (!preset)
        return;

    // values VLC cannot read now (no file playing) stay as they were
    bool changed = false;
    QJsonObject values = capture();
    if (preset->id == defaultId)
        stripPerFile(values, true);
    for (auto it = values.begin(); it != values.end(); ++it)
    {
        if (!preset->values.contains(it.key()) || !sameValue(preset->values.value(it.key()), it.value()))
        {
            preset->values.insert(it.key(), it.value());
            changed = true;
        }
    }
    if (changed)
        save();
}

// ---------------------------------------------------------------------------- playback

void RdPresets::onInputChanged(bool hasInput)
{
    // the changes made on the file that ended are kept; its own values (delays ...) are already
    // those of the next file now, so they are not read
    if (m_captureTimer.isActive())
    {
        m_captureTimer.stop();
        const bool wasBlocked = m_captureBlocked;
        m_captureBlocked = false;
        if (Preset* preset = find(m_currentId))
        {
            const QJsonObject values = capture();
            // (the speeds, stereo mode and visualizer go on to the next file: they are kept too)
            for (const Entry& entry : entries())
                if ((!entry.perFile || keptFromFileToFile(entry)) && values.contains(keyOf(entry)))
                    preset->values.insert(keyOf(entry), values.value(keyOf(entry)));
            save();
        }
        m_captureBlocked = wasBlocked;
    }

    QString folder;
    if (hasInput)
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        if (input_item_t* item = vlc_player_GetCurrentMedia(player))
        {
            const QByteArray uri = item->psz_uri ? QByteArray(item->psz_uri) : QByteArray();
            if (uri.startsWith("file:"))
            {
                char* path = vlc_uri2path(uri.constData());
                if (path)
                {
                    folder = QDir::cleanPath(QFileInfo(QDir::fromNativeSeparators(QString::fromUtf8(path))).path());
                    free(path);
                }
            }
        }
    }
    if (folder != m_folder)
    {
        m_folder = folder;
        emit folderChanged();
        emit presetsChanged();
    }

    if (!hasInput)
    {
        m_pendingApply = false;
        m_captureBlocked = false;
        return;
    }

    // until the file plays and gets the preset's values, its reset values are not the user's
    m_captureBlocked = true;
    m_pendingApply = true;

    if (!m_loaded)
        return;

    // an episode of a folder tied to a preset brings that preset back; a media outside the
    // folders of the preset in use (another show) goes back to "Default Preset", so the show's
    // preset does not take the other media's changes. A preset picked by hand and tied to no
    // folder stays.
    QString next = linkedPreset(m_folder);
    if (next.isEmpty())
    {
        const Preset* current = find(m_currentId);
        next = (current && !current->folders.isEmpty()) ? defaultId : m_currentId;
    }
    if (next != m_currentId && find(next))
    {
        m_currentId = next;
        emit currentChanged();
        save();
    }
    // the options read when the file opens (default tracks, subtitle style) go out at once
    if (const Preset* preset = find(m_currentId))
        apply(*preset, false);
}

void RdPresets::onPlayingStateChanged()
{
    if (!m_pendingApply || !m_loaded)
        return;
    const PlayerController::PlayingState state = m_player->getPlayingState();
    if (state != PlayerController::PLAYING_STATE_PLAYING && state != PlayerController::PLAYING_STATE_PAUSED)
        return;

    m_pendingApply = false;
    // the file's own values (delays, speed, zoom ...) now that it has them
    if (const Preset* preset = find(m_currentId))
    {
        m_captureBlocked = true;
        apply(*preset, true);
    }
    m_captureBlocked = false;
}

void RdPresets::applyToOutputs()
{
    if (!m_loaded || m_pendingApply
            || m_player->getPlayingState() == PlayerController::PLAYING_STATE_STOPPED)
        return;
    Preset* preset = find(m_currentId);
    if (!preset)
        return;

    // a change still settling (a visualizer just picked restarts the audio output) is kept
    // first, so the preset does not put the previous value back; the new output's own values
    // are VLC's defaults, not a change of the user's
    if (m_captureTimer.isActive() && !m_captureBlocked)
    {
        m_captureTimer.stop();
        QJsonObject values = capture();
        if (preset->id == defaultId)
            stripPerFile(values, true);
        bool changed = false;
        for (const Entry& entry : entries())
        {
            const QString key = keyOf(entry);
            if (outputValue(entry) || !values.contains(key))
                continue;
            if (!preset->values.contains(key) || !sameValue(preset->values.value(key), values.value(key)))
            {
                preset->values.insert(key, values.value(key));
                changed = true;
            }
        }
        if (changed)
            save();
    }
    // only the values the new output keeps: the delays and the speed do not depend on it, and
    // the ones set while the file plays stay
    apply(*preset, true, true);
}

QString RdPresets::linkedPreset(const QString& folder) const
{
    // the folder itself, then each folder above it ("The Wand" for "The Wand/S02")
    for (QString dir = folder; !dir.isEmpty(); )
    {
        for (const Preset& preset : m_presets)
            if (preset.folders.contains(dir, pathCase()))
                return preset.id;
        const QString parent = QFileInfo(dir).path();
        if (parent == dir || parent == QLatin1String("."))
            break;
        dir = parent;
    }
    return {};
}

// ---------------------------------------------------------------------------- storage

void RdPresets::load(const QJsonObject& data)
{
    m_presets.clear();
    for (const QJsonValue& value : data.value(QStringLiteral("presets")).toArray())
    {
        const QJsonObject object = value.toObject();
        Preset preset;
        preset.id = object.value(QStringLiteral("id")).toString();
        preset.name = object.value(QStringLiteral("name")).toString();
        preset.values = object.value(QStringLiteral("values")).toObject();
        for (const QJsonValue& folder : object.value(QStringLiteral("folders")).toArray())
            preset.folders.append(folder.toString());
        if (!preset.id.isEmpty() && !find(preset.id))
            m_presets.append(preset);
    }

    // "Default Preset" always exists: the settings VLC has when there is none yet
    if (!find(defaultId))
    {
        Preset builtin;
        builtin.id = defaultId;
        builtin.values = capture();
        m_presets.append(builtin);
    }
    stripPerFile(find(defaultId)->values, false);

    // the Subtitle Duration Factor is hidden for 1.0 (RdEffects::resetSubtitleDurationFactor):
    // a preset that kept one would turn the "subsdelay" filter on again for its files
    const QString durationKey = keyOf({ Kind::SubDuration, "sub-duration-factor", false });
    bool reset = false;
    for (Preset& preset : m_presets)
    {
        if (preset.values.value(durationKey).toDouble() != 0)
        {
            preset.values.insert(durationKey, 0.);
            reset = true;
        }
    }

    m_currentId = data.value(QStringLiteral("current")).toString();
    if (!find(m_currentId))
        m_currentId = defaultId;
    m_loaded = true;
    if (reset)
        save();

    emit presetsChanged();
    emit currentChanged();

    // a file that started while the presets were read gets its folder's preset now
    if (m_pendingApply)
    {
        const QString linked = linkedPreset(m_folder);
        if (!linked.isEmpty())
            m_currentId = linked;
        emit currentChanged();
        apply(*find(m_currentId), false);
        onPlayingStateChanged();
    }
}

QJsonObject RdPresets::serialize() const
{
    QJsonArray list;
    for (const Preset& preset : m_presets)
        list.append(QJsonObject {
            { QStringLiteral("id"), preset.id },
            { QStringLiteral("name"), preset.name },
            { QStringLiteral("values"), preset.values },
            { QStringLiteral("folders"), QJsonArray::fromStringList(preset.folders) }
        });
    return QJsonObject {
        { QStringLiteral("version"), 1 },
        { QStringLiteral("current"), m_currentId },
        { QStringLiteral("presets"), list }
    };
}

void RdPresets::save()
{
    if (!m_loaded)
        return;
    const QByteArray json = QJsonDocument(serialize()).toJson(QJsonDocument::Indented);
    m_storePool.start([json]() {
        const QString path = storePath();
        if (path.isEmpty())
            return;
        QDir().mkpath(QFileInfo(path).absolutePath());
        QSaveFile file(path);
        if (file.open(QIODevice::WriteOnly))
        {
            file.write(json);
            file.commit();
        }
    });
}
