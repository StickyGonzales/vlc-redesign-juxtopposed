# No "Looks like a show" prompt for short files (branch wip/fix-short-episode-prompt)

Branch `wip/fix-short-episode-prompt`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone extra (Decision 71, Up Next), interface only (`modules/gui/qt/player/rd_up_next.*`).

## Cause
Up Next never autoplays a file shorter than the show's shortest episode: under 2 minutes, or under 10 minutes when the file names only weakly look like episodes (UP_NEXT_PLAN.md 3.3). `evaluate()` drops such a file. But the prompt was decided in `updateCard()` from `showActive()` alone, which does not look at the length. A 30 s clip in a folder that looks like a show then asked "Looks like a show. Play episodes in a row?", for autoplay it would never do.

## Fix
`RdUpNext::longEnough()` holds the length rule. Both `evaluate()` and the prompt use it, so the prompt asks only about a file Up Next could actually autoplay. A file whose length is not known yet (a stream) is treated as before.

## Runs
| Run | Result |
|---|---|
| build-windows #145 (41253474570), this branch | build and **all smoke checks pass** |
| build-linux #53 (41253486005), test-only `wip/test-linux-small-fixes` = wip/next-test + the four small fixes | in the sandbox: a 30 s `Clip Show S01E01.mp4` (folder with S01E02): **no prompt** 15 s in; a 2 min 10 s `Long Show S01E01.mp4`: the prompt shows, as before. Picture: `redesign/fix-shots/short_episode_prompt.jpg` |

Checks: C++ syntax check of `rd_up_next.cpp` (g++ `-Wall -Wextra -Wconversion`, public brand): no warnings in this file. privacycheck 0.

## Windows retest (PC session)
Settings > Playback > Episodes "Autoplay next episode": **Ask for each show** (the default). Then Settings > Playback > Remembered shows > **Forget all**.
1. **Short clips.** A folder with `Clip S01E01.mp4`, `Clip S01E02.mp4`, each under 2 minutes (for example 30 s), never answered before. Play E01 and wait 15 s: **no** "Looks like a show" prompt.
2. **Real episodes.** A folder of episodes over 2 minutes (`Show S01E01.mkv` …): after about 10 s the prompt shows, as before.
3. **Weak names** (`Show 01.mp4`, `Show 02.mp4`): files under 10 minutes get no prompt; files over 10 minutes do.
