# "Skip this version" on the update notice (branch wip/update-skip-version)

Branch `wip/update-skip-version`, made from `origin/wip/next-test` (62bf713e005). Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), public brand only: the vlc profile has no update notice. Requested by StickyGonzales, 2026-11-01.

## 1. What it does
The update notice (redesign/UPDATE_NOTICE_NOTES.md) gets a third choice:

| Button | Effect |
|---|---|
| **Download** | opens the release page; the notice is hidden until the next day (as before) |
| **Later** | the notice is hidden until the next day (as before); Escape on any of the buttons is Later |
| **Skip this version** | that exact version is never offered at the start again. A newer version shows the notice as usual, and from then on the skip is gone |

- **Check Now** (Settings > General) always shows the newest version, a skipped one included, and its notice.
- **Settings > General > Skipped version** appears while a version is skipped: "The update notice does not offer Cone Player X.Y.Z …" and a button **Undo Skip of X.Y.Z**. Undo clears the skip; when that version is known to be available, the notice shows again at once.
- When the latest release is not newer than the running Cone (an upgrade was installed), the skip is cleared.

Stored in the Qt settings (`vlc-qt-interface.ini`, group `[RdUpdateCheck]`): `SkippedVersion=X.Y.Z` (removed when cleared).

## 2. Files
- `modules/gui/qt/util/rd_update_check.hpp/.cpp`: `skippedVersion` property, `skipVersion()`, `undoSkip()`; the start and the reply leave a skipped version's notice hidden unless the check was "Check now"; a newer version clears the skip.
- `modules/gui/qt/maininterface/qml/RdUpdateNotice.qml`: the third button.
- `modules/gui/qt/dialogs/redesign/settings/pages/SettingsGeneralPage.qml`: the "Skipped version" row.

## 3. Test hook
The update check only talks HTTPS to api.github.com, so a fake server needs DNS and a trusted test certificate (what the Linux sandbox did for the notice). On the PC that would change Windows' hosts file and certificate store, which the PC session does not do. Instead: when the environment variable **`CONE_UPDATE_CHECK_TEST_FILE`** names a file, the check reads that file as GitHub's answer (HTTP 200) instead of asking the network (log line "update check: answer read from … (test)"). Unset, nothing changes. The file is a release in GitHub's format, for example `{"tag_name": "v1.0.2", "html_url": "https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.0.2"}`. A missing file counts as a failed request.

## 4. Windows retest (PC session)
A manual build is Cone 0.1.0, so any 1.x answer is newer. In PowerShell, per step: write the answer file, then start the build with the variable set, e.g. `$env:CONE_UPDATE_CHECK_TEST_FILE = '<WORK_DIR>\answer.json'; & '<build>\Cone.exe'`. To make the start-up check run again on the same day, delete `CheckedOn` and `DismissedOn` under `[RdUpdateCheck]` in `portable\Cone\vlc-qt-interface.ini`.
1. **Skip.** Answer v1.0.2. About 4 s after the start the notice "Cone Player 1.0.2 is available" shows with Download, Later and Skip this version, nothing cut off. Click **Skip this version**: it closes; the ini has `SkippedVersion=1.0.2`.
2. **Skipped stays away.** Clear the day, start again with the same answer: no notice.
3. **Settings.** Settings > General: the "Skipped version" row with "Undo Skip of 1.0.2". **Check Now**: "Cone Player 1.0.2 is available." and the notice shows (Check Now always shows the newest).
4. **A newer version.** Answer v1.0.3, clear the day, start: the notice "Cone Player 1.0.3 is available" shows; the ini no longer has `SkippedVersion`; Settings has no "Skipped version" row.
5. **Undo.** Skip 1.0.3, open Settings > General, click **Undo Skip of 1.0.3**: the row goes away and the notice shows again.
6. **Later and Escape** behave as before (hidden until the next day).
