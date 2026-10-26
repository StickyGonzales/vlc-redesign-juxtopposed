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

#include "rd_seek_thumbnailer.hpp"

#include <QList>
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QPair>
#include <QQuickImageProvider>
#include <QStringList>
#include <QTransform>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdlib>
#include <cstring>

#include <vlc_common.h>
#include <vlc_image.h>
#include <vlc_input_item.h>
#include <vlc_picture.h>
#include <vlc_player.h>
#include <vlc_preparser.h>

#include "player/player_controller.hpp"

namespace {

// at most one thumbnailer request starts per interval while the pointer moves (ms)
constexpr int kThrottleMs = 150;
// a running request for a position the pointer has left is cancelled after this long (ms):
// long enough for a keyframe seek and decode of a large file to finish, so a pointer that
// keeps moving still gets frames instead of cancelling every request
constexpr int kStaleMs = 800;
// frames kept per media (about 250 KB each at 125 % scaling)
constexpr int kCacheSize = 24;
// the bar is split into this many time buckets at most, each at least kMinBucket long
constexpr int kMaxBuckets = 300;
constexpr vlc_tick_t kMinBucket = VLC_TICK_FROM_SEC(1);
// a stuck request (slow disk, broken file) gives up after this long
constexpr vlc_tick_t kTimeout = VLC_TICK_FROM_SEC(3);
// a precise request decodes every frame from the keyframe before the position: it may take
// this long before it gives up
constexpr vlc_tick_t kTimeoutPrecise = VLC_TICK_FROM_SEC(8);
// failed requests in a row after which the media counts as not previewable; a timeout counts
// twice (each one kept the thumbnailer busy for kTimeout)
constexpr int kMaxFailures = 3;
// two fast-seek frames whose times differ from the hovered times' difference by more than this
// came from keyframes far from the positions: the media's keyframes are too sparse for fast
// seeks (a screen recording, a stream recorded with one keyframe). Between the bounds, an
// eighth of the length: GOPs of normal files stay under 10 s
constexpr vlc_tick_t kFarMin = VLC_TICK_FROM_SEC(4);
constexpr vlc_tick_t kFarMax = VLC_TICK_FROM_SEC(12);

} // namespace

// the image handler scaling the frames: created on the first frame and reused while the frame
// and output sizes stay the same (the frames of one media at one card size), so its scaler is
// not set up again for every frame. The thumbnailer runs a single thread; the lock only guards
// against a second one
struct RdSeekThumbnailer::Converter
{
    explicit Converter(vlc_object_t* obj) : obj(obj) {}
    ~Converter() { reset(); }

    // call with the lock held
    image_handler_t* handlerFor(const QSize& in, const QSize& out)
    {
        if (handler && (in != inSize || out != outSize))
            reset();
        if (!handler)
        {
            handler = image_HandlerCreate(obj);
            inSize = in;
            outSize = out;
        }
        return handler;
    }

    void reset()
    {
        if (handler)
            image_HandlerDelete(handler);
        handler = nullptr;
    }

    QMutex lock;
    vlc_object_t* const obj;
    image_handler_t* handler = nullptr;
    QSize inSize;
    QSize outSize;
};

namespace {

struct Job
{
    RdSeekThumbnailer* self;
    RdSeekThumbnailer::Converter* converter;
    qint64 bucket;
    int generation;
    QSize box;
    // the media time asked for, and whether the request was a fast (keyframe) seek
    vlc_tick_t time;
    bool fast;
};

// the decoded frame, scaled to fit `box` with its display aspect and orientation, as RGBA
QImage frameToImage(RdSeekThumbnailer::Converter& converter, picture_t* picture, const QSize& box)
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

    const double scale = std::min(box.width() / displayWidth, box.height() / displayHeight);
    const int outWidth = std::max(2, int(std::lround(displayWidth * scale)));
    const int outHeight = std::max(2, int(std::lround(displayHeight * scale)));
    // size of the scaled frame as it is stored, before its orientation is applied
    const int storedWidth = swap ? outHeight : outWidth;
    const int storedHeight = swap ? outWidth : outHeight;

