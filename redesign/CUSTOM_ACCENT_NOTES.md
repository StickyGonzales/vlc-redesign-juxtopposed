# Custom accent color (Cone extra)

Branch `wip/custom-accent`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Task owners row "Custom accent color" (web 2). A **Cone extra** (Decision 71): Juxtopposed's design has nine accent colors (Decision 15); this adds a tenth choice, any color. Asked for by StickyGonzales on 2026-11-01.

## 1. What it does

| Part | Behavior |
|---|---|
| **Custom swatch** | After the nine colors, in Settings > General > Appearance > Accent color and on the onboarding's theme screen. Before any custom color exists it shows a spectrum made of her preset colors (red, mustard, green, blue, pink). After that it shows the last custom color, at 70 % like the other colors not chosen, or at full strength with the selected cell fill when it is the accent. |
| **Editor** | A click on Custom (Enter or Space with the keyboard) opens a small panel: "Custom color", a 32 px preview square and a hex field `#RRGGBB` (the `#` is optional; only hex digits can be typed, 7 characters at most). It opens with the current accent's code selected. |
| **Live preview** | Every complete 6-digit code recolors the whole app at once, like a click on a preset. An incomplete code changes nothing. |
| **Keep / undo** | Enter, a click outside or opening another dialog keeps the color. **Escape undoes the typing**: the accent the editor opened with comes back exactly (also "default" and "system"), and so does the swatch's last custom color. A click on Custom chooses the last custom color first (like a click on a preset), so Escape then goes back to that color. |
| **Every highlight follows it** | The palette derives Accent/Bright, Accent/DIm, Accent/Logo, BG/Accent Bright and BG/Accent Dark from the chosen color with the same ratios as the theme's own set (`deriveAccentShade`, existing since W2.1). The icons' accent parts, the seek bar, toggles, tabs, sliders and the logo all follow. |
| **Readable text on accent fills** | Text and icons on Accent/Main fills (Primary buttons such as Next / Save / Continue Watching, the play button, the mini player's primary button, the subtitle timeline buttons, the Light theme's chosen segment, the widget dialogs' main button on hover, value-box and field selections) use the design's color with the theme's own accent. With any other accent they use dark (FG/B1 `#161616`) or light (Dark/FG/1 `#EAEAEA`, or BG/A1 where Light puts light text) text, whichever is readable on it. The rule: the design's color stays unless it is under 4.5:1 (WCAG AA) and the other is better. |
| **Warning** | Under the field: "Hard to see on this theme. Try a brighter or darker color." when the color is under 2:1 against the theme's lightest or darkest surface (BG/A1, BG/B2), for example `#202020` in Dark or `#F0F0F0` in Light. The color is still allowed. |
| **Storage** | The accent is stored in `qt-accent-color` as the hex code, like the presets, so **profiles keep it** (`rd_profile_settings.cpp` copies that option) and Settings > Reset puts "default" back. The last custom color (for the swatch while a preset is chosen) is stored in the interface settings, `RdAccent/Custom`. |

**Side effect on two presets.** With dark text, Blue `#185DD3` gives 3.05:1 and Purple `#8E42FF` 3.77:1, so their Primary buttons and play button now get light text (4.92:1 and 3.99:1). The other seven presets keep dark text, and the default orange is unchanged in both themes.

## 2. Look, against Juxtopposed's design

- **Settings (Figma "Settings - global", "Accent color" row, video 17:44-17:49):** her strip is 320 x 36 (BG/B2, radius 6, padding 2) with nine 31.6 x 32 cells 4 px apart. Custom is one more cell of the same size and gap, so the strip is 356 x 36, still right-aligned in the row. The cell states are the same as the presets': chosen = BG/Accent Bright fill, hover = the 6 % overlay, keyboard focus = 1 px FG/A3 ring, swatch 20 high with radius 1.
- **Onboarding (Figma "Onboarding-1", video 19:49):** her nine 64 px swatches are 16 px apart from x 41. With ten, Figma's gap would put Custom under Back (x 820), so the gaps are 13 px and the row ends at x 798. In a window too narrow for the Figma size the gap shrinks further so Back is never covered. Custom has the same circle, the 50 % unchosen look and the 30 % ring.
- **Editor:** no Figma frame (Decision 21: built in her component style). It reuses the info popover's look (RdTooltip: opaque BG/B1, radius 6, padding 10, shadow) and her text field (RdTextField: BG/B2, 2 px BG/A4 border, accent only for keyboard focus, Inter 14 FG/2). The preview square has the swatch stroke.

## 3. Files

- `widgets/qml/RdAccentEditor.qml` (new): the editor.
- `dialogs/redesign/settings/SettingsAccentPicker.qml`: the Custom cell, keyboard (arrows go on to Custom), the editor under it.
- `dialogs/redesign/Onboarding.qml`: the Custom swatch, the row's gap, the editor above it, the focus keeper.
- `style/systempalette.hpp/.cpp`: `rdFgOnAccent`, `rdFgOnAccentInverse`, `rdAccentLowContrast`, the selection text, contrast helpers.
- `maininterface/mainctx.hpp/.cpp`: `accentOption()` and `restoreAccentOption()` (Escape).
- Text on accent: `RdButton.qml`, `PlayButton.qml`, `RdMiniPlayer.qml`, `SubtitleTimelineButtons.qml`, `OnboardingPreview.qml`, `RdSegmented.qml`, `RdValueBox.qml`, `style/rdwidgetstyle.cpp`.
- `SettingsGeneralPage.qml`: the search finds the row with "custom" and "hex".

## 4. Checks

- `redesign/tools/qmlcheck.py` (Qt 6.8.3): `errors: 1` (the known HighResolutionTimeWidget stub), `crashed: 0`. `buildlists.py`: 0 problems.
- Independent review (fresh agent) of the whole diff found 2 high and 5 lower issues. All are fixed: Escape closed the dialog instead of undoing; the onboarding pulled the focus out of the field; the editor stayed open when its swatch hid; the row could slide under Back in narrow windows; selected text did not follow the accent; Escape lost "system" and the swatch's last color; the onboarding editor moved while typing. A second review of the fixes found one rare focus case, also fixed (the player taking the focus while the onboarding editor is open).

## 5. Runs and sandbox results

| Run | Result |
|---|---|
| build-linux #73 (ed7d4d4) | compiled (palette, MainCtx); cancelled after the compile for the review fixes |
| build-windows #169 (ed7d4d4) | compiled, installer built; smoke cancelled for the review fixes |
| **build-linux #74 (34cbdad, current head)** | **green, Linux smoke checks all pass** |
| **build-windows #170 (41349650025, 34cbdad, current head)** | **green: build, installer and the Windows smoke checks all pass** |

**Real build in the sandbox** (build-linux #74's tarball, Xvfb, a fresh profile; picture `redesign/fix-shots/custom_accent.jpg`):

| Check | Result |
|---|---|
| Settings strip vs Figma "Settings - global" (same scale) | the nine colors, cell sizes and gaps match; Custom is one more cell with the spectrum |
| Click Custom | the editor opens under it with `#D37918` selected |
| Type `#3A7BD` | nothing changes |
| Type the 6th digit (`#3A7BD5`) | the whole app turns blue at once: Theme segment, toggles, Custom cell chosen, seek bar and playhead behind the dialog |
| Enter | the editor closes; `qt-accent-color=#3a7bd5` in vlcrc; `RdAccent/Custom=#3A7BD5` in vlc-qt-interface.conf |
| Play button with `#3A7BD5` | dark icon: dark text is 4.29:1 there, light only 3.51:1, so the rule keeps the design's dark |
| Orange, then Custom, type `#20C080`, Escape | green while typing; Escape: back to `#3A7BD5`, the Settings dialog stays open, vlcrc unchanged |
| Blue preset | light play icon (dark would be 3.05:1); the Custom cell shows the last custom blue at 70 % |
| `#202020` in Dark | the "Hard to see on this theme" line shows; `#F0A0F0`: it goes away |
| Light theme, `#F0A0F0` / `#3A2A80` | the chosen Theme segment has dark text on the pink and light text on the purple |
| Quit and start again | the custom color is still the accent, the Custom cell chosen, the Light theme kept |
| Onboarding (first run, `--qt-privacy-ask`) | ten swatches, the spectrum last, clear of Back; Custom opens the editor above it; `#7A5CFA` recolors the theme ring, the player picture and Next live; Escape goes back to orange without leaving the wizard, and the spectrum comes back |

Not checked here: profiles through the profile menu (the option is copied like every other one, `rd_profile_settings.cpp`; covered by the retest), Windows' own rendering (retest).

## 6. Windows retest (PC session)

Use this branch's build-windows zip (test-builds draft, `wip-custom-accent--win64-public.zip`, or the run's artifact).

1. **Settings strip.** Ctrl+P > General. The Accent color strip has ten cells; the last shows a spectrum. Compare with Figma "Settings - global": the nine colors, sizes and gaps unchanged, Custom one more cell of the same size.
2. **Editor and live preview.** Click Custom: a small panel under it, "Custom color", a preview and the field with the current code selected. Type `#3A7BD5` one character at a time: nothing changes until the 6th digit, then the whole app turns blue at once (dialog toggles, the seek bar behind it, icons, the logo).
3. **Enter keeps.** Press Enter: the panel closes, the Custom cell is chosen and shows the blue. Close Settings and play a file, then pause: the seek bar, the play button and the icons are blue; the play button's icon stays dark (on this blue dark reads better than light, 4.3:1 against 3.5:1).
4. **Escape undoes.** Choose Orange, then click Custom: the app turns to the blue from step 3 (the last custom color). Type `#20C080` (green), then press Escape: the app goes back to that blue and the Settings dialog stays open.
5. **Warning.** Open Custom and type `#202020` (Dark theme): the "Hard to see on this theme" line appears; type `#F0A0F0`: it goes away.
6. **Light theme.** Theme > Light, Custom `#FFE066` (light yellow): Primary buttons (for example Save on a dialog) have dark text; the chosen Theme segment's text is dark too. Custom `#3A2A80` (dark purple): their text is light.
7. **Presets Blue and Purple.** Choose Blue, then Purple: the play button's icon is light on both. Orange, Red, Mustard, Green, Teal, Pink, Gray: dark as before.
8. **Keyboard.** Tab to the strip, arrows to Gray, Right: Custom (chosen when it has a color), Enter opens the editor, Escape closes it, and the focus is back on the Custom cell.
9. **Profiles.** Set a custom color, then the profile menu: + New "Blue test" (copies the settings). Switch to the default profile and back: the custom color comes back with the profile.
10. **Restart.** Quit and start again: the custom color is still the accent, and the Custom cell is chosen.
11. **Onboarding.** Start once with `--qt-privacy-ask` in a portable copy. On the theme screen ten swatches, the last a spectrum, 20 px clear of Back. Click it: the editor opens above it; typing recolors the preview and the whole wizard live; Escape undoes without closing the wizard; Enter keeps; Next goes on.
12. **Video check.** Against her video 17:44-17:49 and 19:49: the presets row looks the same apart from the extra swatch.
