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
#include "rd_eq_curve_item.hpp"

#include <QPainter>
#include <QPen>

#include <algorithm>
#include <cmath>

namespace {

// Figma icon box and its parts (the "name=EQ" icons, 24 x 24)
constexpr double kBox = 24.0;
constexpr double kLeft = 1.0;          // baseline and lobes from x 1 ...
constexpr double kRight = 23.0;        // ... to x 23
constexpr double kBaseline = 12.0;     // 2 px baseline centred on y 12
constexpr double kBaselineWidth = 2.0;
constexpr double kBoostFloor = 10.0;   // boosted lobes stand on y 10
constexpr double kCutCeiling = 14.0;   // cut lobes hang from y 14
constexpr double kMaxLobe = 6.0;       // lobes reach y 4 / y 20 at most
constexpr double kPxPerDb = 0.6;       // Figma: 4.8 dB about 3 px ...
constexpr double kSoftGain = 1.15;     // ... easing off towards kMaxLobe (a rounded top)
constexpr double kMinGain = 0.4;       // flat below this (VLC's "0" bands are -1.1e-15 dB)
constexpr double kSpread = 0.8;        // each band's width, in band spacings (Gaussian sigma)
constexpr double kStep = 0.125;        // curve sampling, in box units

// the preset's curve at x: a blend of the band gains, each band weighted by a Gaussian around
// its centre, so the curve rises and falls in rounded humps (Figma's hand-drawn lobes) instead
// of holding a gain flat across a band
double blendedGain(const QVector<double>& centres, const QVector<double>& gains, double sigma,
                   double x)
{
    double sum = 0;
    double weights = 0;
    for (int i = 0; i < gains.size(); ++i)
    {
        const double d = (x - centres[i]) / sigma;
        const double w = std::exp(-0.5 * d * d);
        sum += w * gains[i];
        weights += w;
    }
    return weights > 0 ? sum / weights : 0;
}

// the lobe height of a gain: kPxPerDb per dB at first, easing off smoothly towards kMaxLobe
double lobeHeight(double gain)
{
    const double u = std::abs(gain) * kPxPerDb / kMaxLobe * kSoftGain;
    return kMaxLobe * u / std::pow(1 + u * u * u * u, 0.25);
}

} // namespace

RdEqCurveItem::RdEqCurveItem(QQuickItem* parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    setImplicitSize(kBox, kBox);
}

void RdEqCurveItem::setBands(const QVariantList& bands)
{
    if (bands == m_bandList)
        return;
    m_bandList = bands;
    m_gains.clear();
    m_gains.reserve(bands.size());
    for (const QVariant& v : bands)
        m_gains.append(v.toDouble());
    m_lobes = lobes(m_gains);
    emit bandsChanged();
    update();
}

void RdEqCurveItem::setLineColor(const QColor& color)
{
    if (color == m_lineColor)
        return;
    m_lineColor = color;
    emit lineColorChanged();
    update();
}

void RdEqCurveItem::setFillColor(const QColor& color)
{
    if (color == m_fillColor)
        return;
    m_fillColor = color;
    emit fillColorChanged();
    update();
}

QPainterPath RdEqCurveItem::lobes(const QVector<double>& gains)
{
    QPainterPath path;
    const int n = gains.size();
    if (n == 0)
        return path;

    // the band centres spread over the baseline
    const double spacing = (kRight - kLeft) / n;
    QVector<double> centres(n);
    for (int i = 0; i < n; ++i)
        centres[i] = kLeft + spacing * (i + 0.5);

    // a run of samples on one side of the baseline is one lobe: from its floor (y 10 above,
    // y 14 below) out to the curve and back; it tapers to the floor where the curve crosses
    // zero, and stands upright only at the ends of the box
    int side = 0;
    double lastX = kLeft;
    for (double x = kLeft; x <= kRight + 1e-9; x += kStep)
    {
        const double gain = blendedGain(centres, gains, kSpread * spacing, x);
        const int s = gain >= kMinGain ? 1 : (gain <= -kMinGain ? -1 : 0);
        const double floor = s > 0 ? kBoostFloor : kCutCeiling;
        if (s != side)
        {
            if (side != 0)
            {
                path.lineTo(lastX, side > 0 ? kBoostFloor : kCutCeiling);
                path.closeSubpath();
            }
            if (s != 0)
                path.moveTo(x, floor);
            side = s;
        }
        if (side != 0)
            path.lineTo(x, side > 0 ? floor - lobeHeight(gain) : floor + lobeHeight(gain));
        lastX = x;
    }
    if (side != 0)
    {
        path.lineTo(lastX, side > 0 ? kBoostFloor : kCutCeiling);
        path.closeSubpath();
    }
    return path;
}

void RdEqCurveItem::paint(QPainter* painter)
{
    const double scale = std::min(width(), height()) / kBox;
    if (scale <= 0)
        return;
    painter->setRenderHint(QPainter::Antialiasing);
    painter->translate((width() - kBox * scale) / 2, (height() - kBox * scale) / 2);
    painter->scale(scale, scale);

    QPen pen(m_lineColor, kBaselineWidth);
    pen.setCapStyle(Qt::RoundCap);
    painter->setPen(pen);
    painter->drawLine(QPointF(kLeft, kBaseline), QPointF(kRight, kBaseline));

    if (!m_lobes.isEmpty())
    {
        painter->setPen(Qt::NoPen);
        painter->setBrush(m_fillColor);
        painter->drawPath(m_lobes);
    }
}