    video_format_t fmtOut;
    video_format_Init(&fmtOut, VLC_CODEC_RGBA);
    fmtOut.i_width = fmtOut.i_visible_width = storedWidth;
    fmtOut.i_height = fmtOut.i_visible_height = storedHeight;
    fmtOut.i_sar_num = fmtOut.i_sar_den = 1;
    // the converter only scales (it refuses to change the orientation); Qt turns it below
    fmtOut.orientation = fmtIn.orientation;

    QImage image;
    {
        QMutexLocker locker(&converter.lock);
        image_handler_t* handler = converter.handlerFor(QSize(int(fmtIn.i_width), int(fmtIn.i_height)),
                                                        QSize(storedWidth, storedHeight));
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
    }

    if (image.isNull())
        return image;

    // the stored picture turned upright (see the orientation schemas of the OpenGL importer)
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

} // namespace

// frames of the current media, most recently used first; read by the image provider (any
// thread) and written by the thumbnailer object (UI thread)
struct RdSeekThumbnailer::Cache
{
    QMutex lock;
    QList<QPair<QPair<int, qint64>, QImage>> frames;

    QImage find(int generation, qint64 bucket)
    {
        QMutexLocker locker(&lock);
        for (qsizetype i = 0; i < frames.size(); ++i)
        {
            if (frames[i].first == qMakePair(generation, bucket))
            {
                if (i > 0)
                    frames.move(i, 0);
                return frames.first().second;
            }
        }
        return {};
    }

    bool contains(int generation, qint64 bucket)
    {
        QMutexLocker locker(&lock);
        return std::any_of(frames.cbegin(), frames.cend(), [&](const auto& frame) {
            return frame.first == qMakePair(generation, bucket);
        });
    }

    void insert(int generation, qint64 bucket, const QImage& image)
    {
        QMutexLocker locker(&lock);
        frames.prepend(qMakePair(qMakePair(generation, bucket), image));
        while (frames.size() > kCacheSize)
            frames.removeLast();
    }

    void clear()
    {
        QMutexLocker locker(&lock);
        frames.clear();
    }
};

namespace {

// "image://rdseekthumb/<generation>/<bucket>": a frame of the cache (an empty image once it
// has left the cache; the card then shows its empty picture area)
class SeekThumbnailProvider : public QQuickImageProvider
{
public:
    explicit SeekThumbnailProvider(std::shared_ptr<RdSeekThumbnailer::Cache> cache)
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
            image = m_cache->find(parts[0].toInt(), parts[1].toLongLong());
        if (size)
            *size = image.size();
        return image;
    }

private:
    std::shared_ptr<RdSeekThumbnailer::Cache> m_cache;
};

} // namespace

RdSeekThumbnailer::RdSeekThumbnailer(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
    , m_cache(std::make_shared<Cache>())
    , m_converter(std::make_unique<Converter>(VLC_OBJECT(intf)))
{
    m_throttle.setSingleShot(true);
    connect(&m_throttle, &QTimer::timeout, this, &RdSeekThumbnailer::startNext);

    connect(m_player, &PlayerController::inputChanged, this, &RdSeekThumbnailer::onInputChanged);
    connect(m_player, &PlayerController::lengthChanged, this, &RdSeekThumbnailer::onInputChanged);
    onInputChanged();
}

RdSeekThumbnailer::~RdSeekThumbnailer()
{
    m_throttle.stop();
    // ends the thumbnailer thread; the callback of the request in flight runs before this
    // returns, and its result (queued to this object) is dropped with it. The converter is
    // deleted after this, once no thread uses it any more
    if (m_preparser)
        vlc_preparser_Delete(m_preparser);
    if (m_inflight)
        vlc_preparser_req_Release(m_inflight);
}

QQuickImageProvider* RdSeekThumbnailer::createImageProvider() const
{
    return new SeekThumbnailProvider(m_cache);
}

void RdSeekThumbnailer::setFrameSize(const QSize& size)
{
    if (size == m_frameSize)
        return;
    m_frameSize = size;
    // frames of the old size are not shown again
    ++m_generation;
    m_cache->clear();
    setSource(-1);
    emit frameSizeChanged();
}

void RdSeekThumbnailer::onInputChanged()
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

    if (uri == m_uri)
    {
        // the same media with a new length (known only after the start, or a file still being
        // written): its item, frames and time buckets stay valid, a preview on screen goes on
        if (length != m_length)
        {
            m_length = length;
            updateSupported();
        }
        return;
    }

    resetMedia();
    m_uri = uri;
    m_length = length;
    updateSupported();
}

