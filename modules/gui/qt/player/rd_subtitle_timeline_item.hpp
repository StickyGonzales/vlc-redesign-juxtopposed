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
#ifndef RD_SUBTITLE_TIMELINE_ITEM_HPP
#define RD_SUBTITLE_TIMELINE_ITEM_HPP

#include <QColor>
#include <QPointer>
#include <QQuickItem>
#include <QRectF>

#include <vector>

#include "player/rd_subtitle_timeline.hpp"

/**
 * redesign: the cue blocks of the subtitle timeline seek bar (P3-16, IA-27, video 6:52-7:04):
 * one square-cornered block as tall as the item for every subtitle line of the visible time
 * window, the part left of the playhead in `playedColor`, the rest in `unplayedColor` (the seek
 * bar draws the trough, the played fill and the playhead).
 *
 * The window is `windowStart` to `windowStart + windowLength` (milliseconds of the media),
 * across the item's whole width; a cue is drawn `delay` milliseconds later than its file says
 * (VLC's subtitle delay), so a drag that changes the delay slides every block. Blocks keep
 * `horizontalInset` free at both ends (the trough's rounded corners) and are at least one
 * device pixel wide.
 *
 * Drawing: the visible blocks are worked out on the GUI thread (updatePolish) and drawn as two
 * flat-colored triangle lists; a moving playhead only moves the cut between them.
 *
 * `source` is the RdSubtitleTimeline singleton; while `active`, the item holds it (acquire()),
 * which reads the selected subtitle file. `ready`: there are cues to show.
 */
class RdSubtitleTimelineItem : public QQuickItem
{
    Q_OBJECT

    Q_PROPERTY(RdSubtitleTimeline* source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged FINAL)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)

    Q_PROPERTY(qreal windowStart MEMBER m_windowStart NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal windowLength MEMBER m_windowLength NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal delay MEMBER m_delay NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal horizontalInset MEMBER m_horizontalInset NOTIFY layoutChanged FINAL)
    // the playhead's center in item coordinates
    Q_PROPERTY(qreal playheadX MEMBER m_playheadX NOTIFY playheadChanged FINAL)

    Q_PROPERTY(QColor playedColor MEMBER m_playedColor NOTIFY lookChanged FINAL)
    Q_PROPERTY(QColor unplayedColor MEMBER m_unplayedColor NOTIFY lookChanged FINAL)

public:
    explicit RdSubtitleTimelineItem(QQuickItem* parent = nullptr);
    ~RdSubtitleTimelineItem() override;

    RdSubtitleTimeline* source() const { return m_source; }
    void setSource(RdSubtitleTimeline* source);
    bool active() const { return m_active; }
    void setActive(bool active);
    bool ready() const { return m_ready; }

    // a block lies under `x` (item coordinates), `slop` pixels around it count too
    Q_INVOKABLE bool cueAt(qreal x, qreal slop) const;

signals:
    void sourceChanged();
    void activeChanged();
    void readyChanged();
    void layoutChanged();
    void playheadChanged();
    void lookChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void updatePolish() override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;

private:
    void hold(bool held);
    void updateReady();
    void invalidate();

    QPointer<RdSubtitleTimeline> m_source;
    bool m_active = false;
    bool m_held = false;
    bool m_ready = false;

    qreal m_windowStart = 0;
    qreal m_windowLength = 60000;
    qreal m_delay = 0;
    qreal m_horizontalInset = 0;
    qreal m_playheadX = 0;
    QColor m_playedColor;
    QColor m_unplayedColor;

    // the visible blocks in item coordinates (GUI thread, made in updatePolish)
    std::vector<QRectF> m_blocks;
    bool m_colorsDirty = true;
};

#endif // RD_SUBTITLE_TIMELINE_ITEM_HPP
