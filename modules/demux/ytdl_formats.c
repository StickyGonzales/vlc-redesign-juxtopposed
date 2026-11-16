/*****************************************************************************
 * ytdl_formats.c: format choice for the YT-DL extractor
 *****************************************************************************
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <math.h>
#include <stdbool.h>
#include <string.h>

#include <vlc_common.h>
#include <vlc_strings.h>

#include "json/json.h"
#include "ytdl_formats.h"

/* What a format carries, worst first */
enum ytdl_content {
    YTDL_NOTHING = 0, /* no audio and no video (storyboards): never picked */
    YTDL_VIDEO_ONLY,  /* plays silent */
    YTDL_AUDIO_ONLY,  /* plays without a picture */
    YTDL_UNKNOWN,     /* the extractor gave no codec information */
    YTDL_AUDIO_VIDEO,
};

static bool StrIs(const struct json_object *fmt, const char *name,
                  const char *value)
{
    const char *str = json_get_str(fmt, name);

    return str != NULL && vlc_ascii_strcasecmp(str, value) == 0;
}

static bool IsStoryboard(const struct json_object *fmt)
{
    /* YouTube's seek previews (sb0 to sb3): a grid of tiny pictures that the
     * image demux would show as a still for image-duration (10 s) */
    return StrIs(fmt, "format_note", "storyboard")
        || StrIs(fmt, "protocol", "mhtml")
        || StrIs(fmt, "ext", "mhtml");
}

/* 1: has the stream, 0: has not, -1: unknown */
static int HasStream(const struct json_object *fmt, const char *codec,
                     const char *ext)
{
    const char *str = json_get_str(fmt, codec);

    if (str != NULL)
        return vlc_ascii_strcasecmp(str, "none") != 0;
    if (StrIs(fmt, ext, "none"))
        return 0;
    return -1;
}

static enum ytdl_content GetContent(const struct json_object *fmt)
{
    if (IsStoryboard(fmt))
        return YTDL_NOTHING;

    int video = HasStream(fmt, "vcodec", "video_ext");
    int audio = HasStream(fmt, "acodec", "audio_ext");

    /* No codec names: guess from the picture size and the audio bit rate
     * (an audio bit rate of 0 means no audio) */
    if (video < 0 && !isnan(json_get_num(fmt, "height")))
        video = 1;
    if (audio < 0 && isgreater(json_get_num(fmt, "abr"), 0.))
        audio = 1;

    if (video == 0 && audio == 0)
        return YTDL_NOTHING;
    if (video > 0 && audio > 0)
        return YTDL_AUDIO_VIDEO;
    if (video > 0 && audio == 0)
        return YTDL_VIDEO_ONLY;
    if (audio >= 0 && video == 0)
        return YTDL_AUDIO_ONLY;
    if (video < 0 && audio == 0)
        return YTDL_VIDEO_ONLY;
    return YTDL_UNKNOWN;
}

static int CompareNum(double a, double b)
{
    if (isgreater(a, b) || (!isnan(a) && isnan(b)))
        return +1;
    if (isless(a, b) || (isnan(a) && !isnan(b)))
        return -1;
    return 0;
}

static int CompareHeight(double h_a, double h_b, double pref_height)
{
    /* A known height beats an unknown one */
    if (isnan(h_a) || isnan(h_b) || isnan(pref_height))
        return CompareNum(h_a, h_b);

    bool fits_a = islessequal(h_a, pref_height);
    bool fits_b = islessequal(h_b, pref_height);

    if (fits_a != fits_b)
        return fits_a ? +1 : -1;
    /* At or below the preferred height: the highest; above it: the lowest */
    return fits_a ? CompareNum(h_a, h_b) : CompareNum(h_b, h_a);
}

static int CompareFormats(const struct json_object *f_a,
                          const struct json_object *f_b, double pref_height)
{
    enum ytdl_content c_a = GetContent(f_a);
    enum ytdl_content c_b = GetContent(f_b);

    if (c_a != c_b)
        return c_a > c_b ? +1 : -1;

    int val = CompareHeight(json_get_num(f_a, "height"),
                            json_get_num(f_b, "height"), pref_height);
    if (val != 0)
        return val;

    val = CompareNum(json_get_num(f_a, "tbr"), json_get_num(f_b, "tbr"));
    if (val != 0)
        return val;

    return CompareNum(json_get_num(f_a, "abr"), json_get_num(f_b, "abr"));
}

const struct json_object *ytdl_PickFormat(const struct json_object *entry,
                                          double pref_height)
{
    const struct json_value *fmts = json_get(entry, "formats");

    if (fmts == NULL)
        return entry; /* only one format */
    if (fmts->type != JSON_ARRAY)
        return NULL;

    const struct json_object *best_fmt = NULL;

    for (size_t i = 0; i < fmts->array.size; i++) {
        const struct json_value *v = &fmts->array.entries[i];

        if (v->type != JSON_OBJECT)
            continue;

        const struct json_object *fmt = &v->object;

        if (GetContent(fmt) == YTDL_NOTHING)
            continue;

        /* yt-dlp lists formats from worst to best: on a tie, the later one */
        if (best_fmt == NULL || CompareFormats(fmt, best_fmt, pref_height) >= 0)
            best_fmt = fmt;
    }

    return best_fmt;
}
