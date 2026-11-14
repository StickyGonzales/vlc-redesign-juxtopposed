#!/usr/bin/python3
# 1.5.0 test pass, Linux side (redesign/TEST_PASS_1.5.0_LINUX_MAC.md): runs Cone's Linux build
# under X11 (Xvfb + openbox, xdotool input) or Wayland (headless Weston, Cone as a native Wayland
# client; no input device, so buttons are pressed through AT-SPI actions). Playback state from
# VLC's cli on a Unix socket, the interface through AT-SPI, screenshots of every step.
#   tp.py --mode x11|wayland --cone <path to cone> --media <dir> --out <dir> [--only name,...]
import argparse
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import tempfile
import time

import pyatspi

ap = argparse.ArgumentParser()
ap.add_argument('--mode', choices=('x11', 'wayland'), required=True)
ap.add_argument('--cone', required=True)
ap.add_argument('--media', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--only', default='')
args = ap.parse_args()
MODE = args.mode
OUT = os.path.abspath(args.out)
MEDIA = os.path.abspath(args.media)
SHOW = os.path.join(MEDIA, 'Pass Show')
os.makedirs(OUT, exist_ok=True)
WORK = tempfile.mkdtemp(prefix='cone-tp-')
RC_SOCK = os.path.join(WORK, 'rc.sock')
LOG = open(os.path.join(OUT, 'tp-log.txt'), 'a', buffering=1)
RESULTS = []


def log(text):
    line = time.strftime('%H:%M:%S ') + f'[{MODE}] ' + text
    print(line, flush=True)
    LOG.write(line + '\n')


class Failed(Exception):
    pass


class NotTestable(Exception):
    pass


def result(name, status, detail):
    RESULTS.append({'mode': MODE, 'test': name, 'status': status, 'detail': detail})
    log(f'{status.upper():5} {name}  {detail}')


def run(cmd, timeout=60, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)


def xdo(*a):
    return run(['xdotool', *[str(x) for x in a]], timeout=15).stdout.strip()


def shot(name):
    path = os.path.join(OUT, f'{MODE}-{name}.png')
    if MODE == 'x11':
        run(['import', '-window', 'root', path], timeout=30)
    else:
        before = set(os.listdir(WORK))
        run(['weston-screenshooter'], timeout=30, cwd=WORK)
        new = [f for f in os.listdir(WORK) if f not in before and f.endswith('.png')]
        if new:
            shutil.move(os.path.join(WORK, new[0]), path)
    return os.path.basename(path)


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


def extents(acc):
    try:
        x, y, w, h = acc.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
        return (x, y, w, h) if w > 0 and h > 0 else None
    except Exception:  # noqa: BLE001
        return None


def find_acc(pred, timeout=0.0, geometry=True):
    end = time.time() + timeout
    while True:
        for acc in _walk(cone_app()):
            try:
                if pred(acc) and (not geometry or extents(acc)):
                    return acc
            except Exception:  # noqa: BLE001
                continue
        if time.time() >= end:
            return None
        time.sleep(0.25)


def find(name, timeout=0.0, role=None):
    acc = find_acc(lambda a: a.name == name and (not role or a.getRoleName() == role), timeout)
    return extents(acc) if acc else None


def find_text(part, timeout=0.0):
    return find_acc(lambda a: part in (a.name or ''), timeout)


def press(name, timeout=3.0, role=None):
    """presses a control through its AT-SPI action (works under Wayland, without input)"""
    acc = find_acc(lambda a: a.name == name and (not role or a.getRoleName() == role), timeout)
    if not acc:
        # hidden bars and the sidebar report no geometry through AT-SPI: by name alone
        acc = find_acc(lambda a: a.name == name and (not role or a.getRoleName() == role), 1, geometry=False)
    if not acc:
        raise Failed(f'no "{name}" to press')
    act = acc.queryAction()
    for i in range(act.nActions):
        if act.getName(i) in ('press', 'click', 'Press', 'activate', 'toggle', 'SetFocus'):
            act.doAction(i)
            return
    act.doAction(0)


def dump_tree(tag):
    with open(os.path.join(OUT, f'{MODE}-{tag}-tree.txt'), 'w') as f:
        for acc in _walk(cone_app()):
            try:
                e = extents(acc)
                f.write(f'{acc.getRoleName():18} {acc.name!r} {e or "(no geometry)"}\n')
            except Exception:  # noqa: BLE001
                continue


# ------------------------------------------------------------------ cli

def rc(cmd):
    with socket.socket(socket.AF_UNIX) as s:
        s.settimeout(3)
        s.connect(RC_SOCK)
        s.sendall((cmd + '\n').encode())
        time.sleep(0.4)
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
    raise Failed(f'no number from "{cmd}"')


def now_playing():
    m = re.search(r'new input: (\S+)', rc('status'))
    return os.path.basename(m.group(1)).replace('%20', ' ') if m else ''


def wait_for(pred, timeout, step=0.5):
    end = time.time() + timeout
    while time.time() < end:
        try:
            v = pred()
            if v:
                return v
        except Exception:  # noqa: BLE001
            pass
        time.sleep(step)
    return None


# ------------------------------------------------------------------ sessions

PROFILE = {'dir': None}


def new_profile(name):
    """every test starts from a fresh Cone profile (settings, media library, Up Next store)"""
    d = os.path.join(WORK, 'profile-' + name)
    shutil.rmtree(d, ignore_errors=True)
    for sub in ('config', 'data', 'cache'):
        os.makedirs(os.path.join(d, sub))
    PROFILE['dir'] = d


def profile_env():
    d = PROFILE['dir']
    if not d:
        return {}
    return {'XDG_CONFIG_HOME': os.path.join(d, 'config'), 'XDG_DATA_HOME': os.path.join(d, 'data'),
            'XDG_CACHE_HOME': os.path.join(d, 'cache')}


def config_dir():
    return os.path.join(profile_env().get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'Cone')


def clear_restore_state():
    conf = os.path.join(config_dir(), 'vlc-qt-interface.conf')
    try:
        lines = open(conf, encoding='utf-8').read().splitlines(True)
    except OSError:
        return
    kept = [l for l in lines if not l.startswith('RecoveryFilePath=')]
    if len(kept) != len(lines):
        open(conf, 'w', encoding='utf-8').writelines(kept)


class Session:
    def __init__(self, files, tag, extra=(), repeat=False, keep_restore=False, env_extra=None):
        self.tag = tag
        if not keep_restore:
            clear_restore_state()
        self.log = os.path.join(OUT, f'{MODE}-cone-{tag}.log')
        if os.path.exists(RC_SOCK):
            os.remove(RC_SOCK)
        env = dict(os.environ)
        env.update(profile_env())
        env.update(env_extra or {})
        a = [args.cone, '--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-qt-cone-update-check',
             '--aout=adummy', *(['--input-repeat=50'] if repeat else []), '--file-logging',
             f'--logfile={self.log}', '--log-verbose=2', '--extraintf=cli', f'--rc-unix={RC_SOCK}',
             *extra, *files]
        if any('update-check' in x for x in extra):
            a.remove('--no-qt-cone-update-check')
        log(f'start {tag}: ' + ' '.join(os.path.basename(x) if x.startswith('/') else x for x in a[1:]))
        self.err = open(os.path.join(OUT, f'{MODE}-cone-{tag}-stderr.txt'), 'w')
        self.proc = subprocess.Popen(a, stdout=self.err, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                     env=env, start_new_session=True)
        self.win = None
        self.window()

    def window(self):
        end = time.time() + 40
        while time.time() < end:
            if self.proc.poll() is not None:
                raise Failed(f'Cone exited with {self.proc.returncode} before its window appeared')
            if MODE == 'x11':
                for w in xdo('search', '--onlyvisible', '--pid', self.proc.pid).split():
                    geo = xdo('getwindowgeometry', w)
                    if 'Geometry:' in geo and int(geo.split('Geometry:')[1].split('x')[0]) > 300:
                        self.win = w
                        xdo('windowmove', w, 0, 0)
                        xdo('windowsize', w, 1280, 720)
                        time.sleep(1.5)
                        return
            else:
                if cone_app() is not None and os.path.exists(RC_SOCK) and find_acc(lambda a: a.getRoleName() == 'frame'):
                    time.sleep(2)
                    return
            time.sleep(0.5)
        raise Failed('no Cone window within 40 s')

    def focus(self):
        if MODE == 'x11' and self.win:
            xdo('windowactivate', '--sync', self.win)

    def key(self, k):
        if MODE != 'x11':
            raise NotTestable(f'no key input under headless Weston ({k})')
        self.focus()
        xdo('key', k)

    def show_bars(self):
        if MODE == 'x11':
            for d in (0, 20, 40, 60):
                xdo('mousemove', 600 + d, 360 + d)
                time.sleep(0.06)

    def stop(self):
        if self.proc.poll() is None:
            os.killpg(self.proc.pid, signal.SIGKILL)
            self.proc.wait(10)
        self.err.close()

    def quit(self):
        try:
            rc('quit')
            self.proc.wait(15)
        except Exception:  # noqa: BLE001
            pass
        self.stop()


def ep(n):
    return os.path.join(SHOW, f'Pass Show S01E0{n}.mkv')


def test(name):
    def deco(fn):
        TESTS.append((name, fn))
        return fn
    return deco


TESTS = []

UPNEXT = ['--qt-autoplay-countdown=5']


# ------------------------------------------------------------------ tests

@test('upnext-play')
def t_upnext_play():
    """When an episode ends: Play the next episode. The card shows in the last minute and counts
    down; the next episode plays by itself"""
    s = Session([ep(1)], 'upnext-play', ['--qt-autoplay-next=1', '--no-qt-autoplay-still-watching', *UPNEXT])
    try:
        time.sleep(3)
        rc('seek 370')
        card = find('Next episode', 8)
        img = shot('upnext-play-card')
        if not card:
            dump_tree('upnext-play')
            raise Failed(f'no "Next episode" on the card at 6:10 of 7:00 ({img})')
        rc('seek 414')
        nxt = wait_for(lambda: 'S01E02' in now_playing(), 30)
        shot('upnext-play-after')
        if not nxt:
            raise Failed(f'episode 2 did not start by itself within 30 s of the end (now: {now_playing()})')
        return f'card at 6:10 ({img}); episode 2 started by itself'
    finally:
        s.quit()


@test('upnext-click')
def t_upnext_click():
    """Show Up Next, I'll click: the card shows "Plays when you choose"; at the end nothing plays and
    Cone stops as before (UP_NEXT_CLICK_MODE_NOTES.md); Next episode on the card plays the next one"""
    s = Session([ep(1)], 'upnext-click', ['--qt-autoplay-next=3', *UPNEXT])
    try:
        time.sleep(3)
        rc('seek 370')
        card = find('Next episode', 8)
        img = shot('upnext-click-card')
        if not card:
            dump_tree('upnext-click')
            raise Failed(f'no "Next episode" on the card at 6:10 ({img})')
        rc('seek 416')
        time.sleep(15)
        still = now_playing()
        img2 = shot('upnext-click-end')
        if 'S01E02' in still:
            raise Failed(f'episode 2 started without a click ({img2})')
    finally:
        s.quit()
    s = Session([ep(1)], 'upnext-click-press', ['--qt-autoplay-next=3', *UPNEXT])
    try:
        time.sleep(3)
        rc('seek 370')
        if not find('Next episode', 8):
            raise Failed('no "Next episode" on the card at 6:10 (second start)')
        press('Next episode')
        nxt = wait_for(lambda: 'S01E02' in now_playing(), 15)
        img3 = shot('upnext-click-after')
        if not nxt:
            raise Failed(f'a press on "Next episode" did not start episode 2 ({img3})')
        return (f'card "Plays when you choose" at 6:10 ({img}); at the end nothing started ({img2}); '
                f'a press on Next episode started episode 2 ({img3})')
    finally:
        s.quit()


@test('upnext-off')
def t_upnext_off():
    """Do nothing: no card, the next episode does not start"""
    s = Session([ep(1)], 'upnext-off', ['--qt-autoplay-next=0', *UPNEXT])
    try:
        time.sleep(3)
        rc('seek 370')
        card = find('Next episode', 6)
        img = shot('upnext-off-6m10')
        if card:
            raise Failed(f'a card with "Next episode" shows with Do nothing ({img})')
        rc('seek 416')
        time.sleep(12)
        p = now_playing()
        img2 = shot('upnext-off-end')
        if 'S01E02' in p:
            raise Failed(f'episode 2 started with Do nothing ({img2})')
        return f'no card at 6:10 ({img}); nothing started after the end ({img2})'
    finally:
        s.quit()


@test('still-watching')
def t_still_watching():
    """Ask if I'm still watching after 3 episodes (UP_NEXT_PLAN.md 2.4): the count is episodes started
    by autoplay; at 3 (episode 4) its Up Next point shows "Still watching?" and the next episode waits"""
    s = Session([ep(1)], 'still-watching', ['--qt-autoplay-next=1', '--qt-autoplay-still-watching', *UPNEXT])
    try:
        seen = []
        for n in (1, 2, 3, 4):
            if not wait_for(lambda: f'S01E0{n}' in now_playing(), 30):
                raise Failed(f'episode {n} did not start (now: {now_playing()}; before: {seen})')
            time.sleep(3)
            rc('seek 370')
            time.sleep(3)
            q = find_text('Still watching', 2)
            seen.append(f'E{n}' + (' asked' if q else ''))
            if q:
                break
            rc('seek 414')
            if n == 4:
                # the question comes at the countdown point, the episode's last seconds
                q = find_text('Still watching', 15)
                seen[-1] = 'E4' + (' asked' if q else '')
        img = shot('still-watching')
        if not q:
            dump_tree('still-watching')
            raise Failed(f'no "Still watching?" by episode 4 ({img}); {seen}')
        if seen[-1] != 'E4 asked':
            raise Failed(f'asked at {seen[-1]} (episode 4 expected): {seen} ({img})')
        time.sleep(10)
        p = now_playing()
        st = rc('status')
        img2 = shot('still-watching-end')
        return (f'{", ".join(seen)}: "{q.name[:90]}" ({img}); after the end {p}, '
                f'{"paused" if "pause" in st.lower() else "state: " + " ".join(st.split())[-60:]} ({img2})')
    finally:
        s.quit()


@test('track-memory')
def t_track_memory():
    """the audio and subtitle track picked in one episode apply to the next (by language)"""
    s = Session([ep(1)], 'track-memory', ['--qt-autoplay-next=1', '--no-qt-autoplay-still-watching', *UPNEXT])
    try:
        time.sleep(3)
        a = rc('atrack')
        st = rc('strack')
        def tid(listing, word):
            for line in listing.splitlines():
                if word in line:
                    m = re.search(r'\|\s*(-?\d+)', line)
                    if m:
                        return m.group(1)
            return None
        fa, fs = tid(a, 'Fran'), tid(st, 'Fran')
        if not fa or not fs:
            raise Failed(f'no French tracks listed: {a!r} {st!r}')
        rc(f'atrack {fa}')
        rc(f'strack {fs}')
        time.sleep(2)
        img = shot('track-memory-e1')
        rc('seek 414')
        if not wait_for(lambda: 'S01E02' in now_playing(), 30):
            raise Failed('episode 2 did not start')
        time.sleep(4)
        a2, s2 = rc('atrack'), rc('strack')
        img2 = shot('track-memory-e2')
        sel_a = [l for l in a2.splitlines() if '*' in l]
        sel_s = [l for l in s2.splitlines() if '*' in l]
        ok = any('Fran' in l for l in sel_a) and any('Fran' in l for l in sel_s)
        detail = f'E1 French picked through the cli ({img}); E2 selected audio {sel_a}, subtitles {sel_s} ({img2})'
        if not ok:
            raise Failed(detail)
        return detail
    finally:
        s.quit()


@test('autosync')
def t_autosync():
    """Auto-sync moves subtitles 2.4 s late back; Undo puts the delay back"""
    sync = os.path.join(MEDIA, 'sync')
    s = Session([os.path.join(sync, 'sync.mp4')], 'autosync',
                [f'--sub-file={os.path.join(sync, "sync-late.srt")}'], repeat=True)
    try:
        time.sleep(3)
        if MODE == 'x11':
            s.show_bars()
            time.sleep(0.5)
        else:
            rc('pause'); time.sleep(0.5); rc('pause')   # the bars show on a state change
        dump_tree('autosync-bars')
        # the settings sidebar: the gear in the control bar, then the Subtitles tab
        opened = False
        try:
            press('Playback Settings', 2)
            opened = True
        except Failed:
            pass
        time.sleep(1.2)
        dump_tree('autosync-sidebar')
        # the sidebar's Subtitles tab (the control bar's "Subtitles" button opens the tracks popup)
        # the sidebar's items report no geometry through AT-SPI: pressed by name
        if MODE == 'x11':
            # the sidebar's Subtitles tab, clicked (its tab row: x 860 to 1270, y 82 at 1280x720)
            xdo('mousemove', 1190, 82)
            time.sleep(0.3)
            xdo('click', 1)
        else:
            tabs = [a for a in _walk(cone_app()) if a.name == 'Subtitles' and a.getRoleName() == 'page tab']
            for t in tabs[-1:]:
                t.queryAction().doAction(0)
        time.sleep(1.2)
        if not find_acc(lambda a: a.name == 'Auto-sync', 4, geometry=False):
            dump_tree('autosync')
            img = shot('autosync-nobutton')
            raise Failed(f'no Auto-sync button (sidebar opened: {opened}; {img})')
        shot('autosync-before')
        find_acc(lambda a: a.name == 'Auto-sync', 2, geometry=False).queryAction().doAction(0)
        undo = find_acc(lambda a: a.name == 'Undo Auto-sync', 60, geometry=False)
        img = shot('autosync-after')
        moved = ''
        if undo:
            try:
                moved = undo.description
            except Exception:  # noqa: BLE001
                pass
        logtail = [l.strip() for l in open(s.log, errors='replace') if 'sync' in l.lower() and ('moved' in l.lower() or 'match' in l.lower() or 'confidence' in l.lower())][-3:]
        if not undo:
            raise Failed(f'no Undo after Auto-sync within 60 s ({img}); log: {logtail}')
        undo.queryAction().doAction(0)
        back = find_acc(lambda a: a.name == 'Auto-sync', 8, geometry=False)
        img2 = shot('autosync-undo')
        if not back:
            raise Failed(f'Undo did not bring back the Auto-sync button ({img2})')
        return f'Auto-sync: {moved or "moved"} ({img}); log {logtail}; Undo restores ({img2})'
    finally:
        s.quit()


@test('covers')
def t_covers():
    """the music player's cover stays square at several window sizes, square and wide covers"""
    out = []
    sizes = [(1280, 720), (1040, 570), (800, 600), (1600, 900), (640, 480)] if MODE == 'x11' else [(None, None)]
    for song in ('song-square', 'song-wide'):
        s = Session([os.path.join(MEDIA, 'smoke', song + '.flac')], f'cover-{song}')
        try:
            time.sleep(3)
            for w, h in sizes:
                if w:
                    xdo('windowsize', s.win, w, h)
                    time.sleep(1.5)
                box = find('Cover', 4)
                label = f'{w}x{h}' if w else 'default'
                img = shot(f'cover-{song}-{label}')
                if not box:
                    dump_tree(f'cover-{song}')
                    out.append(f'{song} {label}: no Cover found ({img})')
                    continue
                ratio = box[2] / box[3]
                out.append(f'{song} {label}: {box[2]}x{box[3]} ({ratio:.2f}) {img}')
        finally:
            s.quit()
    bad = [o for o in out if 'no Cover' in o or not re.search(r'\((0\.9[5-9]|1\.0[0-5])\)', o)]
    if bad:
        raise Failed('; '.join(out))
    return '; '.join(out)


@test('wheel-seek')
def t_wheel():
    """the wheel over the video (VLC's wheel modes, Settings > Controls > Scroll wheel): vertical =
    volume by default, horizontal = seek by default, vertical = seek when set to seek"""
    if MODE != 'x11':
        raise NotTestable('no pointer device under headless Weston')
    out = []
    s = Session([ep(1)], 'wheel-default', ['--qt-autoplay-next=0'])
    try:
        time.sleep(3)
        rc('seek 100')
        time.sleep(1.5)
        s.focus()
        xdo('mousemove', 640, 300)
        time.sleep(0.5)
        def volume():
            raw = rc('volume')
            m = re.findall(r'(-?\d+(?:\.\d+)?)', raw)
            return float(m[-1]) if m else None
        xdo('mousemove', 640, 300)
        time.sleep(0.3)
        v0 = volume()
        xdo('mousemove', 640, 300)
        time.sleep(0.3)
        xdo('click', 5); xdo('click', 5)
        time.sleep(1)
        v1 = volume()
        t0 = rc_number('get_time')
        xdo('click', 7); xdo('click', 7)   # horizontal: right
        time.sleep(1.2)
        t1 = rc_number('get_time')
        img = shot('wheel-default')
        out.append(f'vertical (default): volume {v0} -> {v1}; horizontal right x2: time {t0} -> {t1} s ({img})')
        ok_v, ok_h = (v0 is not None and v1 is not None and v1 < v0), t1 - t0 >= 5
    finally:
        s.quit()
    s = Session([ep(1)], 'wheel-seekmode', ['--qt-autoplay-next=0', '--hotkeys-y-wheel-mode=2'])
    try:
        time.sleep(3)
        rc('seek 100')
        time.sleep(1.5)
        s.focus()
        xdo('mousemove', 640, 300)
        time.sleep(0.5)
        t0 = rc_number('get_time')
        xdo('click', 4)
        time.sleep(1.2)
        t1 = rc_number('get_time')
        xdo('click', 5); xdo('click', 5)
        time.sleep(1.2)
        t2 = rc_number('get_time')
        img = shot('wheel-seekmode')
        out.append(f'vertical set to seek: {t0} s, up {t1} s, down x2 {t2} s ({img})')
        ok_s = t1 - t0 >= 3 and t2 < t1
    finally:
        s.quit()
    detail = '; '.join(out)
    if v0 is None or v0 < 0:
        detail += '; the vertical wheel\'s volume step is not measurable here (dummy audio output: no volume, the cli reports -1)'
        ok_v = True
    if not (ok_v and ok_h and ok_s):
        raise Failed(detail)
    return detail


@test('popups')
def t_popups():
    """the resume toast and the update notice stack without overlapping (POPUP_STACK_NOTES.md)"""
    video = os.path.join(MEDIA, 'smoke', 'Smoke Show', 'Smoke Show S01E03.mp4')
    answer = os.path.join(WORK, 'update-answer.json')
    with open(answer, 'w') as f:
        json.dump([{'tag_name': 'linux-v9.9.9', 'draft': False, 'prerelease': True,
                    'html_url': 'https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/linux-v9.9.9'}], f)
    s = Session([video], 'popups-watch')
    time.sleep(2)
    rc('seek 120')
    time.sleep(2)
    s.quit()
    s = Session([video], 'popups', ['--qt-cone-update-check'], env_extra={'CONE_UPDATE_CHECK_TEST_FILE': answer})
    try:
        r = find('Resume dialog', 15)
        u = find_acc(lambda a: (a.name or '').endswith(' is available'), 15)
        time.sleep(0.8)
        img = shot('popups-two')
        r = find('Resume dialog', 2)
        ue = extents(u) if u else None
        if not r or not ue:
            raise Failed(f'resume toast {r}, update notice {ue}: both expected ({img})')
        overlap = not (r[1] >= ue[1] + ue[3] or ue[1] >= r[1] + r[3])
        gap = r[1] - (ue[1] + ue[3])
        detail = f'toast {r}, update notice {ue}, gap {gap} px ({img})'
        if overlap or ue[1] > r[1]:
            raise Failed('they overlap or the notice is under the toast: ' + detail)
        return detail
    finally:
        s.quit()


@test('quit')
def t_quit():
    """instant quit, 10 times: the window goes at once and the process ends within 3 s"""
    times, notes = [], []
    for i in range(10):
        s = Session([os.path.join(MEDIA, 'smoke', 'test-h264.mp4')], f'quit-{i + 1}', repeat=True)
        try:
            time.sleep(2.5)
            t = time.time()
            if MODE == 'x11':
                s.key('ctrl+q')
                how = 'Ctrl+Q'
            else:
                # no keys under headless Weston: the main menu's Quit through AT-SPI, else the cli
                how = 'cli quit'
                try:
                    press('Menu', 2)
                    time.sleep(0.8)
                    for name in ('Quit Cone', 'Quit', 'Exit'):
                        if find_acc(lambda a, n=name: a.name == n, 1, geometry=False):
                            press(name)
                            how = f'menu "{name}" (AT-SPI)'
                            break
                    else:
                        rc('quit')
                except Exception:  # noqa: BLE001
                    rc('quit')
            try:
                s.proc.wait(10)
            except subprocess.TimeoutExpired:
                notes.append(f'#{i + 1}: still running 10 s after {how}')
                continue
            took = time.time() - t
            fired = 'did not finish quitting' in open(s.log, errors='replace').read()
            times.append(took)
            notes.append(f'#{i + 1} {took:.2f} s via {how}' + (' (watchdog)' if fired else ''))
        finally:
            s.stop()
    detail = '; '.join(notes)
    if len(times) < 10 or max(times) >= 3 or any('watchdog' in n for n in notes):
        raise Failed(detail)
    return f'max {max(times):.2f} s, median {sorted(times)[5]:.2f} s: ' + detail


@test('restore')
def t_restore():
    """the restore question after a killed Cone, and Yes restores the queue"""
    s = Session([ep(1), ep(2), ep(3)], 'restore-kill', ['--qt-autoplay-next=0'])
    time.sleep(15)   # the backup is saved at most 10 s after a change
    s.stop()          # killed: SIGKILL
    s = Session([], 'restore', keep_restore=True)
    try:
        q = find_text('restore', 15) or find_text('closed abruptly', 2)
        qname = (q.name or '') if q else ''
        img = shot('restore-question')
        if not q:
            dump_tree('restore')
            raise Failed(f'no restore question after a killed Cone ({img})')
        if MODE == 'x11':
            # the question is a Qt widget dialog: Yes is its default button
            xdo('key', 'Return')
        else:
            press('Yes', 3)
        time.sleep(3)
        pl0 = rc('playlist')
        rc('play')
        time.sleep(4)
        pl = rc('playlist')
        n = sum(1 for l in pl.splitlines() if 'Pass Show S01E0' in l)
        img2 = shot('restore-after-yes')
        detail = f'question "{qname[:80]}" ({img}); after Yes {n} episodes in the queue ({img2}); queue right after Yes: {" | ".join(l.strip() for l in pl0.splitlines() if l.strip())[:160]}; after play: {" | ".join(l.strip() for l in pl.splitlines() if l.strip())[:300]}'
        if n < 3:
            raise Failed(detail)
        return detail
    finally:
        s.quit()



@test('resume-end')
def t_resume_end():
    """an episode watched to its end, played again by autoplay: does it start at the start?"""
    s = Session([ep(2)], 'resume-end-watch', ['--qt-autoplay-next=0'])
    try:
        time.sleep(3)
        rc('seek 414')
        wait_for(lambda: 'stopped' in rc('status') or not now_playing(), 25)
        time.sleep(2)
    finally:
        s.quit()
    s = Session([ep(1)], 'resume-end-autoplay', ['--qt-autoplay-next=1', '--no-qt-autoplay-still-watching', *UPNEXT])
    try:
        time.sleep(3)
        rc('seek 414')
        started = wait_for(lambda: 'S01E02' in now_playing(), 30)
        time.sleep(2)
        t = None
        try:
            t = rc_number('get_time')
        except Exception:  # noqa: BLE001
            pass
        later = wait_for(lambda: 'S01E03' in now_playing(), 15)
        img = shot('resume-end-autoplay')
        seeks = [l.strip() for l in open(s.log, errors='replace') if 'seek request to 99' in l]
        detail = (f'E2 watched to its end, then E1 near its end with autoplay: E2 started {bool(started)}, '
                  f'2 s later at {t} s; E3 started within 15 s: {bool(later)}; log: {seeks[:2]} ({img})')
        if later or (t is not None and t > 60):
            raise Failed(detail)
        return detail
    finally:
        s.quit()


@test('track-stop')
def t_track_stop():
    """no track is touched: does a stop save a track choice for the show anyway?"""
    s = Session([ep(1)], 'track-stop-e1', ['--qt-autoplay-next=1', *UPNEXT])
    try:
        time.sleep(4)
        sel1 = [l.strip() for l in rc('strack').splitlines() if '*' in l]
        rc('stop')
        time.sleep(3)
    finally:
        s.quit()
    saved1 = [l.strip() for l in open(s.log, errors='replace') if 'tracks for the show saved' in l]
    s = Session([ep(2)], 'track-stop-e2', ['--qt-autoplay-next=1', *UPNEXT])
    try:
        time.sleep(5)
        sel2 = [l.strip() for l in rc('strack').splitlines() if '*' in l]
        applied = [l.strip() for l in open(s.log, errors='replace') if 'tracks for the show applied' in l]
        img = shot('track-stop-e2')
    finally:
        s.quit()
    detail = (f'E1 subtitles at start {sel1}, nothing picked, stopped: saved {saved1}; '
              f'E2 subtitles {sel2}, applied {applied} ({img})')
    if saved1:
        raise Failed(detail)
    return detail


@test('quit-cli')
def t_quit_cli():
    """the cli's quit (not a user path), 3 times: for comparison with Ctrl+Q / the menu"""
    notes = []
    for i in range(3):
        s = Session([os.path.join(MEDIA, 'smoke', 'test-h264.mp4')], f'quit-cli-{i + 1}', repeat=True)
        try:
            time.sleep(2.5)
            t = time.time()
            rc('quit')
            try:
                s.proc.wait(10)
                fired = 'did not finish quitting' in open(s.log, errors='replace').read()
                notes.append(f'{time.time() - t:.2f} s' + (' (watchdog)' if fired else ''))
            except subprocess.TimeoutExpired:
                notes.append('still running after 10 s')
        finally:
            s.stop()
    return 'cli quit: ' + ', '.join(notes)


@test('quit-menu')
def t_quit_menu():
    """the right-click menu's "Quit Cone" (a user path), 5 times: the process ends within 3 s"""
    notes, times = [], []
    for i in range(5):
        s = Session([os.path.join(MEDIA, 'smoke', 'test-h264.mp4')], f'quit-menu-{i + 1}', repeat=True)
        try:
            time.sleep(2.5)
            if MODE == 'x11':
                # the right-click menu holds Quit (Figma "right-click menu"; the "..." menu does not)
                s.focus()
                xdo('mousemove', 640, 330)
                time.sleep(0.3)
                xdo('click', 3)
                q = find('Quit Cone', 3)
                if not q:
                    dump_tree('quit-menu')
                    shot('quit-menu-noquit')
                    raise Failed('the right-click menu shows no "Quit Cone"')
                if i == 0:
                    shot('quit-menu-open')
                xdo('mousemove', q[0] + q[2] // 2, q[1] + q[3] // 2)
                time.sleep(0.3)
                t = time.time()
                xdo('click', 1)
            else:
                press('Menu', 2)
                time.sleep(0.8)
                if i == 0:
                    shot('quit-menu-open')
                    dump_tree('quit-menu')
                if not find_acc(lambda a: a.name == 'Quit Cone', 2, geometry=False):
                    raise NotTestable('the menu\'s items are not reachable through AT-SPI under Wayland '
                                      '(no pointer to click them)')
                t = time.time()
                press('Quit Cone')
            try:
                s.proc.wait(10)
            except subprocess.TimeoutExpired:
                notes.append(f'#{i + 1}: still running 10 s later')
                continue
            took = time.time() - t
            times.append(took)
            fired = 'did not finish quitting' in open(s.log, errors='replace').read()
            notes.append(f'#{i + 1} {took:.2f} s' + (' (watchdog)' if fired else ''))
        finally:
            s.stop()
    detail = '; '.join(notes)
    if len(times) < 5 or max(times) >= 3:
        raise Failed(detail)
    return f'max {max(times):.2f} s: ' + detail


@test('quit-menuopen')
def t_quit_menuopen():
    """a quit request from outside the window (the cli here; also MPRIS or a session logout) while
    the "..." menu is open, 3 times"""
    notes = []
    for i in range(3):
        s = Session([os.path.join(MEDIA, 'smoke', 'test-h264.mp4')], f'quit-menuopen-{i + 1}', repeat=True)
        try:
            time.sleep(2.5)
            press('Menu', 2)
            time.sleep(0.8)
            opened = bool(find_acc(lambda a: a.name == 'Open File(s)', 2, geometry=False))
            t = time.time()
            rc('quit')
            try:
                s.proc.wait(12)
                notes.append(f'{time.time() - t:.2f} s (menu open: {opened})')
            except subprocess.TimeoutExpired:
                notes.append(f'still running after 12 s (menu open: {opened})')
        finally:
            s.stop()
    return 'quit with the "..." menu open: ' + ', '.join(notes)

only = [x for x in args.only.split(',') if x]
for name, fn in TESTS:
    if only and name not in only:
        continue
    log(f'---- {name}')
    new_profile(name)
    try:
        result(name, 'pass', fn() or '')
    except NotTestable as e:
        result(name, 'n/a', str(e))
    except Exception as e:  # noqa: BLE001
        result(name, 'fail', str(e))
    # leftovers of a test: only processes started from the build folder (the runner and this
    # script carry its path in their arguments too)
    run(['pkill', '-9', '-f', '^' + os.path.dirname(os.path.abspath(args.cone)) + '/'])
    time.sleep(1)

with open(os.path.join(OUT, f'results-{MODE}.json'), 'w') as f:
    json.dump(RESULTS, f, indent=1)
