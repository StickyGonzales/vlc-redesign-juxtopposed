/*****************************************************************************
 * video_text.c : OSD text manipulation functions
 *****************************************************************************
 * Copyright (C) 1999-2010 VLC authors and VideoLAN
 *
 * Author: Sigmund Augdal Helberg <dnumgis@videolan.org>
 *         Laurent Aimar <fenrir _AT_ videolan _DOT_ org>
 *
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
#include <assert.h>

#include <vlc_common.h>
#include <vlc_threads.h>
#include <vlc_vout.h>
#include <vlc_vout_osd.h>
#include <vlc_subpicture.h>

typedef struct {
    int  position;
    char *text;
    /* redesign: the shortcut that caused the message ("Pressed C"), or NULL */
    char *hint;
} osd_spu_updater_sys_t;

/* redesign (video 15:23-15:28): the "Pressed C" line is a little smaller than the message */
#define OSD_HINT_REL_FONT_SIZE (STYLE_DEFAULT_REL_FONT_SIZE * 0.8f)
/* redesign: how long after a key press its messages still name the key (src/misc/actions.c
 * sets "osd-key-hint" and "osd-key-hint-date"); an audio output reports the volume from its
 * own thread, a little later */
#define OSD_KEY_HINT_DELAY VLC_TICK_FROM_MS(400)

static void OSDTextUpdate(subpicture_t *subpic,
                          const struct vlc_spu_updater_configuration *cfg)
{
    osd_spu_updater_sys_t *sys = subpic->updater.sys;
    const video_format_t *fmt_dst = cfg->current.video_dst;

    if (video_format_IsSimilar(cfg->previous.video_dst, fmt_dst))
        return;

    vlc_spu_regions_Clear( &subpic->regions );

    assert(fmt_dst->i_sar_den && fmt_dst->i_sar_num);

    subpic->i_original_picture_width  = cfg->current.display_width;
    subpic->i_original_picture_height = cfg->current.display_height;

    subpicture_region_t *r = subpicture_region_NewText();
    if (!r)
        return;
    vlc_spu_regions_push(&subpic->regions, r);

    r->fmt.i_sar_num = 1;
    r->fmt.i_sar_den = 1;
    r->p_text = text_segment_New( sys->text );
    if (sys->hint != NULL && r->p_text != NULL)
    {
        /* the hint on its own line */
        text_segment_t *newline = text_segment_New( "\n" );
        text_segment_t *hint = text_segment_New( sys->hint );
        if (newline != NULL && hint != NULL)
            hint->style = text_style_Create( STYLE_NO_DEFAULTS );
        if (newline != NULL && hint != NULL && hint->style != NULL)
        {
            hint->style->f_font_relsize = OSD_HINT_REL_FONT_SIZE;
            r->p_text->p_next = newline;
            newline->p_next = hint;
            /* both lines left aligned in the corner */
            r->text_flags |= SUBPICTURE_ALIGN_LEFT;
        }
        else
        {
            text_segment_Delete( newline );
            text_segment_Delete( hint );
        }
    }

    const float margin_ratio = 0.04f;
    const int   margin_h     = margin_ratio * fmt_dst->i_visible_width;
    const int   margin_v     = margin_ratio * fmt_dst->i_visible_height;

    r->text_flags |= sys->position;
    if (r->text_flags & SUBPICTURE_ALIGN_LEFT)
        r->text_flags &= ~SUBPICTURE_ALIGN_RIGHT;
    r->b_absolute = false; r->b_in_window = true;
    r->i_align = sys->position;
    if (r->i_align & SUBPICTURE_ALIGN_LEFT)
        r->i_x = margin_h + fmt_dst->i_x_offset;
    else if (r->i_align & SUBPICTURE_ALIGN_RIGHT)
        r->i_x = margin_h - fmt_dst->i_x_offset;
    else
        r->i_x = 0;

    if (r->i_align & SUBPICTURE_ALIGN_TOP )
        r->i_y = margin_v + fmt_dst->i_y_offset;
    else if (r->i_align & SUBPICTURE_ALIGN_BOTTOM )
        r->i_y = margin_v - fmt_dst->i_y_offset;
    else
        r->i_y = 0;
}

static void OSDTextDestroy(subpicture_t *subpic)
{
    osd_spu_updater_sys_t *sys = subpic->updater.sys;

    free(sys->text);
    free(sys->hint);
    free(sys);
}

static void OSDText(vout_thread_t *vout, int channel, int position,
                    vlc_tick_t duration, const char *text, const char *hint)
{
    assert( (position & ~SUBPICTURE_ALIGN_MASK) == 0);
    if (!var_InheritBool(vout, "osd") || duration <= 0)
        return;

    osd_spu_updater_sys_t *sys = malloc(sizeof(*sys));
    if (!sys)
        return;
    sys->position = position;
    sys->text     = strdup(text);
    sys->hint     = hint != NULL ? strdup(hint) : NULL;

    static const struct vlc_spu_updater_ops spu_ops =
    {
        .update   = OSDTextUpdate,
        .destroy  = OSDTextDestroy,
    };

    subpicture_updater_t updater = {
        .sys = sys,
        .ops = &spu_ops,
    };
    subpicture_t *subpic = subpicture_New(&updater);
    if (!subpic) {
        free(sys->text);
        free(sys->hint);
        free(sys);
        return;
    }

    subpic->i_channel  = channel;
    subpic->i_start    = vlc_tick_now();
    subpic->i_stop     = subpic->i_start + duration;
    subpic->b_ephemer  = true;
    subpic->b_fade     = true;

    vout_PutSubpicture(vout, subpic);
}

void vout_OSDText(vout_thread_t *vout, int channel,
                   int position, vlc_tick_t duration, const char *text)
{
    OSDText(vout, channel, position, duration, text, NULL);
}

void vout_OSDMessageVa(vout_thread_t *vout, int channel,
                       const char *format, va_list args)
{
    char *string;
    if (vasprintf(&string, format, args) != -1) {
#ifdef VLC_BRAND_PUBLIC
        /* redesign (P7-08, P8-13): the message stays for the "Show feedback for" time, and a
         * message caused by a shortcut names it on a second line */
        const vlc_tick_t duration =
            VLC_TICK_FROM_MS(var_InheritInteger(vout, "osd-duration"));
        libvlc_int_t *libvlc = vlc_object_instance(vout);
        char *hint = NULL;
        const vlc_tick_t pressed = var_GetInteger(libvlc, "osd-key-hint-date");
        if (pressed > 0 && vlc_tick_now() - pressed < OSD_KEY_HINT_DELAY)
        {
            char *key = var_GetString(libvlc, "osd-key-hint");
            if (key != NULL && key[0] != '\0' && asprintf(&hint, _("Pressed %s"), key) == -1)
                hint = NULL;
            free(key);
        }
        OSDText(vout, channel, SUBPICTURE_ALIGN_TOP|SUBPICTURE_ALIGN_RIGHT, duration,
                string, hint);
        free(hint);
#else
        vout_OSDText(vout, channel,
                     SUBPICTURE_ALIGN_TOP|SUBPICTURE_ALIGN_RIGHT, VLC_TICK_FROM_SEC(1),
                     string);
#endif
        free(string);
    }
}
