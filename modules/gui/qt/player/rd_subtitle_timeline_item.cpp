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

#include "rd_subtitle_timeline_item.hpp"

#include <QQuickWindow>
#include <QSGFlatColorMaterial>
#include <QSGGeometryNode>
#include <QtMath>

#include <algorithm>

namespace {

// the played blocks and the unplayed blocks, one flat-colored triangle list each
class TimelineNode : public QSGNode
{
public:
    TimelineNode()
    {
        for (QSGGeometryNode* node : { &played, &unplayed })
        {
            node->setFlag(QSGNode::OwnedByParent, false);
            auto* geometry = new QSGGeometry(QSGGeometry::defaultAttributes_Point2D(), 0);
            geometry->setDrawingMode(QSGGeometry::DrawTriangles);
            node->setGeometry(geometry);
            node->setFlag(QSGNode::OwnsGeometry);
            node->setMaterial(new QSGFlatColorMaterial);
            node->setFlag(QSGNode::OwnsMaterial);
            appendChildNode(node);
        }
    }

    ~TimelineNode() override
    {
        removeAllChildNodes();
    }

    QSGGeometryNode played;
    QSGGeometryNode unplayed;
};

void setRects(QSGGeometryNode* node, const std::vector<QRectF>& rects)
{
    QSGGeometry* geometry = node->geometry();
    geometry->allocate(static_cast<int>(rects.size() * 6));
    QSGGeometry::Point2D* v = geometry->vertexDataAsPoint2D();
    for (const QRectF& r : rects)
    {
        const float l = static_cast<float>(r.left());
        const float t = static_cast<float>(r.top());
        const float rr = static_cast<float>(r.right());
        const float b = static_cast<float>(r.bottom());
        v[0].set(l, t); v[1].set(rr, t); v[2].set(l, b);
        v[3].set(rr, t); v[4].set(rr, b); v[5].set(l, b);
        v += 6;
    }
    node->markDirty(QSGNode::DirtyGeometry);
}

void setColor(QSGGeometryNode* node, const QColor& color)
{
    auto* material = static_cast<QSGFlatColorMaterial*>(node->material());
    if (material->color() == color)
        return;
    material->setColor(color);
    node->markDirty(QSGNode::DirtyMaterial);
}

} // namespace

RdSubtitleTimelineItem::RdSubtitleTimelineItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
    connect(this, &RdSubtitleTimelineItem::layoutChanged, this, &RdSubtitleTimelineItem::invalidate);
    connect(this, &RdSubtitleTimelineItem::playheadChanged, this, [this]() { update(); });
    connect(this, &RdSubtitleTimelineItem::lookChanged, this, [this]() {
        m_colorsDirty = true;
        update();
    });
}

RdSubtitleTimelineItem::~RdSubtitleTimelineItem()
{
    hold(false);
}

void RdSubtitleTimelineItem::setSource(RdSubtitleTimeline* source)
{
    if (source == m_source)
        return;
    hold(false);
    if (m_source)
        disconnect(m_source, nullptr, this, nullptr);
    m_source = source;
    if (m_source)
        connect(m_source, &RdSubtitleTimeline::cuesChanged, this, [this]() {
            updateReady();
            invalidate();
        });
    hold(m_active && m_source);
    updateReady();
    invalidate();
    emit sourceChanged();
}

void RdSubtitleTimelineItem::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;
    hold(m_active && m_source);
    updateReady();
    emit activeChanged();
}

void RdSubtitleTimelineItem::hold(bool held)
{
    if (held == m_held)
        return;
    m_held = held;
    if (!m_source)
        return;
    if (held)
        m_source->acquire();
    else
        m_source->release();
}

void RdSubtitleTimelineItem::updateReady()
{
    const bool ready = m_held && m_source && m_source->ready();
    if (ready == m_ready)
        return;
    m_ready = ready;
    invalidate();
    emit readyChanged();
}

void RdSubtitleTimelineItem::invalidate()
{
    polish();
}

void RdSubtitleTimelineItem::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        invalidate();
}

void RdSubtitleTimelineItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemDevicePixelRatioHasChanged || (change == ItemSceneChange && value.window))
        invalidate();
}

void RdSubtitleTimelineItem::updatePolish()
{
    m_blocks.clear();
    if (m_ready && m_source && window() && width() > 0 && height() > 0 && m_windowLength > 0)
    {
        const qreal dpr = window()->effectiveDevicePixelRatio();
        const qreal pixel = 1 / dpr;
        const qreal left = m_horizontalInset;
        const qreal right = width() - m_horizontalInset;
        const qreal scale = width() / m_windowLength;
        const qreal windowEnd = m_windowStart + m_windowLength;
        const auto snap = [dpr](qreal x) { return qRound(x * dpr) / dpr; };

        // the cues are sorted by start: every cue starting before the window's end, those
        // that end before its start left out (a few thousand cues at most, and this runs only
        // when the window, the delay or the size change)
        const std::vector<RdSubtitleTimeline::Cue>& cues = m_source->cues();
        const auto first = std::lower_bound(cues.begin(), cues.end(), windowEnd - m_delay,
                                             [](const RdSubtitleTimeline::Cue& cue, qreal t) {
            return cue.start < t;
        });
        for (auto it = cues.begin(); it != first; ++it)
        {
            const qreal start = it->start + m_delay;
            const qreal end = it->end + m_delay;
            if (end <= m_windowStart || start >= windowEnd)
                continue;
            const qreal x0 = std::max(left, snap((start - m_windowStart) * scale));
            const qreal x1 = std::min(right, std::max(x0 + pixel, snap((end - m_windowStart) * scale)));
            if (x1 > x0)
                m_blocks.emplace_back(x0, 0, x1 - x0, height());
        }
    }
    update();
}

bool RdSubtitleTimelineItem::cueAt(qreal x, qreal slop) const
{
    return std::any_of(m_blocks.begin(), m_blocks.end(), [x, slop](const QRectF& block) {
        return x >= block.left() - slop && x <= block.right() + slop;
    });
}

QSGNode* RdSubtitleTimelineItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    if (!m_ready || m_blocks.empty())
    {
        delete oldNode;
        return nullptr;
    }

    auto* node = static_cast<TimelineNode*>(oldNode);
    if (!node)
    {
        node = new TimelineNode;
        m_colorsDirty = true;
    }
    if (m_colorsDirty)
    {
        setColor(&node->played, m_playedColor);
        setColor(&node->unplayed, m_unplayedColor);
        m_colorsDirty = false;
    }

    // a block under the playhead is cut there
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1;
    const qreal cut = qRound(m_playheadX * dpr) / dpr;
    std::vector<QRectF> played;
    std::vector<QRectF> unplayed;
    for (const QRectF& block : m_blocks)
    {
        if (block.left() < cut)
            played.emplace_back(QPointF(block.left(), block.top()),
                                QPointF(std::min(block.right(), cut), block.bottom()));
        if (block.right() > cut)
            unplayed.emplace_back(QPointF(std::max(block.left(), cut), block.top()),
                                  block.bottomRight());
    }
    setRects(&node->played, played);
    setRects(&node->unplayed, unplayed);
    return node;
}
