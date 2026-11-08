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

#include "rd_credits_scans.hpp"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QPointer>
#include <QThread>

#include <algorithm>

#include <vlc_url.h>

#ifdef _WIN32
# include <windows.h>
#endif

#include "qt.hpp"
#include "player/rd_credits_audio.hpp"
#include "player/rd_credits_point.hpp"
#include "player/rd_credits_scanner.hpp"
#include "player/rd_credits_subtitles.hpp"

namespace {

// the files kept in the cache (the oldest seen go first)
constexpr int kMaxFiles = 400;
// the episode lengths a show's usual length is the median of
constexpr int kKeptLengths = 9;
// the fingerprints of full scans kept per show while it has no credits music yet
constexpr int kMaxPrintsPerShow = 3;
// how long a read may take
constexpr int kFullBudgetSeconds = 120;
constexpr int kQuickBudgetSeconds = 30;

bool batterySaver()
{
#ifdef _WIN32
    SYSTEM_POWER_STATUS status;
    return GetSystemPowerStatus(&status) && (status.SystemStatusFlag & SYSTEM_STATUS_FLAG_POWER_SAVING_ON);
#else
    return false;
#endif
}

QString normalized(const QString& path)
{
    const QString clean = QDir::cleanPath(QDir::fromNativeSeparators(path));
#ifdef _WIN32
    return clean.toLower();
#else
    return clean;
#endif
}

QByteArray mrlOf(const QString& path)
{
    char* uri = vlc_path2uri(QDir::toNativeSeparators(path).toUtf8().constData(), "file");
    if (!uri)
        return {};
    const QByteArray mrl(uri);
    free(uri);
    return mrl;
}

QString printsToBase64(const std::vector<uint32_t>& prints)
{
    QByteArray bytes;
    bytes.reserve(int(prints.size() * 4));
    for (uint32_t v : prints)
    {
        const char b[4] = { char(v & 0xff), char((v >> 8) & 0xff), char((v >> 16) & 0xff), char(v >> 24) };
        bytes.append(b, 4);
    }
    return QString::fromLatin1(bytes.toBase64());
}

std::vector<uint32_t> printsFromBase64(const QString& text)
{
    const QByteArray bytes = QByteArray::fromBase64(text.toLatin1());
    std::vector<uint32_t> prints(size_t(bytes.size() / 4));
    for (size_t i = 0; i < prints.size(); ++i)
    {
        const auto* b = reinterpret_cast<const uchar*>(bytes.constData() + i * 4);
        prints[i] = uint32_t(b[0]) | uint32_t(b[1]) << 8 | uint32_t(b[2]) << 16 | uint32_t(b[3]) << 24;
    }
    return prints;
}

qint64 msAt(qint64 fromMs, int index)
{
    return fromMs + qint64(index) * rdcredits::kPrintMs;
}

} // namespace

// a full scan's fingerprint of another episode of the show
struct RdCreditsScans::OtherPrints
{
    QString fileKey;
    qint64 fromMs = 0;
    std::vector<uint32_t> prints;
};

struct RdCreditsScans::Outcome
{
    bool ok = false;
    QString reason;
    // the reason may not hold next time: the file is tried again in a later session
    bool transient = false;
    qint64 lengthMs = -1;
    bool full = false;
    bool quickMissed = false;
    qint64 audioMs = -1;
    qint64 blackMs = -1;
    qint64 dialogueEndMs = -1;
    std::vector<uint32_t> prints;
    qint64 printsFromMs = 0;
    // the credits music matched in another episode's fingerprint (a full scan of each)
    QString pairedKey;
    qint64 pairedAudioMs = -1;
    // the show's credits music, from this episode, when it was found by the pairing
    std::vector<uint32_t> music;
};

RdCreditsScans::RdCreditsScans(vlc_object_t* parent, QObject* parentObject)
    : QObject(parentObject)
    , m_parent(parent)
    , m_paused(std::make_shared<std::atomic<bool>>(false))
{
    m_pool.setMaxThreadCount(1);
    // a scan never keeps a thread around
    m_pool.setExpiryTimeout(1000);
}

RdCreditsScans::~RdCreditsScans()
{
    shutdown();
}

QString RdCreditsScans::fileKey(const QString& path)
{
    // the same file: its path, size and last change (a replaced episode is scanned again)
    const QFileInfo info(path);
    return normalized(path) + QLatin1Char('|') + QString::number(info.size()) + QLatin1Char('|')
           + QString::number(info.lastModified().toMSecsSinceEpoch());
}

