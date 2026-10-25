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
#ifndef RD_FILTER_PREVIEW_HPP
#define RD_FILTER_PREVIEW_HPP

#include <QByteArray>
#include <QImage>
#include <QObject>
#include <QSet>
#include <QSize>
#include <QThreadPool>
#include <QUrl>
#include <QVariantMap>

#include <memory>

#include "qt.hpp"
#include "util/shared_input_item.hpp"

class PlayerController;
class QQuickImageProvider;
struct vlc_preparser_t;
struct vlc_preparser_req;

/**
 * redesign: small previews of video filter settings applied to the playing video
 * (VIDEO_INDEX row 139, line 853; redesign/SIDEBAR_MUSTHAVES_NOTES.md).
 *
 * capture() takes one still frame of the playing file at the current playback time, with
 * VLC's thumbnailer (its own input, software decode, two decoder threads, fast seek: the keyframe at or before that time), so the
 * playback is never touched. preview(values) gives the URL of that frame with the filter
 * values applied (RdFilterMath, VLC's filter math in software) once it is ready, an empty URL
 * before: the filters run on this object's single worker thread at the lowest priority, the
 * result goes into a small LRU cache, and `revision` changes so the bindings ask again. A
 * second request for the same values (the same preset row scrolled back into view, a list
 * opened again on the same frame) is answered from the cache.
 *
 * Only local files are previewed (`supported`); while no frame is ready (`ready` false) the
 * caller shows its placeholder. Nothing runs before the first capture().
 */
class RdFilterPreview : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool supported READ supported NOTIFY supportedChanged FINAL)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)
    // changes whenever a preview becomes available or the frame changes
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)
    // pixel size of a preview (device pixels); the frame keeps its aspect inside it
    Q_PROPERTY(QSize frameSize READ frameSize WRITE setFrameSize NOTIFY frameSizeChanged FINAL)

public:
    static constexpr const char* providerId = "rdfilterpreview";

    RdFilterPreview(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdFilterPreview() override;

    bool supported() const { return m_supported; }
    bool ready() const { return !m_frame.isNull(); }
    int revision() const { return m_revision; }
    QSize frameSize() const { return m_frameSize; }
    void setFrameSize(const QSize& size);

    // the image provider reading this object's cache (owned by the QML engine)
    QQuickImageProvider* createImageProvider() const;

    // take the frame at the current playback time (a list of previews opens)
    Q_INVOKABLE void capture();
    // the preview of `values` (RdFilterMath names), or an empty URL while it is being made
    Q_INVOKABLE QUrl preview(const QVariantMap& values);
    // the filters whose effect the previews show (the others leave the frame as it is)
    Q_INVOKABLE QStringList previewedFilters() const;

    struct Cache;

signals:
    void supportedChanged();
    void readyChanged();
    void revisionChanged();
    void frameSizeChanged();

private:
    void onInputChanged();
    void setSupported(bool supported);
    void resetFrame();
    void cancelCapture();
    void onCaptureEnded(vlc_preparser_req* req, int generation, int status, const QImage& image);
    void onPreviewDone(int generation, const QByteArray& key, const QImage& image);

    static void onThumbnailEnded(vlc_preparser_req* req, int status, picture_t* picture, void* data);

    qt_intf_t* m_intf = nullptr;
    PlayerController* m_player = nullptr;

    vlc_preparser_t* m_preparser = nullptr;
    vlc_preparser_req* m_inflight = nullptr;
    // VLC's thumbnailer could not be created: no previews for the rest of the session
    bool m_unavailable = false;
    // the preview size changed during the capture in flight: capture again when it ends
    bool m_retake = false;

    std::shared_ptr<Cache> m_cache;
    QThreadPool m_pool;

    bool m_supported = false;
    int m_revision = 0;
    QSize m_frameSize;

    // the playing media and a copy of its item made on the first capture
    QByteArray m_uri;
    SharedInputItem m_item;
    vlc_tick_t m_length = 0;

    // the frame the previews start from, and its generation (bumped on every new frame, new
    // media or new size: older previews are not shown again)
    QImage m_frame;
    int m_generation = 0;
    vlc_tick_t m_frameTime = -1;

    // previews being made for the current generation
    QSet<QByteArray> m_pending;
};

#endif // RD_FILTER_PREVIEW_HPP
