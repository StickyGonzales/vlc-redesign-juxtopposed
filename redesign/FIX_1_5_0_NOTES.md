# Three 1.5.0 fixes from the Windows test pass

StickyGonzales, 2026-11-15. Found by the PC session in redesign/TEST_PASS_1.5.0_WINDOWS.md
(items 2, 3 and 4). Branch wip/fixes-1.5.0. The Up Next autoplay and track memory code is not
touched (another session is fixing it).

## 1. Recent listed the oldest first

**What was wrong.** The Recent list put the videos just played at the bottom: on the player's
library pane and on the full library.

**Cause: VLC's Qt code, not Cone's.**
- The Recent page, the "Open Recent" menu and the Ctrl+1..0 shortcuts all use VLC's own
  `MLRecentMediaModel` (modules/gui/qt/medialibrary).
- Every VLC library model passes its sort order to the media library, and it is ascending unless
  something sets it.
- The media library sorts its history by the last play date. It only puts the newest first when it
  gets no query settings at all, and the models always send them.
- So Recent came out oldest first. The menu and the shortcuts ask for 10 items, so they also got
  the 10 oldest instead of the 10 newest.

**Fix.** `MLRecentMediaModel` now starts with the descending order (most recently played first).
That covers the Recent page, Open Recent and Ctrl+1..0 in one place. Nothing in Cone's QML sets
a different order for it.

**Figma.** There is no Recent frame in the Figma file. The video only shows the Recent icon in
the library rail and Recent in the menus, so the design sets no order. Newest first is what every
player's "recent" list does and what the test pass expected.

## 2. OpenSubtitles results: the pick was not what got downloaded and shown

**Superseded (StickyGonzales, 2026-11-15, for 1.5.0):** the one-choice rule below was reversed;
several OpenSubtitles results can be ticked again, as in 1.4.0. See
redesign/FIX_SUBTITLE_LANGUAGE_FIRST_NOTES.md, "Several OpenSubtitles results again". The clean names,
the reuse of a re-picked download and "the picked one is shown" stay.

**What was wrong.**
- The best result came pre-ticked.
- Clicking it unticked it, so Save downloaded nothing.
- Ticking a second result downloaded both. In the test, a Hebrew file came along with the English
  one, and the Hebrew one ended up showing.

**Figma.**
- "Folder-3" (To This File, From OpenSubtitles) shows exactly one result ticked, the best match.
- "Folder-2" (To This File, From Computer) shows two files ticked.
- So OpenSubtitles is one choice, and files from the computer can be several.