void RdSeekThumbnailer::updateSupported()
{
    // local files only: a stream would be opened a second time over the network; a media whose
    // frames keep failing stays on the time-only tooltip
    setSupported(!m_unavailable && m_failures < kMaxFailures
                 && m_uri.startsWith("file://") && m_length > 0);
}

void RdSeekThumbnailer::setSupported(bool supported)
{
    if (supported == m_supported)
        return;
    m_supported = supported;
    emit supportedChanged();
}

void RdSeekThumbnailer::resetMedia()
{
    stop();
    m_item = SharedInputItem();
    m_uri.clear();
    m_length = 0;
    m_bucketLength = 0;
    m_failures = 0;
    m_precise = false;
    m_lastFastTime = VLC_TICK_INVALID;
    m_lastFastDate = VLC_TICK_INVALID;
    ++m_generation;
    m_cache->clear();
}

void RdSeekThumbnailer::setSource(qint64 bucket)
{
    const QUrl url = (bucket < 0) ? QUrl()
                                  : QUrl(QStringLiteral("image://%1/%2/%3")
                                             .arg(QLatin1String(providerId))
                                             .arg(m_generation)
                                             .arg(bucket));
    if (url == m_source)
        return;
    m_source = url;
    emit sourceChanged();
}

void RdSeekThumbnailer::request(double position)
{
    if (!m_supported || m_frameSize.isEmpty() || m_length <= 0)
        return;

    if (!m_item && !makeItem())
        return;

    position = std::clamp(position, 0.0, 1.0);
    const qint64 lastBucket = (m_length - 1) / m_bucketLength;
    const qint64 bucket = std::min<qint64>(lastBucket, qint64(position * m_length) / m_bucketLength);

    if (m_cache->contains(m_generation, bucket))
    {
        m_wanted = -1;
        setSource(bucket);
        return;
    }

    if (bucket == m_wanted)
        return;
    m_wanted = bucket;

    startNext();
}

bool RdSeekThumbnailer::makeItem()
{
    // a copy of the playing item: the thumbnailer's input never touches the item the player
    // shows (its meta and track info), and its decoder uses 2 threads instead of one per core,
    // so a preview neither competes with playback nor waits for a full frame-thread pipeline.
    // A precise seek decodes every frame from the keyframe before the position: 4 threads and
    // no loop filter (invisible at the card's size) roughly double the frames it gets through
    input_item_t* copy = input_item_NewFile(m_uri.constData(), nullptr, m_length, ITEM_LOCAL);
    if (!copy)
        return false;
    input_item_AddOption(copy, m_precise ? ":avcodec-threads=4" : ":avcodec-threads=2",
                         VLC_INPUT_OPTION_TRUSTED);
    if (m_precise)
        input_item_AddOption(copy, ":avcodec-skiploopfilter=4", VLC_INPUT_OPTION_TRUSTED);
    m_item = SharedInputItem(copy, false);
    m_bucketLength = std::max(kMinBucket, m_length / kMaxBuckets);
    return true;
}

