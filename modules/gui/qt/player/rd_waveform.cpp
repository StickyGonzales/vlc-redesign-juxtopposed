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

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QRunnable>
#include <QSaveFile>
#include <QThread>

#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_url.h>

#include "player/player_controller.hpp"

namespace {

// cache file: magic, version, slice count (16 bit little endian), the slices (0: no waveform)
const QByteArray kCacheMagic = QByteArrayLiteral("RDWF");
// 2: the full / sampled rule of 2026-10-16 (files scanned under the old one are scanned again)
constexpr char kCacheVersion = 2;
constexpr int kCacheHeaderSize = 7;

QString cachePath(const QString& dir, const QFileInfo& file)
{
    QByteArray key = file.absoluteFilePath().toUtf8();
    key += '\n' + QByteArray::number(file.size());
    key += '\n' + QByteArray::number(file.lastModified().toMSecsSinceEpoch());
    return dir + QLatin1Char('/')
           + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex())
           + QStringLiteral(".wf");
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

/**
 * One look at a file, on the worker thread: the cache first, then a scan, whose result is
 * cached. A cancelled scan reports nothing.
 */
class RdWaveformJob : public QRunnable
{
public:
    RdWaveformJob(RdWaveform* owner, int generation, std::shared_ptr<RdWaveformScanner> scanner,
                  const QString& path, const QString& cacheDir)
        : m_owner(owner)
        , m_generation(generation)
        , m_scanner(std::move(scanner))
        , m_path(path)
        , m_cacheDir(cacheDir)
    {
    }

    void run() override
    {
        QByteArray levels;
        bool found = false;
        const QFileInfo info(m_path);
        if (info.isFile() && !m_scanner->cancelled())
        {
            const QString cached = cachePath(m_cacheDir, info);
            levels = readCache(cached, &found);
            if (!found)
            {
                levels = m_scanner->run();
                if (m_scanner->cancelled())
                    return;
                writeCache(m_cacheDir, cached, levels);
            }
        }
        if (m_scanner->cancelled())
            return;

        // the owner waits for this job before it goes (~RdWaveform)
        RdWaveform* owner = m_owner;
        const int generation = m_generation;
        QMetaObject::invokeMethod(owner, [owner, generation, levels, found]() {
            owner->onScanEnded(generation, levels, found);
        }, Qt::QueuedConnection);
    }

private:
    RdWaveform* m_owner;
    int m_generation;
    std::shared_ptr<RdWaveformScanner> m_scanner;
    QString m_path;
    QString m_cacheDir;
};

RdWaveform::RdWaveform(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
    , m_pool(std::make_unique<QThreadPool>())
{
    m_pool->setMaxThreadCount(1);
    m_pool->setThreadPriority(QThread::LowestPriority);

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
    cancelScan();
    // a cancelled scan stops at its next packet or seek; a demuxer call in progress finishes
    // first (file reads are not interruptible on Windows), which is one pass over the file at
    // most, as for the player's own input thread that libvlc joins at quit too. The worker is
    // always joined: one left running would still use VLC's modules and objects while libvlc
    // is torn down, and the process's end would cut it off in the middle
    m_pool->clear();
    if (!m_pool->waitForDone(kQuitWaitMs))
    {
        msg_Warn(m_intf, "waveform: the scan did not stop within %d ms, still waiting",
                 kQuitWaitMs);
        m_pool->waitForDone();
    }
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
    m_pool->start(new RdWaveformJob(this, ++m_generation, m_running, path, m_cacheDir));
    m_scanClock.start();
    msg_Dbg(m_intf, "waveform: job started for the playing file");
}

void RdWaveform::cancelScan()
{
    if (!m_running)
        return;
    m_running->cancel();
    m_running.reset();
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
