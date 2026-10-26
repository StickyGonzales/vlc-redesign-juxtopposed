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

#ifndef SUBTITLE_WEB_HPP
#define SUBTITLE_WEB_HPP

#include <QByteArray>
#include <QList>
#include <QPair>
#include <QString>
#include <QUrl>

#include <vlc_common.h>

/**
 * redesign (Add Subtitles, W6.5): the web requests of the dialog's "From OpenSubtitles" and
 * "From Link" sources. VLC's Qt is built without Qt Network, so they go through VLC itself:
 * JSON API calls with their own headers over VLC's TLS sockets (vlc_tls), file downloads
 * through VLC's access modules (vlc_stream_NewURL, which follow redirects).
 *
 * Every call blocks: run them on a worker thread only. They stop when the thread's VLC
 * interrupt context (vlc_interrupt_set) is killed, which is how the dialog cancels them.
 */
class SubtitleWeb
{
public:
    struct Reply
    {
        // HTTP status, 0 when the server could not be reached
        int status = 0;
        QByteArray body;
        // why the request failed, for the log
        QString error;

        bool ok() const { return status >= 200 && status < 300; }
    };

    using Headers = QList<QPair<QByteArray, QByteArray>>;

    // the User-Agent of every request (OpenSubtitles asks for the application's name)
    static QByteArray userAgent();

    // an HTTPS request ("GET", "POST") with a body of at most a few megabytes; `headers`
    // may replace the default User-Agent and Accept
    static Reply request(vlc_object_t* obj, const QByteArray& method, const QUrl& url,
                         const Headers& headers = {}, const QByteArray& body = {});

    // the content of a link (http, https, ftp, file ...), at most `maxSize` bytes
    static Reply fetch(vlc_object_t* obj, const QString& url, qint64 maxSize);
};

#endif // SUBTITLE_WEB_HPP
