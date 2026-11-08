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
#ifndef RD_OSD_PARSE_HPP
#define RD_OSD_PARSE_HPP

#include <functional>

#include <QString>
#include <QVector>
#include <QRegularExpression>

/**
 * redesign (redesign/OSD_INVENTORY.md "Final style"): sorts a message of VLC's core ("Volume:
 * 80%", "Audio track: English", "Next chapter", ...) into what Cone's on-screen message shows:
 * an icon (pixmaps/redesign/<icon>.svg), a name, a value, and for the volume its level.
 *
 * The core's texts are translated with VLC's own catalog, so each pattern is matched in its
 * translated form (`translate`, qtr() in the interface; the identity in the unit test). A text no
 * pattern knows is shown as it is with the info icon. QtCore only.
 */
namespace rdosd {

struct Message
{
    QString icon;
    QString label;
    QString value;
    double level = -1;      // the volume, 1 = 100 %; -1 for every other message
    bool muted = false;
};

class Parser
{
public:
    using Translate = std::function<QString(const char*)>;

    explicit Parser(Translate translate);

    // a message of vout_OSDMessage
    Message message(const QString& text) const;
    // a play state of vout_OSDIcon: "play", "pause", "mute"
    Message icon(const QString& name) const;

    // the key as VLC names it ("Ctrl+Up"), as the message shows it ("Ctrl + ↑")
    static QString keyText(const QString& key);

private:
    enum class Kind { Plain, Value, Volume, Muted, Speed, Delay, Track, Time, Chapter, SubSync, Zoom, Pixels, Deinterlace };

    struct Pattern
    {
        QRegularExpression re;
        Kind kind;
        QString icon;
        QString label;
    };

    void add(const char* format, Kind kind, const char* icon, const char* label = nullptr);
    QRegularExpression compile(const QString& format) const;

    Translate m_tr;
    QVector<Pattern> m_patterns;
};

} // namespace rdosd

#endif
