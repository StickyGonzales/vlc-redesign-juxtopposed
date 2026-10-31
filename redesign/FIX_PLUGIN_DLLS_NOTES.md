# Plug-ins that never loaded on Windows: x265, SRT (2), game-music-emu (branch wip/fix-missing-plugin-dlls)

Branch `wip/fix-missing-plugin-dlls`, made from `origin/wip/next-test` (fad0675581). Draft pull request into `wip/next-test`. **Core change** (`src/win32/plugin.c`) plus packaging, so it gets its own build and test.

## Symptom
Every Windows build logged four plug-ins that cannot load (CI smoke logs, and STATUS.md since build 39464948841, where they were taken for "optional plug-ins that are not built"):
```
cannot load plug-in ...\plugins\codec\libx265_plugin.dll: The specified module could not be found. (error 126)
cannot load plug-in ...\plugins\access\libaccess_srt_plugin.dll: ... (error 126)
cannot load plug-in ...\plugins\access_output\libaccess_output_srt_plugin.dll: ... (error 126)
cannot load plug-in ...\plugins\demux\libgme_plugin.dll: ... (error 126)
```
What that costs users:
- **SRT streams** (`srt://`): neither playing nor streaming works.
- **Game-music files** (.nsf, .spc, .gbs, .vgm and similar): do not play.
- **HEVC encoding** (convert / stream to H.265): not available.

## Cause
1. **A missing DLL.** The four plug-ins contain C++ libraries (x265, libsrt, game-music-emu). With the GCC toolchain of the build image they import **`libgcc_s_seh-1.dll`**, which the package never shipped.
   - configure asks for `-static-libgcc`, but libtool drops it when it links their C++ dependencies.
   - The image's posix toolchain's `libgcc_s_seh-1.dll` itself imports **`libwinpthread-1.dll`**.
   - Checked with objdump over every DLL and exe of the 1.1.0 zip: these are the only non-system DLLs imported and not shipped. `vulkan-1.dll` (libplacebo Vulkan, from the GPU driver), `msdmo.dll` and `XmlLite.dll` are system DLLs.
2. **Shipping it is not enough.** VLC loads plug-ins with `LOAD_LIBRARY_SEARCH_SYSTEM32` (`src/win32/plugin.c`), and `winvlc.c` limits the process's DLL search to System32 (VLC's hardening against planted DLLs). A plug-in's import is found only in System32 or among the modules already loaded; that is how `libvlccore.dll` is found. A DLL next to `Cone.exe` is never searched.

## Fix
- **Packaging:** `extras/package/win32/copy-gcc-runtime.sh`, called by `package-win-common` (`package.mak`), so the zip and the installer both get it (the installer takes every `*.dll` of the package root).
  - It reads the real imports of every packaged DLL and exe (objdump).
  - It copies the GCC runtime DLLs that are imported (`libstdc++-6`, `libgcc_s_seh-1`, `libgcc_s_dw2-1`, `libwinpthread-1`) from the build's own compiler (`$(CC) -print-file-name`), following their own imports.
  - The build fails if one is imported but missing.
  - On the 1.1.0 package it copies `libgcc_s_seh-1.dll` and then `libwinpthread-1.dll`.
- **Loading (core, `src/win32/plugin.c`):** before the first plug-in loads (`vlc_dlopen`, once), the GCC runtime DLLs next to `libvlccore.dll` are loaded by full path. Afterwards the plug-ins' imports resolve to them.
  - Search rules unchanged: still System32 only. Only those named files, from the folder libvlccore itself was loaded from.
  - Covers `Cone.exe`, `vlc-cache-gen.exe` (the installer builds the plug-in cache with it) and `vlc-preparser.exe`.
  - Both profiles (vlc and Cone): the same plug-ins failed in both.

## Proof before the build (Wine 9, the 1.1.0 zip)
- **`Cone.exe -I dummy` without a plug-in cache** (every plug-in loads at start): 4 "cannot load plug-in" lines, the same four. With only the two DLLs copied next to `Cone.exe`: still 4 (the search never looks there).
- **A test program loading the plug-ins exactly like `vlc_dlopen`** (System32-only search, libvlccore loaded):
  - without the runtime preloaded, all four fail with error 126;
  - with `libwinpthread-1.dll` and `libgcc_s_seh-1.dll` preloaded by full path, all four load.
- `plugin.c` compiles with the MinGW compiler (`-Wall -Wextra`), no warnings.

## New smoke check (all Windows builds)
"every plug-in loads", after every session (portable H.264, portable HEVC, installed):
- It fails when Cone's log has any "cannot load plug-in" line, and names the plug-ins.
- It reads the log after the quit, because the file logger is fully buffered on Windows.
- The zip ships no plug-in cache, so its sessions load every plug-in at start.

## Runs
| Run | Build | Result |
|---|---|---|
| smoke-windows-manual 41245616412 | build-windows #139 (run 41243837748), before this fix | the new check **fails** in all 3 sessions: the 4 plug-ins, error 126 |
| build-windows 41245608068 | test branch `wip/test-plugin-dlls` (this fix plus the smoke-media fix, since merged) | **all checks pass**, "every plug-in loads" in all 3 sessions (zip H.264, zip HEVC, installed H.264), no retries |

## Windows retest (PC session)
1. **The package.** The zip and the installed folder have `libgcc_s_seh-1.dll` and `libwinpthread-1.dll` next to `Cone.exe`.
2. **No load errors.** Settings > General > Diagnostics > Save a log, start Cone, open a file, quit: no "cannot load plug-in" line.
3. **Game music.** Play a game-music file (an .nsf or .spc; plenty of free ones online): it plays.
4. **Installed upgrade.** Install over 1.1.0, start, check the log: no "cannot load plug-in" (the installer's plug-in cache now lists the four).
