# Playlist page "..." menu: Favorite (F-11, branch wip/fix-playlist-favorite)

Branch `wip/fix-playlist-favorite`, made from `origin/wip/next-test` (8e005df792). Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), no core change.

WINDOWS_CHECKLIST.md row 337 (F-11): the playlist "..." menu had no "Favorite". Figma "playlist context menu": Play, Favorite, Shuffle, Export Playlist, Add to Queue, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata ("Delete Playlist" at the end is Decisions (Claude) 2026-10-14 Phase 5).

## 1. Cause
There are two playlist "..." menus, both built by `RdLibraryItemMenu.qml` (`_playlistEntries`). Favorite is only added when the item's favorite state is known (so it can always be cleared again), and neither menu knew it:
- **The playlist page's own header "...":** its item was built from the library location (`{ kind, id, title }`), which has no favorite state.
- **A playlist row's "..." on the Playlists page:** the rows come from VLC's playlist list model (`MLPlaylistListModel`), which has no favorite role. (Found in the sandbox test of the first fix: the row menu had no Favorite either.)

## 2. Fix
- `RdLibraryStore.playlistFavorite(id, callback)` (`rdlibrarystore.cpp/.hpp`) reads the playlist's favorite state on the media library thread, like `playlistMedia` does for its items.
- `RdLibraryItemMenu.qml`, in the header's menu only (`forPage`), reads it when a playlist page opens (`_pageFavorite`). The header menu passes it, so Favorite shows with the heart filled when the playlist is a favorite.
- `RdLibraryStore.setFavorite` now sends `favoriteChanged(id, favorite)` once the write is in the library, and the header menu takes the new state from it. That covers a toggle from the header and one from a playlist row just before the page opens.
- The library's jobs run on up to 4 threads, not in order. A read that started before a write could come back after it with the old state, so such a read is dropped (a count of writes seen), and an answer for a page that is no longer shown is dropped too. (Independent review finding, fixed before the test build.)
- The menu still opens at once: nothing waits for the library when "..." is clicked.

- **Rows:** `MLPlaylist` keeps the playlist's `b_is_favorite` and `MLPlaylistListModel` exposes it as `isFavorite` (new role at the end of the list, so the other roles keep their values; VLC's own views don't use it). The Playlists row passes it to its menu. A favorite change reaches the row through the library's playlist update event (`VLC_ML_EVENT_PLAYLIST_UPDATED`, which the model already handles).

## 3. Checks
- qmlcheck: errors 1 (the known HighResolutionTimeWidget stub), crashed 0. buildlists: 0 problems. privacycheck: 0 problems.
- `rdlibrarystore.cpp`, `mlplaylist.cpp` and `mlplaylistlistmodel.cpp` compile with no new warnings (g++, `-Wall -Wextra -Wconversion`, syntax check against Qt 6 headers).

## 4. Sandbox test (Linux)
Linux build 26 (run 39431582848, branch `wip/fix-playlist-favorite-linux` = this branch + wip/linux-build), AppImage, Xvfb, openbox. Test playlist "Road Trip" made with Create playlist. "Before" = Linux build 21 (wip/next-test code).

| Check | Result |
|---|---|
| Playlist page header "..." | **pass**: Play, Favorite, Shuffle, Export Playlist, Add to Queue, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata, Delete Playlist. Before: no Favorite. Side by side with Figma: `redesign/fix-shots/F-11_menu_sbs.png` |
| Favorite from the page menu, menu opened again | **pass**: Favorite selected (check mark) |
| Playlists row "..." | **pass**: Favorite there (it was missing there too before the second commit) |
| Cleared in the row, then the page menu | **pass**: not selected |
| Set on the page, back to Playlists, row menu | **pass**: selected (`redesign/fix-shots/F-11_favorite_sync.png`) |
| Restart Cone | **pass**: the state survives (row menu after a restart) |
| Page "..." opened and closed 10 times quickly | **pass**: opens at once each time |
| Quit | **pass**: exit 0, no QML errors in the log |

Remaining difference, not from this branch: the "Add Audio Tracks" icon has more bars than Figma's (same before and after).

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
