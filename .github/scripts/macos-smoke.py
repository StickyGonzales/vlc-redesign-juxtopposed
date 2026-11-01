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
from AppKit import NSApplicationActivateIgnoringOtherApps, NSRunningApplication
from ApplicationServices import (AXIsProcessTrusted, AXUIElementCopyAttributeValue,
                                 AXUIElementCreateApplication)
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


def check(name, body, retry=None):
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
            RESULTS.append((name, 'fail', str(e)))
            log(f'FAIL  {name}  {e}')
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


def ax_names(pid, limit=4000):
    """every accessibility name in the app's tree (title, description, value)"""
    names = set()
    stack = [AXUIElementCreateApplication(pid)]
    seen = 0
    while stack and seen < limit:
        el = stack.pop()
        seen += 1
        for attr in ('AXTitle', 'AXDescription', 'AXValue', 'AXPlaceholderValue'):
            err, v = AXUIElementCopyAttributeValue(el, attr, None)
            if err == 0 and isinstance(v, str) and v:
                names.add(v)
        err, kids = AXUIElementCopyAttributeValue(el, 'AXChildren', None)
        if err == 0 and kids:
            stack.extend(kids)
    return names


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
        data = b''
        try:
            while True:
                chunk = s.recv(65536)
                if not chunk:
                    break
                data += chunk
                if len(chunk) < 65536:
                    break
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

class Session:
    def __init__(self, exe, video, tag):
        self.tag = tag
        self.log = os.path.join(OUT, f'cone-{tag}.log')
        if os.path.exists(RC_SOCK):
            os.remove(RC_SOCK)
        a = [exe, '--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-qt-cone-update-check',
             '--aout=adummy', '--file-logging', f'--logfile={self.log}', '--log-verbose=2',
             '--extraintf=cli', f'--rc-unix={RC_SOCK}', '--rc-fake-tty',
             f'--sub-file={os.path.join(MEDIA, "test.srt")}', video]
        log('start ' + ' '.join(a))
        self.err = open(os.path.join(OUT, f'cone-{tag}-stderr.txt'), 'w')
        self.proc = subprocess.Popen(a, stdout=self.err, stderr=subprocess.STDOUT,
                                     start_new_session=True)
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


def check_time(s):
    def body():
        end = time.time() + 20
        while True:
            try:
                t1 = rc_number('get_time')
                break
            except Exception:  # noqa: BLE001 (the cli interface starts with the playlist)
                if time.time() > end:
                    raise
                time.sleep(0.5)
        time.sleep(3)
        t2 = rc_number('get_time')
        if t2 <= t1:
            raise CheckFailed(f'time {t1} s, then {t2} s three seconds later')
        return f'{t1} s, then {t2} s three seconds later'
    return check(f'{s.tag}: playback time advances', body)


def check_subtitle(s):
    def body():
        out = rc('strack')
        sel = [ln for ln in out.splitlines() if ln.rstrip().endswith('*') and '-1' not in ln]
        if not sel:
            raise CheckFailed('no subtitle track selected: ' + ' | '.join(out.split()))
        return 'selected: ' + sel[0].strip()
    return check(f'{s.tag}: subtitle file loads', body)


def check_settings(s):
    trusted = bool(AXIsProcessTrusted())

    def body():
        s.focus()
        before = shot(f'{s.tag}-settings-before')
        key(KEY_P, command=True)
        if trusted:
            end = time.time() + 8
            while 'Search settings' not in ax_names(s.proc.pid):
                if time.time() > end:
                    shot(f'{s.tag}-settings-fail')
                    raise CheckFailed('Cmd+P: no Settings dialog ("Search settings") within 8 s')
                time.sleep(0.4)
            shot(f'{s.tag}-settings')
            key(KEY_ESCAPE)
            end = time.time() + 5
            while 'Search settings' in ax_names(s.proc.pid):
                if time.time() > end:
                    raise CheckFailed('Escape did not close the Settings dialog')
                time.sleep(0.3)
            return 'Cmd+P opens the Settings dialog ("Search settings" in the accessibility tree); Escape closes it'
        # no accessibility access: the dialog covers the middle of the window
        time.sleep(2)
        opened = shot(f'{s.tag}-settings')
        d_open = region_diff(before, opened, s.win[1:])
        key(KEY_ESCAPE)
        time.sleep(1.5)
        closed = shot(f'{s.tag}-settings-closed')
        d_closed = region_diff(opened, closed, s.win[1:])
        if d_open < 25:
            raise CheckFailed(f'Cmd+P: the window did not change (difference {d_open:.1f})')
        if d_closed < 25:
            raise CheckFailed(f'Escape: the window did not change back (difference {d_closed:.1f})')
        return (f'Cmd+P changes the middle of the window (difference {d_open:.1f}), Escape changes it '
                f'back ({d_closed:.1f}); screenshots settings / settings-closed (no accessibility access '
                'on this runner)')
    return check(f'{s.tag}: Settings opens', body)


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
        shot(f'{tag}-start')
        check_time(s)
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
