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
#include "rd_filter_math.hpp"

#include <QPainter>
#include <QTransform>

#include <algorithm>
#include <cmath>

namespace {

int clip8(int v)
{
    return std::clamp(v, 0, 255);
}

// BT.601 limited range, the conversion VLC's filters assume (posterize.c, yuv_to_rgb)
struct Yuv { int y, u, v; };

Yuv toYuv(int r, int g, int b)
{
    return { ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16,
             ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128,
             ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128 };
}

QRgb toRgb(const Yuv& p, int alpha)
{
    const int c = p.y - 16;
    const int d = p.u - 128;
    const int e = p.v - 128;
    return qRgba(clip8((298 * c + 409 * e + 128) >> 8),
                 clip8((298 * c - 100 * d - 208 * e + 128) >> 8),
                 clip8((298 * c + 516 * d + 128) >> 8), alpha);
}

double number(const QVariantMap& values, const char* name, double fallback)
{
    const auto it = values.constFind(QLatin1String(name));
    if (it == values.constEnd())
        return fallback;
    bool ok = false;
    const double v = it->toDouble(&ok);
    return ok ? v : fallback;
}

bool enabled(const QVariantMap& values, const char* module)
{
    return values.value(QLatin1String(module)).toBool();
}

// adjust.c, 8 bit: the luma table (contrast, brightness, gamma) and the U/V rotation (hue) and
// scale (saturation), with its clipping
void adjust(QImage& image, const QVariantMap& values)
{
    const double contrast = number(values, "contrast", 1.0);
    const double brightness = number(values, "brightness", 1.0);
    const double hue = number(values, "hue", 0.0) * M_PI / 180.0;
    const double saturation = number(values, "saturation", 1.0);
    const double gamma = number(values, "gamma", 1.0);

    constexpr double fRange = 256.0;
    constexpr double fMax = fRange - 1.0;
    constexpr int iMid = 128;

    const int iCont = int(std::lround(contrast * fMax));
    int iLum = int(std::lround((brightness - 1.0) * fMax));
    const int iSat = int(saturation * fRange);
    const double fGamma = 1.0 / (gamma > 0 ? gamma : 1.0);
    iLum += iMid - iCont / 2;

    int gammaTable[256];
    int luma[256];
    for (int i = 0; i < 256; ++i)
        gammaTable[i] = std::clamp(int(std::pow(i / fMax, fGamma) * fMax), 0, 255);
    for (int i = 0; i < 256; ++i)
        luma[i] = gammaTable[std::clamp(iLum + iCont * i / 256, 0, 255)];

    const int iSin = int(std::sin(hue) * fMax);
    const int iCos = int(std::cos(hue) * fMax);
    const int iX = int((std::cos(hue) + std::sin(hue)) * fRange * iMid);
    const int iY = int((std::cos(hue) - std::sin(hue)) * fRange * iMid);

    for (int y = 0; y < image.height(); ++y)
    {
        QRgb* line = reinterpret_cast<QRgb*>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x)
        {
            const QRgb px = line[x];
            Yuv p = toYuv(qRed(px), qGreen(px), qBlue(px));
            p.y = luma[clip8(p.y)];
            const int u = p.u;
            const int v = p.v;
            p.u = clip8(((((((u * iCos + v * iSin - iX) + 128) >> 8) * iSat) + 128) >> 8) + 128);
            p.v = clip8(((((((v * iCos - u * iSin - iY) + 128) >> 8) * iSat) + 128) >> 8) + 128);
            line[x] = toRgb(p, qAlpha(px));
        }
    }
}

// sepia.c: y = y - y / 4 + intensity / 4, chroma set to the sepia tone
void sepia(QImage& image, const QVariantMap& values)
{
    const int intensity = std::clamp(int(number(values, "sepia-intensity", 120)), 0, 255);
    const int u = 128 - intensity / 6;
    const int v = 128 + intensity / 14;
    for (int y = 0; y < image.height(); ++y)
    {
        QRgb* line = reinterpret_cast<QRgb*>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x)
        {
            const QRgb px = line[x];
            Yuv p = toYuv(qRed(px), qGreen(px), qBlue(px));
            p.y = clip8(p.y - (p.y >> 2) + (intensity >> 2));
            p.u = u;
            p.v = v;
            line[x] = toRgb(p, qAlpha(px));
        }
    }
}

