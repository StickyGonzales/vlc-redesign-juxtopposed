# Linux release: the .deb's file name matches SHA256SUMS.txt (no "~")

Branch `wip/fix-deb-asset-name`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Linux packaging and release workflow only; nothing in the app changes.

## 1. The bug

linux-v1.1.2-beta2 built the package as `cone-player_1.1.2~beta2_amd64.deb`. GitHub keeps only letters, digits, `.`, `-` and `_` in a release file's name and stored it as `cone-player_1.1.2.beta2_amd64.deb`, so SHA256SUMS.txt and the release text named a file that did not exist and `sha256sum -c SHA256SUMS.txt` failed for it (fixed by hand for beta 2, STATUS.md 2026-11-01 15:10).

## 2. The fix

| Where | Before | After |
|---|---|---|
| File name (`linux-deb.sh`) | `cone-player_1.1.2~beta2_amd64.deb` | **`cone-player_1.1.2-beta2_amd64.deb`**: the release's own version, as in the tarball (`Cone-1.1.2-beta2-linux-x86_64.tar.xz`) and the tag (`linux-v1.1.2-beta2`) |
| Package version (`dpkg-deb -f ... Version`) | `1.1.2~beta2` | `1.1.2~beta2` (unchanged) |
| A release without a label | `cone-player_1.1.2_amd64.deb` | the same |

**Debian version order is unchanged:** apt reads the version from the package, never from the file name. `1.1.2~beta2` still sorts before `1.1.2` and after `1.1.2~beta1` and `1.1.1`, so the final 1.1.2 package upgrades the beta.

**Two checks, so it can not come back** (`.github/scripts/release-asset-names.sh`):
- `check <files>`: fails for a name GitHub would change (any character other than letters, digits, `.`, `-`, `_`, or a leading or trailing `.`). Runs in **every build-linux run** right after the package is built, and in release-linux **before** the checksums are written, so a bad name stops the release before anything is uploaded.
- `verify <tag> <files>`: in release-linux **after** the upload, reads what GitHub stored (`gh release view --json assets`): every file must be there under its own name and size, and every line of SHA256SUMS.txt must name a stored file. A mismatch fails the run while the release is still a draft.

The release job now checks out `.github/scripts` (sparse) for the script; the rest of the job is as before.

## 3. Tests (sandbox)

| Test | Result |
|---|---|
| `linux-deb.sh` on a stand-in folder `Cone-1.1.2-beta2-linux-x86_64` | writes `cone-player_1.1.2-beta2_amd64.deb`, `Version: 1.1.2~beta2` |
| `dpkg --compare-versions` | `1.1.2~beta2` < `1.1.2`, > `1.1.2~beta1`, > `1.1.1` |
| `check` on the new name | ok |
| `check` on `cone-player_1.1.2~beta2_amd64.deb` | fails with the error above |
| `verify`, the beta 2 situation (GitHub stored `.` for `~`; `gh` stubbed with that asset list) | fails: SHA256SUMS.txt names a file that is not on the release |
| `verify`, the new names | passes; `sha256sum -c SHA256SUMS.txt` OK for all three |
| The published beta 2's SHA256SUMS.txt (hand-fixed) | GitHub kept `-`, `_` and `.` in all three stored names, as the check assumes |

## 4. Runs

| Run | Result |
|---|---|
| (filled in below the PR) | |

release-linux itself only runs from a `linux-v` tag on `redesign`, so it is not run for this branch; build-linux runs the same `check` and builds the package with the new name, and the smoke checks install that `.deb`.

## 5. Retest at the next Linux release (PC session or whoever publishes)

1. Run release-linux from the next `linux-v` tag as usual. The "Checksums and notes" step prints `ok:` for the three files; "Draft the GitHub Release" ends with "every file is on ... under its own name".
2. On the draft: the .deb is listed as `cone-player_<version>_amd64.deb` with the release's own version (for example `cone-player_1.1.3-beta3_amd64.deb`), the same name as in SHA256SUMS.txt.
3. Download the three files and SHA256SUMS.txt into one folder: `sha256sum -c SHA256SUMS.txt` prints OK three times.
4. `sudo apt install ./cone-player_*_amd64.deb` over the installed beta 2: apt reports an upgrade from `1.1.2~beta2`.
