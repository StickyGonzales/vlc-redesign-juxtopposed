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

#include "rd_stereo_test.hpp"

#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QtEndian>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <utility>

#include <vlc_aout.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_url.h>
#include <vlc_variables.h>

namespace {

constexpr double pi = 3.14159265358979323846;
constexpr int sampleRate = 44100;
constexpr int channels = 2;
// a 440 Hz tone at -10 dBFS: 0.4 s on the left, 0.2 s of silence, 0.4 s on the right, then a
// short silence so the end of the tone is not cut by the output
constexpr double toneHz = 440.0;
constexpr double toneLevel = 0.3;
constexpr double toneSeconds = 0.4;
constexpr double gapSeconds = 0.2;
constexpr double tailSeconds = 0.1;
// raised-cosine fade in and out of each tone (no click)
constexpr double fadeSeconds = 0.02;

void appendSample(QByteArray &data, double value)
{
    const qint16 sample = qToLittleEndian(static_cast<qint16>(std::lround(value * 32767.0)));
    data.append(reinterpret_cast<const char *>(&sample), sizeof(sample));
}

void appendUInt32(QByteArray &data, quint32 value)
{
    const quint32 le = qToLittleEndian(value);
    data.append(reinterpret_cast<const char *>(&le), sizeof(le));
}

void appendUInt16(QByteArray &data, quint16 value)
{
    const quint16 le = qToLittleEndian(value);
    data.append(reinterpret_cast<const char *>(&le), sizeof(le));
}

// the tone at frame `i` of a tone `frames` long
double tone(int i, int frames)
{
    const int fadeFrames = static_cast<int>(fadeSeconds * sampleRate);
    double gain = 1.0;
    if (i < fadeFrames)
        gain = 0.5 - 0.5 * std::cos(pi * i / fadeFrames);
    else if (i >= frames - fadeFrames)
        gain = 0.5 - 0.5 * std::cos(pi * (frames - 1 - i) / fadeFrames);
    return toneLevel * gain * std::sin(2.0 * pi * toneHz * i / sampleRate);
}

// 16 bit PCM WAV of the left / right tones with the stereo mode applied
QByteArray testSound(int stereoMode)
{
    const int toneFrames = static_cast<int>(toneSeconds * sampleRate);
    const int gapFrames = static_cast<int>(gapSeconds * sampleRate);
    const int tailFrames = static_cast<int>(tailSeconds * sampleRate);
    const int frames = 2 * toneFrames + gapFrames + tailFrames;

    QByteArray samples;
    samples.reserve(frames * channels * 2);
    for (int i = 0; i < frames; ++i)
    {
        double left = 0.0;
        double right = 0.0;
        if (i < toneFrames)
            left = tone(i, toneFrames);
        else if (i >= toneFrames + gapFrames && i < 2 * toneFrames + gapFrames)
            right = tone(i - toneFrames - gapFrames, toneFrames);

        // what the audio output does in each stereo mode (src/audio_output/output.c)
        switch (stereoMode)
        {
        case AOUT_VAR_CHAN_RSTEREO:
            std::swap(left, right);
            break;
        case AOUT_VAR_CHAN_LEFT:
            right = left;
            break;
        case AOUT_VAR_CHAN_RIGHT:
            left = right;
            break;
        case AOUT_VAR_CHAN_MONO:
            left = right = (left + right) / 2.0;
            break;
        default:
            break;
        }

        appendSample(samples, left);
        appendSample(samples, right);
    }

    QByteArray wav;
    wav.reserve(44 + samples.size());
    wav.append("RIFF", 4);
    appendUInt32(wav, static_cast<quint32>(36 + samples.size()));
    wav.append("WAVEfmt ", 8);
    appendUInt32(wav, 16);
    appendUInt16(wav, 1); // PCM
    appendUInt16(wav, channels);
    appendUInt32(wav, sampleRate);
    appendUInt32(wav, sampleRate * channels * 2);
    appendUInt16(wav, channels * 2);
    appendUInt16(wav, 16);
    wav.append("data", 4);
    appendUInt32(wav, static_cast<quint32>(samples.size()));
    wav.append(samples);
    return wav;
}

} // namespace

