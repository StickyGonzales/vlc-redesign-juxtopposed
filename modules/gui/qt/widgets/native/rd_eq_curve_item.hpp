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
#ifndef RD_EQ_CURVE_ITEM_HPP
#define RD_EQ_CURVE_ITEM_HPP

#include <QColor>
#include <QPainterPath>
#include <QQuickPaintedItem>
#include <QVariantList>
#include <QVector>

/**
 * redesign: the curve icon of an equalizer preset (IA-40, P4-25, P4-26; Figma "EQ presets"
 * 2372:8487 and the Icon set's "name=EQ" variants), drawn from the preset's real band gains.
 *
 * Geometry of the Figma icons, in a 24 x 24 box (scaled to the item's size): a 22 px baseline
 * from x 1 to x 23 on y 12, 2 px with round caps (`lineColor`, FG/A2); boosted bands are
 * filled lobes standing on y 10, cut bands lobes hanging from y 14 (1 px clear of the
 * baseline), filled with `fillColor` (Accent/Main), at most 6 px tall, about 0.6 px per dB.
 * The lobe outline is a smooth curve through the band gains (monotone cubic, so it never
 * overshoots between two bands), the first and last gains held to the box's edges. A flat
 * preset shows the baseline only.
 *
 * The icon is painted once and again only when the gains, the colours (live accent and
 * theme) or the size change.
 */
class RdEqCurveItem : public QQuickPaintedItem
{
    Q_OBJECT

    // the preset's band gains in dB, low to high frequencies
    Q_PROPERTY(QVariantList bands READ bands WRITE setBands NOTIFY bandsChanged FINAL)
    Q_PROPERTY(QColor lineColor READ lineColor WRITE setLineColor NOTIFY lineColorChanged FINAL)
    Q_PROPERTY(QColor fillColor READ fillColor WRITE setFillColor NOTIFY fillColorChanged FINAL)

public:
    explicit RdEqCurveItem(QQuickItem* parent = nullptr);

    QVariantList bands() const { return m_bandList; }
    void setBands(const QVariantList& bands);
    QColor lineColor() const { return m_lineColor; }
    void setLineColor(const QColor& color);
    QColor fillColor() const { return m_fillColor; }
    void setFillColor(const QColor& color);

    void paint(QPainter* painter) override;

    // the filled lobes of `gains` in the 24 x 24 icon box
    static QPainterPath lobes(const QVector<double>& gains);

signals:
    void bandsChanged();
    void lineColorChanged();
    void fillColorChanged();

private:
    QVariantList m_bandList;
    QVector<double> m_gains;
    QPainterPath m_lobes;
    QColor m_lineColor;
    QColor m_fillColor;
};

#endif // RD_EQ_CURVE_ITEM_HPP
