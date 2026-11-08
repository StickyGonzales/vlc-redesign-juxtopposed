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

#include "rd_update_check.hpp"

#include <QDate>
#include <QDesktopServices>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QRegularExpression>
#include <QSettings>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>

#include <vlc_interrupt.h>

#include "dialogs/redesign/addsubtitles/subtitle_web.hpp"

namespace {

#ifdef VLC_BRAND_PUBLIC
const QString settingsGroup = QStringLiteral("RdUpdateCheck/");
#ifdef Q_OS_LINUX
// Linux is released apart from Windows, as pre-releases tagged linux-vX.Y.Z[-label]
// (release-linux.yml), which /releases/latest never answers: the list of releases, newest first,
// of which the newest Linux one is offered (redesign/LINUX_UX_NOTES.md)
const QUrl latestReleaseApi(QStringLiteral(
    "https://api.github.com/repos/StickyGonzales/vlc-redesign-juxtopposed/releases?per_page=50"));
const QString releaseTagPrefix = QStringLiteral("linux-");
// the release page opened by "Download" must be on GitHub; this one lists every release, the
// Linux ones included
const QString releasesPage = QStringLiteral(
    "https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases");
#else
// the releases API answers with the newest release that is neither a draft nor a pre-release
const QUrl latestReleaseApi(QStringLiteral(
    "https://api.github.com/repos/StickyGonzales/vlc-redesign-juxtopposed/releases/latest"));
// the release page opened by "Download" must be on GitHub; this one lists every release
const QString releasesPage = QStringLiteral(
    "https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/latest");
#endif
const QString releasePagePrefix = QStringLiteral("https://github.com/");
// after the start, so the request never competes with opening the first file
constexpr int startupDelay = 4000;
// the request gives up after this long (a stalled connection or DNS lookup)
constexpr int requestTimeout = 15000;
// tests only: a file whose content stands for GitHub's answer (HTTP 200), so the notice can be
// tested on a real build without a server (redesign/UPDATE_SKIP_NOTES.md); unset in normal use
const char testAnswerVariable[] = "CONE_UPDATE_CHECK_TEST_FILE";

// "1.2.3" out of "1.2.3", "v1.2.3" or "v1.2.3-beta"; empty when there is none
QString versionOf(const QString& text)
{
    static const QRegularExpression pattern(QStringLiteral("(\\d+)\\.(\\d+)\\.(\\d+)"));
    const QRegularExpressionMatch match = pattern.match(text);
    return match.hasMatch() ? match.captured(0) : QString();
}

// true when `version` is newer than `current` (both "X.Y.Z")
bool isNewer(const QString& version, const QString& current)
{
    const QStringList a = version.split(QChar('.'));
    const QStringList b = current.split(QChar('.'));
    for (int i = 0; i < 3; ++i)
    {
        const int x = a.value(i).toInt();
        const int y = b.value(i).toInt();
        if (x != y)
            return x > y;
    }
    return false;
}

// the release to offer out of GitHub's answer; empty when it holds none
QJsonObject releaseOf(const QJsonDocument& answer)
{
#ifdef Q_OS_LINUX
    // the highest version among the Linux releases, pre-releases included (drafts are never
    // listed without a token); of equal versions the first, the newest
    QJsonObject newest;
    QString newestVersion;
    const QJsonArray releases = answer.array();
    for (const QJsonValue& value : releases)
    {
        const QJsonObject release = value.toObject();
        const QString tag = release.value(QStringLiteral("tag_name")).toString();
        if (release.value(QStringLiteral("draft")).toBool() || !tag.startsWith(releaseTagPrefix))
            continue;
        const QString version = versionOf(tag);
        if (version.isEmpty())
            continue;
        if (newestVersion.isEmpty() || isNewer(version, newestVersion))
        {
            newest = release;
            newestVersion = version;
        }
    }
    return newest;
#else
    return answer.object();
#endif
}
#endif

} // namespace

struct RdUpdateCheck::Job
{
    vlc_interrupt_t* interrupt = vlc_interrupt_create();
    QThreadPool pool;

    Job() { pool.setMaxThreadCount(1); }

    ~Job()
    {
        // the interface closes: the request must not keep it waiting on the network
        if (interrupt)
            vlc_interrupt_kill(interrupt);
        pool.waitForDone();
        if (interrupt)
            vlc_interrupt_destroy(interrupt);
    }
};

RdUpdateCheck::RdUpdateCheck(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
#ifdef VLC_BRAND_PUBLIC
    // a newer version found earlier and not yet dismissed today shows again without a request
    QSettings* settings = m_intf->mainSettings;
    const QString found = settings->value(settingsGroup + QStringLiteral("LatestVersion")).toString();
    if (isNewer(found, currentVersion()))
    {
        m_latestVersion = found;
        m_releasePage = settings->value(settingsGroup + QStringLiteral("ReleasePage")).toString();
    }
    m_skippedVersion = settings->value(settingsGroup + QStringLiteral("SkippedVersion")).toString();

    QTimer::singleShot(startupDelay, this, &RdUpdateCheck::startupCheck);
#else
    Q_UNUSED(m_intf);
    Q_UNUSED(m_explicitCheck);
#endif
}

