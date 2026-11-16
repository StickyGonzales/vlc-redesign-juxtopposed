/*****************************************************************************
 * ytdl_formats.c: test for the YT-DL extractor's format choice
 *****************************************************************************
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#undef NDEBUG
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <vlc_common.h>

#include "../modules/demux/json/json.h"
#include "../modules/demux/ytdl_formats.h"

struct reader {
    const char *buf;
    size_t len;
};

size_t json_read(void *opaque, void *buf, size_t max)
{
    struct reader *reader = opaque;
    size_t len = reader->len < max ? reader->len : max;

    memcpy(buf, reader->buf, len);
    reader->buf += len;
    reader->len -= len;
    return len;
}

void json_parse_error(void *opaque, const char *msg)
{
    (void) opaque;
    fprintf(stderr, "json parse error: %s\n", msg);
}

/* Format lists in the layout of `yt-dlp --dump-single-json` (fields the
 * format choice does not read are left out; urls shortened). */

/* A regular YouTube video in 2026: storyboards, audio only, video only (DASH
 * and HLS), and one format with both video and audio (18, 360p). */
static const char youtube[] =
"{\"id\":\"abc\",\"title\":\"A video\",\"duration\":1977,\"formats\":["
"{\"format_id\":\"sb3\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":48,\"height\":27,\"fps\":0.1,\"rows\":10,\"columns\":10,"
" \"abr\":0,\"vbr\":0,\"tbr\":null,\"url\":\"https://i.ytimg.com/sb/abc/storyboard3_L0/default.jpg\","
" \"format\":\"sb3 - 48x27 (storyboard)\"},"
"{\"format_id\":\"sb2\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":80,\"height\":45,\"fps\":0.5,"
" \"abr\":0,\"vbr\":0,\"url\":\"https://i.ytimg.com/sb/abc/storyboard3_L1/M$M.jpg\","
" \"format\":\"sb2 - 80x45 (storyboard)\"},"
"{\"format_id\":\"sb1\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":160,\"height\":90,\"fps\":0.5,"
" \"abr\":0,\"vbr\":0,\"url\":\"https://i.ytimg.com/sb/abc/storyboard3_L2/M$M.jpg\","
" \"format\":\"sb1 - 160x90 (storyboard)\"},"
"{\"format_id\":\"sb0\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":320,\"height\":180,\"fps\":0.5,"
" \"abr\":0,\"vbr\":0,\"url\":\"https://i.ytimg.com/sb/abc/storyboard3_L3/M$M.jpg\","
" \"format\":\"sb0 - 320x180 (storyboard)\"},"
"{\"format_id\":\"233\",\"format_note\":\"Default\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\","
" \"acodec\":\"unknown\",\"vcodec\":\"none\",\"resolution\":\"audio only\",\"url\":\"https://manifest.googlevideo.com/233.m3u8\","
" \"format\":\"233 - audio only (Default)\"},"
"{\"format_id\":\"139\",\"format_note\":\"low\",\"ext\":\"m4a\",\"protocol\":\"https\","
" \"acodec\":\"mp4a.40.5\",\"vcodec\":\"none\",\"abr\":48.8,\"tbr\":48.8,\"height\":null,\"width\":null,"
" \"resolution\":\"audio only\",\"url\":\"https://rr.googlevideo.com/139\",\"format\":\"139 - audio only (low)\"},"
"{\"format_id\":\"140\",\"format_note\":\"medium\",\"ext\":\"m4a\",\"protocol\":\"https\","
" \"acodec\":\"mp4a.40.2\",\"vcodec\":\"none\",\"abr\":129.5,\"tbr\":129.5,\"height\":null,\"width\":null,"
" \"resolution\":\"audio only\",\"url\":\"https://rr.googlevideo.com/140\",\"format\":\"140 - audio only (medium)\"},"
"{\"format_id\":\"251\",\"format_note\":\"medium\",\"ext\":\"webm\",\"protocol\":\"https\","
" \"acodec\":\"opus\",\"vcodec\":\"none\",\"abr\":134.1,\"tbr\":134.1,\"height\":null,\"width\":null,"
" \"resolution\":\"audio only\",\"url\":\"https://rr.googlevideo.com/251\",\"format\":\"251 - audio only (medium)\"},"
"{\"format_id\":\"269\",\"format_note\":\"144p\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4D400C\",\"width\":256,\"height\":144,\"abr\":0,\"tbr\":160.3,"
" \"url\":\"https://manifest.googlevideo.com/269.m3u8\",\"format\":\"269 - 256x144\"},"
"{\"format_id\":\"160\",\"format_note\":\"144p\",\"ext\":\"mp4\",\"protocol\":\"https\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4d400c\",\"width\":256,\"height\":144,\"vbr\":84.1,\"tbr\":84.1,"
" \"url\":\"https://rr.googlevideo.com/160\",\"format\":\"160 - 256x144 (144p)\"},"
"{\"format_id\":\"229\",\"format_note\":\"240p\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4D4015\",\"width\":426,\"height\":240,\"abr\":0,\"tbr\":290.0,"
" \"url\":\"https://manifest.googlevideo.com/229.m3u8\",\"format\":\"229 - 426x240\"},"
"{\"format_id\":\"133\",\"format_note\":\"240p\",\"ext\":\"mp4\",\"protocol\":\"https\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4d4015\",\"width\":426,\"height\":240,\"vbr\":171.5,\"tbr\":171.5,"
" \"url\":\"https://rr.googlevideo.com/133\",\"format\":\"133 - 426x240 (240p)\"},"
"{\"format_id\":\"18\",\"format_note\":\"360p\",\"ext\":\"mp4\",\"protocol\":\"https\","
" \"acodec\":\"mp4a.40.2\",\"vcodec\":\"avc1.42001E\",\"width\":640,\"height\":360,\"tbr\":521.4,"
" \"url\":\"https://rr.googlevideo.com/18\",\"format\":\"18 - 640x360 (360p)\"},"
"{\"format_id\":\"230\",\"format_note\":\"360p\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4D401E\",\"width\":640,\"height\":360,\"abr\":0,\"tbr\":700.1,"
" \"url\":\"https://manifest.googlevideo.com/230.m3u8\",\"format\":\"230 - 640x360\"},"
"{\"format_id\":\"134\",\"format_note\":\"360p\",\"ext\":\"mp4\",\"protocol\":\"https\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4d401e\",\"width\":640,\"height\":360,\"vbr\":340.2,\"tbr\":340.2,"
" \"url\":\"https://rr.googlevideo.com/134\",\"format\":\"134 - 640x360 (360p)\"},"
"{\"format_id\":\"136\",\"format_note\":\"720p\",\"ext\":\"mp4\",\"protocol\":\"https\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.4d401f\",\"width\":1280,\"height\":720,\"vbr\":1201.0,\"tbr\":1201.0,"
" \"url\":\"https://rr.googlevideo.com/136\",\"format\":\"136 - 1280x720 (720p)\"},"
"{\"format_id\":\"270\",\"format_note\":\"1080p\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.640028\",\"width\":1920,\"height\":1080,\"abr\":0,\"tbr\":4400.2,"
" \"url\":\"https://manifest.googlevideo.com/270.m3u8\",\"format\":\"270 - 1920x1080\"},"
"{\"format_id\":\"137\",\"format_note\":\"1080p\",\"ext\":\"mp4\",\"protocol\":\"https\","
" \"acodec\":\"none\",\"vcodec\":\"avc1.640028\",\"width\":1920,\"height\":1080,\"vbr\":3020.5,\"tbr\":3020.5,"
" \"url\":\"https://rr.googlevideo.com/137\",\"format\":\"137 - 1920x1080 (1080p)\"}"
"]}";

