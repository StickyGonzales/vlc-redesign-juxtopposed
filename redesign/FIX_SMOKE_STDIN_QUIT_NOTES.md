# Linux smoke: a Cone just started was quit from outside (test harness only)

StickyGonzales, 2026-11-15. Branch wip/fix-smoke-stdin-quit. The open STATUS row "a Cone just
started is quit from outside the interface", seen in build-linux #152 ("drawing: main window
appears") and #153 ("restore-quit: main window appears"), both green on a re-run.

## Where the quit came from

**The test harness, not Cone and not VLC's core in normal use.**

The Linux smoke started every Cone with `--extraintf=cli --rc-unix=<socket> --rc-fake-tty`.
- **What the fake tty does.** `--rc-fake-tty` makes VLC's command-line interface also read
  commands from stdin (`modules/control/cli/cli.c`, as if stdin were a terminal).
- **The smoke's stdin was already at its end.** The cli gets end-of-file at once and calls
  `libvlc_Quit` (cli.c, "Standard input closed: exit"). That is the `main debug: exiting` line every
  Cone of those runs logs right after the cli starts.
- **Why it is usually lost.** The cli starts while `libvlc_new` runs, and `bin/vlc.c` installs its
  exit handler only after that. When the cli's read comes first, `libvlc_Quit` finds no handler,
  logs `no exit handler`, and nothing happens. That is every passing Cone log.
- **When it hits.** When the cli thread gets to its read slightly later, the handler is already
  there. `libvlc_Quit` then sends SIGTERM to the main thread, which ends Cone about 0.2 s after its
  start, before its window. The watchdog logs "a quit that did not start in the interface".
- **Evidence.**
  - In build-linux #152 and #153, every Cone log has `no exit handler` after its first `exiting`,
    except the two that failed: #152 `cone-drawing.log` and #153 `cone-restore-quit.log`.
  - The macOS smoke found the same thing first (`macos-smoke.py`, its runs 11 and 12).

**Real users are not affected.** It needs the cli interface plus a fake tty, or a terminal on stdin
that ends. Cone does not start the cli interface, and a desktop or file-manager start has no such
stdin.

## Fix (the smoke only)

**The Linux smoke now starts Cone like the macOS smoke does:** no `--rc-fake-tty`, and stdin from
/dev/null. The cli then has no stdin reader at all, and the checks still use its socket. An open
stdin pipe would not do: macOS run 12 showed that a reader blocked on an open stdin holds up the
quit until the watchdog ends Cone.

**New guard check "no Cone of this run is quit before its interface starts".** At the end of the
run, no Cone log may have `main debug: exiting` before `using interface module "qt"`.
- **On the old harness** it flags every Cone that had the cli: 26 of 26 logs of #152, and 26 of 27
  of #153 (the 27th is a Cone started without the cli).
- **With the fix**, locally (ASan build): drawing, drawing-pinned and the Recent checks pass, and the
  guard passes ("8 Cone logs, none quit at the start"). No log has the early `exiting` any more.

## Green runs

(filled in when CI has run)

## Windows retest

Nothing to retest: only the Linux smoke script changed. Windows and the app itself are unchanged.
