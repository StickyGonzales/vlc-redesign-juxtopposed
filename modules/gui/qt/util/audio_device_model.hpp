/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

#ifndef AUDIO_DEVICE_MODEL_HPP
#define AUDIO_DEVICE_MODEL_HPP

#include <QAbstractListModel>

#include <memory>

#include "qt.hpp"

class RdStereoTest;

extern "C" {
    typedef struct vlc_player_aout_listener_id vlc_player_aout_listener_id;
    typedef struct audio_output audio_output_t;
    typedef struct vlc_player_t vlc_player_t;
}

class AudioDeviceModel : public QAbstractListModel
{
    Q_OBJECT

    // redesign: the id of the device the output plays on ("" = the system default)
    Q_PROPERTY(QString current READ current NOTIFY currentChanged FINAL)

public:
    AudioDeviceModel(vlc_player_t *player, QObject *parent = nullptr);

    ~AudioDeviceModel();

    Qt::ItemFlags flags(const QModelIndex &) const  override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    bool setData(const QModelIndex &index, const QVariant &value, int role = Qt::EditRole) override;

    void updateCurrent(QString current);

    QHash<int, QByteArray> roleNames() const override;

    // redesign: re-read the output devices (refresh button of the tracks popup, video 4:41)
    Q_INVOKABLE void refresh();

    // redesign: the devices as [{ value: id, text: name }] for the Settings dialog's "Output
    // device" dropdown (Figma "Settings - audio"); the default device has an empty id
    Q_INVOKABLE QVariantList devices() const;

    // redesign: switches the output to the device `id` (one of devices()); false when the
    // output did not take it
    Q_INVOKABLE bool select(const QString &id);

    // redesign: plays the test sound of the settings sidebar's Stereo Mode "Test" button
    // (RdStereoTest) on the device in use, with the playing file's stereo mode
    Q_INVOKABLE void playStereoTest();

    QString current() const { return m_current; }

signals:
    void currentChanged();

private:
    int m_inputs = 0;
    char **m_names = nullptr;
    char **m_ids = nullptr;
    QString m_current;
    vlc_player_aout_listener_id* m_player_aout_listener = nullptr;
    audio_output_t* m_aout = nullptr;
    vlc_player_t *m_player;
    std::unique_ptr<RdStereoTest> m_stereoTest;
};

#endif // AUDIO_DEVICE_MODEL_HPP
