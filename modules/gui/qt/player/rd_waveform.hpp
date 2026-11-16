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
#ifndef RD_WAVEFORM_HPP
#define RD_WAVEFORM_HPP

#include <QByteArray>
#include <QElapsedTimer>
#include <QObject>
#include <QString>

#include <memory>

#include "qt.hpp"

class PlayerController;
class RdWaveformScanner;

/**
 * redesign: the waveform of the playing file, for the waveform seek bar (P6-06, IB-24; the
 * Playback tab's "Show Waveform on Seekbar").
 *
 * Nothing runs until a seek bar asks for it (acquire(), while the option is on). Then the
 * playing file's loudness profile is read from the cache, or scanned (RdWaveformScanner) as a
 * job of the background queue (RdBackgroundQueue: one job at a time, low priority, paused while
 * the user seeks), so playback and the UI never wait for it. A media change cancels the scan in
 * flight; so does the last seek bar letting go (release()). A scan ends on its own within
 * RdWaveformScanner::kTimeBudgetSeconds; quitting cancels it and the queue joins its thread.
 *
 * Only local files are scanned (a stream would be read a second time over the network), and
 * only once the player knows their duration.
 *
 * Cache: one small file per scanned file in `<VLC user data folder>/waveforms`, named after
 * the file's path, size and modification time (an edited file is scanned again). A file with
 * no usable audio is remembered too, so it is not scanned on every visit. At most
 * `kCacheMaxEntries` files are kept (about 1 KB each); the least recently used go first.
 */
class RdWaveform : public QObject
{
    Q_OBJECT

    // the playing file's levels are known
    Q_PROPERTY(bool ready READ ready NOTIFY levelsChanged FINAL)

public:
    static constexpr int kCacheMaxEntries = 2000;

    RdWaveform(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdWaveform() override;

    bool ready() const { return !m_levels.isEmpty(); }
    // the loudness of the file's slices, 0..255, the loudest slice 255 (empty: none)
    const QByteArray& levels() const { return m_levels; }

    // a seek bar shows the waveform (counted; the scan runs while one is held)
    void acquire();
    void release();

signals:
    void levelsChanged();

private:

    void onInputChanged();
    void startScan();
    void cancelScan();
    void setLevels(const QByteArray& levels);
    void onScanEnded(int generation, const QByteArray& levels, bool cached);

    qt_intf_t* m_intf = nullptr;
    PlayerController* m_player = nullptr;

    // the scan, a job of the background queue (RdBackgroundQueue)
    quint64 m_jobId = 0;
    QString m_cacheDir;

    int m_users = 0;

    QByteArray m_uri;
    vlc_tick_t m_length = 0;
    QByteArray m_levels;
    // the playing file was looked at (levels found, or none to find)
    bool m_done = false;

    // identifies the latest scan: results of older ones are dropped
    int m_generation = 0;
    std::shared_ptr<RdWaveformScanner> m_running;
    // the latest job's start, for the log
    QElapsedTimer m_scanClock;
};

#endif // RD_WAVEFORM_HPP
