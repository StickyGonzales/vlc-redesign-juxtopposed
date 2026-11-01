# Installer polish (branch wip/installer-polish)

Branch `wip/installer-polish`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone build only: every change sits behind `PRODUCT_PROGID != "VLC"` or in `brand-languages.sh` (which runs only for the public brand). The vlc profile's installer is unchanged.

## 1. What changed

| Before | After |
|---|---|
| The components page opened on **"Custom"** | It opens on **"Recommended"**, with the same components ticked as before |
| Every first install showed the components page | It is **skipped**, unless "Customize the installation" is ticked on the welcome page (or "Add/Remove/Reinstall components" is chosen on a reinstall) |
| The desktop shortcut was only on the components page | **"Create a desktop shortcut"** (ticked) on the welcome page, which every interactive install shows |
| "based on VLC 4.0.0-dev" under every page | **"based on VLC 4"** |
| "Discs Playback" | **"DVD and Blu-ray playback"** |

**Why "Custom":** the 13 extra file types that are unticked by default (`AssociateExtensionUnselectedSection`, `helpers/extensions.nsh`) still belonged to the "Recommended" install type (`SectionIn 1 3`). The default ticks then matched no install type, so NSIS showed "Custom". In Cone they now belong to "Full" only (`SectionIn 3`): the default ticks are exactly "Recommended". Nothing that gets installed by default changed.

**The welcome page** (`PageWelcomeShow` / `PageWelcomeLeave`, `vlc.win32.nsi.in`):
- Two boxes under the welcome text:
  - "Create a desktop shortcut": it is the Desktop shortcut component itself, read when the page opens and written when it is left. Ticking or unticking it on the components page shows on the welcome page after Back, and the other way round.
  - "Customize the installation (choose components)": unticked by default.
- The welcome text is a shorter copy of MUI's label: MUI's label runs to the bottom of the page and would cover the boxes.
- English for every language, like the file types' description already is.

**The components page** (`PageComponentsPre`) shows only when Customize is ticked, or on a reinstall when "Add/Remove/Reinstall components" is chosen. An upgrade still skips it as before. A silent install (`/S`) has no pages and installs the same components as before (the desktop shortcut included).

**English names** (`brand-languages.sh`, `EnglishExtra.nsh` only; the other languages keep VLC's translations with the name replaced):

| Before | After |
|---|---|
| Media Player (required) | Cone Player (required) |
| Start Menu Shortcut | Start menu shortcut |
| Desktop Shortcut | Desktop shortcut |
| Discs Playback | DVD and Blu-ray playback |
| File type associations | File types |
| Audio Files / Video Files / Other | Audio files / Video files / Other files |
| Context Menus | Right-click menu entries |
| Delete preferences and cache | Delete old preferences and cache |

The descriptions under them were rewritten the same way, for example "Offers Cone Player when you insert a DVD, Blu-ray or audio CD" (it was "DVD and CD playback registration").

**"based on VLC 4":** `!searchparse` takes the major version from `VLC_VERSION` at compile time, so it stays right when the engine's version changes.

## 2. Test under Wine
Setup:
- Wine 9.0, makensis 3.09.
- The installer built locally from this branch's NSIS files (the public brand's values, as the build fills them in), with the payload of the released Cone Player 1.1.0 zip.
- Each page captured on a virtual screen.

Picture: `redesign/fix-shots/installer_polish.jpg` (before and after).

| Test | Result |
|---|---|
| Before, components page | "Custom" |
| After, welcome page | the two boxes, "Create a desktop shortcut" ticked |
| After, Next without Customize | License, then the install folder: no components page |
| After, Customize ticked | the components page opens on "Recommended"; the new names; "based on VLC 4" at the bottom of every page |
| Untick the shortcut on the welcome page | the components page shows Desktop shortcut unticked ("Custom") |
| Tick it on the components page, Back | the welcome box is ticked again |
| Default install to the end | `Cone Player.lnk` on the desktop and in the Start menu, finish page as before |
| Same-version reinstall, shortcut unticked | the "Already installed" page, then components ("Add/Remove/Reinstall"); after the install no desktop shortcut |

Not testable under Wine: how Windows' own theme draws the boxes (Wine draws its own controls), and Windows scaling at 125 / 150 %.

## 3. Runs
| Run | Result |
|---|---|
| build-windows #141 (41247457291), this branch | the installer builds; **all smoke checks pass**, the silent install (`/S`, the same components as before) and the silent uninstall included |

## 4. Windows retest (PC session)
1. **Fresh install** (uninstall Cone first). Welcome page: "Create a desktop shortcut" ticked, "Customize the installation" unticked. Next, Next (License), the folder page, Install. A desktop shortcut exists.
2. **Customize.** Run the installer again after uninstalling, tick Customize: the components page opens on "Recommended", with "DVD and Blu-ray playback" and the other new names.
3. **No shortcut.** Untick "Create a desktop shortcut": no desktop shortcut after the install.
4. **The bottom line** reads "based on VLC 4" on every page.
5. **125 / 150 % scaling.** The two boxes are fully visible and do not overlap the welcome text.
6. **Upgrade** over 1.1.0: the update path still skips the pages as before.
