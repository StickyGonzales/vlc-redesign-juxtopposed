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
constexpr double kPxPerDb = 0.6;       // Figma: 9.6 dB is the full 6 px, 4.8 dB about 3 px
constexpr double kMinGain = 0.5;       // VLC's "0" bands are -1.1e-15 dB: flat
constexpr double kStep = 0.25;         // curve sampling, in box units

// monotone cubic interpolation (Fritsch-Carlson) through (xs, ys): no overshoot between two
// bands, so a lobe never gets taller than its tallest band or swaps sides between two cuts
class MonotoneCubic
{
public:
    MonotoneCubic(const QVector<double>& xs, const QVector<double>& ys)
        : m_x(xs), m_y(ys), m_m(xs.size(), 0.0)
    {
        const int n = xs.size();
        if (n < 2)
            return;
        QVector<double> d(n - 1);
        for (int i = 0; i < n - 1; ++i)
            d[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]);
        m_m[0] = d[0];
        m_m[n - 1] = d[n - 2];
        for (int i = 1; i < n - 1; ++i)
            m_m[i] = (d[i - 1] * d[i] <= 0) ? 0.0 : (d[i - 1] + d[i]) / 2;
        for (int i = 0; i < n - 1; ++i)
        {
            if (d[i] == 0)
            {
                m_m[i] = m_m[i + 1] = 0;
                continue;
            }
            const double a = m_m[i] / d[i];
            const double b = m_m[i + 1] / d[i];
            const double s = a * a + b * b;
            if (s > 9)
            {
                const double t = 3 / std::sqrt(s);
                m_m[i] = t * a * d[i];
                m_m[i + 1] = t * b * d[i];
            }
        }
    }

    double at(double x) const
    {
        const int n = m_x.size();
        if (n == 0)
            return 0;
        if (n == 1 || x <= m_x[0])
            return m_y[0];
        if (x >= m_x[n - 1])
            return m_y[n - 1];
        int i = 0;
        while (i < n - 2 && x > m_x[i + 1])
            ++i;
        const double h = m_x[i + 1] - m_x[i];
        const double t = (x - m_x[i]) / h;
        const double t2 = t * t;
        const double t3 = t2 * t;
        return (2 * t3 - 3 * t2 + 1) * m_y[i] + (t3 - 2 * t2 + t) * h * m_m[i]
               + (-2 * t3 + 3 * t2) * m_y[i + 1] + (t3 - t2) * h * m_m[i + 1];
    }

private:
    QVector<double> m_x;
    QVector<double> m_y;
    QVector<double> m_m;
};

double lobeHeight(double gain)
{
    return std::min(kMaxLobe, std::abs(gain) * kPxPerDb);
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

    // the band centres spread over the baseline, the outer gains held to its ends
    QVector<double> xs, ys;
    xs.append(kLeft);
    ys.append(gains.first());
    for (int i = 0; i < n; ++i)
    {
        xs.append(kLeft + (kRight - kLeft) * (i + 0.5) / n);
        ys.append(gains[i]);
    }
    xs.append(kRight);
    ys.append(gains.last());
    const MonotoneCubic curve(xs, ys);

    // the sign of a sample: 1 boosted, -1 cut, 0 flat
    auto side = [](double gain) { return gain >= kMinGain ? 1 : (gain <= -kMinGain ? -1 : 0); };
    auto edgeY = [](int s) { return s > 0 ? kBoostFloor : kCutCeiling; };
    auto curveY = [](int s, double gain) {
        return s > 0 ? kBoostFloor - lobeHeight(gain) : kCutCeiling + lobeHeight(gain);
    };

    int current = 0;
    double prevX = kLeft;
    double prevGain = curve.at(kLeft);
    for (double x = kLeft; x <= kRight + 1e-9; x += kStep)
    {
        const double gain = curve.at(x);
        const int s = side(gain);
        if (s != current)
        {
            // where the curve crosses the flat threshold between the two samples
            const double limit = current != 0 ? current * kMinGain : s * kMinGain;
            double cx = x;
            if (gain != prevGain && x > kLeft)
                cx = std::clamp(prevX + (limit - prevGain) / (gain - prevGain) * (x - prevX), prevX, x);
            if (current != 0)
            {
                path.lineTo(cx, edgeY(current));
                path.closeSubpath();
            }
            if (s != 0)
            {
                path.moveTo(cx, edgeY(s));
                path.lineTo(cx, curveY(s, gain));
            }
            current = s;
        }
        if (current != 0)
            path.lineTo(x, curveY(current, gain));
        prevX = x;
        prevGain = gain;
    }
    if (current != 0)
    {
        path.lineTo(kRight, edgeY(current));
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
