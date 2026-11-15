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

**It goes red on the old code.** I put the old ranking (name score only) into the two functions.
The test then fails 5 checks, starting with "language first: the first English result, not the
Hebrew one: got "0", expected "1"": the Hebrew result is picked, the reported bug.

**Not testable in CI: the real OpenSubtitles search.** It needs an account and an API key. It is
retest step 1.

## Green runs

(filled in when CI has run)

## Windows retest (PC session)

Build: build-windows on wip/subtitle-language-first (the run named in the PR).

1. **The reported case.**
   - Open Sintel, then Add Subtitles, To This File, From OpenSubtitles, with English chosen.
   - The pre-ticked result is an English one (its language shows in the name or in the downloaded
     file).
   - The English results come first in the list, and the Hebrew and other results are still
     listed below them.
   - Save: the English subtitle downloads and shows.
2. **Another language.**
   - Choose Hebrew (or French) in the language list. The search runs again.
   - A result in that language is pre-ticked and its results come first.
3. **No result in the chosen language.**
   - Choose a language with no Sintel subtitles, if the search still returns others.
   - The first result OpenSubtitles gives is pre-ticked, and nothing is hidden.
4. **A show folder.**
   - To This Folder, From OpenSubtitles, English: every episode's match is an English file of
     that episode.
   - Play the next episode: its automatic download is English too.
5. **From Computer is unchanged.** Files from the computer are ordered and ticked as before.
