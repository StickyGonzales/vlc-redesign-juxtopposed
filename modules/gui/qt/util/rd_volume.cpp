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
        const QString name = QString::fromUtf8(device).isEmpty() ? QString::fromStdWString(root)
                                                                 : QString::fromUtf8(device);
        info.id = QStringLiteral("net:") + QDir::fromNativeSeparators(name).toLower();
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
