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

#include "rd_waveform.hpp"
#include "rd_waveform_scanner.hpp"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QSaveFile>
#include <QPointer>

#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_url.h>

#include "player/player_controller.hpp"
#include "util/rd_background_queue.hpp"
#include "util/rd_storage.hpp"

namespace {

// cache file: magic, version, slice count (16 bit little endian), the slices (0: no waveform)
const QByteArray kCacheMagic = QByteArrayLiteral("RDWF");
// 2: the full / sampled rule of 2026-10-16 (files scanned under the old one are scanned again)
constexpr char kCacheVersion = 2;
constexpr int kCacheHeaderSize = 7;

// named after the file's path, size and last change (RdStorage moves it with its show)
QString cachePath(const QString& dir, const QFileInfo& file)
{
    return RdStorage::waveformFile(dir, file);
}

// the cached levels (`found` false: not cached); a hit counts as a use for the eviction order
QByteArray readCache(const QString& path, bool* found)
{
    *found = false;
    QFile file(path);
    if (!file.exists())
        return {};
    const bool writable = file.open(QIODevice::ReadWrite);
    if (!writable && !file.open(QIODevice::ReadOnly))
        return {};

    const QByteArray data = file.read(kCacheHeaderSize + RdWaveformScanner::kBins + 1);
    if (data.size() < kCacheHeaderSize || !data.startsWith(kCacheMagic) || data[4] != kCacheVersion)
        return {};
    const int count = static_cast<uchar>(data[5]) | (static_cast<uchar>(data[6]) << 8);
    if (data.size() != kCacheHeaderSize + count)
        return {};

    if (writable)
        file.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);
    *found = true;
    return data.mid(kCacheHeaderSize);
}

void writeCache(const QString& dir, const QString& path, const QByteArray& levels)
{
    if (!QDir().mkpath(dir))
        return;

    QByteArray data = kCacheMagic;
    data += kCacheVersion;
    data += static_cast<char>(levels.size() & 0xff);
    data += static_cast<char>((levels.size() >> 8) & 0xff);
    data += levels;

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size() || !file.commit())
        return;

    // the cap: the least recently used files go (a read refreshes a file's time)
    const QFileInfoList entries = QDir(dir).entryInfoList({ QStringLiteral("*.wf") }, QDir::Files,
                                                          QDir::Time);
    for (qsizetype i = RdWaveform::kCacheMaxEntries; i < entries.size(); ++i)
        QFile::remove(entries[i].absoluteFilePath());
}

} // namespace


RdWaveform::RdWaveform(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
{

    if (char* dir = config_GetUserDir(VLC_USERDATA_DIR))
    {
        m_cacheDir = QString::fromUtf8(dir) + QStringLiteral("/waveforms");
        free(dir);
    }

    connect(m_player, &PlayerController::inputChanged, this, &RdWaveform::onInputChanged);
    connect(m_player, &PlayerController::lengthChanged, this, &RdWaveform::onInputChanged);
    onInputChanged();
}

RdWaveform::~RdWaveform()
{
    // a cancelled scan stops at its next packet or seek; a demuxer call in progress finishes
    // first (file reads are not interruptible on Windows). The background queue joins its
    // thread when the interface closes (it goes first), so no scan outlives libvlc
    cancelScan();
}

void RdWaveform::acquire()
{
    ++m_users;
    startScan();
}

void RdWaveform::release()
{
    if (m_users <= 0)
        return;
    if (--m_users == 0)
        // nobody shows it any more: no work for nothing (the next acquire() starts again)
        cancelScan();
}

void RdWaveform::onInputChanged()
{
    QByteArray uri;
    vlc_tick_t length = 0;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker locker{ player };
        if (input_item_t* item = vlc_player_GetCurrentMedia(player))
        {
            if (char* psz = input_item_GetURI(item))
            {
                uri = QByteArray(psz);
                free(psz);
            }
        }
        length = vlc_player_GetLength(player);
    }

    if (uri != m_uri)
    {
        cancelScan();
        m_uri = uri;
        m_done = false;
        setLevels({});
    }
    m_length = length;
    startScan();
}

void RdWaveform::startScan()
{
    if (m_users == 0 || m_done || m_running || m_length <= 0 || m_cacheDir.isEmpty()
        || !m_uri.startsWith("file://"))
        return;

    char* psz = vlc_uri2path(m_uri.constData());
    if (!psz)
        return;
    const QString path = QString::fromUtf8(psz);
    free(psz);

    // the scan's objects hang from the libvlc instance, which outlives the interface
    m_running = std::make_shared<RdWaveformScanner>(VLC_OBJECT(vlc_object_instance(m_intf)),
                                                    m_uri, m_length);
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (!queue)
        return;
    // a job of the background queue: one at a time with the others, paused while the user
    // seeks or a more urgent job runs, not in Cone's first minute. The cache first, then a
    // scan, whose result is cached
    const int generation = ++m_generation;
    std::shared_ptr<RdWaveformScanner> scanner = m_running;
    const QString cacheDir = m_cacheDir;
    auto levels = std::make_shared<QByteArray>();
    auto found = std::make_shared<bool>(false);
    auto cached = std::make_shared<QString>();
    QPointer<RdWaveform> self(this);
    m_jobId = queue->post(QStringLiteral("waveform"), RdBackgroundQueue::Weight::Heavy, RdBackgroundQueue::Normal,
        [scanner, path, cacheDir, levels, found, cached](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
            scanner->setControl(control);
            control->setCancelHook([scanner]() { scanner->cancel(); });
            const QFileInfo info(path);
            if (info.isFile() && !scanner->cancelled())
            {
                *cached = cachePath(cacheDir, info);
                *levels = readCache(*cached, found.get());
                if (!*found)
                {
                    *levels = scanner->run();
                    if (!scanner->cancelled())
                        writeCache(cacheDir, *cached, *levels);
                }
            }
            control->setCancelHook({});
        },
        [self, generation, scanner, levels, found, cached, path]() {
            if (!self || scanner->cancelled())
                return;
            self->onScanEnded(generation, *levels, *found);
            if (RdStorage* storage = RdStorage::instance(); storage && !levels->isEmpty() && !cached->isEmpty())
                storage->waveformUsed(*cached, path);
        }, true);
    m_scanClock.start();
    msg_Dbg(m_intf, "waveform: job queued for the playing file");
}

void RdWaveform::cancelScan()
{
    if (!m_running)
        return;
    m_running->cancel();
    m_running.reset();
    if (RdBackgroundQueue* queue = RdBackgroundQueue::instance(); queue && m_jobId)
        queue->cancel(m_jobId);
    m_jobId = 0;
    ++m_generation;
}

void RdWaveform::setLevels(const QByteArray& levels)
{
    if (levels == m_levels)
        return;
    m_levels = levels;
    emit levelsChanged();
}

void RdWaveform::onScanEnded(int generation, const QByteArray& levels, bool cached)
{
    if (generation != m_generation)
        return;
    m_running.reset();
    m_done = true;
    setLevels(levels);

    // "ready" for the PC measurements: from the start of the job to the bars' data
    msg_Dbg(m_intf, "waveform: %s %s, %lld ms after the job started",
            levels.isEmpty() ? "no waveform" : "ready", cached ? "from the cache" : "from the scan",
            static_cast<long long>(m_scanClock.elapsed()));
}
