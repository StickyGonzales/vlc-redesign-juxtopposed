#!/usr/bin/python3
# Smoke checks of a Cone (public) Linux build on a GitHub Ubuntu runner, after every Linux build
# (smoke-linux.yml); the Linux counterpart of win64-smoke.ps1 (redesign/LINUX_SMOKE_NOTES.md).
#   linux-smoke.py --tarball <Cone-*-linux-x86_64.tar.xz> --deb <cone-player_*.deb>
#                  --media <folder with test-h264.mp4, test-hevc.mp4, test.srt> --out <folder>
# Runs under Xvfb, openbox and a D-Bus session with the accessibility bus (smoke-linux.yml starts
# them): the interface's controls are found through AT-SPI (Qt's accessibility, as UI Automation
# on Windows), the input is real X input (xdotool), the playback state comes from VLC's cli
# interface on a Unix socket. Sound goes to VLC's dummy audio output; Qt renders in software.
# Each failed check runs once more; every retry is listed in the summary.
import argparse
import glob
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

import pyatspi

ap = argparse.ArgumentParser()
ap.add_argument('--tarball', required=True)
ap.add_argument('--deb', default='')
ap.add_argument('--skip-deb', action='store_true', help='local runs: no apt-get (the .deb checks need sudo and Ubuntu)')
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


def run(cmd, timeout=60, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)


def xdo(*a):
    return run(['xdotool', *[str(x) for x in a]], timeout=15).stdout.strip()


def shot(name):
    run(['import', '-window', 'root', os.path.join(OUT, name + '.png')], timeout=30)


# ------------------------------------------------------------------ AT-SPI

def _walk(acc, depth=0):
    if acc is None or depth > 60:
        return
    yield acc
    try:
        n = acc.childCount
    except Exception:  # noqa: BLE001
        return
    for i in range(n):
        try:
            yield from _walk(acc.getChildAtIndex(i), depth + 1)
        except Exception:  # noqa: BLE001
            continue


def cone_app():
    desk = pyatspi.Registry.getDesktop(0)
    for i in range(desk.childCount):
        app = desk.getChildAtIndex(i)
        if app is not None and (app.name or '') == 'Cone':
            return app
    return None


def find(name, timeout=0.0, role=None):
    """the first showing element named `name`: (x, y, w, h) on the screen, or None"""
    end = time.time() + timeout
    while True:
        app = cone_app()
        for acc in _walk(app):
            try:
                if acc.name != name or (role and acc.getRoleName() != role):
                    continue
                # Qt does not report the "showing" state of Qt Quick items; a hidden item has no
                # geometry (the call fails), a shown one has its place on the screen
                x, y, w, h = acc.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
                if w > 0 and h > 0:
                    return (x, y, w, h)
            except Exception:  # noqa: BLE001
                continue
        if time.time() >= end:
            return None
        time.sleep(0.25)


# ------------------------------------------------------------------ Cone sessions

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


class Session:
    def __init__(self, exe, video, tag, env=None):
        self.tag = tag
        self.log = os.path.join(OUT, f'cone-{tag}.log')
        if os.path.exists(RC_SOCK):
            os.remove(RC_SOCK)
        a = [exe, '--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-qt-cone-update-check',
             '--aout=adummy', '--input-repeat=50', '--file-logging', f'--logfile={self.log}',
             '--log-verbose=2', '--extraintf=cli', f'--rc-unix={RC_SOCK}', '--rc-fake-tty',
             f'--sub-file={os.path.join(MEDIA, "test.srt")}', video]
        log('start ' + ' '.join(a))
        self.proc = subprocess.Popen(a, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     env=env, start_new_session=True)
        self.win = None

    def window(self):
        end = time.time() + 30
        while time.time() < end:
            if self.proc.poll() is not None:
                raise CheckFailed(f'Cone exited with {self.proc.returncode} before its window appeared')
            for w in xdo('search', '--onlyvisible', '--pid', self.proc.pid).split():
                geo = xdo('getwindowgeometry', w)
                if 'Geometry:' in geo:
                    width = int(geo.split('Geometry:')[1].split('x')[0])
                    if width > 300:
                        self.win = w
                        xdo('windowmove', w, 0, 0)
                        xdo('windowsize', w, 1280, 720)
                        time.sleep(1)
                        return
            time.sleep(0.5)
        raise CheckFailed('no Cone window within 30 s')

    def focus(self):
        xdo('windowactivate', '--sync', self.win)

    def show_bars(self):
        for d in (0, 20, 40, 60):
            xdo('mousemove', 600 + d, 360 + d)
            time.sleep(0.06)

    def stop(self):
        if self.proc.poll() is None:
            os.killpg(self.proc.pid, 9)
            self.proc.wait(10)


