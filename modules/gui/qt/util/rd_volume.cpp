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
#include "rd_volume.hpp"

#include <QDir>
#include <QFileInfo>
#include <QStorageInfo>

#include <chrono>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>

#ifdef _WIN32
# include <windows.h>
#endif
#ifdef __APPLE__
# include <sys/mount.h>
# include <sys/attr.h>
# include <unistd.h>
# include <uuid/uuid.h>
#endif

namespace rdvolume {

namespace {

// runs `work` on a thread of its own and waits at most `timeoutMs` for it; a call that does
// not answer in time (a share that is gone) is left to finish on its own
template <typename T>
bool withTimeout(int timeoutMs, std::function<T()> work, T* result)
{
    struct State
    {
        std::mutex mutex;
        std::condition_variable done;
        bool finished = false;
        T value{};
    };
    auto state = std::make_shared<State>();
    std::thread([state, work]() {
        T value = work();
        std::lock_guard<std::mutex> lock(state->mutex);
        state->value = std::move(value);
        state->finished = true;
        state->done.notify_all();
    }).detach();
    std::unique_lock<std::mutex> lock(state->mutex);
    if (!state->done.wait_for(lock, std::chrono::milliseconds(timeoutMs), [&]() { return state->finished; }))
        return false;
    *result = state->value;
    return true;
}

bool isNetworkType(const QByteArray& type)
{
    static const char* const types[] = { "nfs", "nfs4", "cifs", "smb3", "smbfs", "fuse.sshfs", "9p",
                                         "afpfs", "webdav", "davfs" };
    for (const char* name : types)
        if (type == name)
            return true;
    return false;
}

#ifdef __linux__
// the UUID of a block device, from /dev/disk/by-uuid
QString linuxUuid(const QString& device)
{
    const QString target = QFileInfo(device).canonicalFilePath();
    if (target.isEmpty())
        return {};
    const QDir dir(QStringLiteral("/dev/disk/by-uuid"));
    for (const QFileInfo& link : dir.entryInfoList(QDir::System | QDir::Files | QDir::NoDotAndDotDot))
        if (link.canonicalFilePath() == target)
            return link.fileName();
    return {};
}
#endif

#if defined(__APPLE__) && defined(ATTR_VOL_UUID)
QString macUuid(const QString& root)
{
    struct attrlist list{};
    list.bitmapcount = ATTR_BIT_MAP_COUNT;
    list.volattr = ATTR_VOL_INFO | ATTR_VOL_UUID;
    struct
    {
        u_int32_t length;
        uuid_t uuid;
    } __attribute__((aligned(4), packed)) buffer{};
    if (getattrlist(QFile::encodeName(root).constData(), &list, &buffer, sizeof(buffer), 0) != 0)
        return {};
    uuid_string_t text;
    uuid_unparse_upper(buffer.uuid, text);
    return QString::fromLatin1(text);
}
#endif

Info lookUp(const QString& path)
{
    Info info;
    const QStorageInfo storage(path);
    if (!storage.isValid())
        return info;
    info.root = QDir::fromNativeSeparators(storage.rootPath());
    const QByteArray device = storage.device();
    const QByteArray type = storage.fileSystemType();

#ifdef _WIN32
    const std::wstring root = QDir::toNativeSeparators(storage.rootPath()).toStdWString();
    const UINT driveType = GetDriveTypeW(root.c_str());
    if (driveType == DRIVE_REMOTE || root.rfind(L"\\\\", 0) == 0)
    {
        // a share: its server and share name (a mapped letter's own name may change)
        info.network = true;
        // its UNC name; a mapped letter with no name known: the share's serial number (never
        // the letter, which may name another share tomorrow)
        QString name = QString::fromUtf8(device);
        if (name.isEmpty() && root.rfind(L"\\\\", 0) == 0)
            name = QString::fromStdWString(root);
        if (!name.isEmpty())
        {
            info.id = QStringLiteral("net:") + QDir::fromNativeSeparators(name).toLower();
            return info;
        }
        DWORD serial = 0;
        if (GetVolumeInformationW(root.c_str(), nullptr, 0, &serial, nullptr, nullptr, nullptr, 0) && serial)
            info.id = QStringLiteral("netserial:") + QString::number(serial, 16);
        return info;
    }
    wchar_t guid[MAX_PATH] = {};
    if (GetVolumeNameForVolumeMountPointW(root.c_str(), guid, MAX_PATH))
    {
        info.id = QStringLiteral("vol:") + QString::fromWCharArray(guid).toLower();
        return info;
    }
    DWORD serial = 0;
    if (GetVolumeInformationW(root.c_str(), nullptr, 0, &serial, nullptr, nullptr, nullptr, 0))
        info.id = QStringLiteral("serial:") + QString::number(serial, 16);
    return info;
#else
    if (isNetworkType(type) || device.startsWith("//") || device.contains(":/"))
    {
        info.network = true;
        info.id = QStringLiteral("net:") + QString::fromUtf8(device);
        return info;
    }
# ifdef __linux__
    const QString uuid = linuxUuid(QString::fromUtf8(device));
    if (!uuid.isEmpty())
    {
        info.id = QStringLiteral("uuid:") + uuid;
        return info;
    }
# elif defined(__APPLE__) && defined(ATTR_VOL_UUID)
    const QString uuid = macUuid(storage.rootPath());
    if (!uuid.isEmpty())
    {
        info.id = QStringLiteral("uuid:") + uuid;
        return info;
    }
# endif
    // no UUID (a RAM disk, a container's overlay): the device and its type
    info.id = QStringLiteral("dev:") + QString::fromUtf8(device) + QLatin1Char(':') + QString::fromUtf8(type);
    return info;
#endif
}

} // namespace

QString mountRootOf(const QString& path)
{
    const QString clean = QDir::cleanPath(QDir::fromNativeSeparators(path));
#ifdef _WIN32
    // a drive letter or a share's server and name
    if (clean.size() >= 2 && clean.at(1) == QLatin1Char(':'))
        return clean.left(2).toUpper() + QLatin1Char('/');
    if (clean.startsWith(QLatin1String("//")))
    {
        const QStringList parts = clean.mid(2).split(QLatin1Char('/'));
        if (parts.size() >= 2)
            return QStringLiteral("//") + parts.at(0) + QLatin1Char('/') + parts.at(1) + QLatin1Char('/');
    }
    return {};
#else
    // the longest mount point above the path, from the mount table (no access to the drive)
    QStringList mounts;
# ifdef __linux__
    QFile table(QStringLiteral("/proc/self/mounts"));
    if (table.open(QIODevice::ReadOnly))
    {
        for (const QByteArray& line : table.readAll().split('\n'))
        {
            const QList<QByteArray> fields = line.split(' ');
            if (fields.size() < 2)
                continue;
            // spaces in a mount point are written as \040
            QByteArray point = fields.at(1);
            point.replace("\\040", " ");
            mounts.append(QString::fromUtf8(point));
        }
    }
# elif defined(__APPLE__)
    struct statfs* list = nullptr;
    const int count = getmntinfo(&list, MNT_NOWAIT);
    for (int i = 0; i < count; ++i)
        mounts.append(QString::fromUtf8(list[i].f_mntonname));
# endif
    QString best = QStringLiteral("/");
    for (const QString& point : mounts)
    {
        if (point.size() <= best.size())
            continue;
        if (clean == point || clean.startsWith(point.endsWith(QLatin1Char('/')) ? point : point + QLatin1Char('/')))
            best = point;
    }
    return best;
#endif
}

Info volumeOf(const QString& path, int timeoutMs)
{
    Info info;
    if (!withTimeout<Info>(timeoutMs, [path]() { return lookUp(path); }, &info))
        return {};
    return info;
}

rdstorage::FileSystem::Answer SystemFileSystem::exists(const QString& path)
{
    bool found = false;
    if (!withTimeout<bool>(m_timeoutMs, [path]() { return QFileInfo::exists(path); }, &found))
        return Answer::NoAnswer;
    return found ? Answer::Yes : Answer::No;
}

QString SystemFileSystem::volumeOf(const QString& path)
{
    return rdvolume::volumeOf(path, m_timeoutMs).id;
}

} // namespace rdvolume