RdUpdateCheck::~RdUpdateCheck() = default;

bool RdUpdateCheck::supported() const
{
#ifdef VLC_BRAND_PUBLIC
    return true;
#else
    return false;
#endif
}

QString RdUpdateCheck::currentVersion() const
{
#ifdef VLC_BRAND_PUBLIC
    return QStringLiteral(BRAND_VERSION);
#else
    return QString();
#endif
}

void RdUpdateCheck::startupCheck()
{
#ifdef VLC_BRAND_PUBLIC
    // the option, and VLC's rule for its own checker: nothing goes out before the first-run
    // privacy question has been answered
    if (!var_InheritBool(m_intf, "qt-cone-update-check") || var_InheritBool(m_intf, "qt-privacy-ask"))
        return;

    QSettings* settings = m_intf->mainSettings;
    const QDate today = QDate::currentDate();
    const bool dismissedToday = settings->value(settingsGroup + QStringLiteral("DismissedOn")).toDate() == today;

    // a skipped version waits silently: only a newer one (or "Check now") shows the notice
    if (!m_latestVersion.isEmpty() && !dismissedToday && m_latestVersion != m_skippedVersion)
    {
        setStatus(UpdateAvailable);
        setNoticeVisible(true);
    }

    // at most one request a day, counted from the attempt (a failed one included)
    if (settings->value(settingsGroup + QStringLiteral("CheckedOn")).toDate() == today)
        return;
    settings->setValue(settingsGroup + QStringLiteral("CheckedOn"), today);
    request(false);
#endif
}

void RdUpdateCheck::checkNow()
{
#ifdef VLC_BRAND_PUBLIC
    m_intf->mainSettings->setValue(settingsGroup + QStringLiteral("CheckedOn"), QDate::currentDate());
    request(true);
#endif
}

void RdUpdateCheck::request(bool explicitCheck)
{
#ifdef VLC_BRAND_PUBLIC
    if (explicitCheck)
    {
        m_explicitCheck = true;
        setStatus(Checking);
    }
    // a request already on its way answers "Check now" too
    if (m_job)
        return;

    const QString testFile = qEnvironmentVariable(testAnswerVariable);
    if (!testFile.isEmpty())
    {
        QFile file(testFile);
        const bool read = file.open(QIODevice::ReadOnly);
        const QByteArray body = read ? file.readAll() : QByteArray();
        msg_Dbg(m_intf, "update check: answer read from %s (test)", qtu(testFile));
        QTimer::singleShot(0, this, [this, read, body]() { onReply(read ? 200 : 0, body); });
        return;
    }

    auto job = std::make_shared<Job>();
    if (!job->interrupt)
    {
        onReply(0, {});
        return;
    }
    m_job = job;

    std::weak_ptr<Job> weak = job;
    QTimer::singleShot(requestTimeout, this, [weak]() {
        if (const std::shared_ptr<Job> running = weak.lock())
            vlc_interrupt_kill(running->interrupt);
    });

    QPointer<RdUpdateCheck> self(this);
    vlc_object_t* obj = VLC_OBJECT(m_intf);
    vlc_interrupt_t* interrupt = job->interrupt;
    job->pool.start([self, obj, interrupt]() {
        // only what the request itself carries: the address, a User-Agent (GitHub's API asks
        // for one) and the format of the answer
        const SubtitleWeb::Headers headers = {
            { QByteArrayLiteral("User-Agent"), QByteArrayLiteral("Cone-Player") },
            { QByteArrayLiteral("Accept"), QByteArrayLiteral("application/vnd.github+json") },
        };
        vlc_interrupt_t* previous = vlc_interrupt_set(interrupt);
        const SubtitleWeb::Reply reply = SubtitleWeb::request(obj, QByteArrayLiteral("GET"),
                                                              latestReleaseApi, headers);
        vlc_interrupt_set(previous);
        if (!reply.error.isEmpty())
            msg_Dbg(obj, "update check: %s", qtu(reply.error));

        QMetaObject::invokeMethod(self, [self, reply]() {
            if (self)
                self->onReply(reply.error.isEmpty() ? reply.status : 0, reply.body);
        }, Qt::QueuedConnection);
    });
#else
    Q_UNUSED(explicitCheck);
#endif
}