// the frames of fast seeks do not follow the pointer (see kFarMin): from now on the media is
// previewed with precise seeks, which decode up to the position itself. The frames shown so far
// are dropped (they may all be the same keyframe)
void RdSeekThumbnailer::switchToPrecise()
{
    msg_Dbg(m_intf, "seek preview: the keyframes are too sparse for fast seeks, "
                    "using precise seeks for this media");
    m_precise = true;
    ++m_generation;
    m_cache->clear();
    setSource(-1);
    // the thumbnailer and the item are made again with the precise settings (no request runs:
    // this is called once the last one ended)
    if (m_preparser)
    {
        vlc_preparser_Delete(m_preparser);
        m_preparser = nullptr;
    }
    m_item = SharedInputItem();
    makeItem();
}

void RdSeekThumbnailer::stop()
{
    m_wanted = -1;
    m_throttle.stop();
    cancelInflight();
    setSource(-1);
}

void RdSeekThumbnailer::cancelInflight()
{
    if (!m_inflight || m_inflightCancelled)
        return;
    m_inflightCancelled = true;
    vlc_preparser_Cancel(m_preparser, m_inflight);
}

void RdSeekThumbnailer::setUnavailable()
{
    stop();
    m_unavailable = true;
    updateSupported();
}

// the timer fires after `ms` at the latest (an earlier tick only re-checks)
void RdSeekThumbnailer::armTimer(int ms)
{
    if (!m_throttle.isActive() || m_throttle.remainingTime() > ms)
        m_throttle.start(std::max(0, ms));
}

// runs on each new pointer position and on each tick of the single shot timer
void RdSeekThumbnailer::startNext()
{
    if (m_wanted < 0 || !m_item)
        return;

    if (m_inflight)
    {
        // the running request is for a position the pointer has left: once it is stale, cancel
        // it so the wanted position starts sooner; until then, check again when it gets stale
        // (the pointer may not move any more)
        if (!m_inflightCancelled && m_inflightBucket != m_wanted)
        {
            const qint64 age = m_inflightAge.elapsed();
            if (age >= kStaleMs)
                cancelInflight();
            else
                armTimer(int(kStaleMs - age));
        }
        return;
    }

    if (m_lastStart.isValid() && m_lastStart.elapsed() < kThrottleMs)
    {
        armTimer(int(kThrottleMs - m_lastStart.elapsed()));
        return;
    }

    if (!m_preparser)
    {
        struct vlc_preparser_cfg cfg{};
        cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
        cfg.max_parser_threads = 0;
        cfg.max_thumbnailer_threads = 1;
        cfg.timeout = m_precise ? kTimeoutPrecise : kTimeout;
        cfg.external_process = false;
        m_preparser = vlc_preparser_New(VLC_OBJECT(vlc_object_instance(m_intf)), &cfg);
        if (!m_preparser)
        {
            // no thumbnailer: the seek bar keeps the time-only tooltip
            setUnavailable();
            return;
        }
    }

    const qint64 bucket = m_wanted;
    // the start of the bar is the first frame (no seek, the card reads 00:00:00 there);
    // otherwise the middle of the bucket, a little before the end for the last one
    const vlc_tick_t time = (bucket == 0) ? 0
                          : std::min<vlc_tick_t>(bucket * m_bucketLength + m_bucketLength / 2,
                                                 std::max<vlc_tick_t>(0, m_length - VLC_TICK_FROM_MS(500)));

    struct vlc_thumbnailer_arg arg{};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_TIME;
    arg.seek.time = time; // media time; 0 decodes the first frame without a seek
    arg.seek.speed = m_precise ? vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_PRECISE
                               : vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    static const struct vlc_thumbnailer_cbs cbs = { &RdSeekThumbnailer::onThumbnailEnded };

    Job* job = new Job{ this, m_converter.get(), bucket, m_generation, m_frameSize, time, !m_precise };
    vlc_preparser_req* req = vlc_preparser_req_NewThumbnail(m_preparser, m_item.get(), &arg, &cbs, job);
    if (!req)
    {
        delete job;
        m_wanted = -1;
        return;
    }
    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        vlc_preparser_req_Release(req);
        delete job;
        m_wanted = -1;
        return;
    }

    m_inflight = req;
    m_inflightBucket = bucket;
    m_inflightCancelled = false;
    m_inflightAge.start();
    m_lastStart.start();
}

