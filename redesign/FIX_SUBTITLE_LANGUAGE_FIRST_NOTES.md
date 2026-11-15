# OpenSubtitles best match: the chosen language first

StickyGonzales, 2026-11-15, for 1.5.0 (11/19). Found in the PC's retest of #141: Add Subtitles,
To This File, From OpenSubtitles, Sintel with English chosen: the Hebrew result was pre-ticked.
Branch wip/subtitle-language-first.

## What was wrong (Cone's code)

**The search was fine; the ranking was not.**
- The search already asks OpenSubtitles for the chosen language, but its results can still mix
  languages.
- The dialog then ordered the results by how well each file name matches the video's name
  (`SubtitleMatcher::score`). The language counted only +40 (match) or -10 (another language),
  against 400 to 900 for the name.
- So a Hebrew file named exactly like the film, "Sintel (2010).srt" (890), beat English files
  with longer names, "Sintel.Open.Movie.2010.720p.srt" (740), and was pre-ticked.

## Fix

**OpenSubtitles results are ranked language first** (`SubtitleMatcher::rankResults` and
`bestResult`, add_subtitles.cpp `rankedCandidates`). In order:
1. **Results in the chosen language**, in OpenSubtitles' own order (their ranking).
2. **Results in other languages**, in OpenSubtitles' order. With none in the chosen language,
   OpenSubtitles' top result is the best match.

   **One exception inside each language group: the variant kept for a show still counts.** A show
   episode's "forced" or "SDH" file, or the plain one, picked by hand for an earlier episode, is
   kept for the next ones (as before this fix). Variants nobody asked for come after the plain
   file. Otherwise the next episode would pre-tick, and the folder rule auto-download, whatever
   variant OpenSubtitles lists first. Equal cases keep OpenSubtitles' order. Films have no
   variants (those words count as part of the title), so for a film this is purely OpenSubtitles'
   order.
3. **Results that are not this video's** (another episode, another title), last and never
   pre-ticked, as before.

**Nothing is hidden.** Every result stays in the list.

**What counts as the chosen language.**
- The same language tag, ignoring case.
- "pt" takes both "pt-br" and "pt-pt".
- "pt-br" does not take "pt-pt", and "zh-cn" does not take "zh-tw" (another spelling or script).

