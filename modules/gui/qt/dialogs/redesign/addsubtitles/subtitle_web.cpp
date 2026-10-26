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

#include "subtitle_web.hpp"

#include <vlc_stream.h>
#include <vlc_tls.h>

#include <algorithm>
#include <memory>

namespace {

// API answers are small JSON documents
constexpr qint64 maxReplySize = 4 * 1024 * 1024;
constexpr int maxRedirects = 3;

struct TlsClientDeleter
{
    void operator()(vlc_tls_client_t* creds) const { vlc_tls_ClientDelete(creds); }
};

struct TlsDeleter
{
    void operator()(vlc_tls_t* tls) const { vlc_tls_Close(tls); }
};

struct StreamDeleter
{
    void operator()(stream_t* stream) const { vlc_stream_Delete(stream); }
};

QByteArray readLine(vlc_tls_t* tls, bool* ok)
{
    char* line = vlc_tls_GetLine(tls);
    *ok = line != nullptr;
    if (!line)
        return {};
    QByteArray result(line);
    free(line);
    return result;
}

// reads exactly `size` bytes of the body
bool readBody(vlc_tls_t* tls, qint64 size, QByteArray& body)
{
    if (size < 0 || body.size() + size > maxReplySize)
        return false;
    const qsizetype start = body.size();
    body.resize(start + size);
    return size == 0 || vlc_tls_Read(tls, body.data() + start, size_t(size), true) == size;
}

SubtitleWeb::Reply requestOnce(vlc_object_t* obj, const QByteArray& method, const QUrl& url,
                               const SubtitleWeb::Headers& headers, const QByteArray& body,
                               QUrl* redirect)
{
    SubtitleWeb::Reply reply;

    if (url.scheme() != QLatin1String("https") || url.host().isEmpty())
    {
        reply.error = QStringLiteral("not an https address");
        return reply;
    }

    std::unique_ptr<vlc_tls_client_t, TlsClientDeleter> creds(vlc_tls_ClientCreate(obj));
    if (!creds)
    {
        reply.error = QStringLiteral("no TLS support");
        return reply;
    }

    const QByteArray host = url.host().toUtf8();
    const char* const alpn[] = { "http/1.1", nullptr };
    std::unique_ptr<vlc_tls_t, TlsDeleter> tls(
        vlc_tls_SocketOpenTLS(creds.get(), host.constData(), url.port(443), "https", alpn, nullptr));
    if (!tls)
    {
        reply.error = QStringLiteral("cannot connect to %1").arg(url.host());
        return reply;
    }

    QByteArray target = url.path(QUrl::FullyEncoded).toUtf8();
    if (target.isEmpty())
        target = "/";
    if (url.hasQuery())
        target += '?' + url.query(QUrl::FullyEncoded).toUtf8();

    // the caller's User-Agent and Accept replace the defaults (the update check sends its own)
    const auto hasHeader = [&headers](const QByteArray& name) {
        return std::any_of(headers.cbegin(), headers.cend(), [&name](const auto& header) {
            return header.first.compare(name, Qt::CaseInsensitive) == 0;
        });
    };
    QByteArray head = method + ' ' + target + " HTTP/1.1\r\n"
                      "Host: " + host + "\r\n";
    if (!hasHeader("User-Agent"))
        head += "User-Agent: " + SubtitleWeb::userAgent() + "\r\n";
    if (!hasHeader("Accept"))
        head += "Accept: application/json\r\n";
    head += "Connection: close\r\n";
    for (const auto& header : headers)
        head += header.first + ": " + header.second + "\r\n";
    if (!body.isEmpty() || method == "POST")
        head += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
    head += "\r\n";
    head += body;

    if (vlc_tls_Write(tls.get(), head.constData(), size_t(head.size())) != head.size())
    {
        reply.error = QStringLiteral("cannot send the request");
        return reply;
    }

    bool ok = false;
    const QByteArray statusLine = readLine(tls.get(), &ok);
    // "HTTP/1.1 200 OK"
    const QList<QByteArray> status = statusLine.split(' ');
    if (!ok || status.size() < 2 || !status.at(0).startsWith("HTTP/"))
    {
        reply.error = QStringLiteral("no answer");
        return reply;
    }
    reply.status = status.at(1).toInt();

    qint64 contentLength = -1;
    bool chunked = false;
    for (;;)
    {
        const QByteArray line = readLine(tls.get(), &ok);
        if (!ok)
        {
            reply.error = QStringLiteral("answer cut short");
            return reply;
        }
        if (line.isEmpty())
            break;
        const qsizetype colon = line.indexOf(':');
        if (colon <= 0)
            continue;
        const QByteArray name = line.left(colon).trimmed().toLower();
        const QByteArray value = line.mid(colon + 1).trimmed();
        if (name == "content-length")
            contentLength = value.toLongLong();
        else if (name == "transfer-encoding")
            chunked = value.toLower().contains("chunked");
        else if (name == "location" && redirect)
            *redirect = url.resolved(QUrl::fromEncoded(value));
    }

    if (chunked)
    {
        for (;;)
        {
            const QByteArray sizeLine = readLine(tls.get(), &ok);
            bool hex = false;
            const qint64 size = sizeLine.split(';').value(0).trimmed().toLongLong(&hex, 16);
            if (!ok || !hex || !readBody(tls.get(), size, reply.body))
            {
                reply.error = QStringLiteral("answer cut short");
                return reply;
            }
            // the CRLF after the chunk (and the trailer after the last one)
            readLine(tls.get(), &ok);
            if (size == 0 || !ok)
                break;
        }
    }
    else if (contentLength >= 0)
    {
        if (!readBody(tls.get(), contentLength, reply.body))
            reply.error = QStringLiteral("answer cut short");
    }
    else
    {
        // "Connection: close": the body ends with the connection
        char buffer[16384];
        ssize_t read;
        while ((read = vlc_tls_Read(tls.get(), buffer, sizeof(buffer), false)) > 0)
        {
            if (reply.body.size() + read > maxReplySize)
            {
                reply.error = QStringLiteral("answer too large");
                break;
            }
            reply.body.append(buffer, read);
        }
    }

    return reply;
}

} // namespace

