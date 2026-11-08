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
#ifndef RD_OSD_HPP
#define RD_OSD_HPP

#include <QObject>
#include <QString>

#include "qt.hpp"
#include "player/rd_osd_parse.hpp"

/**
 * redesign (redesign/OSD_INVENTORY.md "Final style"): the on-screen messages in Cone's style.
 *
 * Cone build only: the interface creates "cone-osd" on the libvlc object, so the core hands its
 * messages here (src/video_output/video_text.c, video_widgets.c) instead of drawing them into the
 * video; RdOsd.qml in the player draws the latest one. The core draws them itself when no Qt
 * interface listens (the vlc profile, a cli-only start).
 */
class RdOsd : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool active READ active CONSTANT FINAL)
    Q_PROPERTY(QString icon READ icon NOTIFY messageChanged FINAL)
    Q_PROPERTY(QString label READ label NOTIFY messageChanged FINAL)
    Q_PROPERTY(QString value READ value NOTIFY messageChanged FINAL)
    Q_PROPERTY(QString key READ key NOTIFY messageChanged FINAL)
    Q_PROPERTY(double level READ level NOTIFY messageChanged FINAL)
    Q_PROPERTY(bool muted READ muted NOTIFY messageChanged FINAL)
    // how long a message stays: "Show feedback for" (osd-duration)
    Q_PROPERTY(int duration READ duration NOTIFY messageChanged FINAL)

public:
    explicit RdOsd(qt_intf_t* intf, QObject* parent = nullptr);
    ~RdOsd() override;

    bool active() const { return m_active; }
    QString icon() const { return m_message.icon; }
    QString label() const { return m_message.label; }
    QString value() const { return m_message.value; }
    QString key() const { return m_key; }
    double level() const { return m_message.level; }
    bool muted() const { return m_message.muted; }
    int duration() const { return m_duration; }

    // a notification of the interface itself (UINotifier: "Scale: 125%", "Minimal View", ...)
    Q_INVOKABLE void showText(const QString& icon, const QString& text);

signals:
    // a new message (also when it is the same text again, to restart its time)
    void messageChanged();

private:
    void receive(const QString& payload);

    static int onMessage(vlc_object_t*, const char*, vlc_value_t, vlc_value_t, void*);

    qt_intf_t* m_intf;
    bool m_active = false;
    rdosd::Parser m_parser;
    rdosd::Message m_message;
    QString m_key;
    int m_duration = 2750;
};

#endif
