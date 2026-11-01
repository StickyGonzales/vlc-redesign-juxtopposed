# --version prints the Cone Player version (branch wip/fix-version-console)

Branch `wip/fix-version-console`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. **Core change** (`src/config/help.c`), Cone build only, Windows only; per the repo rules, in its own build.

## Cause
The text was already Cone's: "Cone Player X.Y.Z, based on VLC 4.0.0-dev …" (brand layer). The Linux build prints it in the terminal; checked on build-linux #48:

```
$ ./cone --version
Cone Player 0.1.0, based on VLC 4.0.0-dev Otto Chriek (639984a)
```

On Windows it never reached the terminal. `Cone.exe` is a window program, and Windows starts it without the console of the terminal it was typed in. VLC's `ShowConsole()` then:
- opens a console window of its own;
- writes the text into **vlc-help.txt** in the current folder;
- waits for Return.

So in PowerShell, `& "C:\Program Files\Cone\Cone.exe" --version` printed nothing where it was typed.

## Fix (public build, Windows)
- **Started from a terminal** (Command Prompt, PowerShell, Windows Terminal): Cone attaches to that terminal's console (`AttachConsole(ATTACH_PARENT_PROCESS)`) and prints `--version`, `--help` and `-H` there. There is no extra window and no "Press the RETURN key".
- **Started any other way** (a shortcut with `--version`): VLC's behaviour, with the file named **cone-help.txt**.

The vlc profile is unchanged.

A window program's output comes after the prompt (the terminal does not wait for it). Cone starts its text on a new line, then the terminal shows its prompt again after Enter. That is how every window program that prints behaves.

## Runs
| Run | Result |
|---|---|
| build-windows #148 (41253483182), this branch | build and **all smoke checks pass** (the change is in `--version` / `--help` only, which the smoke checks do not call; Windows' console behaviour needs the retest below) |

Checks: `src/config/help.c` syntax check with mingw-w64 (`-Wall -Wextra`), public and vlc profile: no warnings. privacycheck 0.

## Windows retest (PC session)
1. **PowerShell:** `& "<WORK_DIR>\builds\current\Cone.exe" --version` prints "Cone Player 0.1.0, based on VLC 4.0.0-dev …" (a manual build is 0.1.0), then the compiler and license lines, in the same window. No console window opens, and no `vlc-help.txt` or `cone-help.txt` is written.
2. **Command Prompt:** `"…\Cone.exe" --version`: the same.
3. **Help:** `Cone.exe --help` prints the help into the terminal.
4. **Shortcut:** a desktop shortcut with `--version` added opens a console window: "Dumped content to cone-help.txt file." and Press RETURN, as VLC does.
5. **Normal start:** Cone starts as usual (no console).
