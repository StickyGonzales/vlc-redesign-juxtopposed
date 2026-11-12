# Branch cleanup

Every branch deleted from GitHub, with its last commit, so it can be restored:

```
git push origin <sha>:refs/heads/<branch>
```

## 2026-11-09 (StickyGonzales: fully merged branches, and test-only branches older than 3 days)

Kept: redesign, wip/next-test, wip/linux-build, master, every branch with an open PR, the Task owners rows still in progress, and the round's own staging branch.

| Branch | Last commit | Date | Why | Last commit message |
|---|---|---|---|---|
| `wip/ci-release` | `d8fa02d1d0b9f2a17201e2d9fa6314f98d4e27ab` | 2026-10-25 | fully merged into wip/next-test or redesign | CI release: 1.0 file names and the "Cone Player <version>" title |
| `wip/ci-smoke` | `71ac4602ba8556c816c6f80cfa953d8fc99a02a2` | 2026-10-27 | fully merged into wip/next-test or redesign | redesign: CI smoke notes: end-to-end run, iterations, side finding [skip ci] |
| `wip/cone-player` | `4ebdbc92599569ec31c58fae8692f2474b68dbd9` | 2026-10-25 | fully merged into wip/next-test or redesign | redesign: RENAME_CONE_PLAYER: no beta-to-1.0 tests in the Windows steps [skip ci] |
| `wip/custom-accent` | `6a5f7c97ab5dbd4bd875f7288c38f52e11e268cf` | 2026-11-01 | fully merged into wip/next-test or redesign | Custom accent notes: build-windows #170 green [skip ci] |
| `wip/fix-apikey-sidebar` | `404b844fa54c22cfb45630daf3aa10262ed4d6c3` | 2026-10-26 | fully merged into wip/next-test or redesign | qt: an open panel keeps both bars in fullscreen; key fields get an eye button and a Saved note |
| `wip/fix-ass-styling` | `94fd946a44fca68ce235629df9e6cb9303dabf70` | 2026-10-25 | fully merged into wip/next-test or redesign | redesign: VIDEO_INDEX: S2-11 core change built (run 40210779130) [skip ci] |
| `wip/fix-cursor-hide` | `d457f37a32c4f9901c24e1a31451fb33fdde164a` | 2026-11-02 | fully merged into wip/next-test or redesign | notes: cursor fix runs [skip ci] |
| `wip/fix-customize-outlines` | `2c5d6b2cb0e0bde582cf4ac026256bcbbbd162ce` | 2026-10-31 | fully merged into wip/next-test or redesign | FIX_CUSTOMIZE_OUTLINES_NOTES: Decision 74, real drags against Figma, runs [skip ci] |
| `wip/fix-first-start-wait` | `ebabca4ece11093e7580b94c06f96c6185b1baa9` | 2026-11-03 | fully merged into wip/next-test or redesign | notes: F1 build-windows #180 green [skip ci] |
| `wip/fix-fs-menu` | `9c4297863eb584f0715fbea493e575ee64957f29` | 2026-11-01 | fully merged into wip/next-test or redesign | Notes: fullscreen "..." menu, runs [skip ci] |
| `wip/fix-fs-topbar-hover` | `db4e4cbcecb5a5e676e13471fadc1e96716f56ba` | 2026-10-27 | fully merged into wip/next-test or redesign | redesign: fullscreen top bar fix notes: the fixed build passes [skip ci] |
| `wip/fix-linux-audio-device` | `c6894958a42910e20534dc51fd401adf51f94c79` | 2026-10-25 | fully merged into wip/next-test or redesign | qt: Settings > Audio > Output device on Linux (P8-11) |
| `wip/fix-linux-language` | `e66cbf4b9b5c70b022e2feb2a7b788194112b775` | 2026-10-25 | fully merged into wip/next-test or redesign | qt: interface language on Linux (P8-03) |
| `wip/fix-linux-postproc` | `f2d3bfbb3294363bc64f33e937905110d0deb1be` | 2026-11-01 | fully merged into wip/next-test or redesign | Merge remote-tracking branch 'origin/wip/linux-build' into wip/fix-linux-postproc |
| `wip/fix-linux-release-build` | `b9ab185cb6d6b7251eb4ba74413f0c6f0eb2ce81` | 2026-11-01 | fully merged into wip/next-test or redesign | Merge remote-tracking branch 'origin/wip/linux-build' into wip/fix-linux-release-build |
| `wip/fix-missing-plugin-dlls` | `f162f359297931f049f110a75d6500c42759ec7b` | 2026-10-31 | fully merged into wip/next-test or redesign | FIX_PLUGIN_DLLS_NOTES: the runs [skip ci] |
| `wip/fix-mute-key-hint` | `6a021acca0063aecb3e15242f532b75b84587926` | 2026-11-01 | fully merged into wip/next-test or redesign | FIX_AUDIO_ICON_NOTES: cause, fix, runs and Windows retest steps [skip ci] |
| `wip/fix-open-in-running-window` | `f9616da6fe5a9ae7117be439002c00fcf35be21b` | 2026-11-03 | fully merged into wip/next-test or redesign | notes: CI green [skip ci] |
| `wip/fix-pause-rate` | `3a799246a877a60258d6a470779be03947a909f1` | 2026-10-25 | fully merged into wip/next-test or redesign | redesign: issue #52 notes: cause, sandbox results, Windows retest, draft reply [skip ci] |
| `wip/fix-quit-handoff` | `2b31474731a4b2c2b29f835b91deed1897c75547` | 2026-10-26 | fully merged into wip/next-test or redesign | core: a second running instance can create its pipes (Windows) |
| `wip/fix-restore-prompt-after-watchdog` | `042a7d88bf4f25f58d2ded75464143e3a6d32263` | 2026-10-31 | fully merged into wip/next-test or redesign | FIX_RESTORE_PROMPT_NOTES: cause, fix, sandbox test and runs [skip ci] |
| `wip/fix-seek-drag-flicker` | `88dc2623585341350084c48f26da62898e5dc7cc` | 2026-10-26 | fully merged into wip/next-test or redesign | redesign: seek drag flicker notes: count every frame [skip ci] |
| `wip/fix-seek-thumbnails` | `c38ddfa3d33e6ef3f1483835bd9d4974523dfb96` | 2026-10-26 | fully merged into wip/next-test or redesign | qt: seek preview: rename the local variable far (a macro on Windows) |
| `wip/fix-settings-a11y-save` | `35753ef94a1c87baf2f7978209735ccadcbc9008` | 2026-10-25 | fully merged into wip/next-test or redesign | redesign: Settings saves changes made with accessibility tools |
| `wip/fix-settings-advanced-bar` | `91a3c833705a97f46e5b011e46bb789fc38ca3f5` | 2026-10-25 | fully merged into wip/next-test or redesign | qt: Settings pages end 40 under their last element, as in Figma |
| `wip/fix-short-episode-prompt` | `0b10fd56cf00d61d686ab94b2504a8f9fff393cb` | 2026-11-01 | fully merged into wip/next-test or redesign | FIX_AUDIO_ICON_NOTES: cause, fix, runs and Windows retest steps [skip ci] |
| `wip/fix-slider-a11y-value` | `435b0c793b928e5c603230b83a0ce8e584c41a56` | 2026-11-01 | fully merged into wip/next-test or redesign | FIX_AUDIO_ICON_NOTES: cause, fix, runs and Windows retest steps [skip ci] |
| `wip/fix-smoke-media` | `2413a33010ceb4f31c14ae067d0b7daf9f5157c0` | 2026-10-27 | fully merged into wip/next-test or redesign | ci smoke: test media from a cached run, ffmpeg from PyPI instead of apt |
| `wip/fix-speed-freeze` | `5670c06c844d59b0fe63fda9a3bd41d0b2a08a50` | 2026-11-01 | fully merged into wip/next-test or redesign | Notes: speed slider freeze, runs [skip ci] |
| `wip/fix-startup-deadlock` | `d6e93e839365c48aa477cebd2eafb1e7d8063a75` | 2026-10-25 | fully merged into wip/next-test or redesign | input: send the attachments event outside the item lock |
| `wip/fix-subtitle-defaults` | `41522cbe7dbf01a287d5e0b48138cb0ace23530f` | 2026-10-25 | fully merged into wip/next-test or redesign | Cone: keep VLC's Normal subtitle outline (Q8) |
| `wip/fix-sub-ui-margin-dummy` | `a6c43c4c7a61ed44b5f158921bf733aa798f5d8a` | 2026-10-25 | fully merged into wip/next-test or redesign | vout: add the sub-ui-margin callback in vout_IntfInit, not on the dummy output |
| `wip/fix-uninstall-own-keys` | `94c8a75b56196b1fe1911e49e49048cb6f8eee8b` | 2026-10-25 | fully merged into wip/next-test or redesign | redesign: INSTALLER_NOTES: upgrades from installs without a record [skip ci] |
| `wip/fix-upgrade-shortcut` | `428c508ee34363ad9e30f3c0c2d79fb2466d6ad6` | 2026-11-01 | fully merged into wip/next-test or redesign | Installer shortcut notes: CI runs [skip ci] |
| `wip/fix-up-next-card` | `3db09c1f681cd3777c9bc1c47984afcafe5b58fd` | 2026-11-01 | fully merged into wip/next-test or redesign | Up Next card notes: runs, sandbox results, the fade frames of build-linux #70 [skip ci] |
| `wip/fix-version-console` | `b5f7bfbab6ba92573808dfd023244b16720022ec` | 2026-11-01 | fully merged into wip/next-test or redesign | FIX_AUDIO_ICON_NOTES: cause, fix, runs and Windows retest steps [skip ci] |
| `wip/hide-osd-seek-slider` | `9ac1aac155cc6fa34a0036f202e4e6e1d46b9862` | 2026-11-03 | fully merged into wip/next-test or redesign | notes: CI green [skip ci] |
| `wip/hide-subsdelay-factor` | `8c3d3d17c9cfb0992ac17741859bfbb7ece5d2c2` | 2026-10-26 | fully merged into wip/next-test or redesign | redesign: Subtitle Duration Factor notes: the first start after upgrading, fixed [skip ci] |
| `wip/installer` | `09465947145414f48f6d6cc57e87ba5c70296e68` | 2026-10-25 | fully merged into wip/next-test or redesign | redesign: INSTALLER_NOTES: known limits accepted for 1.0, Windows test result [skip ci] |
| `wip/installer-polish` | `e44f448e248bdd0c57f3c80bd9552ce17e58f8a9` | 2026-10-31 | fully merged into wip/next-test or redesign | INSTALLER_POLISH_NOTES: runs [skip ci] |
| `wip/linux-deb` | `548b019f208f2fdee1b9853bcb7c6f13e7feaa09` | 2026-11-01 | fully merged into wip/next-test or redesign | Notes: Linux .deb package (cone-player, /opt/cone-player) [skip ci] |
| `wip/linux-docs` | `edf061b71357e4f6bc4de66b2f17a2138563a238` | 2026-11-01 | fully merged into wip/next-test or redesign | Merge branch 'wip/linux-smoke' into wip/linux-docs |
| `wip/linux-install` | `c6cbd8773695968d6fdc32fba713679f0c376355` | 2026-11-01 | fully merged into wip/next-test or redesign | Notes: Linux per-user install (install.sh, uninstall.sh, AppImage entry) [skip ci] |
| `wip/linux-smoke` | `8f903353852158aee8e751cbc9b472a5384d8397` | 2026-11-01 | fully merged into wip/next-test or redesign | Notes: Linux smoke checks, the speed slider check [skip ci] |
| `wip/linux-update-notice` | `d9e45f93b9d0a49f64dd212126f3883ed91c5948` | 2026-11-01 | fully merged into wip/next-test or redesign | qt: update notice on Linux: the newest Linux release, not the Windows one |
| `wip/linux-ux-desktop-id` | `8e855f43e1887c95bff704c4b76c5f2cd5a2eeaa` | 2026-11-01 | fully merged into wip/next-test or redesign | Linux: windows, media controls and sound mixer name cone-player.desktop |
| `wip/linux-ux-notes` | `144c63ec1ed737d7e6548532e64433b2e1f51668` | 2026-11-01 | fully merged into wip/next-test or redesign | Linux UX notes: #93 run green [skip ci] |
| `wip/linux-ux-open-in-window` | `f0a301d2298467267f98b87779a404e32fbb59b2` | 2026-11-01 | fully merged into wip/next-test or redesign | Linux: files opened from the desktop go to the running Cone window |
| `wip/linux-ux-vaapi-paths` | `e74d9c3cd933cec7260035a013b31f7c65e4f264` | 2026-11-01 | fully merged into wip/next-test or redesign | Linux: hardware decoding finds the system's drivers outside Debian/Ubuntu |
| `wip/osd-cone-style` | `074204f122a5b602eb21788e39271ce85cd03542` | 2026-11-03 | fully merged into wip/next-test or redesign | notes: OSD build-windows #186 green [skip ci] |
| `wip/readme-1.0` | `be46b2898c0f89f2abf7ee194c3cc512245e5566` | 2026-10-26 | fully merged into wip/next-test or redesign | README: homepage shots with the Blender open movies, accent colors section, film credits [skip ci] |
| `wip/release-portable` | `c79ae6bafa452d2f3e909dca6b2bc74b70d39433` | 2026-10-26 | fully merged into wip/next-test or redesign | CI release: the zip ships an empty portable folder again [skip ci] |
| `wip/show-tracks` | `3517edf5885d57e27811b176fcedab7fa5a66a72` | 2026-11-02 | fully merged into wip/next-test or redesign | Show tracks notes: build-windows #174 green [skip ci] |
| `wip/subtitle-auto-sync` | `c6ce321421e930aaa793f42600eb10f8e41b005d` | 2026-11-03 | fully merged into wip/next-test or redesign | notes: Auto-sync builds #90 and #192 green, slider-only shots [skip ci] |
| `wip/update-notice` | `6a2ffee74a08b07aa273962d5c36a51436fbf86b` | 2026-10-26 | fully merged into wip/next-test or redesign | redesign: update notice: rebuild checked in the sandbox, picture [skip ci] |
| `wip/update-skip-version` | `70d3081106a8de67463d24d3f9d07c8249777507` | 2026-11-01 | fully merged into wip/next-test or redesign | UPDATE_SKIP_NOTES: step 6 was not rerun [skip ci] |
| `wip/up-next` | `9e36dc7e64a72bf9dd0fb1d9d5ebc095dfeabac0` | 2026-10-25 | fully merged into wip/next-test or redesign | Cone extra (Up Next): build 32 retest results [skip ci] |
| `wip/up-next-credits` | `fb8697f442301fc4b28977161b68581ca024c91e` | 2026-11-01 | fully merged into wip/next-test or redesign | Up Next credits notes: runs, sandbox results and the card picture [skip ci] |
| `wip/up-next-no-end-text` | `a5869ceb5179bebbf9fae1ca9991b32e56a261e6` | 2026-11-08 | fully merged into wip/next-test or redesign | Up Next card: no "Plays at the end of the episode" line while an autoplaying episode waits |
| `wip/diag-fs-menu` | `530ff35e5d9fc454f6e58c9339fd2a162ac119d6` | 2026-11-01 | test-only, older than 3 days, not merged | diagnostic only: the fullscreen "..." click with each compositor forced |
| `wip/diag-hevc-stall` | `fb060dd6c23f32beba8c6388cfa37dd8bac6894d` | 2026-10-25 | test-only, older than 3 days, not merged | DIAG (test-only, never merge): count D3D11VA surfaces in use, log codec flushes |
| `wip/fs-topbar-probe` | `130630c5210bf40b3a52b949da72881827746b14` | 2026-10-27 | test-only, older than 3 days, not merged | Merge branch 'wip/fix-smoke-media' into wip/fs-topbar-probe |
| `wip/linux-fixes-linux` | `e319e04663d293e43a50cebbbfeb2d24c8e88c1d` | 2026-10-25 | test-only, older than 3 days, not merged | Merge remote-tracking branch 'origin/wip/fix-linux-release-build' into wip/linux-fixes-linux |
| `wip/pr74-cursor-hide` | `687f9353559a66f81dbf0b9b3c99bcd4b9242484` | 2026-11-01 | test-only, older than 3 days, not merged | Merge PR #74 (krishvaghasiya705): hide the cursor only during playback, for the Windows build |
| `wip/quit-hang-cause` | `1d8f2ed8485e79ac3b676bc6efc79d19d1dfaea7` | 2026-10-20 | test-only, older than 3 days, not merged | redesign: quit hang cause: the HEVC frame-threaded decoder never returns during the stop [skip ci] |
| `wip/seekfix-linux` | `dccf53044520109dc546f29bc161229528177f75` | 2026-10-26 | test-only, older than 3 days, not merged | Merge branch 'wip/fix-seek-thumbnails' into wip/seekfix-linux |
| `wip/test-fs-topbar` | `0e8266b9cacaf8c19b4c0784a5bc80c5f3063844` | 2026-10-27 | test-only, older than 3 days, not merged | Merge remote-tracking branch 'origin/wip/fix-smoke-media' into wip/test-fs-topbar |
| `wip/test-installer-1.0-ownkeys` | `703178022fb4ce0d6f82e9ef46e069474554ce17` | 2026-10-25 | test-only, older than 3 days, not merged | Merge the uninstaller review fixes (wip/fix-uninstall-own-keys) into the installer test branch (test only, never merge) |
| `wip/test-linux-restore-customize` | `639984a0a03dd66ba5e97a773e4d3b881a0298c2` | 2026-10-31 | test-only, older than 3 days, not merged | Merge branch 'wip/fix-customize-outlines' into wip/test-linux-restore-customize |
| `wip/test-linux-small-fixes` | `0e149ae6db423bcf04dfae33d523fe14d0beb552` | 2026-11-01 | test-only, older than 3 days, not merged | Merge remote-tracking branch 'origin/wip/fix-version-console' into wip/test-linux-small-fixes |
| `wip/test-plugin-dlls` | `526d68755b8234a4ce958bdcf151eb0da70d11ba` | 2026-10-31 | test-only, older than 3 days, not merged | Merge remote-tracking branch 'origin/wip/fix-smoke-media' into wip/test-plugin-dlls |
| `wip/test-pr48-49` | `f2bf43fd7b58493d26a91b257ebf3761c33015e7` | 2026-10-25 | test-only, older than 3 days, not merged | Test branch: wip/next-test + PR #48 + PR #49 (test only, never merge) |
| `wip/test-speed-check-only` | `6142db7a4e13b964eff62381975e87f7159ec7d8` | 2026-11-01 | test-only, older than 3 days, not merged | test only: the speed slider smoke check without the fix (never merge) |
| `wip/update-notice-linux` | `6df717740983abc31859316627161eca214268af` | 2026-10-26 | test-only, older than 3 days, not merged | Merge branch 'wip/update-notice' into wip/update-notice-linux |
| `wip/up-next-linux` | `d400dc01c124d10d3bd14cd9b927f47019847230` | 2026-10-25 | test-only, older than 3 days, not merged | Merge branch 'wip/up-next' into wip/up-next-linux |

