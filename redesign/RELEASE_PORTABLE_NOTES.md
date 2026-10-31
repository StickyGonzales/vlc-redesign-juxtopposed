# The portable zip keeps its settings next to Cone.exe (branch wip/release-portable)

Branch `wip/release-portable`, made from `origin/wip/next-test` (bbea290093) with `redesign` (612574e76d) merged in, draft pull request into `wip/next-test`. CI and docs only: no app code, nothing to build for a test before the next release.

## Why
The 0.1.0 and 0.2.0 beta zips held an empty `portable` folder (added by hand when they were published), so Cone kept its settings, media library and presets in that folder next to `Cone.exe`. The 1.0.0 zip is made by the release workflow, which ships the build's zip as built, without that folder. So the 1.0.0 zip writes its settings to `%APPDATA%\Cone`, the same folder an installed Cone Player uses (STATUS.md 2026-10-26, release check).

## Change
- `.github/scripts/release-package.sh` (the release workflow's packaging step): after copying the build's zip, it adds the empty folder `ConePlayer-<version>/portable/` to the release zip, then checks that it is there. It stops when the build's zip already has a portable folder, so nobody ships someone's settings by mistake. Only the zip gets the folder: the installer is built from the same files, and an installed Cone Player must keep using `%APPDATA%\Cone`. The SHA-256 in `SHA256SUMS.txt` and the release text are computed after the folder is added.
- `build-windows.yml` is unchanged, so test-build zips stay as they are (the PC session's test folder has its own `portable` folder).
- Texts: README's download table, the release text template (`.github/release/release-notes.md`) and `redesign/CI_RELEASE_NOTES.md` now say the zip keeps its settings in the `portable` folder; the release text adds that deleting the folder makes Cone use `%APPDATA%\Cone` instead. `RELEASE_1.0_NOTES_DRAFT.md` stays as published: 1.0.0's zip has no portable folder.
- README still names the 1.0.0 file. Its text is meant for the next release, so it reaches `redesign` (the homepage) together with that release, when the file names are updated anyway.

## For the next release's notes
Who used the 1.0.0 zip has settings in `%APPDATA%\Cone`. A new zip starts with an empty `portable` folder, so it starts like a first run. To keep the 1.0.0 settings, delete the new zip's `portable` folder before the first start. One line for the next release's "New since 1.0.0" list: "The zip keeps its settings in the portable folder next to Cone.exe again, as the betas did. Coming from the 1.0.0 zip? Delete that folder to keep using your settings."

## Sandbox test
`release-package.sh` run on a fake build (`ConePlayer-1.2.0-win64.zip` with a top folder and two files, plus an installer file):
- the release zip lists `ConePlayer-1.2.0/portable/` after the build's files;
- `SHA256SUMS.txt` matches both files (`sha256sum -c`) and the GITHUB_OUTPUT checksums;
- run again on its own output, it stops: "already holds a portable folder".

## Retest on Windows (with the next release, or a manual release run with a test tag)
1. Download the zip from the release, check its SHA-256 against `SHA256SUMS.txt`, and unzip it with Explorer ("Extract all"). The folder has an empty `portable` folder next to `Cone.exe`.
2. Start `Cone.exe`, change the theme or the accent, then quit. `portable` now holds the settings (`vlcrc` and the `Cone` folder), and `%APPDATA%\Cone` has not changed (compare its modified dates from before the start).
3. Move the whole folder somewhere else and start it again: the changed theme or accent is still there.
4. Delete `portable` and start it: Cone uses `%APPDATA%\Cone` (an installed Cone Player's settings, if any).
5. The installer from the same release: install it, start Cone Player, change a setting. It is written to `%APPDATA%\Cone`, and `C:\Program Files\Cone` has no `portable` folder.
