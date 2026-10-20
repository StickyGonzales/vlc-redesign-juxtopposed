# Review: Cone without skins (Decision 63) and the launcher fix, wip/beta-brand

This is an independent review of 5e98d58150 ("Cone: no skins interface") and f025fce2e9 (batch files keep CRLF). The reviewer did not write either commit. The review is offline only: no Windows build or test was run, so nothing here is verified (Decision 55).

## What was checked

| Check | Result |
|---|---|
| Skins module not shipped in the public build | **OK.** All four switches lead to the same place: build.sh passes `--disable-skins2` / `-Dskins2=disabled` for `BRAND=public`; configure stops on `--enable-skins2` and forces `enable_skins2=no` with `--with-brand=public` (`with_brand` is already set from the command line at that point, before its `AC_ARG_WITH` default further down); meson stops on `-Dskins2=enabled`; `modules/gui/skins2/meson.build` makes `skins2_allowed` false. So `BUILD_SKINS` is off, and package.mak (the zip's `skins` folder), the NSIS `InstallFolder skins`, the skin file associations and the MSI's `HaveSkins` all drop out. |
| Skin option gone from Settings | **OK.** The Skin section of Settings > Interface is hidden (`shown: !Brand.isPublic`), and its rows stay out of the search count (the option rows are `shown: false`, and "Skin file" has no option without the module). `intf` is one of the options the curated pages own, so "All Other Options" doesn't list it either. |
| Skin option gone from Preferences | **OK.** VLC's old Preferences hide the "Use custom skin" choice when the skins2 module doesn't exist (`simple_preferences.cpp`, `module_exists("skins2")`), so they can't write `intf=skins2,any`. In VLC's full preferences, the interface module choices list only modules that exist. |
| "Cone skinned" shortcut gone from installer and zip | **OK.** The NSIS installer creates neither the shortcut nor `New_Skins.url` in the public profile, and deletes an old test install's skinned shortcut on upgrade; the uninstaller removes the whole Start menu folder. The MSI's skinned shortcut was already commented out. The zip has no shortcuts. Cone's uninstaller still unregisters Cone's own skin associations: that only touches `Cone.*` keys and cleans up after earlier test installs. |
| Nothing can switch Cone to skins | **OK, one gap fixed.** `-I skins`, `--intf=skins2` and `intf=skins2` in the settings file fall back to the Qt interface in winvlc.c (`var_InheritString` returns NULL for an empty `intf`, so a failing default interface isn't retried). The `--skins2-*` options are dropped. **Fixed:** the module's other two options, `--skinned-playlist` and `--skinned-video` (and their `--no-` forms), were not dropped and made Cone refuse to start (e7ae9d0f20). |
| Skin add-ons | **One gap fixed.** Settings > Extensions blocked installing skin add-ons, but Tools > Plugins and extensions still had a "Skins" category and listed skin add-ons for install. **Fixed** (70d575355e): in the public profile the add-ons model leaves skins out of every add-ons list. One that an earlier test build installed still shows, so it can be removed. The Skins category is gone from that dialog. |
| The vlc profile unchanged | **OK.** Every change is behind the public profile: build.sh's else branch has the old flags; configure, meson and skins2's meson.build act only for public; the NSIS lines sit behind `!if PRODUCT_PROGID == VLC` (the vlc branch still defines `PRODUCT_SKINS_URL`); winvlc.c and the two new Qt edits sit behind `#ifdef VLC_BRAND_PUBLIC`; the QML conditions are false for vlc, and `SettingsSection.shown` defaults to true. |
| Launcher (byte order mark) | **OK.** `redesign/tools/test-latest.bat` in git is ASCII only, with no byte order mark. `.gitattributes` gives `*.bat` / `*.cmd` `text eol=crlf`, so a fresh checkout has CRLF, which `git check-attr` confirms. It is the only batch file in the repository. |
| Build breaks | **None found.** winvlc.c passes a syntax check with the MinGW cross-compiler in both profiles (no errors; the two warnings come from upstream code and the test's stub config). `addonsmodel.cpp` and `plugins.cpp` pass a syntax check against Qt 6.4 in both profiles. qmlcheck: errors 1, crashed 0 (400 files). buildlists: 0 problems. privacycheck: 0 problems. |

## Fixed on this branch
- **70d575355e:** no skin add-ons in the add-ons lists, and no Skins category in Plugins and extensions (public profile).
- **e7ae9d0f20:** winvlc.c also drops `--skinned-playlist` / `--skinned-video` (core file, already part of this branch's core build).

## Left for the PC session
- **Windows build and test:**
  - a public build and its zip have no `skins` folder and no `libskins2_plugin.dll`;
  - `Cone.exe -I skins` and `--skinned-video` open the normal window;
  - a Cone settings file with `intf=skins2` does too;
  - the Start menu has no "Cone skinned" entry after an upgrade over a test install;
  - Tools > Plugins and extensions has no Skins category;
  - a vlc-profile build still has skins, its shortcut and the Skins category.
- **Docs:** CLAUDE.md doesn't list Decision 63 yet (the commit left that to the main session), and BUILD_NOTES still needs its entry for this change.
