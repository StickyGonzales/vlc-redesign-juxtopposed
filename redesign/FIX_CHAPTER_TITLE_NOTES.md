# Chapter titles 4 px right of Figma (P7-06, branch wip/fix-chapter-title)

Branch `wip/fix-chapter-title`, made from `origin/wip/next-test` (8e005df792). Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt/player/input_models.cpp`), no core change.

WINDOWS_CHECKLIST.md row 251 (P7-06): in the Chapters tab the chapter title started 4 px right of Figma (72 px from the panel edge on Linux, Figma 68); cause not found.

## 1. Cause
The row was never the problem:
- Figma "chapters" (Controls, `Frame 39`): row at 20, number box 4 + 34, gap 10, so the title's box starts at x 48 in the row, 68 from the panel edge.
- `RdListRow.qml` puts it there. Rendered with Qt 6.8.3, VLC's Qt version, outside VLC with the same file, "Winter" starts at 68.

In Cone the text itself was different: VLC's Matroska demuxer writes a **space** (after a "+" for each nesting level) in front of every chapter name (`modules/demux/mkv/matroska_segment_parse.cpp`, `KaxChapterString`). The list drew " Winter", one Inter space (about 4 px at 14 px) right of the box. The seek bar's chapter name (`getNameAtPosition`) carried the same space.

The sandbox test media and most real films are Matroska, so this showed on Windows too.

## 2. Fix
`ChapterListModel` (`input_models.cpp`) trims the chapter name for the list and for the seek bar's chapter name (`chapterName()`). The "+" markers of nested chapters stay, so their depth still shows. Other formats (MP4 chapters, DVD) had no leading space, so nothing changes for them. The vlc profile gets the same trim (the same model is shared).

## 3. Checks
- `input_models.cpp` compiles with no new warnings (g++, `-Wall -Wextra -Wconversion`, syntax check against Qt 6 headers).
- privacycheck: 0 problems. No QML changed.

## 4. Sandbox test (Linux)
RESULTS

## 5. Windows retest steps
1. Play a Matroska file with chapters (any .mkv with named chapters).
2. Open the queue panel (queue button, bottom right), click the **Chapters** tab.
3. Take a screenshot and crop the panel next to Figma (Controls, panel variant "chapters").
   - Expect: the chapter number at the same x as Figma, and the title starting 10 px after the number box, at the same x as Figma's "Winter" (68 px from the panel's left edge at 100% scaling).
4. Hover the seek bar over a chapter.
   - Expect: the chapter name in the seek preview has no leading space (centred under the time).
5. Play an .mp4 with chapters, if you have one: titles at the same x.