/* HLS formats with both video and audio at every height (YouTube live
 * streams and older videos: itags 91 to 96) next to storyboards and DASH
 * video-only formats. */
static const char hls_muxed[] =
"{\"id\":\"live\",\"title\":\"A stream\",\"formats\":["
"{\"format_id\":\"sb0\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":320,\"height\":180,\"url\":\"https://i.ytimg.com/sb0\"},"
"{\"format_id\":\"91\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\",\"acodec\":\"mp4a.40.5\",\"vcodec\":\"avc1.4D400C\","
" \"width\":256,\"height\":144,\"tbr\":290.3,\"url\":\"https://manifest.googlevideo.com/91.m3u8\"},"
"{\"format_id\":\"92\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\",\"acodec\":\"mp4a.40.5\",\"vcodec\":\"avc1.4D4015\","
" \"width\":426,\"height\":240,\"tbr\":546.1,\"url\":\"https://manifest.googlevideo.com/92.m3u8\"},"
"{\"format_id\":\"93\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\",\"acodec\":\"mp4a.40.2\",\"vcodec\":\"avc1.4D401E\","
" \"width\":640,\"height\":360,\"tbr\":1209.4,\"url\":\"https://manifest.googlevideo.com/93.m3u8\"},"
"{\"format_id\":\"94\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\",\"acodec\":\"mp4a.40.2\",\"vcodec\":\"avc1.4D401F\","
" \"width\":854,\"height\":480,\"tbr\":1568.7,\"url\":\"https://manifest.googlevideo.com/94.m3u8\"},"
"{\"format_id\":\"95\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\",\"acodec\":\"mp4a.40.2\",\"vcodec\":\"avc1.4D401F\","
" \"width\":1280,\"height\":720,\"tbr\":2969.3,\"url\":\"https://manifest.googlevideo.com/95.m3u8\"},"
"{\"format_id\":\"96\",\"ext\":\"mp4\",\"protocol\":\"m3u8_native\",\"acodec\":\"mp4a.40.2\",\"vcodec\":\"avc1.640028\","
" \"width\":1920,\"height\":1080,\"tbr\":5420.1,\"url\":\"https://manifest.googlevideo.com/96.m3u8\"},"
"{\"format_id\":\"137\",\"ext\":\"mp4\",\"protocol\":\"https\",\"acodec\":\"none\",\"vcodec\":\"avc1.640028\","
" \"width\":1920,\"height\":1080,\"tbr\":4500.0,\"url\":\"https://rr.googlevideo.com/137\"},"
"{\"format_id\":\"299\",\"ext\":\"mp4\",\"protocol\":\"https\",\"acodec\":\"none\",\"vcodec\":\"avc1.64002a\","
" \"width\":1920,\"height\":1080,\"fps\":60,\"tbr\":6200.0,\"url\":\"https://rr.googlevideo.com/299\"}"
"]}";

