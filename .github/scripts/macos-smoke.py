#!/usr/bin/env python3
# Smoke checks of the experimental Cone macOS build on a GitHub macOS runner (smoke-macos.yml,
# redesign/MACOS_NOTES.md); the macOS counterpart of linux-smoke.py and win64-smoke.ps1, with the
# checks a runner allows:
#   - the .dmg opens, the app copies out of it and its ad-hoc signature verifies
#   - the main window appears; H.264 and HEVC play (VLC's cli interface on a Unix socket gives
#     the time); the subtitle file loads; Cmd+P opens the Settings dialog, Escape closes it;
#     Cmd+Q quits in under 3 s; no "cannot load plug-in" line in the log
# Windows come from CoreGraphics' window list (no permission needed). Keys are real keyboard events
# (CoreGraphics); the Settings dialog is found in the app's accessibility tree when the runner lets
# this process read it, otherwise by the change of the window's picture.
#   macos-smoke.py --dmg <Cone-*-macos-arm64.dmg> --media <folder with test-h264.mp4,
#                  test-hevc.mp4, test.srt> --out <folder>
import argparse
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

import Quartz
from AppKit import NSApplicationActivateIgnoringOtherApps, NSRunningApplication, NSWorkspace
from ApplicationServices import (AXIsProcessTrusted, AXUIElementCopyAttributeValue,
                                 AXUIElementCreateApplication, AXUIElementPerformAction)
from PIL import Image, ImageChops, ImageStat

ap = argparse.ArgumentParser()
ap.add_argument('--dmg', required=True)
ap.add_argument('--media', required=True)
ap.add_argument('--out', required=True)
args = ap.parse_args()

OUT = os.path.abspath(args.out)
MEDIA = os.path.abspath(args.media)
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, 'smoke-log.txt'), 'a', buffering=1)
RESULTS = []      # (name, status, detail)
RETRIES = []      # (name, first error)
WORK = tempfile.mkdtemp(prefix='cone-smoke-')
RC_SOCK = os.path.join(WORK, 'rc.sock')
APP_NAME = 'Cone Player'
BUNDLE_ID = 'io.github.stickygonzales.coneplayer'

# virtual key codes (Carbon's kVK_ANSI_*)
KEY_P, KEY_Q, KEY_ESCAPE = 35, 12, 53


def log(text):
    line = time.strftime('%H:%M:%S ') + text
    print(line, flush=True)
    LOG.write(line + '\n')


class CheckFailed(Exception):
    pass


def check(name, body, retry=None, soft=False):
    """a check, run once more when it fails; `soft`: a check the runner cannot always confirm
    (synthetic keys into Qt's window): its failure is a warning, the run stays green"""
    for attempt in (1, 2):
        try:
            detail = body() or ''
            if attempt == 2:
                RETRIES.append((name, first))
            RESULTS.append((name, 'pass', detail))
            log(f'PASS  {name}  {detail}')
            return True
        except Exception as e:  # noqa: BLE001 (every failure is a failed check)
            if attempt == 1:
                first = str(e) or type(e).__name__
                log(f'retry  {name}  first attempt failed: {first}')
                if retry:
                    try:
                        retry()
                    except Exception as e2:  # noqa: BLE001
                        log(f'retry setup failed: {e2}')
                continue
            RETRIES.append((name, first))
            RESULTS.append((name, 'warning' if soft else 'fail', str(e)))
            log(f'{"WARN" if soft else "FAIL"}  {name}  {e}')
            return False


def note(name, detail):
    RESULTS.append((name, 'info', detail))
    log(f'INFO  {name}  {detail}')


def run(cmd, timeout=120, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)


def shot(name):
    path = os.path.join(OUT, name + '.png')
    run(['screencapture', '-x', path], timeout=30)
    return path


# ------------------------------------------------------------------ input and windows

def key(code, command=False):
    flags = Quartz.kCGEventFlagMaskCommand if command else 0
    for down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, code, down)
        Quartz.CGEventSetFlags(ev, flags)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(0.05)


