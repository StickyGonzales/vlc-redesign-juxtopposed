# Playlist page "..." menu: Favorite (F-11, branch wip/fix-playlist-favorite)

Branch `wip/fix-playlist-favorite`, made from `origin/wip/next-test` (8e005df792). Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), no core change.

WINDOWS_CHECKLIST.md row 337 (F-11): the playlist "..." menu had no "Favorite". Figma "playlist context menu": Play, Favorite, Shuffle, Export Playlist, Add to Queue, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata ("Delete Playlist" at the end is Decisions (Claude) 2026-10-14 Phase 5).

## 1. Cause
There are two playlist "..." menus, both built by `RdLibraryItemMenu.qml` (`_playlistEntries`):
- **A playlist row on the Playlists page:** its item comes from the library model, which knows the playlist's favorite state, so Favorite was there.
- **The playlist page's own header "...":** its item was built from the library location (`{ kind, id, title }`). The location has no favorite state, and Favorite is only added when the state is known (so it can always be cleared again), so the entry was left out.

## 2. Fix
- `RdLibraryStore.playlistFavorite(id, callback)` (`rdlibrarystore.cpp/.hpp`) reads the playlist's favorite state on the media library thread, like `playlistMedia` does for its items.
- `RdLibraryItemMenu.qml`, in the header's menu only (`forPage`), reads it when a playlist page opens (`_pageFavorite`). The header menu passes it, so Favorite shows with the heart filled when the playlist is a favorite.
- `RdLibraryStore.setFavorite` now sends `favoriteChanged(id, favorite)` once the write is in the library, and the header menu takes the new state from it. That covers a toggle from the header and one from a playlist row just before the page opens.
- The library's jobs run on up to 4 threads, not in order. A read that started before a write could come back after it with the old state, so such a read is dropped (a count of writes seen), and an answer for a page that is no longer shown is dropped too. (Independent review finding, fixed before the test build.)
- The menu still opens at once: nothing waits for the library when "..." is clicked.

## 3. Checks
- qmlcheck: errors 1 (the known HighResolutionTimeWidget stub), crashed 0. buildlists: 0 problems. privacycheck: 0 problems.
- `rdlibrarystore.cpp` compiles with no new warnings (g++, `-Wall -Wextra -Wconversion`, syntax check against Qt 6 headers).

## 4. Sandbox test (Linux)
RESULTS

## 5. Windows retest steps
1. Start Cone, open the library (sidebar button in the top bar), go to **Playlists**, use **Create playlist**, name it, Save.
2. Click the playlist to open its page, then click the **"..."** in the page header (next to the pop-out button).
   - Expect: Play, **Favorite**, Shuffle, Export Playlist, Add to Queue, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata, Delete Playlist (Figma "playlist context menu").
3. Click **Favorite**, then open "..." again.
   - Expect: Favorite is shown selected (filled heart).
4. Go back to Playlists and open the playlist row's "..." menu.
   - Expect: Favorite selected there too.
5. Click Favorite in the row menu to clear it, open the playlist page again, open its "...".
   - Expect: Favorite not selected.
6. Restart Cone, open the playlist page "..." once more.
   - Expect: the state you left survives.
7. Rapid check: open and close the header "..." 10 times quickly.
   - Expect: it opens at once every time, nothing freezes.
