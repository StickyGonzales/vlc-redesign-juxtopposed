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

#include "rd_osd_parse.hpp"

#include <QFileInfo>
#include <QLocale>

namespace rdosd {

Parser::Parser(Translate translate)
    : m_tr(std::move(translate))
{
    // the core's texts (src/player/osd.c, player.c, playlist/control.c, control/hotkeys.c,
    // video_output/vout_intf.c; redesign/OSD_INVENTORY.md), the specific ones first
    add("Volume: %ld%%", Kind::Volume, "volume_value-high", "Volume");
    add("Muted", Kind::Muted, "volume_value-muted", "Muted");
    add("Speed: %.2fx", Kind::Speed, "speed", "Speed");
    add("%s delay: %i ms", Kind::Delay, "audio");
    add("%s track: %s", Kind::Track, "audio");
    add("%s tracks: %s", Kind::Track, "audio");
    add("Sub sync: bookmarked audio time", Kind::SubSync, "subtitles", "Sub sync");
    add("Sub sync: bookmarked subtitle time", Kind::SubSync, "subtitles", "Sub sync");
    add("Sub sync: set bookmarks first!", Kind::SubSync, "subtitles", "Sub sync");
    add("Sub sync: corrected %lld ms (total delay = %lld ms)", Kind::SubSync, "subtitles", "Sub sync");
    add("Sub sync: delay reset", Kind::SubSync, "subtitles", "Sub sync");
    add("Aspect ratio: %s", Kind::Value, "window", "Aspect ratio");
    add("Crop: %s", Kind::Value, "window", "Crop");
    add("Top crop: %d px", Kind::Pixels, "window", "Top crop");
    add("Bottom crop: %d px", Kind::Pixels, "window", "Bottom crop");
    add("Left crop: %d px", Kind::Pixels, "window", "Left crop");
    add("Right crop: %d px", Kind::Pixels, "window", "Right crop");
    add("Zoom mode: %s", Kind::Value, "view", "Zoom");
    add("Zoom: x%.2f", Kind::Zoom, "view", "Zoom");
    add("Zooming reset", Kind::Plain, "view", "Zoom reset");
    add("Subtitle position %d px", Kind::Pixels, "subtitles", "Subtitle position");
    add("Secondary subtitle position %d px", Kind::Pixels, "subtitles", "Secondary subtitle position");
    add("%s subtitle control", Kind::Value, "subtitles", "Subtitle control");
    add("Deinterlace %s (%s)", Kind::Deinterlace, "eye", "Deinterlace");
    add("Random: %s", Kind::Value, "shuffle_direction-right", "Shuffle");
    add("Loop: %s", Kind::Value, "repeat_direction-right", "Loop");
    add("Audio device: %s", Kind::Value, "audio", "Audio device");
    add("Program Service ID: %s", Kind::Value, "tv", "Program");
    add("Projection: %s", Kind::Value, "view", "Projection");
    add("Chapter %ld", Kind::Chapter, "chapters", "Chapter");
    add("Next chapter", Kind::Plain, "chapters");
    add("Previous chapter", Kind::Plain, "chapters");
    add("Next title", Kind::Plain, "playback");
    add("Previous title", Kind::Plain, "playback");
    add("Next frame", Kind::Plain, "playback");
    add("Previous frame", Kind::Plain, "playback");
    add("Next", Kind::Plain, "next");
    add("Previous", Kind::Plain, "previous");
    add("Recording", Kind::Plain, "record");
    add("Recording done", Kind::Plain, "record");
    add("Scaled to screen", Kind::Plain, "window");
    add("Original size", Kind::Plain, "window");
    add("Subtitle slave added", Kind::Plain, "subtitles", "Subtitle file added");
    add("Slave added", Kind::Plain, "file", "File added");
    add("%s / %s", Kind::Time, "playback");
}

void Parser::add(const char* format, Kind kind, const char* icon, const char* label)
{
    Pattern pattern { compile(m_tr(format)), kind, QString::fromLatin1(icon),
                      label ? m_tr(label) : QString() };
    m_patterns.append(pattern);
    // "Speed: %.2fx" and a few others are not translated by the core: the English form too
    const QRegularExpression english = compile(QString::fromUtf8(format));
    if (english.pattern() != pattern.re.pattern())
        m_patterns.append({ english, kind, pattern.icon, pattern.label });
}

QRegularExpression Parser::compile(const QString& format) const
{
    // the literal parts escaped, every conversion (%s, %ld, %.2f, %lld, %i, %d) a group
    static const QRegularExpression conversion(QStringLiteral("%(%|[-+ #0-9.]*[hlLqjzt]*[a-zA-Z])"));
    QString re = QStringLiteral("^");
    qsizetype last = 0;
    auto it = conversion.globalMatch(format);
    while (it.hasNext())
    {
        const auto m = it.next();
        re += QRegularExpression::escape(format.mid(last, m.capturedStart() - last));
        re += m.captured(1) == QLatin1String("%") ? QStringLiteral("%") : QStringLiteral("(.*?)");
        last = m.capturedEnd();
    }
    re += QRegularExpression::escape(format.mid(last)) + QStringLiteral("$");
    return QRegularExpression(re, QRegularExpression::DotMatchesEverythingOption);
}

namespace {

QString number(double value, int decimals)
{
    // "1.50" -> "1.5", "2.00" -> "2", in the user's locale
    QString text = QLocale().toString(value, 'f', decimals);
    const QChar point = QLocale().decimalPoint().at(0);
    if (text.contains(point))
    {
        while (text.endsWith(QLatin1Char('0')))
            text.chop(1);
        if (text.endsWith(point))
            text.chop(1);
    }
    return text;
}

} // namespace

Message Parser::message(const QString& text) const
{
    for (const Pattern& p : m_patterns)
    {
        const auto m = p.re.match(text);
        if (!m.hasMatch())
            continue;
        Message msg;
        msg.icon = p.icon;
        msg.label = p.label;
        switch (p.kind)
        {
        case Kind::Plain:
            if (msg.label.isEmpty())
                msg.label = text;
            break;
        case Kind::Value:
            msg.value = m.captured(1);
            break;
        case Kind::Volume:
        {
            const int volume = m.captured(1).toInt();
            msg.value = QStringLiteral("%1%").arg(volume);
            msg.level = volume / 100.0;
            break;
        }
        case Kind::Muted:
            msg.level = 0;
            msg.muted = true;
            break;
        case Kind::Speed:
            msg.value = number(m.captured(1).toDouble(), 2) + QStringLiteral("×");
            break;
        case Kind::Delay:
        case Kind::Track:
        {
            // the category comes untranslated from the core (src/player/player.h)
            const QString category = m.captured(1);
            const bool delay = p.kind == Kind::Delay;
            if (category == QLatin1String("Subtitle"))
            {
                msg.icon = QStringLiteral("subtitles");
                msg.label = delay ? m_tr("Subtitle delay") : m_tr("Subtitles");
            }
            else if (category == QLatin1String("Video"))
            {
                msg.icon = QStringLiteral("video");
                msg.label = delay ? m_tr("Video delay") : m_tr("Video track");
            }
            else if (category == QLatin1String("Audio"))
            {
                msg.label = delay ? m_tr("Audio delay") : m_tr("Audio");
            }
            else
            {
                // a secondary subtitle's own name (2.4)
                msg.icon = QStringLiteral("subtitles");
                msg.label = delay ? m_tr("Subtitle delay") : category;
            }
            if (delay)
            {
                const int ms = m.captured(2).toInt();
                msg.value = QStringLiteral("%1%2 ms").arg(ms > 0 ? QStringLiteral("+") : QString())
                                                      .arg(ms);
            }
            else
            {
                msg.value = m.captured(2) == QLatin1String("N/A") ? m_tr("Off") : m.captured(2);
            }
            break;
        }
        case Kind::Time:
            // "00:12:40 / 00:42:10"; anything else with a " / " is not a time
            if (!m.captured(1).contains(QLatin1Char(':')))
                continue;
            msg.label = m.captured(1);
            msg.value = QStringLiteral("/ ") + m.captured(2);
            break;
        case Kind::Chapter:
            // the core counts from 0 (redesign/OSD_INVENTORY.md 4.4)
            msg.value = QString::number(m.captured(1).toLongLong() + 1);
            break;
        case Kind::SubSync:
        {
            const qsizetype colon = text.indexOf(QLatin1String(": "));
            msg.value = colon >= 0 ? text.mid(colon + 2) : text;
            if (!msg.value.isEmpty())
                msg.value[0] = msg.value[0].toUpper();
            break;
        }
        case Kind::Zoom:
            msg.value = QStringLiteral("×") + number(m.captured(1).toDouble(), 2);
            break;
        case Kind::Pixels:
            msg.value = QStringLiteral("%1 px").arg(m.captured(1));
            break;
        case Kind::Deinterlace:
            msg.value = QStringLiteral("%1 (%2)").arg(m.captured(1), m.captured(2));
            break;
        }
        return msg;
    }

    Message msg;
    // the snapshot's message is the saved file's path (6.2)
    const QFileInfo file(text);
    if (file.isAbsolute() && file.exists())
    {
        msg.icon = QStringLiteral("snapshot");
        msg.label = m_tr("Snapshot saved");
        msg.value = file.fileName();
        return msg;
    }
    msg.icon = QStringLiteral("info");
    msg.label = text;
    return msg;
}

Message Parser::icon(const QString& name) const
{
    Message msg;
    if (name == QLatin1String("pause"))
    {
        msg.icon = QStringLiteral("pause");
        msg.label = m_tr("Paused");
    }
    else if (name == QLatin1String("mute"))
    {
        msg.icon = QStringLiteral("volume_value-muted");
        msg.label = m_tr("Muted");
        msg.level = 0;
        msg.muted = true;
    }
    else
    {
        msg.icon = QStringLiteral("play");
        msg.label = m_tr("Playing");
    }
    return msg;
}

QString Parser::keyText(const QString& key)
{
    QStringList parts = key.split(QLatin1Char('+'), Qt::SkipEmptyParts);
    // "Ctrl++" (the plus key)
    if (key.endsWith(QLatin1String("++")))
        parts << QStringLiteral("+");
    for (QString& part : parts)
    {
        part = part.trimmed();
        if (part == QLatin1String("Up"))
            part = QStringLiteral("↑");
        else if (part == QLatin1String("Down"))
            part = QStringLiteral("↓");
        else if (part == QLatin1String("Left"))
            part = QStringLiteral("←");
        else if (part == QLatin1String("Right"))
            part = QStringLiteral("→");
        else if (part.size() == 1)
            part = part.toUpper();
    }
    return parts.join(QStringLiteral(" + "));
}

} // namespace rdosd