qint64 RdCreditsScans::usualLength(const ShowInfo& show)
{
    if (show.lengths.isEmpty())
        return -1;
    QVector<qint64> sorted = show.lengths;
    std::sort(sorted.begin(), sorted.end());
    return sorted.at(sorted.size() / 2);
}

void RdCreditsScans::request(const QString& showKey, const QString& showName, const QString& path,
                             const QStringList& slaves, bool first)
{
    if (m_shutdown || showKey.isEmpty() || path.isEmpty())
        return;
    const QString key = fileKey(path);
    if (m_skipped.contains(key))
        return;
    const auto file = m_files.find(key);
    if (file != m_files.end())
    {
        file->seenAt = QDateTime::currentMSecsSinceEpoch();
        return;
    }
    for (const Request& queued : m_queue)
    {
        if (normalized(queued.path) == normalized(path))
            return;
    }
    if (first)
        m_queue.push_front({ showKey, showName, path, slaves });
    else
        m_queue.push_back({ showKey, showName, path, slaves });
    startNext();
}

RdCreditsScans::Found RdCreditsScans::found(const QString& path) const
{
    Found result;
    const auto file = m_files.constFind(fileKey(path));
    if (file == m_files.constEnd())
        return result;
    result.scanned = true;
    result.audioMs = file->audioMs;
    result.blackMs = file->blackMs;
    result.dialogueEndMs = file->dialogueEndMs;
    return result;
}

qint64 RdCreditsScans::fixedLead(const QString& showKey) const
{
    const auto show = m_shows.constFind(showKey);
    return show != m_shows.constEnd() ? show->fixedLeadMs : -1;
}

void RdCreditsScans::setFixedLead(const QString& showKey, const QString& showName, qint64 leadMs)
{
    if (showKey.isEmpty())
        return;
    ShowInfo& show = m_shows[showKey];
    const qint64 lead = leadMs > 0 ? leadMs : -1;
    if (!showName.isEmpty())
        show.name = showName;
    if (show.fixedLeadMs == lead)
        return;
    show.fixedLeadMs = lead;
    emit changed();
}

int RdCreditsScans::fixedCount() const
{
    int count = 0;
    for (const ShowInfo& show : m_shows)
        count += show.fixedLeadMs > 0 ? 1 : 0;
    return count;
}

QStringList RdCreditsScans::fixedShows() const
{
    QStringList shows;
    for (auto it = m_shows.cbegin(); it != m_shows.cend(); ++it)
    {
        if (it->fixedLeadMs > 0)
            shows.append(it.key());
    }
    return shows;
}

void RdCreditsScans::setPaused(bool paused)
{
    m_paused->store(paused, std::memory_order_relaxed);
}

void RdCreditsScans::shutdown()
{
    m_shutdown = true;
    m_queue.clear();
    if (m_current)
        m_current->cancel();
    // the read stops at its next packet (its I/O is interrupted): this returns at once
    m_pool.waitForDone();
    m_current.reset();
}

void RdCreditsScans::stop()
{
    ++m_generation;
    m_queue.clear();
    if (m_current)
        m_current->cancel();
}

void RdCreditsScans::clear()
{
    stop();
    m_shows.clear();
    m_files.clear();
    m_skipped.clear();
    emit changed();
}

bool RdCreditsScans::hasData() const
{
    return !m_shows.isEmpty() || !m_files.isEmpty();
}

void RdCreditsScans::startNext()
{
    // nothing runs before the cache is read (a file in it is never scanned again)
    if (m_running || m_shutdown || !m_loaded || m_queue.empty())
        return;
    if (batterySaver())
    {
        // nothing runs on battery saver; what waits is asked again with the next request
        msg_Dbg(m_parent, "up next: credits scans wait (battery saver)");
        return;
    }
    const Request request = m_queue.front();
    m_queue.pop_front();
    const QString key = fileKey(request.path);
    if (m_files.contains(key) || m_skipped.contains(key) || !QFileInfo::exists(request.path))
    {
        startNext();
        return;
    }

    // what the worker needs of the show, copied: the merge on this thread changes the originals
    const ShowInfo show = m_shows.value(request.showKey);
    const qint64 usual = usualLength(show);
    std::vector<OtherPrints> others;
    for (auto it = m_files.cbegin(); it != m_files.cend(); ++it)
    {
        if (it->showKey == request.showKey && !it->prints.empty())
            others.push_back({ it.key(), it->printsFromMs, it->prints });
    }

    const QByteArray mrl = mrlOf(request.path);
    auto scanner = std::make_shared<RdCreditsScanner>(m_parent, mrl, m_paused);
    m_current = scanner;
    m_running = true;

    QPointer<RdCreditsScans> self(this);
    const int generation = m_generation;
    m_pool.start([self, request, key, show, usual, others, scanner, generation]() {
        // a background scan never takes time from playback
        QThread::currentThread()->setPriority(QThread::LowestPriority);
        const Outcome outcome = scan(*scanner, request, show, usual, others);
        QMetaObject::invokeMethod(self.data(), [self, request, key, outcome, generation]() {
            if (!self)
                return;
            self->m_running = false;
            self->m_current.reset();
            if (self->m_shutdown)
                return;
            // a result of before a Forget all or a stop is dropped
            if (generation == self->m_generation)
                self->merge(request, key, outcome);
            self->startNext();
        }, Qt::QueuedConnection);
    });
}