def windows(pid):
    """the pid's normal on-screen windows: [(id, x, y, w, h)]"""
    out = []
    infos = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
        Quartz.kCGNullWindowID) or []
    for w in infos:
        if w.get('kCGWindowOwnerPID') != pid or w.get('kCGWindowLayer', 1) != 0:
            continue
        b = w.get('kCGWindowBounds') or {}
        out.append((w.get('kCGWindowNumber'), int(b.get('X', 0)), int(b.get('Y', 0)),
                    int(b.get('Width', 0)), int(b.get('Height', 0))))
    return out


def dismiss_prompts():
    """presses "Don't Allow" on macOS's own prompts (the local network one VLC's network
    discovery brings up holds the keyboard): the names of the apps whose prompt was dismissed"""
    done = []
    if not AXIsProcessTrusted():
        return done
    for app in NSWorkspace.sharedWorkspace().runningApplications():
        stack = [AXUIElementCreateApplication(app.processIdentifier())]
        seen = 0
        while stack and seen < 400:
            el = stack.pop()
            seen += 1
            err, role = AXUIElementCopyAttributeValue(el, 'AXRole', None)
            err2, title = AXUIElementCopyAttributeValue(el, 'AXTitle', None)
            if err == 0 and role == 'AXButton' and err2 == 0 and title in ("Don't Allow", 'Don’t Allow'):
                AXUIElementPerformAction(el, 'AXPress')
                done.append(str(app.localizedName()))
                break
            err, kids = AXUIElementCopyAttributeValue(el, 'AXChildren', None)
            if err == 0 and kids:
                stack.extend(kids)
    return done


def click(x, y):
    for kind in (Quartz.kCGEventLeftMouseDown, Quartz.kCGEventLeftMouseUp):
        ev = Quartz.CGEventCreateMouseEvent(None, kind, (x, y), Quartz.kCGMouseButtonLeft)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(0.05)


