# Installer: upgrades no longer bring back a removed desktop shortcut (#73)

Branch `wip/fix-upgrade-shortcut`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone build only: every installer change sits behind `PRODUCT_PROGID != "VLC"`; the vlc profile's installer is unchanged.

## 1. The bug

An upgrade or reinstall created the desktop shortcut again, also when the user had deleted it (seen on the 1.1.0 to 1.1.1 silent upgrade, STATUS.md 2026-11-01 14:30; listed as a known issue in 1.1.2).

**Cause:** NSIS's Memento (`${MementoSectionRestore}` in `.onInit`) restores the components picked at the last install from the registry. The last install had "Desktop shortcut" ticked, so every later install ticked it again, whatever is on the desktop now. The silent upgrade (`/S`) has no pages, so nothing could untick it.

## 2. The fix (`extras/package/win32/NSIS/vlc.win32.nsi.in`)

| Case | "Create a desktop shortcut" starts | Result |
|---|---|---|
| Fresh install (no Cone Player installed, or its folder deleted by hand) | ticked, as before | shortcut created |
| Upgrade or reinstall, the shortcut is on the desktop | ticked | shortcut kept (re-created) |
| Upgrade or reinstall, the shortcut was removed | **unticked** | **no shortcut** |
| Upgrade or reinstall, the user unticks a ticked box | (ticked) | **the existing shortcut is removed** |
| Upgrade or reinstall, the user ticks an unticked box | (unticked) | shortcut created |

- `.onInit`, after Memento: when a previous install exists (`$PreviousVersion`), the Desktop shortcut component (`SEC02b`) is selected only when `DesktopShortcutExists` finds the shortcut. The welcome page box and the components page both show that component, so they start in the same state; the silent upgrade uses it directly.
- `DesktopShortcutExists` looks at the all-users desktop, where the installer creates the shortcut and the uninstaller removes it. A 0.x beta's `Cone.lnk` counts too (the install already replaces it with `Cone Player.lnk`). A copy the user put on their own desktop is theirs: never counted, never touched.
- New hidden section `-DesktopShortcutOff` (after `SEC02b`): on an upgrade or reinstall with the box unticked it deletes the all-users `Cone Player.lnk`, so the box always means "the install has a desktop shortcut". On a fresh install it does nothing.
- Memento still saves the choice at the end (`.OnInstSuccess`); it no longer decides the next upgrade.

**Smoke checks** (`.github/scripts/win64-smoke.ps1`, real Windows on every build): after the silent install, three new checks: the shortcut exists on the all-users desktop; a silent reinstall keeps it; after deleting it, a silent reinstall does not create it again.

## 3. Test under Wine

Setup: Wine 9.0 (32 and 64 bit), makensis 3.09, mingw for `nsProcess.dll`; the installer built as `package.mak` does (public brand values, `brand-languages.sh`), with the payload of the released Cone Player 1.1.2 zip. Three installers: the old one as 1.1.2 (from wip/next-test), the old one as 1.1.3 (control), this branch as 1.1.3. A fresh Wine prefix per case.

Silent (`/S`):

| Case | Before | After |
|---|---|---|
| Fresh install (fixed 1.1.3) | no install | `Cone Player.lnk` on the all-users desktop, version 1.1.3 |
| Upgrade with shortcut (1.1.2, then fixed 1.1.3) | shortcut | shortcut, 1.1.3 |
| **Upgrade without shortcut** (1.1.2, shortcut deleted, then fixed 1.1.3) | none | **none**, 1.1.3 |
| Control: same, with the unfixed 1.1.3 | none | `Cone Player.lnk` again (the bug) |
| Same-version reinstall without shortcut | none | none |
| Same-version reinstall with shortcut | shortcut | shortcut |
| Shortcut only on the user's own desktop | user's copy | user's copy only, no second one |
| 0.x beta `Cone.lnk` on the desktop | `Cone.lnk` | `Cone Player.lnk` (renamed, as before) |
| Install folder deleted by hand after an upgrade without shortcut (Memento still says unticked), install again | no install folder | `Cone Player.lnk`: counts as a fresh install (review finding, second commit) |

Interactive (welcome page under Xvfb, picture `redesign/fix-shots/installer_upgrade_shortcut.jpg`):

| Case | Welcome page | After the install |
|---|---|---|
| Fresh install | "Create a desktop shortcut" ticked | (not run to the end; the silent fresh install above creates it) |
| Upgrade 1.1.2 to 1.1.3, shortcut deleted | **unticked** | no shortcut |
| Upgrade 1.1.2 to 1.1.3, shortcut there, user unticks | ticked, then unticked | **shortcut removed** |

The makensis output has the same warnings as the unchanged installer (135, all missing translations), none new.

Not testable under Wine: Windows' own desktop folders and Explorer refreshing the desktop; covered by the smoke checks on the Windows runner and the retest below.

## 4. Runs

| Run | Result |
|---|---|
| build-windows #164 (41336043714), e787ef6 | build and installer green; **smoke 31 of 31 plus the three new checks**: "desktop shortcut on a fresh install" (C:\Users\Public\Desktop\Cone Player.lnk), "reinstall keeps the desktop shortcut", "reinstall does not bring back a removed desktop shortcut"; silent uninstall after them |
| build-windows #166 (41338203178), 7f641f1 (review follow-up) | green, smoke checks pass |

## 5. Windows retest (PC session)

Use this branch's build-windows installer (test-builds draft pre-release, `wip-fix-upgrade-shortcut--win64-installer.exe`, or the run's `cone-installer-win64` artifact). A test build carries the default version 0.1.0, so over the installed 1.1.2 the installer offers a downgrade ("Already Installed" page, keep "Downgrade ..." picked); the shortcut logic is the same for upgrades, downgrades and reinstalls. Afterwards, install the released 1.1.2 again (that installer is the old one: it still brings the shortcut back).

1. **Upgrade without shortcut (the bug).** With Cone Player 1.1.2 installed, delete the "Cone Player" desktop shortcut. Run the installer: the welcome page shows "Create a desktop shortcut" **unticked**. Next through to Finish: no desktop shortcut.
2. **Silent upgrade without shortcut.** Same state (no shortcut), in an admin PowerShell: run the installer with `/S`. No desktop shortcut afterwards.
3. **Upgrade with shortcut.** Put the shortcut back (tick the box on a run of the installer, or reinstall). Run the installer again: the box starts **ticked**; Finish: the shortcut is there.
4. **Untick on upgrade.** With the shortcut there, run the installer, untick the box, Finish: the shortcut is gone.
5. **Fresh install.** Uninstall Cone Player (settings kept), run the installer: the box is ticked; Finish: the shortcut is there.
6. Cone Player starts from the Start menu after each run, and Settings > Apps shows the branch's version.