def check_window(s):
    def body():
        t = time.time()
        s.window()
        return f'after {time.time() - t:.1f} s'
    return check(f'{s.tag}: main window appears', body)


def check_time(s):
    def body():
        end = time.time() + 15
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
        sel = [l for l in out.splitlines() if l.rstrip().endswith('*') and '-1' not in l]
        if not sel:
            raise CheckFailed('no subtitle track selected: ' + ' | '.join(out.split()))
        return 'selected: ' + sel[0].strip()
    return check(f'{s.tag}: subtitle file loads', body)


def check_seek(s):
    def body():
        s.focus()
        s.show_bars()
        r = find('Progress', 3, role='slider')
        if not r:
            raise CheckFailed('the seek bar ("Progress") is not shown')
        x, y, w, h = r
        length = rc_number('get_length')
        xdo('mousemove', x + int(w * 0.75), y + h // 2)
        time.sleep(0.2)
        xdo('click', 1)
        time.sleep(1.5)
        t = rc_number('get_time')
        want = length * 0.75
        if abs(t - want) > max(3, length * 0.1):
            raise CheckFailed(f'clicked at 75 % of {length} s, the time is {t} s')
        shot(f'{s.tag}-seek')
        return f'clicked at 75 % of {length} s, the time is {t} s'
    return check(f'{s.tag}: seek bar responds', body)


def check_settings(s):
    def body():
        s.focus()
        xdo('key', 'ctrl+p')
        if not find('Search settings', 8):
            shot(f'{s.tag}-settings-fail')
            raise CheckFailed('Ctrl+P: no Settings dialog ("Search settings") within 8 s')
        shot(f'{s.tag}-settings')
        xdo('key', 'Escape')
        end = time.time() + 3
        while find('Search settings'):
            if time.time() > end:
                raise CheckFailed('Escape did not close the Settings dialog')
            time.sleep(0.25)
        return 'Ctrl+P opens the Settings dialog; Escape closes it'
    return check(f'{s.tag}: Settings opens', body)


def is_fullscreen(s):
    geo = xdo('getwindowgeometry', s.win)
    size = geo.split('Geometry:')[1].strip() if 'Geometry:' in geo else ''
    screen = xdo('getdisplaygeometry').replace(' ', 'x')
    return size == screen


def open_menu(s, fullscreen):
    s.focus()
    if fullscreen:
        # the bars hide while the pointer rests over the video; the top edge shows the top bar
        xdo('mousemove', 640, 400)
        time.sleep(0.1)
        xdo('mousemove', 645, 405)
        time.sleep(5)
        xdo('mousemove', 640, 0)
        r = find('Menu', 3, role='push button')
        if not r:
            raise CheckFailed('the top edge did not show the top bar')
        mx, my = r[0] + r[2] // 2, r[1] + r[3] // 2
        for y in range(0, my + 1, 2):
            xdo('mousemove', mx, y)
            time.sleep(0.02)
    else:
        s.show_bars()
        r = find('Menu', 3, role='push button')
        if not r:
            raise CheckFailed('the top bar\'s "..." button is not shown')
        mx, my = r[0] + r[2] // 2, r[1] + r[3] // 2
        xdo('mousemove', mx, my)
    time.sleep(0.6)
    xdo('click', 1)
    row = find('Open File(s)', 2)
    mode = 'fs' if fullscreen else 'win'
    shot(f'{s.tag}-menu-{mode}')
    if not row:
        raise CheckFailed(f'a click on "..." ({mx}, {my}) did not open the main menu')
    time.sleep(1.5)
    if not find('Open File(s)'):
        raise CheckFailed('the main menu opened, then closed by itself')
    xdo('key', 'Escape')
    time.sleep(0.5)
    if find('Open File(s)'):
        raise CheckFailed('Escape did not close the main menu')
    return f'a click on "..." ({mx}, {my}) opened the main menu; Escape closed it'


def check_menu(s):
    check(f'{s.tag}: "..." opens the main menu in a window', lambda: open_menu(s, False))

    def fs():
        s.focus()
        xdo('key', 'f')
        time.sleep(2)
        try:
            if not is_fullscreen(s):
                raise CheckFailed('F did not make the window fullscreen')
            return open_menu(s, True)
        finally:
            if find('Open File(s)'):
                xdo('key', 'Escape')
                time.sleep(0.4)
            if is_fullscreen(s):
                xdo('key', 'f')
                time.sleep(1)
    check(f'{s.tag}: "..." opens the main menu in fullscreen', fs)


def check_speed(s):
    """the playback speed slider (sidebar, Playback tab): a real drag across it while the video
    plays, then Cone must still answer: the interface (AT-SPI), the cli (speed and time) and the
    time moves on. Before the fix the first speed change from the interface made it lock the
    player twice: an assertion build aborts, a release build freezes (FIX_SPEED_FREEZE_NOTES.md)"""
    def body():
        if s.proc.poll() is not None:
            raise CheckFailed(f'Cone is not running (exit code {s.proc.returncode})')
        s.focus()
        s.show_bars()
        g = find('Playback Settings', 5, role='push button')
        if not g:
            raise CheckFailed('the control bar has no "Playback Settings" button')
        xdo('mousemove', g[0] + g[2] // 2, g[1] + g[3] // 2)
        time.sleep(0.3)
        xdo('click', 1)
        r = find('Speed', 5, role='slider')
        shot(f'{s.tag}-speed-sidebar')
        if not r:
            raise CheckFailed('the gear opened no "Speed" slider (sidebar, Playback tab)')
        x, y, w, h = r
        # the track is the top of the element, its step labels are below; the thumb starts at
        # 1x (0.25 to 2: 43 % of the track)
        ty = y + int(0.23 * h)
        xdo('mousemove', x + int(0.43 * w), ty)
        time.sleep(0.15)
        xdo('mousedown', 1)
        moves = 0
        end = time.time() + 4
        try:
            while time.time() < end:
                f = 0.05 + 0.9 * abs(((moves % 40) / 20.0) - 1)
                xdo('mousemove', x + int(f * w), ty)
                time.sleep(0.03)
                moves += 1
            # it ends near 2x: the speed then shows that the drag reached the slider
            xdo('mousemove', x + int(0.9 * w), ty)
            time.sleep(0.15)
        finally:
            xdo('mouseup', 1)
        time.sleep(0.5)
        if s.proc.poll() is not None:
            raise CheckFailed(f'Cone exited during the drag (exit code {s.proc.returncode})')
        t0 = time.time()
        if not find('Play/Pause', 5, role='push button'):
            shot(f'{s.tag}-speed-frozen')
            raise CheckFailed('after the drag the interface does not answer (AT-SPI, 5 s)')
        ui = time.time() - t0
        try:
            out = rc('rate')
            rate = float([l.strip().lstrip('>').strip() for l in out.splitlines()
                          if l.strip().lstrip('>').strip().replace('.', '', 1).isdigit()][0])
            rc('rate 1')
            t1 = rc_number('get_time')
            time.sleep(2)
            t2 = rc_number('get_time')
        except Exception as e:  # noqa: BLE001
            raise CheckFailed(f'after the drag the player does not answer: {e}')
        if rate < 1.5:
            raise CheckFailed(f'the speed is {rate}x after the drag ended near 2x: the drag did not reach the slider')
        # the file repeats (--input-repeat): the time moves on or starts over, it does not stand still
        if t2 == t1:
            raise CheckFailed(f'after the drag the time stands still ({t1} s, then {t2} s two seconds later)')
        shot(f'{s.tag}-speed-after')
        xdo('key', 'Escape')
        time.sleep(0.4)
        return (f'{moves} moves across the slider, released at {rate}x; the interface answers '
                f'({ui:.2f} s); time {t1} s, then {t2} s two seconds later')
    return check(f'{s.tag}: speed slider drag, Cone keeps responding', body)


def quit_cone(s, hevc):
    if s.proc.poll() is not None:
        raise CheckFailed(f'Cone had already exited (exit code {s.proc.returncode})')
    s.focus()
    xdo('key', 'ctrl+q')
    t = time.time()
    try:
        s.proc.wait(10)
    except subprocess.TimeoutExpired:
        raise CheckFailed('Cone still runs 10 s after Ctrl+Q: the quit watchdog did not end it')
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
    return f'ended after {took:.2f} s'


def check_plugins(s):
    def body():
        with open(s.log, errors='replace') as f:
            bad = sorted({l.split('cannot load plug-in', 1)[1].strip()
                          for l in f if 'cannot load plug-in' in l})
        if bad:
            raise CheckFailed('cannot load plug-in: ' + '; '.join(bad))
        return 'no "cannot load plug-in" line'
    return check(f'{s.tag}: every plug-in loads', body)


def check_handoff(s, exe, env):
    """a file opened while Cone runs, as the menu entry and "Open with" start it
    (--started-from-file): it plays in the running window, the second start exits at once"""
    def body():
        other = os.path.join(WORK, 'handoff.mp4')
        if not os.path.exists(other):
            shutil.copy(os.path.join(MEDIA, 'test-h264.mp4'), other)
        t = time.time()
        r = run([exe, '--started-from-file', other], timeout=30, env=env)
        took = time.time() - t
        if r.returncode:
            raise CheckFailed(f'the second start exited with {r.returncode}')
        end = time.time() + 15
        while 'handoff.mp4' not in rc('status'):
            if time.time() > end:
                raise CheckFailed('the running window did not open the file: ' + ' | '.join(rc('status').split()))
            time.sleep(0.5)
        if s.proc.poll() is not None:
            raise CheckFailed('the running Cone exited')
        others = [w for w in xdo('search', '--onlyvisible', '--name', 'handoff.mp4').split()
                  if xdo('getwindowpid', w).strip() != str(s.proc.pid)]
        if others:
            raise CheckFailed(f'another process shows the file in a window: {others}')
        return f'the second start ended after {took:.1f} s; the running window plays handoff.mp4'
    return check(f'{s.tag}: a second start opens the file in the running window', body)


def session(exe, codec, tag, full, env=None):
    video = os.path.join(MEDIA, f'test-{codec}.mp4')
    s = Session(exe, video, tag, env)
    try:
        if not check_window(s):
            return
        time.sleep(2)
        shot(f'{tag}-start')
        check_time(s)
        if full:
            check_subtitle(s)
            check_settings(s)
            check_seek(s)
            check_menu(s)
            check_speed(s)
            if codec == 'h264':
                check_handoff(s, exe, env)

        def retry_quit():
            nonlocal s
            s.stop()
            s = Session(exe, video, tag, env)
            s.window()
            time.sleep(4)
        check(f'{tag}: quit', lambda: quit_cone(s, codec == 'hevc'), retry_quit)
        check_plugins(s)
    finally:
        s.stop()


# ------------------------------------------------------------------ runs

def all_files(root):
    return sorted(os.path.relpath(os.path.join(d, f), root)
                  for d, _, fs in os.walk(root) for f in fs) + \
           sorted(os.path.relpath(os.path.join(d, x), root) + '/'
                  for d, xs, _ in os.walk(root) for x in xs)


log(f'screen {xdo("getdisplaygeometry")}, {run(["lsb_release", "-ds"]).stdout.strip()}')

# 1. the portable tarball
pkg = os.path.join(WORK, 'pkg')
os.makedirs(pkg)
run(['tar', '-xJf', args.tarball, '-C', pkg], timeout=300)
folder = glob.glob(os.path.join(pkg, 'Cone-*'))[0]
home = os.path.join(WORK, 'home')
os.makedirs(home)
env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=os.path.join(home, '.config'),
           XDG_DATA_HOME=os.path.join(home, '.local/share'), XDG_CACHE_HOME=os.path.join(home, '.cache'))
session(os.path.join(folder, 'cone'), 'h264', 'tar-h264', True, env)
session(os.path.join(folder, 'cone'), 'hevc', 'tar-hevc', True, env)


def settings_in_home():
    have = os.path.isfile(os.path.join(home, '.config/Cone/vlc-qt-interface.conf'))
    if not have:
        raise CheckFailed('no ~/.config/Cone/vlc-qt-interface.conf after the session')
    return '~/.config/Cone/vlc-qt-interface.conf written'
check('tarball: settings in ~/.config/Cone', settings_in_home)

def validate(desktop):
    # errors fail; hints (VLC's older MIME type names) are only logged
    v = run(['desktop-file-validate', desktop])
    out = (v.stdout + v.stderr).strip()
    if out:
        log('desktop-file-validate: ' + out)
    errors = [l for l in out.splitlines() if 'error:' in l]
    if v.returncode or errors:
        raise CheckFailed('desktop-file-validate: ' + '; '.join(errors or [out]))


def exec_line(desktop):
    # files from the menu and "Open with" go to the running window (check_handoff)
    lines = [l for l in open(desktop) if l.startswith('Exec=')]
    if not lines or '--started-from-file %U' not in lines[0]:
        raise CheckFailed(f'{os.path.basename(desktop)}: {lines[0].strip() if lines else "no Exec="} lacks --started-from-file')


# 2. install.sh / uninstall.sh for one user (no sudo)
ihome = os.path.join(WORK, 'ihome')
os.makedirs(ihome)
ienv = {'HOME': ihome, 'PATH': '/usr/bin:/bin', 'DISPLAY': os.environ.get('DISPLAY', ''),
        'DBUS_SESSION_BUS_ADDRESS': os.environ.get('DBUS_SESSION_BUS_ADDRESS', '')}
idata = os.path.join(ihome, '.local/share')


def install():
    r = run(['sh', os.path.join(folder, 'install.sh')], env=ienv, timeout=300)
    log(r.stdout + r.stderr)
    if r.returncode:
        raise CheckFailed(f'install.sh exited with {r.returncode}: {r.stderr.strip()}')
    must = [os.path.join(idata, 'cone-player/cone'), os.path.join(ihome, '.local/bin/cone-player'),
            os.path.join(idata, 'applications/cone-player.desktop')]
    must += [os.path.join(idata, f'icons/hicolor/{n}x{n}/apps/cone-player.png') for n in (16, 24, 32, 48, 64, 128, 256)]
    missing = [m for m in must if not os.path.exists(m)]
    if missing:
        raise CheckFailed('missing: ' + ', '.join(os.path.relpath(m, ihome) for m in missing))
    validate(os.path.join(idata, 'applications/cone-player.desktop'))
    exec_line(os.path.join(idata, 'applications/cone-player.desktop'))
    # "Open with": the menu entry is listed for video, audio and subtitle types ...
    with open(os.path.join(idata, 'applications/mimeinfo.cache')) as f:
        cache = f.read()
    for t in ('video/mp4', 'video/x-matroska', 'audio/mpeg', 'application/x-subrip'):
        if not any(l.startswith(t + '=') and 'cone-player.desktop' in l for l in cache.splitlines()):
            raise CheckFailed(f'cone-player.desktop is not offered for {t} (mimeinfo.cache)')
    # ... and never made the default
    apps = os.path.join(ihome, '.config/mimeapps.list')
    if os.path.exists(apps) and 'cone-player' in open(apps).read():
        raise CheckFailed('install.sh wrote a default application (mimeapps.list)')
    return 'program, command, menu entry (valid), icons 16-256 px; offered for video/mp4, audio/mpeg, application/x-subrip; no default set'
installed = check('tarball: install.sh for the current user', install)

if installed:
    session(os.path.join(ihome, '.local/bin/cone-player'), 'h264', 'installed-h264', False, dict(env, HOME=ihome))

    def uninstall():
        r = run(['sh', os.path.join(idata, 'cone-player/uninstall.sh')], env=ienv, timeout=120)
        log(r.stdout + r.stderr)
        if r.returncode:
            raise CheckFailed(f'uninstall.sh exited with {r.returncode}')
        left = [f for f in all_files(ihome) if 'cone-player' in f]
        if left:
            raise CheckFailed('left behind: ' + ', '.join(left))
        return 'nothing named cone-player left in the home folder'
    check('tarball: uninstall.sh', uninstall)

# 3. the .deb, next to Ubuntu's VLC
def deb_install():
    vlc_before = run(['dpkg-query', '-W', '-f=${Version}', 'vlc-bin']).stdout.strip()
    r = run(['sudo', 'apt-get', 'install', '-y', '-q', os.path.abspath(args.deb)], timeout=600)
    log(r.stdout[-3000:] + r.stderr[-2000:])
    if r.returncode:
        raise CheckFailed(f'apt-get install exited with {r.returncode}: {r.stderr.strip()[-300:]}')
    for p in ('/opt/cone-player/cone', '/usr/bin/cone-player', '/usr/share/applications/cone-player.desktop',
              '/usr/share/icons/hicolor/256x256/apps/cone-player.png'):
        if not os.path.exists(p):
            raise CheckFailed(f'{p} missing')
    vlc_after = run(['dpkg-query', '-W', '-f=${Version}', 'vlc-bin']).stdout.strip()
    if vlc_before != vlc_after or not os.path.exists('/usr/bin/vlc'):
        raise CheckFailed(f'VLC changed: vlc-bin {vlc_before} -> {vlc_after}')
    validate('/usr/share/applications/cone-player.desktop')
    exec_line('/usr/share/applications/cone-player.desktop')
    return f'installed into /opt/cone-player with /usr/bin/cone-player; VLC {vlc_before} untouched'
if not args.skip_deb and check('deb: install next to VLC', deb_install):
    session('/usr/bin/cone-player', 'h264', 'deb-h264', False, env)

    def deb_remove():
        r = run(['sudo', 'apt-get', 'remove', '-y', '-q', 'cone-player'], timeout=300)
        log(r.stdout[-2000:] + r.stderr[-1000:])
        if r.returncode:
            raise CheckFailed(f'apt-get remove exited with {r.returncode}')
        left = [p for p in ('/opt/cone-player', '/usr/bin/cone-player', '/usr/share/applications/cone-player.desktop')
                if os.path.exists(p)] + glob.glob('/usr/share/icons/hicolor/*/apps/cone-player.png')
        if left:
            raise CheckFailed('left behind: ' + ', '.join(left))
        if not os.path.exists('/usr/bin/vlc'):
            raise CheckFailed('/usr/bin/vlc is gone')
        return 'removed; /opt/cone-player and its files gone, VLC still installed'
    check('deb: remove', deb_remove)

# ------------------------------------------------------------------ summary
fails = [r for r in RESULTS if r[1] == 'fail']
warns = [r for r in RESULTS if r[1] == 'warning']
with open(os.path.join(OUT, 'summary.md'), 'w') as f:
    f.write('## Cone Linux smoke checks\n\n| Check | Result | Detail |\n|---|---|---|\n')
    for name, status, detail in RESULTS:
        icon = {'pass': 'pass', 'fail': '**FAIL**', 'warning': 'warning'}[status]
        f.write(f'| {name} | {icon} | {detail.replace("|", "/")} |\n')
    f.write('\n### Retries\n\n' + ('\n'.join(f'- {n}: first attempt: {e}' for n, e in RETRIES) or 'none') + '\n')
summary = os.environ.get('GITHUB_STEP_SUMMARY')
if summary:
    with open(summary, 'a') as f, open(os.path.join(OUT, 'summary.md')) as s:
        f.write(s.read())
for name, _, detail in fails:
    print(f'::error title=Cone Linux smoke checks::{name}: {detail}')
for name, _, detail in warns:
    print(f'::warning title=Cone Linux smoke checks::{name}: {detail}')
log(f'{len(fails)} check(s) failed' if fails else 'all checks passed')
shutil.rmtree(WORK, ignore_errors=True)
sys.exit(1 if fails else 0)
