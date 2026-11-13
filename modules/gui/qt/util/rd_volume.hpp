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
#ifndef RD_VOLUME_HPP
#define RD_VOLUME_HPP

// The drive a path is on, identified by the volume itself (redesign/STORAGE_CLEANUP_NOTES.md):
// - Windows: the volume GUID ("\\?\Volume{...}\"), else its serial number; a network share
//   by its server and share name
// - Linux: the file system's UUID (/dev/disk/by-uuid), else its device
// - macOS: the volume UUID, else its device
// never by a drive letter or a mount folder. Every call that touches a drive answers within a
// short time: a network share (or a sleeping drive) that does not answer counts as not there.
// Worker threads only.
#include "rd_storage_model.hpp"

#include <QString>

namespace rdvolume {

struct Info
{
    // empty when unknown or not answered
    QString id;
    // where the volume is mounted now ("E:/", "/media/usb")
    QString root;
    bool network = false;
};

// the volume of an existing path; empty when it did not answer within `timeoutMs`
Info volumeOf(const QString& path, int timeoutMs = 2000);

// where the volume a path would be on is mounted, from the path and the system's mount table
// only: never touches the drive ("E:/", "//server/share/", "/media/usb", "/")
QString mountRootOf(const QString& path);

// the file system, for the cleanup's rules: every answer within `timeoutMs`
class SystemFileSystem : public rdstorage::FileSystem
{
public:
    explicit SystemFileSystem(int timeoutMs = 2000) : m_timeoutMs(timeoutMs) {}
    Answer exists(const QString& path) override;
    QString volumeOf(const QString& path) override;

private:
    int m_timeoutMs;
};

} // namespace rdvolume

#endif
