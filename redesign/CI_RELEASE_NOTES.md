# CI: compiler cache and releases (branch wip/ci-release)

Status: written and checked offline. **Nothing is verified.** No workflow was run from this session.

Base: `wip/ci-release` starts from `origin/wip/cone-release` (it builds on that branch's workflow changes). Merging it into redesign also brings in all of wip/cone-release, which is not verified yet either. Only CI files changed: `.github/workflows/`, `.github/scripts/`, `.github/release/`.

## 1. What changed

| File | Change | Commit |
|---|---|---|
| `.github/workflows/build-windows.yml` | Runs the build through **ccache**, with the cache stored between runs. Also callable by the release workflow (inputs `brand`, `release`, `cache-branch`). Normal builds otherwise behave as before: same triggers, artifacts, 14-day retention, and the installer step still may fail. | d8719d00bd, 4a4efa283f |
| `.github/scripts/win64-build.sh` | New helper that runs inside VideoLAN's build image. It puts ccache in front of the cross compilers, then runs `build.sh` (unchanged) and `make package-win32-zip`, or `make package-win32-exe` for the installer. It prints the ccache statistics at the end. | d8719d00bd |
| `.github/workflows/release.yml` | New release workflow (section 3). | 4a4efa283f |
| `.github/scripts/release-guard.sh` | Refuses anything but verified code, and checks the version. | 4a4efa283f |
| `.github/scripts/release-package.sh` | Builds the release files and `SHA256SUMS.txt`. | 4a4efa283f |
| `.github/scripts/release-notes.py`, `.github/release/release-notes.md` | Release notes template and the script that fills it. | 4a4efa283f |

## 2. Build cache

**How it works**
- **Before:** the workflow cached a `.ccache` folder, but nothing used ccache, so the cache stayed empty and every build compiled everything (about 27 minutes in run 38815866248).
- **Wrappers:** inside the build image, `win64-build.sh` creates links named like the compilers (`x86_64-w64-mingw32-gcc`, `-g++`, ...) that point to ccache, and puts them first in `PATH`. `build.sh` and configure run unchanged.
- **Which ccache:** the image's own ccache if it has one. Otherwise a pinned ccache 4.10.2 that the workflow downloads and checks against a fixed SHA-256. If that download fails, the build still runs, just without the cache.
- **Settings:** `CCACHE_DIR=/build/.ccache`, max 2 GB, `compiler_check=content`, so a new build image never reuses results from an old compiler.
- **Same output:** ccache only skips a compile it has seen before (same compiler, flags and preprocessed source) and returns that compiler output byte for byte. No path rewriting is enabled, so `__FILE__` and debug paths don't change. Checked here with mingw-w64 g++: the object files from a plain compile, a ccache miss and a ccache hit were identical (`cmp`).

**Cache keys** (`ccache-win64-<brand>:<branch>:<commit>`; a `:` can't appear in a branch name, so one branch's keys never match another's):
1. The run's own branch and brand.
2. Its own branch, other brand. The vlc and public builds share almost every object file.
3. `redesign`, same brand.
4. `redesign`, other brand.

New branches therefore start warm from redesign.
- **Fallback:** works because `redesign` appears to be the default branch, and GitHub lets a branch read only its own caches and the default branch's. If the default branch is ever something else, steps 3 and 4 find nothing; the build still works, it just starts cold.
- **Saving:** the cache is saved at the end, also when the build failed. It isn't saved when the exact key was already restored, or for release builds (a tag's cache can't be read by any later run).
- **Storage:** each saved cache is at most about 2 GB. GitHub keeps 10 GB per repository and drops the least recently used entries first.

**What the log shows**
- Step **"Compiler cache restored"**, one of:
  - `compiler cache restored from ccache-win64-public:redesign:<commit>`
  - `compiler cache of this exact commit: ...`
  - `no compiler cache found: cold build, every file is compiled`
- Step **"Build in VideoLAN's image"**, at the start: the ccache version and path, the cache folder, the wrapped compilers and the restored cache's size. At the end: a collapsible group "ccache statistics of this build" (hits, misses, cache size).
- Step **"Compiler cache result"**: one line such as `ccache: 4210 hits (4198 direct, 12 preprocessed), 35 misses, hit rate 99.2%`.
- The **job summary** (run page, "Summary") repeats the restored-cache line and the result line.

**How to test the cache** (two manual runs of the same branch)
1. GitHub, **Actions**, **build-windows**, **Run workflow**, "Use workflow from: `wip/ci-release`", brand `public`, **Run workflow**.
2. Run 1 starts cold: redesign has no ccache cache yet (that only starts once this is merged), and the branch has none. Expect "no compiler cache found", a hit rate near 0 percent, and a build time like before (the "Build in VideoLAN's image" step took about 27 minutes in run 38815866248).
3. When run 1 is green, start the same thing again (step 1).
4. Run 2 should show "compiler cache of this exact commit" and a hit rate near 100 percent. Compare the duration of **"Build in VideoLAN's image"** between the two runs (click each run, the step shows its time).
   - Compiling is skipped on hits, but configure, Qt's code generators, linking and packaging still run, so the step gets shorter, not instant. The real gain still has to be measured.
5. Optional: run once with brand `vlc`. It should restore `ccache-win64-public:wip/ci-release:...` (the other brand) and hit most files.
6. The artifacts are still `vlc-redesign-win64-public` and `cone-installer-win64`, kept 14 days.

## 3. Release workflow

**Triggers**
- Pushing a version tag `v<major>.<minor>.<patch>` with an optional suffix (`v0.1.0`, `v0.2.0-beta.1`).
- Or by hand: Actions, **release**, Run workflow, with the inputs `version` and `prerelease` (default on).

**Guard (job "Only verified code (redesign)")**
- **Pushed tag:** its commit must be on `redesign`. If not, the run fails and tells you how to delete the tag.
- **Manual run:** it must be started from `redesign` ("Use workflow from: redesign"), and the tag must not exist yet. The release then creates the tag on the commit it built.
- **Version:** must look like `v0.1.0` or `v0.2.0-beta.1`.
- When the guard fails, nothing is built and nothing is published.

**Build:** the normal `build-windows.yml` with brand `public` and the release's tag as its `version` input, so the app's version and the package names come from the tag on a manual run too (`v1.0.0-rc1`: version 1.0.0, packages `ConePlayer-1.0.0-rc1-win64.zip` and `coneplayer-1.0.0-win64.exe`). In a release build the installer must succeed. The run starts from redesign's compiler cache and doesn't save one. Both packages go to the release job exactly as built; they need the Cone Player names (`wip/cone-player`, redesign/RENAME_CONE_PLAYER.md), or the build's release-files step fails.

**Release** titled "Cone Player <version>: Juxtopposed's redesign on a real VLC 4 fork, not a skin" (Decision 68, Cone Player name: Decision 73; `<version>` without the `v`) (`gh release create` with the repository's own token, `contents: write` for this job only). Published as a **pre-release** by default; a pushed tag is always a pre-release, a manual run can untick it. Files:

| File | What |
|---|---|
| `ConePlayer-<version>-win64.zip` | the build's zip (top folder `ConePlayer-<version>`) plus an empty `ConePlayer-<version>/portable` folder, so the unzipped Cone Player keeps its settings next to `Cone.exe` as the betas did (added 2026-10-26, after 1.0.0, whose zip wrote them to `%APPDATA%\Cone`); `release-package.sh` checks its name and folder, adds the folder to the zip only (the installer is built from the same files and must keep `%APPDATA%\Cone`) and stops if the build's zip already has one |
| `coneplayer-<version>-win64.exe` | the build's installer; renamed only for a suffixed tag (the build names it `coneplayer-1.0.0-win64.exe` for `v1.0.0-rc1`) |
| `SHA256SUMS.txt` | SHA-256 of both |

**Notes** come from `.github/release/release-notes.md`, filled in by the workflow. They cover:
- **What Cone is**, an "experimental" warning, and that Cone installs next to VLC.
- **Downloads:** the two files with their SHA-256 and how to check them in PowerShell, plus the SmartScreen note (the files are unsigned).
- **Credits:** "Based on VLC media player by VideoLAN"; "Design by Juxtopposed" (Figma file and video, CC BY 4.0); "not affiliated with, endorsed by or supported by VideoLAN or Juxtopposed"; VLC trademark line.
- **License:** GPL v2 or later, a link to the exact source commit, and a link to the build log.

Any placeholder left without a value stops the release.

**How to do a test release safely**

Before merging, check only the refusal; nothing gets published:
1. Actions, **release**, Run workflow, "Use workflow from: `wip/ci-release`", version `v0.0.1-test.1`, Run.
2. Expect a red run: "started from refs/heads/wip/ci-release: start the release from the redesign branch". The build and release jobs are skipped.

After wip/ci-release is merged into redesign (and verified):
1. Actions, **release**, Run workflow, "Use workflow from: `redesign`", version `v0.0.1-test.1`, keep **Publish as a pre-release** ticked, Run. It takes about as long as a normal build, plus a few minutes.
2. When green: open **Releases** (right side of the repository page). The release "Cone v0.0.1-test.1" is marked **Pre-release**. Check the three files, the notes, and that the checksums match the downloads (`Get-FileHash`).
3. **Delete it afterwards:**
   - Open the release, click the trash icon (Delete), confirm.
   - Deleting a release keeps its tag, so also open **Tags** (Releases page, "Tags" tab), find `v0.0.1-test.1`, "...", Delete tag. Or in PowerShell in the repository: `git push origin :refs/tags/v0.0.1-test.1`.
4. Use a new version name for every test (the guard refuses a tag that already exists).

Tag route, also after the merge: `git tag v0.0.1-test.2 origin/redesign; git push origin v0.0.1-test.2`. Delete it the same way.

## 4. Not done, limits

- **Nothing run:** no workflow was started from this session. Both workflows pass actionlint 1.7.7 and shellcheck. Tested locally:
  - ccache through the compiler links (identical objects; cold run misses, warm run hits);
  - the helper's setup, statistics and summary line, using a stub build;
  - the guard's six cases: tag on redesign, tag off redesign, bad version, manual run from redesign, manual run from another branch, existing tag;
  - the packaging and checksums;
  - the notes template.
- **Verified-code rule:** I didn't find a line saying "redesign only receives verified code" in CLAUDE.md, either on `origin/redesign` or on `wip/cone-release`. I applied the rule as you described it: releases only from redesign.
- **ccache in the image:** I couldn't confirm whether VideoLAN's build image has its own ccache (the job log available to me starts too late). The pinned download covers the case where it doesn't.
- **Pinned ccache checksum:** the fixed SHA-256 is of the release file as downloaded here; ccache doesn't publish a checksum file next to that release.
- **Tag protection:**
  - A pushed tag runs the `release.yml` stored in the tagged commit itself. A tag on a branch with an edited `release.yml` could therefore skip the guard.
  - To close that gap: Settings, Rules, Rulesets, New tag ruleset, target `v*`, restrict creations to yourself. The workflow alone can't enforce this.
- **Version shown inside Cone:** the app and the installer still report VLC's version (`4.0.0-dev`), for example in "Apps" in Windows Settings and in the About dialog. Only the release file names and the zip folder carry the release version. Changing that touches the build and brand files, which this task excludes.
- **Code signing:** none. The notes tell users about the SmartScreen warning.
- **Cancellation:** two manual releases started at the same time from redesign share one build queue, so the later one cancels the earlier one's build.
- **Speed-up not measured:** the expected speed-up has to be measured with the two runs in section 2.
