# A double-click during a slow quit was lost (branch wip/fix-quit-handoff)

Branch `wip/fix-quit-handoff`, made from `origin/wip/next-test` (a5aacbe668), draft pull request into `wip/next-test`. Interface only (`modules/gui/qt/util/quit_watchdog.cpp`), no core change; Windows only (the code does nothing on other systems).

## The bug (PC, 2026-10-26, STATUS.md 13:05)
MED. Cone in one-instance mode, as a double-click in Explorer starts it ("one-instance-when-started-from-file"). When a quit stalls in the core, the window disappears at once (0.0 to 0.2 s), but the process keeps running until the quit watchdog ends it, up to 5 s later. A file double-clicked during those 5 s was lost. The new copy handed the file to the quitting one and exited within a second, the quitting one did nothing with it, and no window ever appeared (observer run quitux-20261026-124952). Starting Cone without a file during the wait worked: there was nothing to hand over, so the new copy opened its own start screen.

## Cause
VLC's one-instance mode on Windows has two parts:
- **The new start** (`src/win32/specific.c`, `system_Configure`). It opens the named mutex "Cone ipc <version>". When the mutex already exists, it waits for it, looks for a window with that same name, sends its files there (`WM_COPYDATA`) and exits. When it finds no such window, it logs "one instance mode DISABLED (couldn't find 1st instance of program)" and starts normally.
- **The running instance** (`modules/control/win_msg.c`). It owns that window on a helper thread and adds each file it receives to its play queue.

The running instance keeps both for its whole life, including the seconds of a stalled quit. So a new start found it and handed the file to an instance whose play queue was shutting down.

## Fix
At the very start of a quit (`QuitWatchdog::arm`: the window's close, Quit, Ctrl+Q; and `armWithoutSaving` for quits that do not start in the interface), Cone takes the name off its own IPC window. A new start then finds no running instance and opens the file in a fresh Cone. The window itself stays, so `win_msg` still closes it as before. The new name is sent with `SendMessageTimeoutW` (at most 500 ms, `SMTO_ABORTIFHUNG`), after the watchdog timer has started, so a busy helper thread cannot hold the quit. Only a window of this process is renamed (`GetWindowThreadProcessId`). The log says "quit watchdog: one-instance handoff released, a new start opens its own window".

## Known limit (not changed)
The fresh Cone starts as a normal instance without the handoff of its own. VLC only makes the first instance the owner, and the quitting one still holds the mutex while it runs. So while that fresh Cone runs, a further double-click opens another window instead of handing over. Once every Cone has closed, one-instance mode works as before. A full fix is a small core change: `src/win32/specific.c` would take over the handoff (start `win_msg`) when it finds no first instance's window. It needs StickyGonzales's OK (Decision 27) and its own build.

## Sandbox test (Wine, protocol level)
This sandbox cannot run Cone for Windows, so the protocol was tested with a small Windows program built with VideoLAN's win64 toolchain (MinGW g++, C++17, `-Wall -Wextra`: no warnings) and run under Wine 10 (64-bit). It contains `system_Configure`'s new-start code, `win_msg`'s IPC window thread and this branch's release function, the same code as here. The first copy "quits" 2 s after starting and waits 5 s like a stalled quit; the second copy is started 4 s in, during the wait.

| Scenario | Result |
|---|---|
| First copy running, not quitting: a double-click | handed over: "received a file through the handoff", the new copy exits (as before) |
| Quit without the release (the bug) | the quitting copy receives the file and ends: lost |
| Quit with the release (this branch) | "one instance mode DISABLED (couldn't find 1st instance): starts normally with C:\media\film.mkv" |
| With the release, two more starts while that fresh copy runs | both start normally (the known limit above) |

The Linux build of the branch compiles clean (the code is Windows only), and Cone still quits normally there ("quit watchdog: armed ..." in the log, exit 0).

## Retest on Windows
Build this branch on its own (`gh workflow run build-windows.yml --ref wip/fix-quit-handoff`) and deploy it. Cone must start by a double-click, the one-instance mode the bug needs. Use two test films A and B.
1. **The bug's case.** Double-click A, then run the quit recipe that makes the watchdog wait (as quitux-20261026-124952). Close the window, and within 1 to 2 s double-click B in Explorer: a new Cone window opens and plays B. The old process ends on its own (watchdog, about 5 s), and B keeps playing. The old run's log (`--file-logging`) has "one-instance handoff released".
2. **The handoff still works normally.** With Cone running and not quitting, double-click B: B opens in that same window, and no second window appears.
3. **A clean quit:** close Cone after a short play: it ends in under a second as before, with no watchdog message.
4. **Starting without a file during the wait** (Start menu or desktop icon), as in step 1: it opens its start screen, as before.
5. **The known limit,** for the record: after step 1, while B's window runs, double-click another file: it opens a second window. Close every Cone, double-click once more: the handoff works again.