**Fix (Cone's code, dialogs/redesign/addsubtitles).**
- **One choice.** OpenSubtitles results for one file are a single choice. The best match stays
  pre-ticked (Figma). Clicking another result moves the tick to it. Clicking the ticked result
  keeps it ticked, so Save always has something to download.
- **Save downloads exactly the pick.** Only one result can be ticked, so only one is downloaded.
- **The pick is shown.**
  - Right away: the downloaded subtitle is selected once VLC lists its track.
  - Picked again: if the same subtitle was downloaded before and VLC already has it loaded, it is
    still selected, by the address VLC loaded it with. Before, it was skipped and the other
    subtitle kept showing. It is not synced again (auto sync ran when it was first added).
  - Next time: it is stored first in the video's saved subtitles. The first one is the one shown
    when the video plays again.
- **From Computer is unchanged.** It is still several files, as in Figma "Folder-2".

## 3. The downloaded subtitle's name: "67399-Sintel (2010 [English]"

**Both parts are Cone's code, not VLC's.**
- **The number.** Cone saved each OpenSubtitles download as `<OpenSubtitles file id>-<name>`
  (add_subtitles.cpp), to keep two subtitles with the same name apart.
- **The missing bracket.** The track name is built by Cone (player/input_models.cpp,
  `externalTrackName`, as the video shows it: "name [English]"). It removed the language word at
  the end of the file name (".eng") and then every character before it that was not a letter or a
  digit. That took the ")" along with the ".".

**Fix.**
- **The file name.** A download keeps the subtitle's own name: "Sintel (2010).eng.srt".
  - If another subtitle already has that name, it becomes "Sintel (2010).eng (2).srt".
  - If the file there holds the same subtitle (downloaded again), that file is used, with no copy.
- **The track name.** Only separators (space . _ -) before the language word go, and brackets
  stay. The track now reads "Sintel (2010) [English]".
- **Older downloads.** Subtitles downloaded before this fix, in Cone's OpenSubtitles download
  folder, keep their file names, but their track names drop the id: "Sintel (2010) [English]".
  Only an id of four digits or more is dropped, so a name such as "24-S01E01.eng.srt" keeps its
  number.
- **Two downloads at once.** Choosing the name and writing the file is one locked step for every
  download, so two subtitles with the same name downloaded at the same moment get two files. A
  file that already holds the same subtitle is not written again (VLC may have it open).
- **Known limit.** A subtitle downloaded with 1.5.0 or earlier ("67399-X.eng.srt") and then
  downloaded again is a second file ("X.eng.srt"). Both stay in the video's subtitles and show as
  the same name twice. Deleting the old one in Settings, Storage clears it.
- **Storage cleanup.** Downloads stay in the same folder as before (subtitles/opensubtitles, top
  level), which is where the storage cleanup looks for them.

## Tests

- **Unit test `test_rd_subtitle_picks`** (QtCore, in unit-tests.yml with the sanitizers, 37
  checks). It covers:
  - the one-choice rule for OpenSubtitles and the several-files rule for the computer;
  - the download file name and the saved file: its own name, numbered on a clash, the same file
    reused and not rewritten;
  - the track name the player shows (`externalTrackName`, moved from input_models.cpp into the
    tested helper): "Sintel (2010).eng.srt" reads "Sintel (2010) [English]", the video's
    "The_Wand_S01E04_EN.srt" reads "The_Wand_S01E04 [English]";
  - the old id prefix being dropped (and a short number kept).
- **It goes red on the old rules.** With the old rules put back in the helper (a click flips the
  row; everything that is not a letter or digit goes before the language word), it fails 5 of 25
  checks: "bracket kept: got "Sintel (2010", expected "Sintel (2010)"". That is exactly the track
  name from the test pass.
- **Linux smoke check "recent: the Recent list shows the last played video first".** It reuses
  the Recent thumbnail check's fresh home: five videos are played one by one, then the cards are
  read in reading order (rows top to bottom, each left to right). The last played must come first.
  - **Could the check see the bug?** Yes: five videos played at different times, in a known order,
    so oldest first and newest first are different pictures.
  - **Local result (ASan Linux build).** With the fix: pass, "test-hevc.mp4, test-h264.mp4, Smoke
    Show S01E03.mp4, Smoke Show S01E02.mp4, Smoke Show S01E01.mp4", no sanitizer reports. With the
    one line removed: fail, the order S01E01, S01E02, S01E03, test-h264, test-hevc (oldest first,
    the reported bug); the screenshot shows the same.
- **Independent review.** Requirement 1 clean (the order reaches the media library as descending,
  and a limit of 10 keeps the newest ten). Fixed from its findings: an already loaded pick is
  selected by VLC's own address for it; only a newly added download is auto synced; the name
  choice and write are locked together and identical files are not rewritten; only 4+ digit ids
  are dropped; the track name function is now unit tested. Left as a known limit: the old/new
  duplicate above.
- **Not covered automatically: OpenSubtitles itself.** It needs an account and an API key, which
  CI does not have. The rules it uses are in the unit test. The real download is retest step 2.

## Green runs

All on bb7ce27850 (merged into wip/next-test as PR #141):
- **build-linux #151:** build, packages and every smoke job pass, including "recent: the Recent
  list shows the last played video first" (test-hevc, test-h264, S01E03, S01E02, S01E01) on
  Ubuntu 24.04.
- **build-windows #264:** build, installer and the Windows smoke pass.
- **unit-tests #12 and #13:** pass, test_rd_subtitle_picks included.

## Windows retest (PC session)

Build: build-windows on wip/fixes-1.5.0 (the run named in the PR).

1. **Recent order.**
   - Play three videos one after the other, a few seconds each: A, then B, then C.
   - Open Recent in the player's library pane: C is first (top left), then B, then A.
   - Open the full library's Recent: the same order.
   - Main menu, Open Recent: C is at the top.
   - Ctrl+1 plays C.
2. **OpenSubtitles, one choice.** Use Sintel or another film with several subtitle languages.
   - Open Add Subtitles, To This File, From OpenSubtitles. The best match is ticked, and only it.
   - Click the ticked result: it stays ticked. Save: that subtitle is downloaded and shows.
   - Open the dialog again and pick another result (another language): the tick moves, and only
     one row is ticked. Save: only that subtitle is downloaded, and it is the one that shows.
   - Pick the first one again and Save: it shows again, with no copy in the download folder.
   - Close and reopen the video: the subtitle picked last shows.
3. **The subtitle's name.**
   - The subtitle menu shows "Sintel (2010) [English]": no number in front, and the ")" is there.
   - The file in the portable folder, subtitles\opensubtitles, is named "Sintel (2010).eng.srt".
   - A subtitle downloaded with build 1.5.0 or earlier (named "67399-Sintel (2010).eng.srt") also
     shows as "Sintel (2010) [English]".
4. **From Computer is unchanged.** Add Subtitles, To This File, From Computer: several files can
   still be ticked, and all of them are added.
5. **Regression.**
   - Settings, Storage still lists the downloaded subtitles and can delete them.
   - A folder rule (To This Folder, From OpenSubtitles) still downloads the next episode's
     subtitle when it plays.