**Where it applies.** Every OpenSubtitles path:
- the results list for one file (the pre-tick and the order);
- the episode matches for a folder or playlist;
- each episode's list of choices;
- the automatic download for the next episodes of a folder (with the folder's saved language).

**Computer files and links** are ranked as before.

**A late search answer is dropped.** Changing the language starts a new search. If the previous
search answered after it, its results replaced the new ones and were ranked against the new
language. Now only the latest search's answer is shown (found by the independent review).

## Tests

**Unit test `test_rd_subtitle_picks`** (unit-tests.yml, with the sanitizers, 45 checks). The new
part, `testLanguageFirst`, covers:
- **The mixed list from the retest.** Hebrew "Sintel (2010)" first in OpenSubtitles' order, two
  English files with longer names, a French one and another film. The first English result is the
  best match. The order is: English in OpenSubtitles' order, then the other languages, then the
  other film.
- **No result in the chosen language.** OpenSubtitles' top result is picked, and both results
  stay listed.
- **Another film** is never the best match.
- **Regions.** "pt-br" chosen picks the pt-br result; "pt" chosen takes either.
- **An episode.** The other episode's result never comes first.
- **The kept variant.** With no variant kept, the plain English file comes before the SDH file
  OpenSubtitles lists first. With "sdh" kept, the SDH file is picked.

**It goes red on the old code.** I put the old ranking (name score only) into the two functions.
The test then fails 5 of 47 checks, starting with "language first: the first English result, not
the Hebrew one: got "0", expected "1"": the Hebrew result is picked, the reported bug. Without the
variant ordering, "the plain English file without a kept variant" fails.

**Independent review.** The language comparison, the four OpenSubtitles paths, thread safety and
the other sources were clean. Fixed from its findings: the kept variant (above), the late search
answer (above) and an outdated comment.

**Not testable in CI: the real OpenSubtitles search.** It needs an account and an API key. It is
retest step 1.

## Windows retest 1 failed: OpenSubtitles mislabels uploads

**What the PC saw.** Retest on build-windows 268 (f8e2231ac59), step 1: Sintel with English chosen
still listed "sintel.he" first and pre-ticked it.

**Why.** OpenSubtitles itself files that upload under English: `languages=en` returns it tagged
"en", and also under Finnish, while the file holds Hebrew text. The ranking used OpenSubtitles' tag,
so all the English-tagged results tied, and OpenSubtitles' own order put "sintel.he" first.

**Fix (`SubtitleMatcher::namedLanguage`, `rankResults`).** Within the chosen language, a result
whose file name, or else release name, names another language goes after the others. OpenSubtitles'
order decides otherwise, and nothing is hidden.
- **What counts as naming a language.** A whole word after the title: a language name or three
  letter code anywhere there (".heb", "Hebrew", ".fin", also before release tags as in
  "Movie.2010.heb.720p"), a two letter code only as the last word (".he", ".fi").
- **What never counts.** A part of a word ("the", "chef"), or a word of the title ("The Hebrew
  Hammer", "He Got Game").
- **Several mislabeled results** keep OpenSubtitles' order among themselves. If every result is
  mislabeled, OpenSubtitles' top one is still the best match.

## Several OpenSubtitles results again (StickyGonzales's decision for 1.5.0)

**The decision.** It reverses the one-choice part of #141: StickyGonzales downloads several
subtitles at once and tries them one by one.
- **The best match** is still ticked to start with.
- **A click** ticks or unticks a row, for every source. Clicking the only ticked row unticks it, and
  Save is then disabled, as for files from the computer.
- **Save** downloads every ticked result.
- **The subtitle shown** is the best ranked of the ticked ones: they are saved in the list's order
  (`rdsubtitles::checkedInOrder`), and the first saved is the one selected.
- **Kept from #141:**
  - the clean names ("Sintel (2010).eng.srt", the track "Sintel (2010) [English]");
  - one file per subtitle: the same subtitle downloaded again, or two ticked results with the same
    content, reuse one file, while a different subtitle with the same name is numbered "(2)";
  - the downloaded-subtitle cleanup (each download is recorded for its video as before);
  - an already loaded subtitle picked again is shown.

**RELEASE_NEXT_NOTES.md** now says this instead of "one result is ticked at a time".

**Quota.** Each ticked result is one OpenSubtitles download and counts against the account's daily
quota. If the quota runs out partway, the results are downloaded in the list's order, so the better
ranked ones are the ones kept. Saving again downloads them again, reusing the files on disk, and
counts again.

## Independent review (this round), fixed

- **"HI" read as Hindi.** "HI" (hearing impaired) and the other variant words (SDH, forced) are never
  a language word now, so ".en.hi" reads as English.
- **Episode titles and title words.** A language word counts only where a language goes: not the
  first word, and either the last meaningful word or right before a release tag, a year or the
  episode. So "The.Chinese.Restaurant" as an episode title does not count, while
  "Sintel.Hebrew.720p" and "Show.Hebrew.S01E04" (no year) now do.
  - **Known limit.** An episode titled with a language code as its last word ("Fin", "Ben") still
    reads as that language; it only moves down among the chosen language's results.
- **Traditional Chinese.** The push-down compares base languages, so with zh-tw chosen a ".chi"
  upload (zh-cn) is not pushed down.
- **Download order.** Downloads now follow the list's order instead of a hash's, so a failure
  partway keeps the better ranked results and the subtitle shown is still the best ranked one that
  arrived.
- **Notes.** The one-choice wording of FIX_1_5_0_NOTES.md is marked as superseded.

## Tests (this round)

**Unit test `test_rd_subtitle_picks`, 79 checks.**
- **The language word in a name:** .he, .heb, Hebrew, .fi, .fin, before release tags, in an
  episode name, and from the release name.
- **Words that must not count:** "the", "chef", "The Hebrew Hammer", "He Got Game", an episode title
  of plain words, "The Chinese Restaurant", "HI" and "SDH", a one-word title ("It").
- **Without a year:** "Sintel.Hebrew.720p", "Sintel.HEB.WEB", "Show.Hebrew.S01E04".
- **Traditional Chinese chosen:** a ".chi" upload is not pushed down.
- **The Sintel case:** "sintel.he" and a ".fin" file tagged English go below the English files, in
  OpenSubtitles' order, nothing hidden.
- **Other mislabels:** a mislabel by release name; an English file filed under Finnish; all results
  mislabeled.
- **Several checked:** a click adds, a click on a checked row unchecks it, the ticked results are
  saved in the list's order (best first).

**It goes red on the current #144 code.** I put #144's ranking back (no push-down), keeping only the
new name function so the test compiles. 4 checks fail, starting with "mislabeled: the English file,
not sintel.he: got "0", expected "1"": "sintel.he" is picked, the retest's failure.

**Not testable in CI:** the real OpenSubtitles list, which needs an account and an API key. It is
retest step 1.

## Green runs

All on f8e2231ac5:
- **build-linux #152:** build, packages and every smoke job pass.
  - The first attempt failed one Ubuntu 24.04 smoke check, "drawing: main window appears". Cone
    was started 0.4 s after the previous check's Cone was told to quit, and handed the file to
    that still-closing Cone (exit 0 in half a second, both tries).
  - The same check passed on Ubuntu 22.04 in that attempt, and the whole job passed on its one
    re-run. This change does not touch Cone's start.
- **build-windows #268:** build, installer and the Windows smoke pass.
- **unit-tests #14 and #15:** pass, test_rd_subtitle_picks included (47 checks).

## Windows retest (PC session)

Build: build-windows on wip/subtitle-language-first (the run named in the PR).

1. **The reported case (retest 1's failure).**
   - Open Sintel, then Add Subtitles, To This File, From OpenSubtitles, with English chosen.
   - The pre-ticked result is an English one, not "sintel.he".
   - "sintel.he" (and any other file named in another language) is listed below the English files,
     still in the list.
   - Save: the English subtitle downloads and shows; its text is English.
2. **Several at once.**
   - Tick two more English results (three ticked). Save: all three download.
   - The subtitle shown is the topmost ticked one.
   - The subtitle menu lists all three with clean names, such as "Sintel (2010) [English]".
3. **Untick.** Open the dialog again and click the pre-ticked row: it unticks, and Save is disabled
   with nothing ticked. Tick one again: Save works.
4. **No duplicates.** Tick a result you downloaded in step 2 and Save: it shows again, and the
   portable folder's subtitles\opensubtitles has no second copy of it.
5. **Another language.** Choose Hebrew (or French): a result in that language is pre-ticked and its
   results come first.
6. **From Computer is unchanged.** Several files can be ticked and added, as before.
7. **Cleanup.** Settings, Storage lists the downloaded subtitles and deletes them.