// invert.c: every plane inverted
void invert(QImage& image)
{
    for (int y = 0; y < image.height(); ++y)
    {
        QRgb* line = reinterpret_cast<QRgb*>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x)
        {
            const QRgb px = line[x];
            Yuv p = toYuv(qRed(px), qGreen(px), qBlue(px));
            p = { 255 - p.y, 255 - p.u, 255 - p.v };
            line[x] = toRgb(p, qAlpha(px));
        }
    }
}

// posterize.c: POSTERIZE_PIXEL on R, G and B
void posterize(QImage& image, const QVariantMap& values)
{
    const int level = std::clamp(int(number(values, "posterize-level", 6)), 2, 256);
    auto level8 = [level](int c) { return (((c * level) >> 8) * 255) / (level - 1); };
    for (int y = 0; y < image.height(); ++y)
    {
        QRgb* line = reinterpret_cast<QRgb*>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x)
        {
            const QRgb px = line[x];
            line[x] = qRgba(clip8(level8(qRed(px))), clip8(level8(qGreen(px))),
                            clip8(level8(qBlue(px))), qAlpha(px));
        }
    }
}

// transform.c: the seven transform types (the same turns the seek thumbnailer applies)
QImage transform(const QImage& image, const QVariantMap& values)
{
    const QString type = values.value(QStringLiteral("transform-type"), QStringLiteral("90")).toString();
    if (type == QLatin1String("90"))
        return image.transformed(QTransform().rotate(90));
    if (type == QLatin1String("180"))
        return image.transformed(QTransform().rotate(180));
    if (type == QLatin1String("270"))
        return image.transformed(QTransform().rotate(270));
    if (type == QLatin1String("hflip"))
        return image.mirrored(true, false);
    if (type == QLatin1String("vflip"))
        return image.mirrored(false, true);
    if (type == QLatin1String("transpose"))
        return image.transformed(QTransform().rotate(90)).mirrored(true, false);
    if (type == QLatin1String("antitranspose"))
        return image.transformed(QTransform().rotate(90)).mirrored(false, true);
    return image;
}

// rotate.c: turned counter-clockwise by the angle around the centre, same size, black outside
QImage rotate(const QImage& image, const QVariantMap& values)
{
    const double angle = number(values, "rotate-angle", 30.0);
    if (std::fmod(angle, 360.0) == 0)
        return image;
    QImage out(image.size(), QImage::Format_ARGB32);
    out.fill(Qt::black);
    QPainter painter(&out);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    painter.translate(image.width() / 2.0, image.height() / 2.0);
    painter.rotate(-angle);
    painter.translate(-image.width() / 2.0, -image.height() / 2.0);
    painter.drawImage(0, 0, image);
    painter.end();
    return out;
}

} // namespace

QImage RdFilterMath::apply(const QImage& frame, const QVariantMap& values)
{
    if (frame.isNull())
        return frame;
    QImage image = frame.convertToFormat(QImage::Format_ARGB32);

    // one fixed order, geometry first, then colours: VLC runs the filters in the order they were
    // turned on, so with several colour filters at once the video can differ from the preview
    if (enabled(values, "transform"))
        image = transform(image, values).convertToFormat(QImage::Format_ARGB32);
    if (enabled(values, "rotate"))
        image = rotate(image, values);
    if (enabled(values, "adjust"))
        adjust(image, values);
    if (enabled(values, "invert"))
        invert(image);
    if (enabled(values, "posterize"))
        posterize(image, values);
    if (enabled(values, "sepia"))
        sepia(image, values);
    return image;
}

QStringList RdFilterMath::previewedFilters()
{
    return { QStringLiteral("transform"), QStringLiteral("rotate"), QStringLiteral("adjust"),
             QStringLiteral("invert"), QStringLiteral("posterize"), QStringLiteral("sepia") };
}