Not deleted, unmerged and not in the Task owners table (for StickyGonzales to decide):

| Branch | Last commit | Date | Last commit message |
|---|---|---|---|
| `wip/a839e9d9ddb97595a` | `0623e3febd6d594815f436a4b098edd0bbf534d8` | 2026-10-15 | redesign: log the subtitle speed stall and the sidebar slider audit |
| `wip/beta-gate` | `277560ec9f77869f7a2bc15672df7ba0fef9bd80` | 2026-10-18 | redesign: beta gate: process samples are objects (perf / soak summaries failed), soak saves its samples as it goes [skip ci] |
| `wip/code-audit` | `1c8fe5a62714dccd0e827edae8d3bfab56a13769` | 2026-10-16 | redesign: CODE_AUDIT: code vs Figma for every coded, unverified row |
| `wip/fix-deb-asset-name` | `e8d509b9a2a755ab79a3e4cd258ffe6f8b420593` | 2026-11-01 | Deb asset name notes: CI run [skip ci] |
| `wip/fix-pause-rate-clock` | `f29fc12a3d522d19cba72dbece78778e94cd3e17` | 2026-10-25 | redesign: notes for the pause at speed != 1x time jump fix (#52) [skip ci] |
| `wip/fix-visualizer` | `5ef8dcec493b39508b18bf937b0123ad53c13e6e` | 2026-10-20 | win32 vout: Cone's own video windows read just "Cone" |
| `wip/verify-harness` | `43961c6b60b73cc4e0c1e34917d1d25966f828fc` | 2026-10-18 | GitHub handle renamed: links and credits point to StickyGonzales [skip ci] |
| `wip/verify-linux` | `771aae56f7db41cc822eb56d0a85877b1888610d` | 2026-10-18 | redesign: LINUX_VERIFY summary per screen [skip ci] |
| `wip/verify-sheets` | `b07ef7ea3be16e89a912171f30a4382fb523fe68` | 2026-10-18 | redesign: SHEET_CONFIRMATIONS for the 45 verify sheets [skip ci] |

## 2026-11-09, end of the morning round (CLAUDE.md branch rule)

| Branch | Last commit | Why |
|---|---|---|
| `wip/up-next-card-click-fill` | `7abd12173d8c09a69133078e67b64097be4c1a93` | PR #101 merged into wip/next-test |
| `wip/fix-fullscreen-exit` | `58b0f4cac104fe08bc751696467b37ba3960fb86` | PR #105 merged into wip/next-test |
| `wip/fix-autosync-message` | `dc3974528a235b856ec413d80bba857d2b23fe64` | PR #108 merged into wip/next-test |
| `wip/macos-build` | `f144b3a889db0574351c31211e93bd5216a1e2b5` | PR #109 merged into wip/next-test |
| `wip/round-2026-11-09` | `519d07e74cf65d0210ac986f2df0ce0004a50466` | combined test build of the round, merged into wip/next-test |

## 2026-11-08, PR #107 merged (CLAUDE.md branch rule)

| Branch | Last commit | Why |
|---|---|---|
| `wip/up-next-credits-scan` | `8700961a25c9a5a292a76697660840f7e894161f` | PR #107 merged into wip/next-test |
| `wip/stage-107` | `4521447d8737a9ac6d75de78ee144fb585bc79b5` | test build of #107 merged onto wip/next-test, merged into wip/next-test |

## 2026-11-08, Cone Player 1.3.0 released (CLAUDE.md branch rule)

| Branch | Last commit | Why |
|---|---|---|
| `wip/autosync-undo-message` | `905e3441b4ded2ab5feb44e229a8d4f97cb43088` | PR #110 merged, released in 1.3.0 |
| `wip/linux-live-usb-checklist` | `2d4519eda05d6027756ff03b0d91814684aec3e6` | PR #111 merged, released in 1.3.0 |
| `wip/linux-glibc-235` | `e297350badaeece4944612d777e8639453b0c4bf` | PR #112 merged, released in 1.3.0 |
| `wip/up-next-card-tune` | `d94ad689a7cba1c750055617946b4a82edbd3a64` | Up Next card tune merged, released in 1.3.0 |
| `wip/round-1.3.0` | `16ea09558ff577963d7fcc7d7f6d5308d731b6b3` | the 1.3.0 test build, merged |

## 2026-11-11, StickyGonzales' decision on the unmerged branches

| Branch | Last commit | Why |
|---|---|---|
| `wip/a839e9d9ddb97595a` | `0623e3febd6d594815f436a4b098edd0bbf534d8` | old notes branch (subtitle speed stall, slider audit), StickyGonzales chose delete |
| `wip/beta-gate` | `277560ec9f77869f7a2bc15672df7ba0fef9bd80` | beta gate harness branch, StickyGonzales chose delete |
| `wip/code-audit` | `1c8fe5a62714dccd0e827edae8d3bfab56a13769` | CODE_AUDIT notes, StickyGonzales chose delete |
| `wip/verify-harness` | `43961c6b60b73cc4e0c1e34917d1d25966f828fc` | verify harness branch, StickyGonzales chose delete |
| `wip/verify-linux` | `771aae56f7db41cc822eb56d0a85877b1888610d` | LINUX_VERIFY notes, StickyGonzales chose delete |
| `wip/verify-sheets` | `b07ef7ea3be16e89a912171f30a4382fb523fe68` | verify sheets notes, StickyGonzales chose delete |
| `wip/fix-deb-asset-name` | `e8d509b9a2a755ab79a3e4cd258ffe6f8b420593` | PR #89 merged; leftover notes commit, StickyGonzales chose delete |
| `wip/fix-pause-rate-clock` | `f29fc12a3d522d19cba72dbece78778e94cd3e17` | the #52 fix and FIX_PAUSE_RATE_NOTES.md (with the draft reply) are in wip/next-test through PR #55; StickyGonzales chose delete |
| `wip/fix-visualizer` | `5ef8dcec493b39508b18bf937b0123ad53c13e6e` | window title already in wip/next-test ("Cone Player"); the ICC-profile hang theory was never confirmed and the white visualizer / slow quit were fixed by the HEVC surface and Spectrometer fixes (2026-10-25); StickyGonzales chose delete, no retest |

## 2026-11-11, PC fixes merged

| Branch | Last commit | Why |
|---|---|---|
| `wip/pc-fixes-1.3.1` | `bf9e459369c3fdb210674c75a16ab3fee04ce2dd` | merged into wip/next-test (settings on update, account saved as typed, volume in movie mode) |
| `wip/up-next-plan` | `b8309be9992b5d379233b37a1ff12938a8d5b06d` | PR #44 closed (everything in it shipped in 1.1.0 to 1.3.0); StickyGonzales chose delete |
| `wip/seekbar-wheel` | `fb097056997b6c2bf76cdefa71bc6b35d35775a1` | merged into wip/next-test (wheel seeking on the timeline) |

## 2026-11-11, Linux fixes, Flatpak, Flathub prep and AUR merged

| Branch | Last commit | Why |
|---|---|---|
| `wip/fix-linux-jammy-image` | `29e7f9de3ce6de7eccf87159514b6995ca127792` | PR #119 merged (Linux build image) |
| `wip/fix-linux-wayland-embed` | `5cf3e27ed88a285a8c1e6a3a79b11f6d34e735c9` | PR #120 merged (Wayland embed, #116) |
| `wip/linux-flatpak` | `9a212bdb2f4175bb5439cc7b9f73d11c2c63e679` | PR #114 merged (Flatpak) |
| `wip/flathub-prep` | `e289f8e85c6cac41573253f3d9dccf242eb01062` | PR #115 merged (Flathub prep) |
| `wip/aur-cone-player-bin` | `ed5664bf02537cf11564c5394036e3a64596e8da` | PR #113 merged (AUR package) |
| `wip/round-linux-1.4.0` | `3cfbf2f0c2b804bc95058a1780b533cb4b65a541` | the combined test build of the five, merged into wip/next-test |

## 2026-11-12, Cone Player 1.4.0 round

| Branch | Last commit | Why |
|---|---|---|
| `wip/macos-fixes` | `4f370df77af36822d42ef4d04d93081c0174e51c` | PR #118 merged (macOS fixes, issue #69) |
| `wip/fix-update-autocheck` | `8afcd1ba95272fb372cc837b1a5a561f2504b0a1` | PR #121 merged (update check) |
| `wip/fix-show-name-clean` | `821fb60de5dca99e79daed4928434855ae0f326f` | PR #122 merged (clean show names) |
| `wip/fix-ctrlq-quit` | `14b33daa80786832b68c1df32af222fa399bd3bf` | PR #123 merged (Ctrl+Q) |
| `wip/fix-pointer-hide-resume` | `b1303a0f6a93f89b1f1e125d8577b1234f8b0aeb` | PR #124 merged (pointer after Space) |
| `wip/round-1.4.0` | `7162f781885f8779cd956aba3a2b5bb7959c0586` | the 1.4.0 combined test build, merged into wip/next-test |

## 2026-11-12, PR #126

| Branch | Last commit | Why |
|---|---|---|
| `wip/fix-popup-stack` | `b8ce9883ef3c519caafad18a61c1476c38e61dd6` | PR #126 merged into wip/next-test (notices stack) |
