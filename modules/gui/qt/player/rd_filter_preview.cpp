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

#include "rd_filter_preview.hpp"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QList>
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QPair>
#include <QPointer>
#include <QQuickImageProvider>
#include <QRunnable>
#include <QStringList>
#include <QThread>
#include <QTransform>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <utility>

#include <vlc_common.h>
#include <vlc_image.h>
#include <vlc_input_item.h>
#include <vlc_picture.h>
#include <vlc_player.h>
#include <vlc_preparser.h>

#include "player/player_controller.hpp"
#include "player/rd_filter_math.hpp"

namespace {

// previews kept for one frame (each new frame empties the cache). It must hold every preview
// shown at once: when one is evicted, the rows ask for it again, and its return evicts another,
// a loop that never ends. 256 previews of a preset row are about 4 MB.
constexpr int kCacheSize = 256;
// a stuck capture (slow disk, broken file) gives up after this long
constexpr vlc_tick_t kTimeout = VLC_TICK_FROM_SEC(3);
// a capture at about the same time as the last one reuses the frame (seconds)
constexpr double kSameFrameSec = 1.0;

struct Job
{
    RdFilterPreview* self;
    int generation;
    QSize box;
};

// the decoded frame, scaled to fit `box` with its display aspect and orientation, as RGBA
// (the conversion of the seek preview, rd_seek_thumbnailer.cpp)
QImage frameToImage(vlc_object_t* obj, picture_t* picture, const QSize& box)
{
    video_format_t fmtIn = picture->format;
    if (fmtIn.i_sar_num == 0 || fmtIn.i_sar_den == 0)
        fmtIn.i_sar_num = fmtIn.i_sar_den = 1;

    const unsigned visibleWidth = fmtIn.i_visible_width ? fmtIn.i_visible_width : fmtIn.i_width;
    const unsigned visibleHeight = fmtIn.i_visible_height ? fmtIn.i_visible_height : fmtIn.i_height;
    if (visibleWidth == 0 || visibleHeight == 0 || box.isEmpty())
        return {};

    const bool swap = ORIENT_IS_SWAP(fmtIn.orientation);
    double displayWidth = double(visibleWidth) * fmtIn.i_sar_num / fmtIn.i_sar_den;
    double displayHeight = visibleHeight;
    if (swap)
        std::swap(displayWidth, displayHeight);

    // cover the box (the preview is cut to its shape), so the frame is at least that big
    const double scale = std::max(box.width() / displayWidth, box.height() / displayHeight);
    const int outWidth = std::max(2, int(std::lround(displayWidth * scale)));
    const int outHeight = std::max(2, int(std::lround(displayHeight * scale)));
    const int storedWidth = swap ? outHeight : outWidth;
    const int storedHeight = swap ? outWidth : outHeight;

    video_format_t fmtOut;
    video_format_Init(&fmtOut, VLC_CODEC_RGBA);
    fmtOut.i_width = fmtOut.i_visible_width = storedWidth;
    fmtOut.i_height = fmtOut.i_visible_height = storedHeight;
    fmtOut.i_sar_num = fmtOut.i_sar_den = 1;
    fmtOut.orientation = fmtIn.orientation;

    QImage image;
    image_handler_t* handler = image_HandlerCreate(obj);
    if (!handler)
        return {};
    picture_t* rgba = image_Convert(handler, picture, &fmtIn, &fmtOut);
    if (rgba)
    {
        const plane_t& plane = rgba->p[0];
        const int rowBytes = storedWidth * 4;
        if (plane.i_pitch >= rowBytes && plane.i_visible_lines >= storedHeight)
        {
            image = QImage(storedWidth, storedHeight, QImage::Format_RGBA8888);
            for (int y = 0; y < storedHeight; ++y)
                memcpy(image.scanLine(y), plane.p_pixels + y * plane.i_pitch, rowBytes);
        }
        picture_Release(rgba);
    }
    image_HandlerDelete(handler);

    if (image.isNull())
        return image;

    switch (fmtIn.orientation)
    {
    case ORIENT_ROTATED_90:
        return image.transformed(QTransform().rotate(90));
    case ORIENT_ROTATED_180:
        return image.transformed(QTransform().rotate(180));
    case ORIENT_ROTATED_270:
        return image.transformed(QTransform().rotate(270));
    case ORIENT_HFLIPPED:
        return image.mirrored(true, false);
    case ORIENT_VFLIPPED:
        return image.mirrored(false, true);
    case ORIENT_TRANSPOSED:
        return image.transformed(QTransform().rotate(90)).mirrored(true, false);
    case ORIENT_ANTI_TRANSPOSED:
        return image.transformed(QTransform().rotate(90)).mirrored(false, true);
    default:
        return image;
    }
}

// the values in one canonical form (sorted keys), the cache key
QByteArray keyOf(const QVariantMap& values)
{
    const QByteArray json = QJsonDocument(QJsonObject::fromVariantMap(values)).toJson(QJsonDocument::Compact);
    return QCryptographicHash::hash(json, QCryptographicHash::Sha1).toHex();
}

} // namespace