QByteArray SubtitleWeb::userAgent()
{
    return QByteArrayLiteral("VLC Redesign v" PACKAGE_VERSION);
}

SubtitleWeb::Reply SubtitleWeb::request(vlc_object_t* obj, const QByteArray& method, const QUrl& url,
                                        const Headers& headers, const QByteArray& body)
{
    QUrl current = url;
    for (int i = 0; ; ++i)
    {
        QUrl redirect;
        Reply reply = requestOnce(obj, method, current, headers, body, &redirect);
        const bool redirected = reply.status == 301 || reply.status == 302 || reply.status == 307
                                || reply.status == 308;
        // only a GET follows a redirect (OpenSubtitles redirects queries it wants written in
        // another order)
        if (!redirected || method != "GET" || !redirect.isValid() || i >= maxRedirects)
            return reply;
        current = redirect;
    }
}

SubtitleWeb::Reply SubtitleWeb::fetch(vlc_object_t* obj, const QString& url, qint64 maxSize)
{
    Reply reply;

    const QByteArray mrl = url.toUtf8();
    std::unique_ptr<stream_t, StreamDeleter> stream(vlc_stream_NewURL(obj, mrl.constData()));
    if (!stream)
    {
        reply.error = QStringLiteral("cannot open %1").arg(url);
        return reply;
    }

    char buffer[16384];
    ssize_t read;
    while ((read = vlc_stream_Read(stream.get(), buffer, sizeof(buffer))) > 0)
    {
        if (reply.body.size() + read > maxSize)
        {
            reply.error = QStringLiteral("file too large");
            return reply;
        }
        reply.body.append(buffer, read);
    }
    if (read < 0)
    {
        reply.error = QStringLiteral("download failed");
        return reply;
    }

    reply.status = 200;
    return reply;
}