// on the worker thread: the quick check when the show's music is known and the length is the
// usual one, else (or on a miss) the full scan of the last 8 minutes
RdCreditsScans::Outcome RdCreditsScans::scan(RdCreditsScanner& scanner, const Request& request,
                                             const ShowInfo& show, qint64 usual,
                                             const std::vector<OtherPrints>& others)
{
    Outcome outcome;
    const bool hasMusic = !show.music.empty() && show.creditsLeadMs > 0;

    // 1. the quick check: audio only, 1 minute either side of where the music is expected
    const RdCreditsScanner::Result quick = scanner.run([&](qint64 lengthMs) {
        RdCreditsScanner::Plan plan;
        if (rdcredits::planScan(hasMusic, usual, lengthMs) != rdcredits::ScanKind::Quick)
            return plan;
        const qint64 expectedMs = lengthMs - show.creditsLeadMs;
        plan.read = true;
        plan.fromMs = std::max<qint64>(0, expectedMs - rdcredits::kQuickHalfMs);
        // the needle is the music's first seconds: they must fit after the latest start
        plan.toMs = expectedMs + rdcredits::kQuickHalfMs + rdcredits::kQuickMatchSeconds * 1000;
        plan.budgetSeconds = kQuickBudgetSeconds;
        return plan;
    });
    if (scanner.cancelled())
        return outcome;
    outcome.lengthMs = quick.lengthMs;
    if (quick.ok)
    {
        const int index = rdcredits::findMusic(quick.prints, show.music);
        if (index >= 0)
        {
            outcome.ok = true;
            outcome.audioMs = msAt(quick.plan.fromMs, index);
            return outcome;
        }
        outcome.quickMissed = true;
    }
    else if (quick.plan.read)
        outcome.quickMissed = true;
    else if (quick.lengthMs <= 0)
    {
        outcome.reason = QString::fromUtf8(quick.reason);
        outcome.transient = quick.transient;
        return outcome;
    }

    // 2. the full scan: the credits window, audio, key frames and an embedded text track (when
    // no subtitle file goes with the episode)
    QVector<rdcredits::Line> lines;
    {
        RdCreditsSubtitles files(nullptr, request.path, {}, request.slaves, outcome.lengthMs);
        lines = files.fromFiles();
    }
    const bool readSubtitles = lines.isEmpty();
    const RdCreditsScanner::Result full = scanner.run([&](qint64 lengthMs) {
        RdCreditsScanner::Plan plan;
        plan.read = true;
        plan.fromMs = rdcredits::windowStart(lengthMs);
        plan.toMs = lengthMs;
        plan.frames = true;
        plan.subtitles = readSubtitles;
        plan.budgetSeconds = kFullBudgetSeconds;
        return plan;
    });
    if (scanner.cancelled())
        return outcome;
    if (!full.ok)
    {
        outcome.reason = QString::fromUtf8(full.reason);
        outcome.transient = full.transient;
        return outcome;
    }
    outcome.ok = true;
    outcome.full = true;
    outcome.lengthMs = full.lengthMs;
    if (readSubtitles)
        lines = full.lines;
    outcome.dialogueEndMs = rdcredits::dialogueEnd(lines, full.lengthMs);
    outcome.blackMs = rdcredits::blackStart(full.frames);
    outcome.prints = full.prints;
    outcome.printsFromMs = full.plan.fromMs;

    // the credits music: the same music in another episode's end (the longest match), else the
    // show's kept music
    rdcredits::Match best;
    const OtherPrints* bestOther = nullptr;
    for (const OtherPrints& other : others)
    {
        if (scanner.cancelled())
            return outcome;
        const rdcredits::Match match = rdcredits::longestMatch(full.prints, other.prints);
        if (match.found && match.length > best.length)
        {
            best = match;
            bestOther = &other;
        }
    }
    if (bestOther)
    {
        outcome.audioMs = msAt(full.plan.fromMs, best.aStart);
        outcome.pairedKey = bestOther->fileKey;
        outcome.pairedAudioMs = msAt(bestOther->fromMs, best.bStart);
        const size_t from = size_t(best.aStart);
        const size_t count = std::min<size_t>(size_t(best.length),
                                              size_t(rdcredits::kKeptMusicSeconds * rdcredits::kPrintsPerSecond));
        outcome.music.assign(full.prints.begin() + from, full.prints.begin() + from + count);
    }
    else if (hasMusic)
    {
        const int index = rdcredits::findMusic(full.prints, show.music);
        if (index >= 0)
            outcome.audioMs = msAt(full.plan.fromMs, index);
    }
    return outcome;
}