/* Nothing but storyboards: nothing can be played */
static const char storyboards[] =
"{\"id\":\"sb\",\"formats\":["
"{\"format_id\":\"sb3\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":48,\"height\":27,\"abr\":0,\"url\":\"https://i.ytimg.com/sb3\"},"
"{\"format_id\":\"sb0\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"protocol\":\"mhtml\","
" \"acodec\":\"none\",\"vcodec\":\"none\",\"width\":320,\"height\":180,\"abr\":0,\"url\":\"https://i.ytimg.com/sb0\"}"
"]}";

/* Separate video and audio only (no format with both) */
static const char split[] =
"{\"id\":\"split\",\"formats\":["
"{\"format_id\":\"137\",\"acodec\":\"none\",\"vcodec\":\"avc1.640028\",\"height\":1080,\"abr\":0,\"tbr\":3020.5,\"url\":\"v1080\"},"
"{\"format_id\":\"140\",\"acodec\":\"mp4a.40.2\",\"vcodec\":\"none\",\"abr\":129.5,\"tbr\":129.5,\"url\":\"a140\"},"
"{\"format_id\":\"139\",\"acodec\":\"mp4a.40.5\",\"vcodec\":\"none\",\"abr\":48.8,\"tbr\":48.8,\"url\":\"a139\"},"
"{\"format_id\":\"133\",\"acodec\":\"none\",\"vcodec\":\"avc1.4d4015\",\"height\":240,\"abr\":0,\"tbr\":171.5,\"url\":\"v240\"}"
"]}";

