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
#ifndef RD_SUBTITLE_LIFT_HPP
#define RD_SUBTITLE_LIFT_HPP

#include <QObject>

#include "qt.hpp"

class PlayerController;

/**
 * redesign: keeps the subtitles above the control bar while the bar covers the bottom of the
 * picture (redesign/BETA_SUBS_NOTES.md).
 *
 * The player sets `lift`, the height in display pixels of the picture the bar covers (0 while
 * the bars are hidden); it goes to every video output as "sub-ui-margin", which VLC adds to the
 * user's "Subtitle position" (sub-margin) and applies to all subtitles, without an on-screen
 * message. A new video output gets the current value.
 *
 * `pictureAspect` is the display aspect ratio of the picture (the playing video track with its
 * pixel aspect and orientation, or the forced aspect ratio), 0 while unknown: the player uses it
 * to find the bottom of the picture inside the video surface (letterboxed films need no lift).
 */
class RdSubtitleLift : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int lift READ lift WRITE setLift NOTIFY liftChanged FINAL)
    Q_PROPERTY(double pictureAspect READ pictureAspect NOTIFY pictureAspectChanged FINAL)

public:
    RdSubtitleLift(PlayerController* player, QObject* parent = nullptr);

    int lift() const { return m_lift; }
    void setLift(int lift);

    double pictureAspect() const { return m_pictureAspect; }

signals:
    void liftChanged();
    void pictureAspectChanged();

private:
    void apply();
    void updatePictureAspect();

    PlayerController* m_player = nullptr;
    int m_lift = 0;
    double m_pictureAspect = 0.;
};

#endif // RD_SUBTITLE_LIFT_HPP