// previews of the current frame, most recently used first; read by the image provider (any
// thread) and written by the preview object (UI thread)
struct RdFilterPreview::Cache
{
    QMutex lock;
    QList<QPair<QPair<int, QByteArray>, QImage>> images;

    QImage find(int generation, const QByteArray& key)
    {
        QMutexLocker locker(&lock);
        for (qsizetype i = 0; i < images.size(); ++i)
        {
            if (images[i].first.first == generation && images[i].first.second == key)
            {
                if (i > 0)
                    images.move(i, 0);
                return images.first().second;
            }
        }
        return {};
    }

    bool contains(int generation, const QByteArray& key)
    {
        QMutexLocker locker(&lock);
        return std::any_of(images.cbegin(), images.cend(), [&](const auto& entry) {
            return entry.first.first == generation && entry.first.second == key;
        });
    }

    void insert(int generation, const QByteArray& key, const QImage& image)
    {
        QMutexLocker locker(&lock);
        images.prepend(qMakePair(qMakePair(generation, key), image));
        while (images.size() > kCacheSize)
            images.removeLast();
    }

    void clear()
    {
        QMutexLocker locker(&lock);
        images.clear();
    }
};

namespace {

// "image://rdfilterpreview/<generation>/<key>": a preview of the cache (an empty image once it
// has left the cache; the row then shows its placeholder until the next revision)
class FilterPreviewProvider : public QQuickImageProvider
{
public:
    explicit FilterPreviewProvider(std::shared_ptr<RdFilterPreview::Cache> cache)
        : QQuickImageProvider(QQuickImageProvider::Image)
        , m_cache(std::move(cache))
    {
    }

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override
    {
        Q_UNUSED(requestedSize)
        QImage image;
        const QStringList parts = id.split(QLatin1Char('/'));
        if (parts.size() == 2)
            image = m_cache->find(parts[0].toInt(), parts[1].toLatin1());
        if (size)
            *size = image.size();
        return image;
    }

private:
    std::shared_ptr<RdFilterPreview::Cache> m_cache;
};

} // namespace