RdStereoTest::RdStereoTest(vlc_object_t *parent)
    : m_parent(parent)
{
}

RdStereoTest::~RdStereoTest()
{
    if (m_player)
        vlc_player_Delete(m_player);
    if (m_object)
        vlc_object_delete(m_object);
}

bool RdStereoTest::createPlayer(float volume)
{
    if (m_player)
        return true;
    if (!m_parent)
        return false;

    if (!m_object)
    {
        m_object = static_cast<vlc_object_t *>(vlc_object_create(m_parent, sizeof(vlc_object_t)));
        if (!m_object)
            return false;

        // the test player inherits these instead of the main player's: no audio effects, no
        // visualization window, normal speed, no video or subtitles
        var_Create(m_object, "audio-filter", VLC_VAR_STRING);
        var_SetString(m_object, "audio-filter", "");
        var_Create(m_object, "audio-visual", VLC_VAR_STRING);
        var_SetString(m_object, "audio-visual", "");
        var_Create(m_object, "rate", VLC_VAR_FLOAT);
        var_SetFloat(m_object, "rate", 1.f);
        var_Create(m_object, "video", VLC_VAR_BOOL);
        var_SetBool(m_object, "video", false);
        var_Create(m_object, "spu", VLC_VAR_BOOL);
        var_SetBool(m_object, "spu", false);
        // the tone has the stereo mode applied already: the output must not remix it
        var_Create(m_object, "stereo-mode", VLC_VAR_INTEGER);
        var_SetInteger(m_object, "stereo-mode", AOUT_VAR_CHAN_UNSET);
        var_Create(m_object, "mix-mode", VLC_VAR_INTEGER);
        var_SetInteger(m_object, "mix-mode", AOUT_MIX_MODE_UNSET);
        // the output shares the playing file's audio session (one per process, or VLC's own
        // with "volume-save"): it must not set the session volume when it opens, which would
        // change the playing file's volume. mmdevice skips a negative start volume; waveout
        // starts at the playing file's volume
        var_Create(m_object, "mmdevice-volume", VLC_VAR_FLOAT);
        var_SetFloat(m_object, "mmdevice-volume", -1.f);
        var_Create(m_object, "waveout-volume", VLC_VAR_FLOAT);
        var_SetFloat(m_object, "waveout-volume", volume >= 0.f ? std::min(volume, 2.f) : 1.f);
    }

    m_player = vlc_player_New(m_object, VLC_PLAYER_LOCK_NORMAL);
    return m_player != nullptr;
}

QString RdStereoTest::soundFile(int stereoMode)
{
    if (!m_dir.isValid())
        return {};

    const QString path = m_dir.filePath(QStringLiteral("stereo-test-%1.wav").arg(stereoMode));
    if (QFile::exists(path))
        return path;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return {};
    const QByteArray sound = testSound(stereoMode);
    const bool written = file.write(sound) == static_cast<qint64>(sound.size());
    file.close();
    if (!written)
    {
        QFile::remove(path);
        return {};
    }
    return path;
}

void RdStereoTest::play(int stereoMode, const char *device, float volume)
{
    const QString path = soundFile(stereoMode);
    if (path.isEmpty() || !createPlayer(volume))
        return;

    char *uri = vlc_path2uri(qtu(QDir::toNativeSeparators(path)), "file");
    if (!uri)
        return;
    input_item_t *item = input_item_New(uri, "Stereo test");
    free(uri);
    if (!item)
        return;

    // the device the playing file is heard on; switching blocks until the output has it, so
    // only when it changed
    audio_output_t *aout = vlc_player_aout_Hold(m_player);
    if (aout)
    {
        const char *wanted = device ? device : "";
        char *current = aout_DeviceGet(aout);
        if (strcmp(current ? current : "", wanted) != 0)
            aout_DeviceSet(aout, wanted);
        free(current);
        aout_Release(aout);
    }

    vlc_player_Lock(m_player);
    if (vlc_player_SetCurrentMedia(m_player, item) == VLC_SUCCESS)
        vlc_player_Start(m_player);
    vlc_player_Unlock(m_player);
    input_item_Release(item);
}