void RdUpdateCheck::onReply(int httpStatus, const QByteArray& body)
{
#ifdef VLC_BRAND_PUBLIC
    // the worker is done: its thread can go
    m_job.reset();
    const bool explicitCheck = m_explicitCheck;
    m_explicitCheck = false;

    const QJsonDocument answer = QJsonDocument::fromJson(body);
    const QJsonObject release = releaseOf(answer);

    // 404: GitHub has no release that is not a pre-release yet; on Linux, a list without a
    // Linux release: nothing newer either
    if (httpStatus == 404 || (httpStatus == 200 && answer.isArray() && release.isEmpty()))
    {
        msg_Dbg(m_intf, "update check: no release yet");
        setNoticeVisible(false);
        setStatus(UpToDate);
        return;
    }

    const QString version = versionOf(release.value(QStringLiteral("tag_name")).toString());
    if (httpStatus != 200 || version.isEmpty())
    {
        msg_Dbg(m_intf, "update check failed (HTTP %d)", httpStatus);
        // a failed check at the start stays silent; the notice of an earlier one stays as it is
        if (explicitCheck)
            setStatus(CheckFailed);
        return;
    }

    QSettings* settings = m_intf->mainSettings;
    if (!isNewer(version, currentVersion()))
    {
        msg_Dbg(m_intf, "update check: %s is the latest release", qtu(version));
        settings->remove(settingsGroup + QStringLiteral("LatestVersion"));
        settings->remove(settingsGroup + QStringLiteral("ReleasePage"));
        m_latestVersion.clear();
        m_releasePage.clear();
        // up to date: a version skipped earlier is installed or older now
        setSkippedVersion(QString());
        setNoticeVisible(false);
        setStatus(UpToDate);
        return;
    }

    msg_Dbg(m_intf, "update check: %s is available", qtu(version));
    const QString page = release.value(QStringLiteral("html_url")).toString();
    const bool changed = version != m_latestVersion;
    m_latestVersion = version;
    m_releasePage = page.startsWith(releasePagePrefix) ? page : releasesPage;
    settings->setValue(settingsGroup + QStringLiteral("LatestVersion"), m_latestVersion);
    settings->setValue(settingsGroup + QStringLiteral("ReleasePage"), m_releasePage);
    if (changed && m_status == UpdateAvailable)
        emit statusChanged();
    setStatus(UpdateAvailable);

    // a newer version than the skipped one ends the skip: only that exact version was skipped
    if (!m_skippedVersion.isEmpty() && isNewer(version, m_skippedVersion))
        setSkippedVersion(QString());

    // "Later" holds for the day and "Skip this version" for that version, except against
    // "Check now", which always shows the newest version
    const bool dismissedToday = settings->value(settingsGroup + QStringLiteral("DismissedOn")).toDate()
                                == QDate::currentDate();
    if (explicitCheck || (!dismissedToday && version != m_skippedVersion))
        setNoticeVisible(true);
#else
    Q_UNUSED(httpStatus);
    Q_UNUSED(body);
#endif
}

void RdUpdateCheck::download()
{
#ifdef VLC_BRAND_PUBLIC
    QDesktopServices::openUrl(QUrl(m_releasePage.isEmpty() ? releasesPage : m_releasePage));
    dismissForToday();
#endif
}

void RdUpdateCheck::later()
{
    dismissForToday();
}

void RdUpdateCheck::skipVersion()
{
#ifdef VLC_BRAND_PUBLIC
    if (!m_latestVersion.isEmpty())
        setSkippedVersion(m_latestVersion);
#endif
    setNoticeVisible(false);
}

void RdUpdateCheck::undoSkip()
{
#ifdef VLC_BRAND_PUBLIC
    setSkippedVersion(QString());
    // the version that was skipped is offered again at once
    if (m_status == UpdateAvailable && !m_latestVersion.isEmpty())
        setNoticeVisible(true);
#endif
}

void RdUpdateCheck::setSkippedVersion(const QString& version)
{
#ifdef VLC_BRAND_PUBLIC
    if (m_skippedVersion == version)
        return;
    m_skippedVersion = version;
    if (version.isEmpty())
        m_intf->mainSettings->remove(settingsGroup + QStringLiteral("SkippedVersion"));
    else
        m_intf->mainSettings->setValue(settingsGroup + QStringLiteral("SkippedVersion"), version);
    emit skippedVersionChanged();
#else
    Q_UNUSED(version);
#endif
}

void RdUpdateCheck::dismissForToday()
{
#ifdef VLC_BRAND_PUBLIC
    m_intf->mainSettings->setValue(settingsGroup + QStringLiteral("DismissedOn"), QDate::currentDate());
#endif
    setNoticeVisible(false);
}

void RdUpdateCheck::setStatus(Status status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}

void RdUpdateCheck::setNoticeVisible(bool visible)
{
    if (m_noticeVisible == visible)
        return;
    m_noticeVisible = visible;
    emit noticeVisibleChanged();
}
