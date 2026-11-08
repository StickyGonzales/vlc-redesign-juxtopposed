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

#include "rd_osd.hpp"

#include <vlc_common.h>
#include <vlc_variables.h>

RdOsd::RdOsd(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_parser([](const char* text) { return qfut(text); })
{
#ifdef VLC_BRAND_PUBLIC
    libvlc_int_t* libvlc = vlc_object_instance(m_intf);
    var_Create(libvlc, "cone-osd", VLC_VAR_STRING);
    var_AddCallback(libvlc, "cone-osd", onMessage, this);
    m_active = true;
#endif
}

RdOsd::~RdOsd()
{
    if (!m_active)
        return;
    libvlc_int_t* libvlc = vlc_object_instance(m_intf);
    var_DelCallback(libvlc, "cone-osd", onMessage, this);
    // from now on the core draws its messages again (a video output outliving the interface)
    var_Destroy(libvlc, "cone-osd");
}

namespace {
// how long after Auto-sync set a delay the core's message for it is expected (it is queued from
// the core's thread right away)
constexpr qint64 kSyncMessageWindowMs = 1500;
}

// any thread of the core: the message goes to the interface's thread
int RdOsd::onMessage(vlc_object_t*, const char*, vlc_value_t, vlc_value_t value, void* data)
{
    auto* self = static_cast<RdOsd*>(data);
    const QString payload = QString::fromUtf8(value.psz_string ? value.psz_string : "");
    QMetaObject::invokeMethod(self, [self, payload]() { self->receive(payload); },
                              Qt::QueuedConnection);
    return VLC_SUCCESS;
}

void RdOsd::receive(const QString& payload)
{
    // "msg" or "icon", the text or icon name, the key that caused it (src/video_output/video_text.c)
    const QStringList parts = payload.split(QChar(0x1f));
    if (parts.size() < 2)
        return;
    const rdosd::Message message = parts.at(0) == QLatin1String("icon") ? m_parser.icon(parts.at(1))
                                                                        : m_parser.message(parts.at(1));
    // the delay Auto-sync set: its own message ("Moved -2.3 s") is already showing
    if (message.subtitleDelay && m_syncDelaySet.isValid())
    {
        const bool expected = message.delayMs == m_syncDelayMs
                              && !m_syncDelaySet.hasExpired(kSyncMessageWindowMs);
        m_syncDelaySet.invalidate();
        if (expected)
            return;
    }
    m_message = message;
    m_key = parts.size() > 2 ? rdosd::Parser::keyText(parts.at(2)) : QString();
    m_duration = static_cast<int>(var_InheritInteger(m_intf, "osd-duration"));
    emit messageChanged();
}

void RdOsd::showSubtitleSync(const QString& label, const QString& value, int delayMs)
{
    m_syncDelayMs = delayMs;
    m_syncDelaySet.start();
    rdosd::Message msg;
    msg.icon = QStringLiteral("subtitles");
    msg.label = label;
    msg.value = value;
    m_message = msg;
    m_key.clear();
    m_duration = static_cast<int>(var_InheritInteger(m_intf, "osd-duration"));
    emit messageChanged();
}

void RdOsd::showText(const QString& icon, const QString& text)
{
    // "Scale: 125%" -> "Scale", "125%"
    rdosd::Message msg;
    msg.icon = icon;
    const qsizetype colon = text.indexOf(QLatin1String(": "));
    msg.label = colon > 0 ? text.left(colon) : text;
    msg.value = colon > 0 ? text.mid(colon + 2) : QString();
    m_message = msg;
    m_key.clear();
    m_duration = static_cast<int>(var_InheritInteger(m_intf, "osd-duration"));
    emit messageChanged();
}
