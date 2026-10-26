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
#ifndef RD_SEEK_THUMBNAILER_HPP
#define RD_SEEK_THUMBNAILER_HPP

#include <QByteArray>
#include <QElapsedTimer>
#include <QImage>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QSize>
#include <QTimer>
#include <QUrl>

#include <memory>

#include "qt.hpp"
#include "util/shared_input_item.hpp"

class PlayerController;
class QQuickImageProvider;
struct vlc_preparser_t;
struct vlc_preparser_req;

/**
 * redesign: frames for the seek bar preview card (P2-04, video 3:24-3:31, Figma "thumbnail").
 *
 * While the pointer hovers or drags the seek bar, QML calls request() with the hovered
 * position. One VLC thumbnailer request (vlc_preparser, its own input thread, software decode,
 * fast keyframe seek) runs at a time, at most one starts per throttle interval, and the newest
 * position replaces any position still waiting; a running request that no longer matches the
 * pointer is cancelled once it has run for a while (stale). Frames are scaled to the card's
 * pixel size on the thumbnailer thread and kept in a small LRU cache keyed by time bucket, so
 * going back over the bar shows them at once. stop() (pointer gone) cancels everything; the
 * thumbnailer itself is created on the first request, so nothing runs before the first hover.
 *
 * Fast seeks land on the keyframe before the position. When a media's keyframes are too sparse
 * for that (a screen recording, a file with one keyframe), every position shows the same frame:
 * once two fast frames show it, the media switches to precise seeks, which decode up to the
 * position itself. A fast seek first finds the keyframe before the position; the precise seek
 * runs only when decoding from there fits a budget, otherwise the card shows the time only (a
 * precise seek cannot be stopped before it reached the position).
 *
 * Only local files are previewed (`supported`); streams and other media keep the time-only
 * tooltip. The frames reach QML through the "rdseekthumb" image provider: `source` is the
 * URL of the frame to show, empty while none is ready.
 */
class RdSeekThumbnailer : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool supported READ supported NOTIFY supportedChanged FINAL)
    Q_PROPERTY(QUrl source READ source NOTIFY sourceChanged FINAL)
    // pixel size of the card's picture (device pixels); frames keep their aspect inside it
    Q_PROPERTY(QSize frameSize READ frameSize WRITE setFrameSize NOTIFY frameSizeChanged FINAL)

public:
    static constexpr const char* providerId = "rdseekthumb";

    RdSeekThumbnailer(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdSeekThumbnailer() override;

    bool supported() const { return m_supported; }
    QUrl source() const { return m_source; }
    QSize frameSize() const { return m_frameSize; }
    void setFrameSize(const QSize& size);

    // the image provider reading this thumbnailer's cache (owned by the QML engine)
    QQuickImageProvider* createImageProvider() const;

    // the pointer is over the seek bar at `position` (0..1)
    Q_INVOKABLE void request(double position);
    // the pointer left the seek bar: drop the waiting position, cancel the running request
    Q_INVOKABLE void stop();

    struct Cache;
    struct Converter;

    // what a thumbnailer request is for
    enum class Kind
    {
        Fast,    // a fast seek's frame
        Start,   // the first frame: its timestamp is the time base of the precise mode
        Probe,   // a fast seek, to find the keyframe before the position
        Precise, // a precise seek's frame
    };

    struct Result
    {
        int status = VLC_EGENERIC;
        QImage image;
        vlc_tick_t date = VLC_TICK_INVALID;
        double pixelRate = 0.;
    };

signals:
    void supportedChanged();
    void sourceChanged();
    void frameSizeChanged();

private:
    void onInputChanged();
    void updateSupported();
    void setSupported(bool supported);
    void setUnavailable();
    void resetMedia();
    bool makeItem();
    void switchToPrecise();
    void resetPrecise();
    bool fastSeekMisses(vlc_tick_t time, vlc_tick_t date);
    void setSource(qint64 bucket);
    void startNext();
    void armTimer(int ms);
    void cancelInflight();
    void onRequestEnded(vlc_preparser_req* req, qint64 bucket, int generation, vlc_tick_t time,
                        Kind kind, const Result& result);

    static void onThumbnailEnded(vlc_preparser_req* req, int status, picture_t* picture, void* data);

    qt_intf_t* m_intf = nullptr;
    PlayerController* m_player = nullptr;

    vlc_preparser_t* m_preparser = nullptr;
    std::shared_ptr<Cache> m_cache;
    // the frame scaler, used on the thumbnailer thread only (it has a single thread)
    std::unique_ptr<Converter> m_converter;

    bool m_supported = false;
    // VLC's thumbnailer could not be created: no previews for the rest of the session
    bool m_unavailable = false;
    QUrl m_source;
    QSize m_frameSize;

    // the media being previewed: the playing item's URI, and a copy of the item made on the
    // first request (see request())
    QByteArray m_uri;
    SharedInputItem m_item;
    vlc_tick_t m_length = 0;
    vlc_tick_t m_bucketLength = 0;
    // bumped whenever the media or the frame size changes: older frames are dropped
    int m_generation = 0;
    // failed requests in a row for this media (a timeout counts twice)
    int m_failures = 0;
    // the media's keyframes are too sparse for fast seeks: precise seeks only
    bool m_precise = false;
    // the last fast-seek frame: the time asked for and the frame's timestamp
    vlc_tick_t m_lastFastTime = VLC_TICK_INVALID;
    vlc_tick_t m_lastFastDate = VLC_TICK_INVALID;
    // precise mode: the first frame's timestamp, the buckets whose keyframe is near enough for
    // a precise seek (with that seek's work in pixels), the buckets too far from one, pixels per
    // second of video, the budget
    vlc_tick_t m_startDate = VLC_TICK_INVALID;
    QHash<qint64, double> m_probed;
    QSet<qint64> m_tooFar;
    double m_pixelRate = 0.;
    double m_budget = 0.;

    // the position under the pointer, as a time bucket (-1: none waiting)
    qint64 m_wanted = -1;

    // the single request in flight
    vlc_preparser_req* m_inflight = nullptr;
    qint64 m_inflightBucket = -1;
    Kind m_inflightKind = Kind::Fast;
    bool m_inflightCancelled = false;
    QElapsedTimer m_inflightAge;

    // throttle: at most one request starts per interval, and a running request for a position
    // the pointer has left is checked again once it is stale; single shot, only armed while a
    // position waits
    QElapsedTimer m_lastStart;
    QTimer m_throttle;
};

#endif // RD_SEEK_THUMBNAILER_HPP
