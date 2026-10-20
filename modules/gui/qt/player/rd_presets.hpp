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

#ifndef RD_PRESETS_HPP
#define RD_PRESETS_HPP

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QThreadPool>
#include <QTimer>
#include <QVariant>
#include <QVector>

#include "qt.hpp"

class PlayerController;
class RdEffects;

/**
 * redesign (W4.7, Decisions 18 and 25; video 7:52-8:56, Figma "Setting Preset"): per-show
 * presets of the settings sidebar, a QML singleton ("RdPresets").
 *
 * A preset holds every setting of the sidebar's four tabs that belongs to a show: subtitle
 * delay, speed, duration, font, colors, outline, size, position and default track or language;
 * audio delay, stereo mode, default track or language, the equalizer and the audio filters; the
 * video transforms, zoom, aspect ratio, crop and video filters; the playback speed and audio
 * visualizer. The list is `entries()` in the .cpp.
 *
 * One preset is selected at a time. Selecting one applies its values at once, only the ones
 * that differ, through the same calls the sidebar tabs make (RdEffects, the player), so nothing
 * waits on VLC. While a preset is selected, the changes made in the sidebar (and anywhere else:
 * hotkeys, the Settings dialog) are kept in it: it always holds what the show was last watched
 * with. "Default Preset" is the one that always exists.
 *
 * A preset can be tied to the folder of the media playing ("Use for This Folder"): a video of
 * that folder, or of a folder inside it, selects the preset when it starts, so the next
 * episode comes back with the show's settings. The values that belong to one file (delays,
 * speed, zoom ...) are applied again to every file that starts.
 *
 * Kept as JSON in VLC's user data folder, read and written on worker threads.
 */
class RdPresets : public QObject
{
    Q_OBJECT

    // [{ id, name, builtin, linked }], "Default Preset" last
    Q_PROPERTY(QVariantList presets READ presets NOTIFY presetsChanged FINAL)
    Q_PROPERTY(QString currentId READ currentId NOTIFY currentChanged FINAL)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentChanged FINAL)
    // the media playing is a local file, so a preset can be tied to its folder
    Q_PROPERTY(bool folderAvailable READ folderAvailable NOTIFY folderChanged FINAL)
    // the folder of the media playing, as shown ("The Wand / S01")
    Q_PROPERTY(QString folderName READ folderName NOTIFY folderChanged FINAL)

public:
    RdPresets(qt_intf_t* intf, RdEffects* effects, QObject* parent = nullptr);
    ~RdPresets() override;

    QVariantList presets() const;
    QString currentId() const { return m_currentId; }
    QString currentName() const;
    bool folderAvailable() const { return !m_folder.isEmpty(); }
    QString folderName() const;

    // applies a preset and selects it
    Q_INVOKABLE void select(const QString& id);
    // a new preset with the current settings, selected; returns its id
    Q_INVOKABLE QString create();
    Q_INVOKABLE void rename(const QString& id, const QString& name);
    // a copy of a preset ("Anime Copy"), not selected; returns its id
    Q_INVOKABLE QString duplicate(const QString& id);
    // deleting the selected preset selects "Default Preset"
    Q_INVOKABLE void remove(const QString& id);
    // ties a preset to the folder of the media playing (and unties the folder from the others)
    Q_INVOKABLE void setLinked(const QString& id, bool linked);

signals:
    void presetsChanged();
    void currentChanged();
    void folderChanged();

private:
    struct Preset
    {
        QString id;
        QString name;
        QJsonObject values;
        // folders (local paths) whose media select this preset
        QStringList folders;
    };

    Preset* find(const QString& id);
    const Preset* find(const QString& id) const;
    QString uniqueName(const QString& base) const;
    QString newId() const;

    // the settings as they are now, and applying stored ones (only those that differ)
    QJsonObject capture() const;
    // "Default Preset" also puts the delays of the file back to 0, except with `listsOnly`: then
    // only the values an output keeps (its lists: zoom, crop, stereo mode, visualizer ...; the
    // crop margins) go out
    void apply(const Preset& preset, bool perFileOnly, bool listsOnly = false);
    void scheduleCapture();
    void captureIntoCurrent();

    void onInputChanged(bool hasInput);
    void onPlayingStateChanged();
    // a video or audio output appeared: its lists (zoom, crop, stereo mode ...) and the crop
    // margins can take values
    void applyToOutputs();
    // the preset tied to `folder` or to the closest folder above it, empty when none
    QString linkedPreset(const QString& folder) const;

    void load(const QJsonObject& data);
    QJsonObject serialize() const;
    void save();

    qt_intf_t* m_intf;
    RdEffects* m_effects;
    PlayerController* m_player;

    QVector<Preset> m_presets;
    QString m_currentId;
    bool m_loaded = false;

    // the folder of the media playing (local path), empty for other media
    QString m_folder;
    // a media started: its values are applied once it plays
    bool m_pendingApply = false;
    // no capture while a new media resets its values or while a preset is applied
    bool m_captureBlocked = false;

    // changes are kept in the selected preset once they settle
    QTimer m_captureTimer;
    QTimer m_outputsTimer;
    QThreadPool m_storePool;
};

#endif // RD_PRESETS_HPP