/* Video only: the best one still plays */
static const char video_only[] =
"{\"id\":\"vo\",\"formats\":["
"{\"format_id\":\"sb0\",\"format_note\":\"storyboard\",\"ext\":\"mhtml\",\"acodec\":\"none\",\"vcodec\":\"none\",\"height\":180,\"url\":\"sb\"},"
"{\"format_id\":\"133\",\"acodec\":\"none\",\"vcodec\":\"avc1.4d4015\",\"height\":240,\"url\":\"v240\"},"
"{\"format_id\":\"136\",\"acodec\":\"none\",\"vcodec\":\"avc1.4d401f\",\"height\":720,\"url\":\"v720\"}"
"]}";

/* A site whose extractor gives no codec names (generic, direct files) */
static const char generic[] =
"{\"id\":\"gen\",\"formats\":["
"{\"format_id\":\"sd\",\"ext\":\"mp4\",\"height\":480,\"url\":\"sd.mp4\"},"
"{\"format_id\":\"hd\",\"ext\":\"mp4\",\"height\":720,\"url\":\"hd.mp4\"},"
"{\"format_id\":\"preview\",\"ext\":\"mp4\",\"vcodec\":\"none\",\"acodec\":\"none\",\"height\":90,\"url\":\"none.mp4\"}"
"]}";

/* A single format: the entry itself */
static const char single[] =
"{\"id\":\"one\",\"title\":\"One\",\"ext\":\"mp3\",\"url\":\"https://example.org/one.mp3\"}";

static void parse(const char *doc, struct json_object *obj)
{
    struct reader reader = { doc, strlen(doc) };
    int ret = json_parse(&reader, obj);

    assert(ret == 0);
}

static const char *pick(const struct json_object *entry, double pref)
{
    const struct json_object *fmt = ytdl_PickFormat(entry, pref);

    if (fmt == NULL)
        return NULL;
    if (fmt == entry)
        return "(entry)";
    return json_get_str(fmt, "format_id");
}

static void check(const char *name, const char *doc, double pref,
                  const char *expected)
{
    struct json_object obj;

    parse(doc, &obj);

    const char *got = pick(&obj, pref);

    printf("%-12s preferred %-5g -> %s (expected %s)\n", name, pref,
           got != NULL ? got : "(none)",
           expected != NULL ? expected : "(none)");
    if (expected == NULL)
        assert(got == NULL);
    else {
        assert(got != NULL);
        assert(strcmp(got, expected) == 0);
    }
    json_free(&obj);
}

int main(void)
{
    /* The issue: 240p picked the 48x27 storyboard (10 s still); Best
     * available picked 270 (1080p, no sound). Only 18 has both. */
    check("youtube", youtube, NAN, "18");
    check("youtube", youtube, 144, "18");
    check("youtube", youtube, 240, "18");
    check("youtube", youtube, 360, "18");
    check("youtube", youtube, 720, "18");
    check("youtube", youtube, 1080, "18");

    /* With video and audio at every height: the chosen quality */
    check("hls_muxed", hls_muxed, NAN, "96");
    check("hls_muxed", hls_muxed, 1080, "96");
    check("hls_muxed", hls_muxed, 720, "95");
    check("hls_muxed", hls_muxed, 600, "94");
    check("hls_muxed", hls_muxed, 240, "92");
    check("hls_muxed", hls_muxed, 100, "91");
    check("hls_muxed", hls_muxed, 4320, "96");

    check("storyboards", storyboards, NAN, NULL);
    check("storyboards", storyboards, 240, NULL);

    /* No format with both: sound before a silent picture */
    check("split", split, NAN, "140");
    check("split", split, 240, "140");

    check("video_only", video_only, NAN, "136");
    check("video_only", video_only, 360, "133");
    check("video_only", video_only, 144, "133");

    check("generic", generic, NAN, "hd");
    check("generic", generic, 480, "sd");
    check("generic", generic, 240, "sd");

    check("single", single, NAN, "(entry)");
    check("single", single, 240, "(entry)");

    return 0;
}