void RdCreditsScans::merge(const Request& request, const QString& key, const Outcome& outcome)
{
    if (!outcome.ok)
    {
        // a file that cannot be read is not tried again this session (a cancel is, next time)
        msg_Dbg(m_parent, "up next: credits scan of an episode gave nothing (%s)", qtu(outcome.reason));
        if (outcome.reason.isEmpty())
            return;
        if (outcome.transient)
        {
            // not again this session, but in a later one (it may be slow today only)
            m_skipped.insert(key);
            return;
        }
        FileInfo& file = m_files[key];
        file.path = request.path;
        file.showKey = request.showKey;
        file.seenAt = QDateTime::currentMSecsSinceEpoch();
        emit changed();
        return;
    }
    ShowInfo& show = m_shows[request.showKey];
    if (!request.showName.isEmpty())
        show.name = request.showName;

    QString pairedPath;
    FileInfo& file = m_files[key];
    file.path = request.path;
    file.showKey = request.showKey;
    file.lengthMs = outcome.lengthMs;
    file.audioMs = outcome.audioMs;
    file.blackMs = outcome.blackMs;
    file.dialogueEndMs = outcome.dialogueEndMs;
    file.full = outcome.full;
    file.seenAt = QDateTime::currentMSecsSinceEpoch();

    if (outcome.lengthMs > 0)
    {
        show.lengths.append(outcome.lengthMs);
        while (show.lengths.size() > kKeptLengths)
            show.lengths.removeFirst();
    }
    if (!outcome.pairedKey.isEmpty())
    {
        // the other episode's credits start where the music starts in it
        const auto other = m_files.find(outcome.pairedKey);
        if (other != m_files.end() && other->audioMs < 0)
        {
            other->audioMs = outcome.pairedAudioMs;
            // the episode playing may be that one: its card takes the point now
            pairedPath = other->path;
        }
        show.music = outcome.music;
    }
    // the show's credits length follows its latest full scan that found the music
    if (outcome.full && outcome.audioMs >= 0 && outcome.lengthMs > 0)
        show.creditsLeadMs = outcome.lengthMs - outcome.audioMs;

    if (show.music.empty())
    {
        // kept to be matched with the next episode's end (a few per show)
        file.prints = outcome.prints;
        file.printsFromMs = outcome.printsFromMs;
        QVector<QString> kept;
        for (auto it = m_files.begin(); it != m_files.end(); ++it)
        {
            if (it->showKey == request.showKey && !it->prints.empty())
                kept.append(it.key());
        }
        std::sort(kept.begin(), kept.end(), [this](const QString& a, const QString& b) {
            return m_files.value(a).seenAt > m_files.value(b).seenAt;
        });
        for (int i = kMaxPrintsPerShow; i < kept.size(); ++i)
            m_files[kept.at(i)].prints.clear();
    }
    else
    {
        for (auto it = m_files.begin(); it != m_files.end(); ++it)
        {
            if (it->showKey == request.showKey)
                it->prints.clear();
        }
    }

    msg_Dbg(m_parent, "up next: credits %s of \"%s\", %lld ms: audio %lld, black %lld, dialogue end %lld ms%s",
            outcome.full ? (outcome.quickMissed ? "quick check missed, full scan" : "full scan") : "quick check",
            qtu(QFileInfo(request.path).fileName()), static_cast<long long>(outcome.lengthMs), static_cast<long long>(outcome.audioMs),
            static_cast<long long>(outcome.blackMs), static_cast<long long>(outcome.dialogueEndMs),
            outcome.pairedKey.isEmpty() ? "" : " (credits music matched with another episode)");
    prune();
    emit resultReady(request.path);
    if (!pairedPath.isEmpty())
        emit resultReady(pairedPath);
    emit changed();
}

