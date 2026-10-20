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
#ifndef RD_EFFECTS_HPP
#define RD_EFFECTS_HPP

#include <QByteArray>
#include <QElapsedTimer>
#include <QHash>
#include <QList>
#include <QObject>
#include <QPair>
#include <QQmlPropertyMap>
#include <QSet>
#include <QStringList>
#include <QThreadPool>
#include <QTimer>
#include <QVariant>

#include <functional>

#include "qt.hpp"

class PlayerController;

/**
 * redesign: the settings sidebar's access to VLC's audio and video effects and to the
 * options it shows (video 7:12-9:19). The logic mirrors VLC's "Adjustments and Effects"
 * dialog (dialogs/extended/extended_panels.cpp): audio filters are enabled on the player's
 * audio output, video filters are set on the video output's filter chains, and every
 * change is also written to the configuration (saved shortly after), so it is kept for
 * the next files and the next start.
 *
 * Values are cached in `values`, one property per key, so a binding only re-evaluates when
 * its own value changes and reading it takes no lock:
 *     RdEffects.values[RdEffects.videoKey("hue")]
 * The ...Key() functions return the key of a value and read it from VLC the first time it is
 * asked for. Four keys always exist: "equalizerPreset", "equalizerBands", "subtitleTextScale"
 * and "subtitleDurationFactor".
 *
 * A setter updates its cached value at once; the change reaches VLC (variables of the
 * outputs, configuration) on the next apply, at most one per frame, and the cached values it
 * touched are then read back from VLC. The configuration file is written on a worker thread
 * half a second after the last change. The cache is read again from VLC by refresh(), when the
 * video outputs change, and when a settings page is shown.
 *
 * The older form `(RdEffects.revision, RdEffects.option(name))` still works: the getters
 * return the cached values and `revision` changes once per apply and on refresh().
 */
class RdEffects : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QQmlPropertyMap* values READ values CONSTANT FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)

