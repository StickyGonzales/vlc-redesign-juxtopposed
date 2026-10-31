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
#ifndef RD_UPDATE_CHECK_HPP
#define RD_UPDATE_CHECK_HPP

#include <QObject>
#include <QString>

#include <memory>

#include "qt.hpp"

/**
 * redesign: Cone's update notice (redesign/UPDATE_NOTICE_NOTES.md). Public brand only: VLC's
 * own update checker (src/misc/update.c, videolan.org) is never built into Cone, and in the
 * vlc profile this object stays idle.
 *
 * At most once a day, a few seconds after the start, while the "qt-cone-update-check" option is
 * on and the first-run privacy question has been answered, it asks GitHub for the latest release
 * of Cone (one GET of the releases API, no data beyond the request itself). A newer version
 * than this build's shows the notice (RdUpdateNotice.qml): "Download" opens the release page in
 * the browser, "Later" hides it until the next day. Nothing is downloaded or installed.
 * "Check now" (Settings > General) asks at once and reports the result.
 */
class RdUpdateCheck : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool supported READ supported CONSTANT FINAL)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged FINAL)
    Q_PROPERTY(bool noticeVisible READ noticeVisible NOTIFY noticeVisibleChanged FINAL)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY statusChanged FINAL)
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT FINAL)

public:
    enum Status
    {
        Unchecked,
        Checking,
        UpToDate,
        UpdateAvailable,
        CheckFailed
    };
    Q_ENUM(Status)

    RdUpdateCheck(qt_intf_t* intf, QObject* parent = nullptr);
    ~RdUpdateCheck() override;

    bool supported() const;
    Status status() const { return m_status; }
    bool noticeVisible() const { return m_noticeVisible; }
    QString latestVersion() const { return m_latestVersion; }
    QString currentVersion() const;

    // "Check now": asks at once, whatever the option and the day
    Q_INVOKABLE void checkNow();
    // the notice's buttons: both hide it until the next day; download opens the release page
    Q_INVOKABLE void download();
    Q_INVOKABLE void later();

signals:
    void statusChanged();
    void noticeVisibleChanged();

private:
    struct Job;

    void startupCheck();
    void request(bool explicitCheck);
    void onReply(int httpStatus, const QByteArray& body);
    void setStatus(Status status);
    void setNoticeVisible(bool visible);
    void dismissForToday();

    qt_intf_t* m_intf;
    Status m_status = Unchecked;
    bool m_noticeVisible = false;
    QString m_latestVersion;
    QString m_releasePage;
    // the running request answers "Check now": its result is reported
    bool m_explicitCheck = false;
    std::shared_ptr<Job> m_job;
};

#endif // RD_UPDATE_CHECK_HPP
