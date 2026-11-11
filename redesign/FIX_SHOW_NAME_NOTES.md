# Clean show names on the Up Next card and in the Playback tab (1.4.0)

Branch `wip/fix-show-name-clean`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-11 (the BUG row "the show name is the raw release folder name", PC test 2026-11-08).

## 1. The bug
A show kept in a release folder showed that folder's raw name: "Some.Show.S01.1080p.WEBRip.10Bit.DDP5.1.x265-Group" in the Playback tab's "Autoplay this show" and "Up Next for <show>" rows, and on the Up Next card. `rdepisode::detect()` took the show root folder's name as it is (`show.name = QFileInfo(show.root).fileName()`).

## 2. The fix
`rdepisode::displayName(folderName)` (`player/rd_episode_parser.cpp`), used for `show.name`:
- **Cut points.** The name ends at:
  - the season or episode marker ("S01", "S01E02", "S01-S03", "1x02", "Season 1", "Series 2");
  - a year ("Doctor.Who.2005", "(2005)"), unless the year is the name ("1883");
  - the first release tag. These are the parser's own list (resolution, codec, source, audio, HDR, streaming services, sites such as RARBG / YTS / EZTV) plus words only folder names carry (Complete, Multi, Subs, TGx, PSA, MSD, …).
- **Removed:** brackets (`[TGx]`, `{MSD}`) and sites in front ("www.Site.com - ").
- **Spacing:** dots and underscores become spaces.
- **Abbreviations:** runs of single letters get their dots back ("S.W.A.T.").
- **Fallback:** when nothing is left, the folder name with spaces.
- **What stays the same:**
  - The show's key, which keeps its answers, credits points and track choices, stays the folder path, so earlier answers still apply.
  - The "folder supplies the title" check for numbered files still reads the raw folder name.
  - The extra folder words are used only here, never in episode titles ("The Complete Story" keeps its title).
- **Unit tests** (`tests/test_rd_episode_parser.cpp`, `testDisplayNames`):
  - 25 folder names: release folders, season packs, years, brackets, sites, groups, abbreviations, and names that are already clean;
  - `detect()` on a release folder and on a season folder.
  - Locally: `rd_episode_parser: 504 checks, 0 failed` (the earlier cases unchanged).

## 3. Windows retest (PC)
1. Make a folder `Some.Show.S01.1080p.WEBRip.x265-GROUP` with three short videos named `Some.Show.S01E01.1080p.WEBRip.x265-GROUP.mkv`, `...S01E02...`, `...S01E03...`. Any clips will do, at least 2 minutes each, for example the generated "Test Show" episodes renamed.
2. Open the first one in Cone. Sidebar > Playback: the rows read "Autoplay this show" with **Some Show** under it, and "Up Next for Some Show".
3. Seek to about 20 s before the end: the Up Next card says **Some Show** and the next episode (S01E02).
4. Rename the folder `Doctor.Who.2005.1080p.BluRay`, with the episodes in a `Season 1` subfolder (`Doctor.Who.S01E01.mkv`, ...): the rows and the card say **Doctor Who**.
5. A show answered earlier (Autoplay on or off) keeps its answer after this update: the key is the folder path, not the name.
