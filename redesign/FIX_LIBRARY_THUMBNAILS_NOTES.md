# Grey squares instead of thumbnails in the library's Recent list

StickyGonzales, 2026-11-14. In the library's Recent list some videos showed a grey square instead
of a thumbnail, while others in the same list had one. On the PC: several episodes of one show and
one of another, all 1080p episode files.

## Finding: VLC's Qt code, not Cone's, not VLC core

**Cause.** The Recent page uses VLC's own `MLRecentMediaModel`, which is built on `MLMediaModel`
(modules/gui/qt/medialibrary, upstream VLC code that Cone had not changed). It works like this:

1. A card without a thumbnail asks the media library to make one.
2. The library makes it and sends "thumbnail generated".
3. VLC's base model (`MLBaseModel`) passes that to `thumbnailUpdated()` of the model showing the row.
4. `MLMediaModel` never implemented `thumbnailUpdated()` (only `MLVideoModel` and `MLPlaylistModel`
   did), so nothing happened.

The card kept its grey placeholder until the page was built again (another page and back, or a
restart). Which cards stayed grey depended on timing: the ones made before the model happened to
reload showed, the later ones did not.

**Ruled out:**
- **File types and codecs.** 1080p HEVC 10-bit (x265), H.264, H.264 10-bit, and HEVC with a
  single keyframe all got thumbnails.
- **Files never thumbnailed.** Every file was thumbnailed: the media library's database lists every
  thumbnail as available while the page shows grey.
- **Cache paths.** The thumbnails were written and readable: they show after a restart.
- **The background queue.** It does not touch the media library's thumbnailer.
- **VLC core** (the media library and its thumbnailer, modules/misc/medialibrary) worked.

**Reproduced on Linux.** Seven 1080p episodes (three shows plus one; x265 10-bit, H.264, H.264 10-bit,
HEVC with one keyframe):
- **While the page was open:** each was played once, then Recent was opened. After 2 minutes three
  cards showed a thumbnail and four stayed grey, while the database had all seven as available.
- **After a restart:** all seven showed.

**Fix.** Two small changes in VLC's Qt module (modules/gui/qt/medialibrary):

- **Recent page.** `MLMediaModel::thumbnailUpdated()`, as `MLVideoModel` has: it sets the video's
  small cover and announces the change of `MEDIA_SMALL_COVER`, so the card shows the picture as soon
  as it is made.
- **Videos page.** The same bug, found by the independent review. That page uses `MLVideoModel`,
  whose handler announced only its own `thumbnail` role, while the page reads `small_cover`. It now
  announces both.

**Upstream.** This is a bug in VLC's own Qt code. It is worth reporting to VideoLAN, with
StickyGonzales's OK first.

## Other things that also leave a grey square (VLC, not changed)

**What these are.** VLC's media library behaviour, the same in stock VLC 4. They would show as a
grey square that stays after a restart, unlike the bug above.

- **The thumbnailer gives up after 3 s** per file (modules/misc/medialibrary/Thumbnailer.cpp:
  software decoding, one file at a time). A slow file, a busy disk or a slow network share is then
  marked failed. VLC asks again up to 3 times in total, then stops for good ("persistent failure").
- **A thumbnail that was being made when Cone ended is marked "crash"** by the media library and is
  never asked for again, by VLC or Cone. Ending normally avoids this, because the library cancels
  cleanly. If the quit watchdog has to end Cone (a stuck quit), the record can stay.

If grey squares remain after the fix and a restart, these are the likely reasons. The retest below
says how to tell.

## Test

- **Linux smoke `check_recent_thumbnails`.** A fresh home (a new media library). Five videos are
  played one by one, so each enters Recent without a thumbnail. Then Recent is opened, and within
  60 s every card must show its picture (its upper part is read off the screen).
- **Local result (ASan Linux build).**
  - Without the fix: it failed, with two cards still grey after 60 s.
  - With the fix: it passed, "5 of 5 cards show their thumbnail", with no sanitizer reports.

- **Independent review.** The C++ fix is correct. The findings were:
  - the Videos page (fixed above);
  - the check now leaves the page and comes back before its second try, so a thumbnail that failed
    once is asked for again;
  - it only counts the cards ("list item") that lie inside the window;
  - it reports a failed play as its own failure.
- **Not covered by the smoke: the Videos page.** It needs a library folder, which a test home
  without the onboarding does not have. It is retest step 4 below.

## Green runs

- build-linux #147 (620a2f780b): build, packages and smoke pass, including "recent: every video in
  the Recent list gets its thumbnail while the page is open".
- build-windows #259 (620a2f780b): build, installer and the Windows smoke pass.

## Windows retest (PC session)

Build: build-windows on wip/library-thumbnails (the run named in the PR).

1. **The reported case.** Start with a library whose Recent list had grey squares. Open Recent:
   cards that already had a thumbnail show it. Leave the page open about a minute: every grey card
   fills in with its picture, without leaving the page.
2. **New files.** Play two or three episodes you have never played in this Cone (one at a time,
   a few seconds each), then open Recent and stay on it: their thumbnails appear within a few
   seconds each.
3. **A grey square that stays after a restart.** Leave Recent, come back, then restart Cone. If a
   card is still grey, that file's thumbnail failed or was cut off (the section above, VLC's
   behaviour). Note the file name, codec and size, and whether it is on a network drive. It is not
   this bug.
4. **The Videos page.** Add a folder with videos Cone has not seen yet (Add item), open Videos and
   stay on it: the grey cards fill in with their pictures without leaving the page.
5. **Regression.** The home page and the mini player show thumbnails as before; playing from Recent
   and from Videos works.