RdFilterPreview::RdFilterPreview(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
    , m_cache(std::make_shared<Cache>())
{
    // one worker, below the playback threads: a preview never takes time from the video
    m_pool.setMaxThreadCount(1);
    m_pool.setThreadPriority(QThread::LowestPriority);

    connect(m_player, &PlayerController::inputChanged, this, &RdFilterPreview::onInputChanged);
    connect(m_player, &PlayerController::lengthChanged, this, &RdFilterPreview::onInputChanged);
    onInputChanged();
}

RdFilterPreview::~RdFilterPreview()
{
    // ends the thumbnailer thread; the callback of the capture in flight runs before this
    // returns, and its result (queued to this object) is dropped with it
    if (m_preparser)
        vlc_preparser_Delete(m_preparser);
    if (m_inflight)
        vlc_preparser_req_Release(m_inflight);
    // the jobs only post to this object through a QPointer: let the running one finish
    m_pool.clear();
    m_pool.waitForDone();
}

QQuickImageProvider* RdFilterPreview::createImageProvider() const
{
    return new FilterPreviewProvider(m_cache);
}

void RdFilterPreview::setFrameSize(const QSize& size)
{
    if (size == m_frameSize)
        return;
    m_frameSize = size;
    // a capture in flight is for the old size: take the frame again when it ends
    m_retake = m_inflight != nullptr;
    resetFrame();
    emit frameSizeChanged();
}

QStringList RdFilterPreview::previewedFilters() const
{
    return RdFilterMath::previewedFilters();
}

void RdFilterPreview::onInputChanged()
{
    vlc_tick_t length = 0;
    QByteArray uri;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker locker{ player };
        input_item_t* item = vlc_player_GetCurrentMedia(player);
        length = vlc_player_GetLength(player);
        if (item)
        {
            char* psz = input_item_GetURI(item);
            if (psz)
                uri = QByteArray(psz);
            free(psz);
        }
    }

    if (uri != m_uri)
    {
        cancelCapture();
        m_retake = false;
        m_item = SharedInputItem();
        m_uri = uri;
        resetFrame();
    }
    m_length = length;
    // local files only: a stream would be opened a second time over the network
    setSupported(!m_unavailable && m_uri.startsWith("file://") && m_length > 0);
}

void RdFilterPreview::setSupported(bool supported)
{
    if (supported == m_supported)
        return;
    m_supported = supported;
    emit supportedChanged();
}

void RdFilterPreview::resetFrame()
{
    const bool wasReady = ready();
    m_frame = QImage();
    m_frameTime = -1;
    ++m_generation;
    m_cache->clear();
    m_pending.clear();
    if (wasReady)
        emit readyChanged();
    ++m_revision;
    emit revisionChanged();
}

void RdFilterPreview::cancelCapture()
{
    if (m_preparser && m_inflight)
        vlc_preparser_Cancel(m_preparser, m_inflight);
}

void RdFilterPreview::capture()
{
    if (!m_supported || m_frameSize.isEmpty() || m_inflight)
        return;

    vlc_tick_t time = 0;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker locker{ player };
        time = vlc_player_GetTime(player);
    }
    if (time == VLC_TICK_INVALID || time < 0)
        time = 0;
    // the frame on hand is still the picture on screen
    if (!m_frame.isNull() && m_frameTime >= 0
        && std::abs(secf_from_vlc_tick(time - m_frameTime)) < kSameFrameSec)
        return;

    if (!m_item)
    {
        // a copy of the playing item: the thumbnailer's input never touches the item the
        // player shows, and its decoder uses 2 threads, so the capture never competes with
        // the playback (the seek preview does the same)
        input_item_t* copy = input_item_NewFile(m_uri.constData(), nullptr, m_length, ITEM_LOCAL);
        if (!copy)
            return;
        input_item_AddOption(copy, ":avcodec-threads=2", VLC_INPUT_OPTION_TRUSTED);
        m_item = SharedInputItem(copy, false);
    }

    if (!m_preparser)
    {
        struct vlc_preparser_cfg cfg{};
        cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
        cfg.max_parser_threads = 0;
        cfg.max_thumbnailer_threads = 1;
        cfg.timeout = kTimeout;
        cfg.external_process = false;
        m_preparser = vlc_preparser_New(VLC_OBJECT(vlc_object_instance(m_intf)), &cfg);
        if (!m_preparser)
        {
            m_unavailable = true;
            setSupported(false);
            return;
        }
    }

    struct vlc_thumbnailer_arg arg{};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_TIME;
    arg.seek.time = std::min<vlc_tick_t>(time, std::max<vlc_tick_t>(0, m_length - VLC_TICK_FROM_MS(500)));
    // the keyframe at or before the time, like the seek preview: a precise seek decodes every
    // frame from that keyframe on in software, seconds of CPU next to the playback on a 4K or
    // long-GOP file; a small preview does not need the exact frame
    arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    static const struct vlc_thumbnailer_cbs cbs = { &RdFilterPreview::onThumbnailEnded };

    Job* job = new Job{ this, m_generation, m_frameSize };
    vlc_preparser_req* req = vlc_preparser_req_NewThumbnail(m_preparser, m_item.get(), &arg, &cbs, job);
    if (!req)
    {
        delete job;
        return;
    }
    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        vlc_preparser_req_Release(req);
        delete job;
        return;
    }
    m_inflight = req;
    m_frameTime = time;
}