public:
    RdEffects(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdEffects() override;

    QQmlPropertyMap* values() const { return m_values; }
    int revision() const { return m_revision; }

    // keys of `values` (the value is read from VLC when a key is first asked for)
    Q_INVOKABLE QString optionKey(const QString& name);        // an option of the configuration
    Q_INVOKABLE QString audioKey(const QString& name);         // number: audio output variable / option
    Q_INVOKABLE QString audioFlagKey(const QString& name);     // bool: audio output variable / option
    Q_INVOKABLE QString audioFilterKey(const QString& module); // bool: audio filter enabled
    Q_INVOKABLE QString videoKey(const QString& name);         // video output variable / option
    Q_INVOKABLE QString videoFilterKey(const QString& module); // bool: video filter enabled

    // reads every cached value again from VLC (after another window, e.g. VLC's preferences,
    // changed the configuration); nothing is written
    Q_INVOKABLE void refresh();
    // forgets the changes not yet written to VLC (before VLC's options are all reset, so none
    // of them lands after the reset); refresh() then reads the reset values
    Q_INVOKABLE void discardPending();

    // options of the configuration (most apply to the next file)
    Q_INVOKABLE QVariant option(const QString& name);
    Q_INVOKABLE void setOption(const QString& name, const QVariant& value);
    // the choices VLC declares for an option: [{ value, text }]
    Q_INVOKABLE QVariantList optionChoices(const QString& name) const;
    // the range VLC declares for a numeric option: { min, max, default }
    Q_INVOKABLE QVariantMap optionRange(const QString& name) const;
    // VLC's explanation of an option (its long text, else its label), translated; empty if unknown
    Q_INVOKABLE QString optionDescription(const QString& name) const;

    // audio filters: live on the audio output, kept in "audio-filter"
    Q_INVOKABLE bool audioFilterEnabled(const QString& module);
    Q_INVOKABLE void setAudioFilterEnabled(const QString& module, bool enabled);
    Q_INVOKABLE double audioValue(const QString& name);
    Q_INVOKABLE void setAudioValue(const QString& name, double value);
    Q_INVOKABLE bool audioFlag(const QString& name);
    Q_INVOKABLE void setAudioFlag(const QString& name, bool value);

    // 10 band equalizer ("equalizer" audio filter)
    Q_INVOKABLE QStringList equalizerPresetNames() const;
    Q_INVOKABLE QVariantList equalizerPresetBands(int preset) const;
    // the preset's icon exported from Figma (RdIcon name, "eq_eq-rock"), empty when it has none
    Q_INVOKABLE QString equalizerPresetIcon(int preset) const;
    Q_INVOKABLE QStringList equalizerBandNames() const;
    Q_INVOKABLE int equalizerPreset();                 // -1: off ("None")
    Q_INVOKABLE void setEqualizerPreset(int preset);   // -1 disables the equalizer
    Q_INVOKABLE QVariantList equalizerBands();
    Q_INVOKABLE void setEqualizerBand(int band, double gain);

    // video filters: live on the video output, kept in "video-filter" / "sub-source" / ...
    Q_INVOKABLE bool videoFilterEnabled(const QString& module);
    Q_INVOKABLE void setVideoFilterEnabled(const QString& module, bool enabled);
    Q_INVOKABLE QVariant videoValue(const QString& name);
    Q_INVOKABLE void setVideoValue(const QString& name, const QVariant& value);
    // re-applies a filter whose options are read when it starts (e.g. transform-type)
    Q_INVOKABLE void restartVideoFilter(const QString& module);

    // subtitle text size in percent (live, "sub-text-scale")
    Q_INVOKABLE int subtitleTextScale();
    Q_INVOKABLE void setSubtitleTextScale(int percent);

    // subtitle duration factor ("subsdelay" sub filter, 0 disables it)
    Q_INVOKABLE double subtitleDurationFactor();
    Q_INVOKABLE void setSubtitleDurationFactor(double factor);

signals:
    void changed();

private:
    // cache
    QString ensure(const QString& key);
    void readKeys(const QStringList& keys);
    QVariant readKey(const QString& key, vout_thread_t* vout, audio_output_t* aout);
    bool store(const QString& key, const QVariant& value);
    void setCached(const QString& key, const QVariant& value);
    void touch(const QString& key);
    void touchIfCached(const QString& key);

    // values as VLC has them (vout / aout may be null)
    QString configString(const char* name) const;
    QVariant configValue(const char* name) const;
    QString audioChain(audio_output_t* aout) const;
    QString videoChain(const QString& type, vout_thread_t* vout) const;
    QString videoFilterType(const QString& module) const;
    int readEqualizerPreset(audio_output_t* aout) const;
    QVariantList readEqualizerBands(audio_output_t* aout) const;
    bool readVideoFilterEnabled(const QString& module, vout_thread_t* vout) const;
    QVariant readVideoValue(const QString& name, vout_thread_t* vout) const;

    // changes reach VLC on the next apply, at most one per frame
    void schedule(const QString& id, std::function<void()> apply);
    void runPending();
    void applyPending();
    void putConfig(const char* name, const QVariant& value);
    void applyVideoFilter(const QString& module, const QString& type, bool enabled);

    // configuration file, written on a worker thread
    void save();
    void onSaved();

    qt_intf_t* m_intf = nullptr;
    PlayerController* m_player = nullptr;
    QQmlPropertyMap* m_values = nullptr;
    int m_revision = 0;
    mutable QHash<QString, QString> m_filterTypes;

    QList<QPair<QString, std::function<void()>>> m_pending;
    QSet<QString> m_touched;
    QTimer m_applyTimer;
    QElapsedTimer m_lastApply;

    QTimer m_saveTimer;
    QThreadPool m_savePool;
    bool m_saving = false;
    bool m_saveAgain = false;
    // string options written while the file is being saved (config_PutPsz would wait for it)
    QHash<QByteArray, QString> m_pendingStrings;
};

#endif // RD_EFFECTS_HPP
