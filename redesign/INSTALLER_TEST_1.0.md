# Real installer test: Cone Player 1.0.0 (branch wip/test-installer-1.0)

**Test only, never merge this branch.** It is `wip/next-test` (82bde58b00 era, 6b1f01f366) with these merged in:
- PR #33 (installer, `wip/installer`, including its SupportedTypes fix 4aed518662);
- PR #46 (Cone Player rename, `wip/cone-player`).

Plus one test-only CI commit (deb465b8c0), a `brand-version` input, so a manual build can be 1.0.0 and upgrade over the 0.2.0 beta.

The `VIDEO_INDEX.md` merge conflict was Decision 56 in two wordings. They became one Decision 56 line carrying both; Decisions 30 to 72 are all there.

## The build to test

| | |
|---|---|
| Run | **build-windows #102**, ID 40214644177, `wip/test-installer-1.0` at f75d617b47, inputs brand public, brand-version 1.0.0, green |
| Installer | artifact **cone-installer-win64** (ID 12606899950): `coneplayer-1.0.0-win64.exe`, sha256 `a2f07679dd792eab98b1c98ffa37fbdd9be91a322348789dbeea6feaf689b3d6` |
| Zip | artifact **vlc-redesign-win64-public** (ID 12606819751): folder `ConePlayer-1.0.0` |
| Kept until | 2026-11-08 (this run still used the 14-day retention) |
| Download | Actions, build-windows, run #102, Artifacts, cone-installer-win64 |

An earlier build of the same branch (#98, 40211094229) differed only in the SupportedTypes fix. It is superseded and can be deleted.

## How it was tested

The real installers, under Wine 10 (64-bit) in VideoLAN's win64 build image:
- the Cone Player installer above;
- the real **Cone 0.2.0 beta installer**: `cone-0.2.0-win64.exe` from the v0.2.0-beta tag build #85 (artifact 12290842143), checksum checked;
- the real **VLC 3.0.21** installer from videolan.org, sha256 checked against VideoLAN's `.sha256`.

After every step: `reg query HKLM\Software /s` in the 64-bit and 32-bit views, `HKCU\Software`, and a list of every file outside `C:\windows`. A script then checks the installed state against `redesign/INSTALLER_NOTES.md` sections 3 and 4, using the Cone Player names: 82 checks covering every key, value, ProgID, command, handler, file and shortcut.

## Results (build #102)

| Scenario | Result |
|---|---|
| **Fresh install** next to VLC 3.0.21 (`/S`) | **82 of 82 checks pass.** `Uninstall\Cone`: DisplayName "Cone Player", version 1.0.0, publisher StickyGonzales, size; 134 ProgIDs "… (Cone Player)", FileAssociations and SupportedTypes; 130 `OpenWithProgids` (the 4 unticked types excepted); `.mp4` stays `VLC.mp4`; "Play with Cone Player" / "Add to Cone Player's Playlist"; 8 AutoPlay handlers; Start menu StickyGonzales with the 5 Cone Player links; desktop "Cone Player.lnk"; `plugins.dat` made by the real cache generator. **Not one line of VLC's registry changed.** |
| Its **silent uninstall** | HKLM (both views), HKCU and the file list are **identical to the VLC-only state**. |
| **0.2.0 beta** next to VLC, then the **GUI upgrade** | The installer says "An older version of Cone Player is installed", with "Upgrade Cone Player using previous settings" selected; every page shows Cone Player. Afterwards: **82 of 82 checks pass**; one Settings > Apps key (`Uninstall\Cone`, "Cone Player 1.0.0"); no beta shortcut, desktop link or "Cone Website.url" left; SupportedTypes exactly 134 (the beta's stray value is gone); the settings in `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone` unchanged; no line of VLC's registry changed. The file types stay unticked as the beta had them (it unticked them next to VLC, Decision 56 then), because the upgrade keeps the saved choices. |
| The **real app** | "Run Cone Player 1.0.0" on the finish page starts `Cone.exe` under Wine: window title "Cone Player", onboarding "Welcome to Cone Player!". It writes its media library and Qt cache to `%APPDATA%\Cone` and `%LOCALAPPDATA%\Cone`, the identity folders, as decided. |
| **Silent uninstall** after the upgrade ("Delete preferences and cache" unticked) | HKLM identical to the VLC-only state, apart from Wine's own `MMDevices` audio keys (created by Wine when Cone ran, not by the installer); `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone` kept. |
| Reinstall, then **GUI uninstall with "Delete preferences and cache" ticked** | Files identical to the VLC-only state: `%APPDATA%\Cone` (with the real media library), `%LOCALAPPDATA%\Cone` (the real Qt cache) and `HKCU\Software\Cone` removed. HKLM and HKCU identical to the VLC-only state apart from Wine's `MMDevices` and audio driver keys. |
| **VLC 3.0.21** afterwards, in both test prefixes | Plays a test file to the end (`-I dummy`, its log: audio decoder faad, "EOF reached"); its install key, uninstall key, files and file types untouched. |

Found and fixed on the way (build #98):
- **SupportedTypes stray value:** an upgrade kept the 0.2.0 beta's one stray SupportedTypes value (VLC's `$0` bug). Fixed in PR #33 (4aed518662: the list is rewritten); confirmed gone with #102.
- **No `locale\` folder:** the CI build ships no translations, so there's no `locale\` folder. That is a build property, not an installer bug; `INSTALLER_NOTES.md` corrected (53bf2aa207).

Not testable under Wine: the Windows shell itself (Apps list icons, Open with, Default apps, AutoPlay) and a double-click on a video. Those are the PC session's steps: `redesign/INSTALLER_NOTES.md` section 6 and `redesign/RENAME_CONE_PLAYER.md` section 6, with this build and the real `cone-0.2.0-win64.exe` (artifact 12290842143, kept until 2026-11-03) for the upgrade.