// thumbnailer thread (or the UI thread, inside vlc_preparser_Cancel, for a capture that had
// not started): convert the frame here, hand the result to the UI thread
void RdFilterPreview::onThumbnailEnded(vlc_preparser_req* req, int status, picture_t* picture, void* data)
{
    const Job job = *static_cast<Job*>(data);
    delete static_cast<Job*>(data);

    QImage image;
    if (status == VLC_SUCCESS && picture)
        image = frameToImage(VLC_OBJECT(vlc_object_instance(job.self->m_intf)), picture, job.box);

    RdFilterPreview* self = job.self;
    QMetaObject::invokeMethod(self, [self, req, job, status, image]() {
        self->onCaptureEnded(req, job.generation, status, image);
    }, Qt::QueuedConnection);
}

void RdFilterPreview::onCaptureEnded(vlc_preparser_req* req, int generation, int status, const QImage& image)
{
    if (req == m_inflight)
        m_inflight = nullptr;
    vlc_preparser_req_Release(req);

    if (status == -EINTR)
        return;
    if (generation != m_generation)
    {
        // the preview size changed while the frame was taken: take it again at the new size
        // (a frame of the previous media that ended before its cancel is only dropped)
        if (std::exchange(m_retake, false) && m_frame.isNull())
            capture();
        return;
    }
    if (image.isNull())
    {
        // the frame on hand (if any) stays; the next capture tries again
        m_frameTime = -1;
        return;
    }

    // a new frame: every preview is made again from it
    const bool wasReady = ready();
    ++m_generation;
    m_cache->clear();
    m_pending.clear();
    m_frame = image;
    if (!wasReady)
        emit readyChanged();
    ++m_revision;
    emit revisionChanged();
}

QUrl RdFilterPreview::preview(const QVariantMap& values)
{
    if (m_frame.isNull())
        return {};

    const QByteArray key = keyOf(values);
    if (m_cache->contains(m_generation, key))
        return QUrl(QStringLiteral("image://%1/%2/%3")
                        .arg(QLatin1String(providerId))
                        .arg(m_generation)
                        .arg(QString::fromLatin1(key)));

    if (!m_pending.contains(key))
    {
        m_pending.insert(key);
        const QImage frame = m_frame;
        const int generation = m_generation;
        QPointer<RdFilterPreview> self(this);
        m_pool.start([self, frame, values, generation, key]() {
            const QImage image = RdFilterMath::apply(frame, values);
            // the destructor waits for this job, so the object is still there
            if (!self)
                return;
            QMetaObject::invokeMethod(self.data(), [self, generation, key, image]() {
                if (self)
                    self->onPreviewDone(generation, key, image);
            }, Qt::QueuedConnection);
        });
    }
    return {};
}

void RdFilterPreview::onPreviewDone(int generation, const QByteArray& key, const QImage& image)
{
    if (generation != m_generation)
        return;
    m_pending.remove(key);
    if (image.isNull())
        return;
    m_cache->insert(generation, key, image);
    ++m_revision;
    emit revisionChanged();
}