// thumbnailer thread (or the UI thread, inside vlc_preparser_Cancel, for a request that had
// not started): convert the frame here, hand the result to the UI thread
void RdSeekThumbnailer::onThumbnailEnded(vlc_preparser_req* req, int status, picture_t* picture, void* data)
{
    const Job job = *static_cast<Job*>(data);
    delete static_cast<Job*>(data);

    QImage image;
    // the frame's timestamp, in the stream's own time base (not always 0 at the start: an
    // MPEG-TS starts anywhere), so only differences between frames are compared
    vlc_tick_t date = VLC_TICK_INVALID;
    if (status == VLC_SUCCESS && picture)
    {
        image = frameToImage(*job.converter, picture, job.box);
        date = picture->date;
    }

    RdSeekThumbnailer* self = job.self;
    QMetaObject::invokeMethod(self, [self, req, job, status, image, date]() {
        self->onRequestEnded(req, job.bucket, job.generation, status, image,
                             job.fast ? job.time : VLC_TICK_INVALID, date);
    }, Qt::QueuedConnection);
}

bool RdSeekThumbnailer::fastSeekMisses(vlc_tick_t time, vlc_tick_t date)
{
    if (time == VLC_TICK_INVALID || date == VLC_TICK_INVALID)
        return false;
    bool misses = false;
    if (m_lastFastTime != VLC_TICK_INVALID)
    {
        const vlc_tick_t far = std::clamp(m_length / 8, kFarMin, kFarMax);
        const vlc_tick_t asked = time - m_lastFastTime;
        const vlc_tick_t got = date - m_lastFastDate;
        misses = std::llabs(got - asked) > far;
    }
    m_lastFastTime = time;
    m_lastFastDate = date;
    return misses;
}

void RdSeekThumbnailer::onRequestEnded(vlc_preparser_req* req, qint64 bucket, int generation,
                                       int status, const QImage& image, vlc_tick_t fastTime,
                                       vlc_tick_t date)
{
    if (req == m_inflight)
        m_inflight = nullptr;
    vlc_preparser_req_Release(req);

    // a cancelled request says nothing about the media, and its position may be wanted again
    // (the pointer came back to it): it is started again below
    const bool cancelled = (status == -EINTR);

    if (generation == m_generation && !cancelled && !image.isNull() && !m_precise
        && fastSeekMisses(fastTime, date))
    {
        // the pointer's position is asked for again, with a precise seek
        const bool wanted = (bucket == m_wanted);
        switchToPrecise();
        if (wanted)
            m_wanted = bucket;
        startNext();
        return;
    }

    if (generation == m_generation && !cancelled)
    {
        if (!image.isNull())
        {
            m_failures = 0;
            m_cache->insert(generation, bucket, image);
        }
        else if (status == VLC_ETIMEOUT && m_precise)
        {
            // too many frames to decode from the keyframe before this position: no frame here,
            // but the media itself previews fine elsewhere
        }
        else
        {
            m_failures += (status == VLC_ETIMEOUT) ? 2 : 1;
            if (m_failures >= kMaxFailures)
            {
                // VLC cannot make frames of this media (codec, damaged file, too slow): the
                // seek bar falls back to the time-only tooltip until another media plays
                stop();
                updateSupported();
                return;
            }
        }
        if (bucket == m_wanted)
        {
            // shown when it arrived, given up when it failed (no endless retries)
            m_wanted = -1;
            if (!image.isNull())
                setSource(bucket);
        }
    }

    startNext();
}