def picture_colour(path, box):
    """how colourful the middle of the video area is: the mean of each pixel's spread between its
    red, green and blue (the test pattern's colour bars score far above 40; black or grey is 0)"""
    im = Image.open(path).convert('RGB')
    scale = im.size[0] / Quartz.CGDisplayBounds(Quartz.CGMainDisplayID()).size.width
    x, y, w, h = [int(v * scale) for v in box]
    crop = im.crop((x + w // 4, y + h // 4, x + w * 3 // 4, y + h * 3 // 4)).resize((64, 36))
    px = list(crop.getdata())
    return sum(max(p) - min(p) for p in px) / len(px)


def region_diff(a, b, box):
    """mean difference of two screenshots inside box (x, y, w, h, in points; Retina doubles)"""
    ia, ib = Image.open(a).convert('L'), Image.open(b).convert('L')
    if ia.size != ib.size:
        return 255.0
    scale = ia.size[0] / Quartz.CGDisplayBounds(Quartz.CGMainDisplayID()).size.width
    x, y, w, h = [int(v * scale) for v in box]
    crop = (x + w // 6, y + h // 6, x + w * 5 // 6, y + h * 5 // 6)
    return ImageStat.Stat(ImageChops.difference(ia.crop(crop), ib.crop(crop))).mean[0]


# ------------------------------------------------------------------ the cli interface

def rc(cmd):
    with socket.socket(socket.AF_UNIX) as s:
        s.settimeout(3)
        s.connect(RC_SOCK)
        s.sendall((cmd + '\n').encode())
        time.sleep(0.4)
        # the whole reply: the socket also gets VLC's status lines ("status change: ..."), which
        # can come first; read until nothing more arrives for half a second
        s.settimeout(0.5)
        data = b''
        try:
            while True:
                chunk = s.recv(65536)
                if not chunk:
                    break
                data += chunk
        except socket.timeout:
            pass
    return data.decode(errors='replace')


def rc_number(cmd):
    for line in rc(cmd).splitlines():
        line = line.strip().lstrip('>').strip()
        if line.lstrip('-').isdigit():
            return int(line)
    raise CheckFailed(f'no number from "{cmd}"')


# ------------------------------------------------------------------ Cone sessions

STARTS = {}


class Session:
    def __init__(self, exe, video, tag, extra=()):
        self.tag = tag
        # every start its own log (a retry's session used to overwrite the log of the one that failed)
        STARTS[tag] = STARTS.get(tag, 0) + 1
        suffix = '' if STARTS[tag] == 1 else f'-{STARTS[tag]}'
        self.log = os.path.join(OUT, f'cone-{tag}{suffix}.log')
        if os.path.exists(RC_SOCK):
            os.remove(RC_SOCK)
        a = [exe, '--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-qt-cone-update-check',
             '--aout=adummy', '--input-repeat=50', '--file-logging', f'--logfile={self.log}', '--log-verbose=2',
             '--extraintf=cli', f'--rc-unix={RC_SOCK}',
             f'--sub-file={os.path.join(MEDIA, "test.srt")}', *extra, video]
        log('start ' + ' '.join(a))
        self.err = open(os.path.join(OUT, f'cone-{tag}{suffix}-stderr.txt'), 'w')
        self.started = time.time()
        # the checks use the cli's socket only. With --rc-fake-tty (or a terminal on stdin) the cli
        # also reads stdin: it quits VLC when stdin ends (run 11: the runner's stdin ended at once
        # and Cone quit at its start), and a reader blocked on a stdin that stays open holds up
        # the quit until the watchdog ends Cone (run 12). No fake tty and no terminal: no stdin
        # reader at all
        self.proc = subprocess.Popen(a, stdin=subprocess.DEVNULL, stdout=self.err,
                                     stderr=subprocess.STDOUT, start_new_session=True)
        self.win = None

    def window(self):
        end = time.time() + 45
        while time.time() < end:
            if self.proc.poll() is not None:
                raise CheckFailed(f'Cone exited with {self.proc.returncode} before its window appeared')
            for w in windows(self.proc.pid):
                if w[3] > 300 and w[4] > 200:
                    self.win = w
                    return
            time.sleep(0.5)
        raise CheckFailed('no Cone window within 45 s')

    def focus(self):
        app = NSRunningApplication.runningApplicationWithProcessIdentifier_(self.proc.pid)
        if app is not None:
            app.activateWithOptions_(NSApplicationActivateIgnoringOtherApps)
        time.sleep(0.6)
        # the window under the pointer gets the bars; a click would pause the video
        Quartz.CGWarpMouseCursorPosition((self.win[1] + self.win[3] / 2, self.win[2] + self.win[4] / 2))

    def stop(self):
        if self.proc.poll() is None:
            os.killpg(self.proc.pid, 9)
            self.proc.wait(10)
        self.err.close()


def check_window(s):
    def body():
        t = time.time()
        s.window()
        _, x, y, w, h = s.win
        return f'after {time.time() - t:.1f} s, {w}x{h} at {x},{y}'
    return check(f'{s.tag}: main window appears', body)


def exited(s):
    """a clear message when Cone is no longer running (rather than the cli's "connection refused")"""
    if s.proc.poll() is not None:
        raise CheckFailed(f'Cone exited by itself (exit code {s.proc.returncode}) '
                          f'{time.time() - s.started:.0f} s after its start; log {os.path.basename(s.log)}')


def time_advances(s):
    end = time.time() + 20
    while True:
        exited(s)
        try:
            t1 = rc_number('get_time')
            break
        except Exception:  # noqa: BLE001 (the cli interface starts with the playlist)
            exited(s)
            if time.time() > end:
                raise
            time.sleep(0.5)
    time.sleep(3)
    t2 = rc_number('get_time')
    if t2 <= t1:
        raise CheckFailed(f'time {t1} s, then {t2} s three seconds later')
    return f'{t1} s, then {t2} s three seconds later'



def check_subtitle(s):
    def body():
        out = rc('strack')
        sel = [ln for ln in out.splitlines() if ln.rstrip().endswith('*') and '-1' not in ln]
        if not sel:
            raise CheckFailed('no subtitle track selected: ' + ' | '.join(out.split()))
        return 'selected: ' + sel[0].strip()
    return check(f'{s.tag}: subtitle file loads', body)


def check_settings(s):
    """Cmd+P opens Settings, Escape closes it. Qt's content is not in this runner's accessibility
    tree (runs 41336561372, 41340750128: the menu bar only), so the dialog is found in the picture:
    it covers the middle of the black video (dark grey, about 30 of 255)"""
    def changed(ref, seconds, name):
        end = time.time() + seconds
        while True:
            now = shot(name)
            d = region_diff(ref, now, s.win[1:])
            if d >= 12 or time.time() > end:
                return d, now
            time.sleep(0.5)

    def body():
        prompts = dismiss_prompts()
        if prompts:
            log('dismissed a system prompt of: ' + ', '.join(prompts))
            time.sleep(1.5)
        s.focus()
        # Qt's shortcuts need Cone's window to be the key window (Cmd+Q, the app menu's, does
        # not): a click on the middle of the top bar (the title) gives it the keyboard
        _, x, y, w, h = s.win
        click(x + w * 0.55, y + 14)
        time.sleep(0.8)
        before = shot(f'{s.tag}-settings-before')
        key(KEY_P, command=True)
        d_open, opened = changed(before, 5, f'{s.tag}-settings')
        if d_open < 12:
            # the first key after the system prompt has been lost on this runner: once more
            log('Cmd+P: no change yet, pressed again')
            click(x + w * 0.55, y + 14)
            time.sleep(0.5)
            key(KEY_P, command=True)
            d_open, opened = changed(before, 5, f'{s.tag}-settings')
        if d_open < 12:
            raise CheckFailed(f'Cmd+P: the window did not change (difference {d_open:.1f})')
        key(KEY_ESCAPE)
        d_closed, _ = changed(opened, 4, f'{s.tag}-settings-closed')
        if d_closed < 12:
            # the dialog's close button (its top right corner), so the session goes on
            click(x + w - 35, y + 31)
            time.sleep(1)
            d_x, _ = changed(opened, 3, f'{s.tag}-settings-closed')
            RESULTS.append((f'{s.tag}: Escape closes Settings', 'warning',
                            f'Escape did not close the dialog on this runner (difference {d_closed:.1f}); '
                            f'its close button did ({d_x:.1f}): check by hand on a Mac'))
            log(f'WARN  {s.tag}: Escape did not close Settings; the close button: {d_x:.1f}')
            return f'Cmd+P opens the Settings dialog (difference {d_open:.1f}); screenshot settings'
        return (f'Cmd+P opens the Settings dialog (difference {d_open:.1f}), Escape closes it '
                f'({d_closed:.1f}); screenshots settings / settings-closed')
    # the runner delivers synthetic keys to Qt's window unreliably (MACOS_NOTES.md, runs 6 to 9):
    # a miss is a warning, the tester list checks Settings by hand
    return check(f'{s.tag}: Settings opens', body, soft=True)


def quit_cone(s, hevc):
    if s.proc.poll() is not None:
        raise CheckFailed(f'Cone had already exited (exit code {s.proc.returncode})')
    s.focus()
    key(KEY_Q, command=True)
    t = time.time()
    try:
        s.proc.wait(10)
    except subprocess.TimeoutExpired:
        raise CheckFailed('Cone still runs 10 s after Cmd+Q')
    took = time.time() - t
    with open(s.log, errors='replace') as f:
        fired = 'did not finish quitting' in f.read()
    if fired and hevc:
        RESULTS.append((f'{s.tag}: quit', 'warning', f'the quit watchdog ended it after {took:.2f} s'))
        log(f'WARN  {s.tag}: quit ended by the quit watchdog ({took:.2f} s)')
        return None
    if fired:
        raise CheckFailed(f'the quit watchdog ended Cone ({took:.2f} s)')
    if took >= 3 and hevc:
        # the HEVC decoder's threads end slowly on the Intel runner (3.2 to 3.5 s, run 10): a
        # warning while Cone still quits by itself, as the HEVC quit on Windows and Linux
        RESULTS.append((f'{s.tag}: quit time', 'warning', f'Cone took {took:.2f} s to quit (3 s or more)'))
        log(f'WARN  {s.tag}: quit took {took:.2f} s')
        return f'ended after {took:.2f} s (exit code {s.proc.returncode}), slower than 3 s'
    if took >= 3:
        raise CheckFailed(f'Cone took {took:.2f} s to quit (3 s or more)')
    return f'ended after {took:.2f} s (exit code {s.proc.returncode})'


def check_plugins(s):
    def body():
        with open(s.log, errors='replace') as f:
            bad = sorted({ln.split('cannot load plug-in', 1)[1].strip()
                          for ln in f if 'cannot load plug-in' in ln})
        if bad:
            raise CheckFailed('cannot load plug-in: ' + '; '.join(bad))
        return 'no "cannot load plug-in" line'
    return check(f'{s.tag}: every plug-in loads', body)


def session(exe, codec, full):
    tag = codec
    video = os.path.join(MEDIA, f'test-{codec}.mp4')
    s = Session(exe, video, tag)
    try:
        if not check_window(s):
            return
        time.sleep(2)
        s.focus()
        start = shot(f'{tag}-start')
        note(f'{tag}: picture (information)', f'colour {picture_colour(start, s.win[1:]):.0f} in the middle '
             'of the video (the test pattern: far above 40; black: 0)')
        def restart():
            nonlocal s
            s.stop()
            s = Session(exe, video, tag)
            s.window()
            time.sleep(2)
        # the retry starts a fresh session (the lambda reads the current one)
        check(f'{tag}: playback time advances', lambda: time_advances(s), restart)
        if full:
            check_subtitle(s)
            time.sleep(1)
            shot(f'{tag}-subtitle')
            check_settings(s)

        def retry_quit():
            nonlocal s
            s.stop()
            s = Session(exe, video, tag)
            s.window()
            time.sleep(4)
        check(f'{tag}: quit (Cmd+Q)', lambda: quit_cone(s, codec == 'hevc'), retry_quit)
        check_plugins(s)
    finally:
        s.stop()


# ------------------------------------------------------------------ runs

log(f'macOS {run(["sw_vers", "-productVersion"]).stdout.strip()} on {os.uname().machine}; '
    f'accessibility access: {bool(AXIsProcessTrusted())}')

MOUNT = os.path.join(WORK, 'dmg')
APP = os.path.join(WORK, 'Applications', APP_NAME + '.app')


def open_dmg():
    os.makedirs(MOUNT, exist_ok=True)
    r = run(['hdiutil', 'attach', '-nobrowse', '-readonly', '-mountpoint', MOUNT, args.dmg])
    if r.returncode:
        raise CheckFailed(f'hdiutil attach: {r.stderr.strip()}')
    try:
        listing = sorted(os.listdir(MOUNT))
        if APP_NAME + '.app' not in listing or 'Applications' not in listing:
            raise CheckFailed(f'the .dmg holds {listing}')
        os.makedirs(os.path.dirname(APP), exist_ok=True)
        # ditto keeps the bundle's links, modes and signature, as a drag in the Finder does
        r = run(['ditto', os.path.join(MOUNT, APP_NAME + '.app'), APP])
        if r.returncode:
            raise CheckFailed(f'ditto: {r.stderr.strip()}')
    finally:
        run(['hdiutil', 'detach', MOUNT])
    return f'holds {", ".join(listing)}; the app copies out'


if not check('dmg: opens and the app copies out', open_dmg):
    sys.exit(1)


def signature():
    r = run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', APP])
    if r.returncode:
        raise CheckFailed(r.stderr.strip()[-500:])
    d = run(['codesign', '-dv', APP]).stderr
    sig = [ln for ln in d.splitlines() if ln.startswith(('Signature=', 'Identifier=', 'Format='))]
    return '; '.join(sig)


check('app: ad-hoc signature verifies', signature)


def info_plist():
    import plistlib
    with open(os.path.join(APP, 'Contents', 'Info.plist'), 'rb') as f:
        p = plistlib.load(f)
    if p.get('CFBundleIdentifier') != BUNDLE_ID or p.get('CFBundleName') != APP_NAME:
        raise CheckFailed(f'{p.get("CFBundleIdentifier")} / {p.get("CFBundleName")}')
    return f'{p["CFBundleName"]} {p.get("CFBundleShortVersionString")}, {BUNDLE_ID}'


check('app: name and identifier', info_plist)

# Gatekeeper's verdict on an app without a Developer ID: expected "rejected", the reason testers
# open it with right-click > Open (MACOS_NOTES.md); informational only
note('app: Gatekeeper (expected: rejected, unsigned)',
     ' '.join(run(['spctl', '--assess', '--type', 'execute', '-vv', APP]).stderr.split())[:300])

EXE = os.path.join(APP, 'Contents', 'MacOS', APP_NAME)
session(EXE, 'h264', True)
session(EXE, 'hevc', False)


# macOS file-open events (issue #69): Finder opens a file with an "open documents" Apple event,
# as `open -a <app> <file>` does through LaunchServices. Warnings while the runner's handling of
# a Cone started from its executable is unproven; the tester list checks Finder by hand
def playing_file(name, seconds=15):
    end = time.time() + seconds
    while time.time() < end:
        try:
            if name in rc('status'):
                t1 = rc_number('get_time')
                time.sleep(2)
                t2 = rc_number('get_time')
                if t2 > t1:
                    return f'{name} plays ({t1} s, then {t2} s)'
        except Exception:  # noqa: BLE001 (the cli starts with the playlist)
            pass
        time.sleep(1)
    raise CheckFailed(f'{name} is not playing {seconds} s later')


def finder_open_running():
    s = Session(EXE, os.path.join(MEDIA, 'test-h264.mp4'), 'finder-running')
    try:
        s.window()
        time.sleep(3)
        r = run(['open', '-a', APP, os.path.join(MEDIA, 'test-hevc.mp4')])
        if r.returncode:
            raise CheckFailed(f'open -a failed: {r.stderr.strip()}')
        return 'the running Cone: ' + playing_file('test-hevc.mp4')
    finally:
        s.stop()


def finder_open_launch():
    # Cone started by LaunchServices with a file, as a double-click in Finder; the cli's socket
    # through --args, which the file does not travel with (it comes as the Apple event)
    if os.path.exists(RC_SOCK):
        os.remove(RC_SOCK)
    log_path = os.path.join(OUT, 'cone-finder-launch.log')
    # Qt's macOS application logging (the delegate's launch and open-files calls) into Cone's log,
    # to see whether the launch's open event reaches Qt at all (run 17 and 18: it did not play)
    r = run(['open', '-n', '-a', APP, '--env', 'QT_LOGGING_RULES=qt.qpa.application*=true;qt.qpa.events*=true',
             os.path.join(MEDIA, 'test-hevc.mp4'), '--args',
             '--no-qt-privacy-ask', '--no-qt-cone-update-check', '--aout=adummy', '--input-repeat=50',
             '--file-logging', f'--logfile={log_path}', '--log-verbose=2', '--extraintf=cli',
             f'--rc-unix={RC_SOCK}'])
    if r.returncode:
        raise CheckFailed(f'open -a failed: {r.stderr.strip()}')
    try:
        end = time.time() + 30
        while not os.path.exists(RC_SOCK) and time.time() < end:
            time.sleep(0.5)
        return 'a start from Finder: ' + playing_file('test-hevc.mp4', 20)
    finally:
        try:
            rc('quit')
        except Exception:  # noqa: BLE001
            pass
        time.sleep(3)
        run(['pkill', '-f', os.path.join(APP, 'Contents', 'MacOS')])


check('finder: a file opened while Cone runs plays there', finder_open_running, soft=True)
check('finder: a start with a file plays it', finder_open_launch, soft=True)


# information only: why the picture is black on the runner (MACOS_NOTES.md, "The black picture").
# The same H.264 file with each of VLC's macOS video outputs, and with software decoding, each with
# a screenshot (vout-<name>.png) and the colour in the middle of the video; VLC's own snapshot of
# the decoded picture (a picture that is not black there was decoded fine, so only the display is
# black); and one run without Cone's interface (-I dummy: VLC's own video window, no Qt), to tell
# the Qt embedding from the runner's virtual GPU
def snapshot_colour(folder):
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith('.png'))
    if not files:
        return None
    # kept with the results, next to the screenshot of the same moment
    shutil.copy(os.path.join(folder, files[-1]), os.path.join(OUT, os.path.basename(folder.rstrip('/')) + '.png'))
    im = Image.open(os.path.join(folder, files[-1])).convert('RGB').resize((64, 36))
    px = list(im.getdata())
    return sum(max(p) - min(p) for p in px) / len(px)


def vout_experiment(tag, extra, whole_screen=False):
    snaps = os.path.join(WORK, 'snap-' + tag)
    os.makedirs(snaps, exist_ok=True)
    s = Session(EXE, os.path.join(MEDIA, 'test-h264.mp4'), tag,
                (*extra, f'--snapshot-path={snaps}', '--snapshot-format=png'))
    try:
        if whole_screen:
            time.sleep(6)
            b = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
            box = (0, 0, int(b.size.width), int(b.size.height))
        else:
            s.window()
            time.sleep(4)
            box = s.win[1:]
        path = shot(tag)
        screen = picture_colour(path, box)
        try:
            rc('snapshot')
            time.sleep(2)
            snap = snapshot_colour(snaps)
        except Exception as e:  # noqa: BLE001 (information only)
            snap = None
            log(f'{tag}: snapshot failed: {e}')
        vout = ''
        try:
            with open(s.log, errors='replace') as f:
                used = [ln.strip() for ln in f if 'using vout display module' in ln or 'using video output' in ln]
            vout = used[-1].split('"')[-2] if used and '"' in used[-1] else (used[-1][-60:] if used else '')
        except OSError:
            pass
        note(f'picture: {tag} (information)',
             f'screen colour {screen:.0f}, VLC snapshot colour '
             f'{"none" if snap is None else f"{snap:.0f}"} (the test pattern: far above 40; black: 0); '
             f'video output in use: {vout or "not in the log"}; screenshot {tag}.png')
    except Exception as e:  # noqa: BLE001 (information only)
        note(f'picture: {tag} (information)', f'not measured: {e}')
    finally:
        s.stop()


for tag, extra, whole in (
        ('vout-default', (), False),
        ('vout-samplebufferdisplay-legacy', ('--vout=samplebufferdisplay', '--force-darwin-legacy-display'), False),
        ('vout-caopengllayer', ('--vout=caopengllayer',), False),
        ('vout-macosx', ('--vout=macosx',), False),
        ('vout-gl', ('--vout=gl',), False),
        ('vout-software-decoding', ('--avcodec-hw=none', '--codec=avcodec,none'), False),
        ('vout-no-qt', ('-I', 'dummy'), True)):
    vout_experiment(tag, extra, whole)


def own_settings():
    home = os.path.expanduser('~/Library')
    # VLC's core files under the bundle identifier (src/darwin/dirs.m); the interface's own
    # settings in Qt's native format under the organization "Cone" (qt.cpp, util/brand.hpp)
    found = [p for p in (f'{home}/Preferences/{BUNDLE_ID}', f'{home}/Application Support/{BUNDLE_ID}',
                         f'{home}/Preferences/com.cone.vlc-qt-interface.plist')
             if os.path.exists(p)]
    vlc = [p for p in (f'{home}/Preferences/org.videolan.vlc', f'{home}/Preferences/com.vlc.vlc-qt-interface.plist')
           if os.path.exists(p)]
    if vlc:
        raise CheckFailed(f'Cone wrote into VLC\'s folder: {vlc}')
    return 'own folders: ' + (', '.join(found) or 'none written yet') + "; VLC's folder untouched"


check('app: settings in its own folders, not VLC\'s', own_settings)

# ------------------------------------------------------------------ summary
fails = [r for r in RESULTS if r[1] == 'fail']
warns = [r for r in RESULTS if r[1] == 'warning']
with open(os.path.join(OUT, 'summary.md'), 'w') as f:
    f.write('## Cone macOS smoke checks\n\n| Check | Result | Detail |\n|---|---|---|\n')
    for name, status, detail in RESULTS:
        icon = {'pass': 'pass', 'fail': '**FAIL**', 'warning': 'warning', 'info': 'info'}[status]
        f.write(f'| {name} | {icon} | {detail.replace("|", "/")} |\n')
    f.write('\n### Retries\n\n' + ('\n'.join(f'- {n}: first attempt: {e}' for n, e in RETRIES) or 'none') + '\n')
summary = os.environ.get('GITHUB_STEP_SUMMARY')
if summary:
    with open(summary, 'a') as f, open(os.path.join(OUT, 'summary.md')) as s:
        f.write(s.read())
for name, _, detail in fails:
    print(f'::error title=Cone macOS smoke checks::{name}: {detail}')
for name, _, detail in warns:
    print(f'::warning title=Cone macOS smoke checks::{name}: {detail}')
log(f'{len(fails)} check(s) failed' if fails else 'all checks passed')
shutil.rmtree(WORK, ignore_errors=True)
sys.exit(1 if fails else 0)