void RdCreditsScans::prune()
{
    if (m_files.size() <= kMaxFiles)
        return;
    QVector<QPair<qint64, QString>> byAge;
    for (auto it = m_files.cbegin(); it != m_files.cend(); ++it)
        byAge.append({ it->seenAt, it.key() });
    std::sort(byAge.begin(), byAge.end());
    for (int i = 0; i < byAge.size() - kMaxFiles; ++i)
        m_files.remove(byAge.at(i).second);
}

QJsonObject RdCreditsScans::toJson() const
{
    QJsonObject shows;
    for (auto it = m_shows.cbegin(); it != m_shows.cend(); ++it)
    {
        QJsonObject entry;
        entry.insert(QStringLiteral("name"), it->name);
        if (it->creditsLeadMs > 0)
            entry.insert(QStringLiteral("creditsLeadMs"), it->creditsLeadMs);
        if (it->fixedLeadMs > 0)
            entry.insert(QStringLiteral("fixedLeadMs"), it->fixedLeadMs);
        if (!it->music.empty())
            entry.insert(QStringLiteral("music"), printsToBase64(it->music));
        QJsonArray lengths;
        for (qint64 length : it->lengths)
            lengths.append(length);
        entry.insert(QStringLiteral("lengths"), lengths);
        shows.insert(it.key(), entry);
    }
    QJsonObject files;
    for (auto it = m_files.cbegin(); it != m_files.cend(); ++it)
    {
        QJsonObject entry;
        entry.insert(QStringLiteral("show"), it->showKey);
        entry.insert(QStringLiteral("lengthMs"), it->lengthMs);
        entry.insert(QStringLiteral("audioMs"), it->audioMs);
        entry.insert(QStringLiteral("blackMs"), it->blackMs);
        entry.insert(QStringLiteral("dialogueEndMs"), it->dialogueEndMs);
        entry.insert(QStringLiteral("full"), it->full);
        entry.insert(QStringLiteral("seenAt"), it->seenAt);
        if (!it->prints.empty())
        {
            entry.insert(QStringLiteral("prints"), printsToBase64(it->prints));
            entry.insert(QStringLiteral("printsFromMs"), it->printsFromMs);
        }
        files.insert(it.key(), entry);
    }
    QJsonObject root;
    root.insert(QStringLiteral("shows"), shows);
    root.insert(QStringLiteral("files"), files);
    return root;
}

void RdCreditsScans::load(const QJsonObject& data)
{
    const QJsonObject shows = data.value(QStringLiteral("shows")).toObject();
    for (auto it = shows.begin(); it != shows.end(); ++it)
    {
        const QJsonObject entry = it.value().toObject();
        ShowInfo show;
        show.name = entry.value(QStringLiteral("name")).toString();
        show.creditsLeadMs = entry.value(QStringLiteral("creditsLeadMs")).toInteger(-1);
        show.fixedLeadMs = entry.value(QStringLiteral("fixedLeadMs")).toInteger(-1);
        show.music = printsFromBase64(entry.value(QStringLiteral("music")).toString());
        for (const QJsonValue& length : entry.value(QStringLiteral("lengths")).toArray())
        {
            if (length.toInteger() > 0)
                show.lengths.append(length.toInteger());
        }
        // a Fixed point set (or reset) while the file was read wins; the rest comes from the file
        const auto set = m_shows.constFind(it.key());
        if (set != m_shows.constEnd())
        {
            show.fixedLeadMs = set->fixedLeadMs;
            if (!set->name.isEmpty())
                show.name = set->name;
        }
        m_shows.insert(it.key(), show);
    }
    const QJsonObject files = data.value(QStringLiteral("files")).toObject();
    for (auto it = files.begin(); it != files.end(); ++it)
    {
        if (m_files.contains(it.key()))
            continue;
        const QJsonObject entry = it.value().toObject();
        FileInfo file;
        file.showKey = entry.value(QStringLiteral("show")).toString();
        file.path = it.key().section(QLatin1Char('|'), 0, 0);
        file.lengthMs = entry.value(QStringLiteral("lengthMs")).toInteger(-1);
        file.audioMs = entry.value(QStringLiteral("audioMs")).toInteger(-1);
        file.blackMs = entry.value(QStringLiteral("blackMs")).toInteger(-1);
        file.dialogueEndMs = entry.value(QStringLiteral("dialogueEndMs")).toInteger(-1);
        file.full = entry.value(QStringLiteral("full")).toBool();
        file.seenAt = entry.value(QStringLiteral("seenAt")).toInteger(0);
        file.prints = printsFromBase64(entry.value(QStringLiteral("prints")).toString());
        file.printsFromMs = entry.value(QStringLiteral("printsFromMs")).toInteger(0);
        m_files.insert(it.key(), file);
    }
    prune();
    m_loaded = true;
    startNext();
}
