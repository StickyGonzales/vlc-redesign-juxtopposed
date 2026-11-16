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
        || StrIs(fmt, "ext", "mhtml")
        || (StrIs(fmt, "vcodec", "none") && StrIs(fmt, "acodec", "none"));
}

static int CompareFormats(const struct json_object *f_a,
                          const struct json_object *f_b, double pref_height)
{
    double h_a = json_get_num(f_a, "height");
    double abr_a = json_get_num(f_a, "abr");
    double h_b = json_get_num(f_b, "height");
    double abr_b = json_get_num(f_b, "abr");

    /* Prefer non-mute formats */
    if (!isnan(abr_a) != !isnan(abr_b))
        return isnan(abr_a) ? -1 : +1;

    /* Prefer non-blind formats */
    if (!isnan(h_a) != !isnan(h_b))
        return isnan(h_a) ? -1 : +1;

    if (islessequal(h_a, pref_height)) {
        if (!islessequal(h_b, pref_height))
            return +1;
        if (h_a > h_b)
            return -1;
        if (h_a < h_b)
            return +1;
    } else {
        if (islessequal(h_b, pref_height))
            return -1;
        if (isless(h_a, h_b))
            return -1;
        if (isgreater(h_a, h_b))
            return +1;
    }

    if (isgreater(abr_a, abr_b))
        return +1;
    if (isgreater(abr_b, abr_a))
        return -1;

    return 0;
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

        if (IsStoryboard(fmt))
            continue;

        if (best_fmt == NULL) {
            best_fmt = fmt;
            continue;
        }

        if (CompareFormats(fmt, best_fmt, pref_height) > 0)
            best_fmt = fmt;
    }

    return best_fmt;
}
