# Smoke checks of a Cone Player Windows build on a GitHub Windows runner (redesign/CI_SMOKE_NOTES.md).
#
#   powershell -File win64-smoke.ps1 -ZipDir <unpacked portable zip> -Installer <setup .exe> -Media <dir> -Out <dir>
#
# Checks, each with one retry when it fails (the summary lists every retry):
#   portable zip, Up Next: a click on the card's "Next episode" leaves the next episode playing.
#   portable zip, H.264 and HEVC: the main window appears, the playback time advances, the
#   subtitle file loads, a click on the seek bar moves playback, Settings opens (Ctrl+P), quitting
#   (Ctrl+Q) ends the process; H.264: within 3 s and without the quit watchdog; HEVC: a quit the
#   watchdog ends is a warning (known HEVC quit stall, STATUS.md), only a process that outlives the
#   watchdog fails; the settings land in the zip's portable folder, none in %APPDATA%\Cone.
#   portable zip, notices: a watched file opened with the update notice forced on shows the resume
#   toast and the update notice stacked, not overlapping; the notice takes the toast's place after it.
#   restore question (zip): Ctrl+Q while Cone asks to restore the playlist keeps it for the next
#   start, which asks again; No clears it.
#   cast discovery (zip and installed): the microdns and upnp plug-ins load and their renderer
#   probes are in the plug-in cache (vlc-cache-gen on a copy for the zip, the installer's own cache).
#   installer: a silent install, the installed Cone plays, silent reinstalls keep or leave out the
#   desktop shortcut as it is, a silent uninstall removes it.
# Software rendering on the runner: no picture quality or sound checks.
# Input goes through UI Automation and Win32 (like redesign/tools/perf/vlcperf.ps1); playback state
# comes from VLC's cli interface on 127.0.0.1. Results: <Out>\summary.md, <Out>\smoke-log.txt,
# screenshots and Cone's logs; the exit code is 1 when a check failed.
param(
    [Parameter(Mandatory)][string]$ZipDir,
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][string]$Media,
    [Parameter(Mandatory)][string]$Out
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Out | Out-Null
$LogFile = Join-Path $Out 'smoke-log.txt'
$RcPort = 42130
$WatchdogSeconds = 5
# a process the watchdog has not ended by then never will be
$QuitLimitSeconds = $WatchdogSeconds + 5

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RdSmoke {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, int d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint mapType);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] public struct CURSORINFO { public int cbSize; public int flags; public IntPtr hCursor; public int x; public int y; }
  [DllImport("user32.dll")] static extern bool GetCursorInfo(ref CURSORINFO ci);
  [DllImport("user32.dll")] static extern IntPtr GetCursor();
  // the cursor the window under the pointer set (its handle, none for a hidden cursor). The
  // CURSOR_SHOWING flag is not used: a runner has no mouse, so Windows never shows the pointer
  // there, but it still keeps the cursor the app set
  public static IntPtr ScreenCursor(out int flags) {
    var ci = new CURSORINFO(); ci.cbSize = Marshal.SizeOf(typeof(CURSORINFO));
    flags = -1;
    if (!GetCursorInfo(ref ci)) return IntPtr.Zero;
    flags = ci.flags;
    return ci.hCursor;
  }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(POINT p);
  // the cursor set by the thread of the window under the screen point (the interface, or the
  // video output's own window), read through that thread's input state; the window's class goes
  // to cls for the check's message
  public static IntPtr CursorAt(int x, int y, out string cls) {
    POINT p; p.X = x; p.Y = y;
    IntPtr h = WindowFromPoint(p);
    StringBuilder sb = new StringBuilder(256); GetClassName(h, sb, sb.Capacity); cls = sb.ToString();
    uint t = GetWindowThreadProcessId(h, IntPtr.Zero);
    uint me = GetCurrentThreadId();
    if (t == 0 || !AttachThreadInput(me, t, true)) return IntPtr.Zero;
    try { return GetCursor(); } finally { AttachThreadInput(me, t, false); }
  }
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);

  // the process's main Qt window: visible, at least 300 px wide, the largest one
  public static IntPtr FindMainWindow(int pid) {
    IntPtr best = IntPtr.Zero; long bestArea = 0;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != (uint)pid || !IsWindowVisible(h)) return true;
      StringBuilder sb = new StringBuilder(256); GetClassName(h, sb, sb.Capacity);
      if (!sb.ToString().StartsWith("Qt")) return true;
      RECT r; GetWindowRect(h, out r);
      long w = r.Right - r.Left, ht = r.Bottom - r.Top;
      if (w < 300 || w * ht <= bestArea) return true;
      best = h; bestArea = w * ht;
      return true;
    }, IntPtr.Zero);
    return best;
  }
  public static bool Visible(IntPtr h) { return IsWindowVisible(h); }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  // the process's visible top-level window whose title contains `part` (a Qt dialog's title is its
  // window text), or zero
  public static IntPtr FindWindowByTitle(int pid, string part) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != (uint)pid || !IsWindowVisible(h)) return true;
      StringBuilder sb = new StringBuilder(512); GetWindowText(h, sb, sb.Capacity);
      if (sb.ToString().IndexOf(part, StringComparison.OrdinalIgnoreCase) < 0) return true;
      found = h;
      return false;
    }, IntPtr.Zero);
    return found;
  }
  // every top-level window of the process: "class 'title' visible", for the log when a check fails
  public static string ListWindows(int pid) {
    StringBuilder all = new StringBuilder();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != (uint)pid) return true;
      StringBuilder c = new StringBuilder(256); GetClassName(h, c, c.Capacity);
      StringBuilder t = new StringBuilder(512); GetWindowText(h, t, t.Capacity);
      all.Append(c).Append(" '").Append(t).Append("' ").Append(IsWindowVisible(h) ? "visible" : "hidden").Append("; ");
      return true;
    }, IntPtr.Zero);
    return all.ToString();
  }
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
}
"@
[RdSmoke]::SetProcessDPIAware() | Out-Null

# ---------------------------------------------------------------- results

$script:Results = New-Object System.Collections.ArrayList
$script:Retries = New-Object System.Collections.ArrayList
function Log([string]$text) {
    $line = "$(Get-Date -Format 'HH:mm:ss.fff') $text"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}
function Add-Result([string]$name, [string]$status, [string]$detail) {
    [void]$script:Results.Add([pscustomobject]@{ Check = $name; Status = $status; Detail = $detail })
    $mark = @{ pass = 'PASS'; warn = 'WARN'; fail = 'FAIL' }[$status]
    Log "$mark  $name  $detail"
}
# runs a check; a check that throws runs once more ($retry, or the same body), and the retry is
# listed in the summary. The check returns its detail text, or @('warn', text) for a warning
function Check([string]$name, [scriptblock]$body, [scriptblock]$retry = $null) {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $r = if ($attempt -eq 2 -and $retry) { & $retry } else { & $body }
            if ($attempt -eq 2) { [void]$script:Retries.Add("$name (first attempt: $script:FirstError)") }
            if ($r -is [array] -and $r.Count -eq 2 -and $r[0] -eq 'warn') { Add-Result $name 'warn' $r[1] }
            else { Add-Result $name 'pass' "$r" }
            return $true
        } catch {
            $msg = $_.Exception.Message
            if ($attempt -eq 1) {
                $script:FirstError = $msg
                Log "retry  $name  first attempt failed: $msg"
                Start-Sleep -Milliseconds 1500
            } else {
                [void]$script:Retries.Add("$name (failed twice)")
                Add-Result $name 'fail' $msg
                return $false
            }
        }
    }
}

# ---------------------------------------------------------------- helpers

function Shot([string]$name) {
    try {
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
        $bmp.Save((Join-Path $Out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
    } catch { Log "screenshot $name failed: $($_.Exception.Message)" }
}
function Focus-Window($h) {
    for ($i = 0; $i -lt 5; $i++) {
        $fg = [RdSmoke]::GetForegroundWindow()
        if ($fg -eq $h) { return }
        # a process may take the foreground only while it owns the last input: a lone Alt press
        # (VK_MENU down, up) gives it that, then the thread attach lets SetForegroundWindow work
        [RdSmoke]::keybd_event(0x12, 0, 0, [IntPtr]::Zero); [RdSmoke]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
        $t1 = [RdSmoke]::GetWindowThreadProcessId($fg, [IntPtr]::Zero); $t2 = [RdSmoke]::GetCurrentThreadId()
        [RdSmoke]::AttachThreadInput($t2, $t1, $true) | Out-Null
        [RdSmoke]::ShowWindow($h, 5) | Out-Null
        [RdSmoke]::BringWindowToTop($h) | Out-Null
        [RdSmoke]::SetForegroundWindow($h) | Out-Null
        [RdSmoke]::AttachThreadInput($t2, $t1, $false) | Out-Null
        Start-Sleep -Milliseconds 300
    }
    if ([RdSmoke]::GetForegroundWindow() -ne $h) { throw 'Cone is not the foreground window, no input sent' }
}
# a key with modifiers: virtual-key codes, e.g. Keys @(0x11, 0x50) = Ctrl+P. With the hardware scan
# code, as a keyboard sends it: Qt's shortcuts (Ctrl+P) ignore a key event without one
function Keys([byte[]]$vks) {
    foreach ($k in $vks) { [RdSmoke]::keybd_event($k, [byte][RdSmoke]::MapVirtualKey($k, 0), 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 30 }
    [array]::Reverse($vks)
    foreach ($k in $vks) { [RdSmoke]::keybd_event($k, [byte][RdSmoke]::MapVirtualKey($k, 0), 2, [IntPtr]::Zero); Start-Sleep -Milliseconds 30 }
}
function Click([int]$x, [int]$y) {
    [RdSmoke]::SetCursorPos($x, $y) | Out-Null; Start-Sleep -Milliseconds 80
    [RdSmoke]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 60
    [RdSmoke]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
}
function Rc([string]$cmd) {
    $c = New-Object Net.Sockets.TcpClient
    $c.Connect('127.0.0.1', $RcPort)
    try {
        $s = $c.GetStream(); $s.ReadTimeout = 2000
        $w = New-Object IO.StreamWriter($s); $w.NewLine = "`n"; $w.AutoFlush = $true
        Start-Sleep -Milliseconds 250
        $buf = New-Object byte[] 65536
        while ($s.DataAvailable) { $null = $s.Read($buf, 0, $buf.Length) }
        $w.WriteLine($cmd)
        Start-Sleep -Milliseconds 500
        $text = ''
        while ($s.DataAvailable) { $n = $s.Read($buf, 0, $buf.Length); $text += [Text.Encoding]::UTF8.GetString($buf, 0, $n) }
        return $text
    } finally { $c.Close() }
}
function Rc-Number([string]$cmd) {
    $t = Rc $cmd
    # the cli may put its "> " prompt before the answer
    $m = [regex]::Match($t, '(?m)^[>\s]*(\d+)\s*$')
    if (-not $m.Success) { throw "cli '$cmd' gave no number: '$($t.Trim())'" }
    return [int]$m.Groups[1].Value
}
function Wait-Rc([int]$seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $seconds) {
        try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $RcPort); $c.Close(); return } catch { Start-Sleep -Milliseconds 300 }
    }
    throw "Cone's cli interface did not open port $RcPort within $seconds s"
}
# an element of Cone's window by its accessible name, shown on screen (a closed dialog's items can
# stay in the tree, off screen)
function Uia-Find($hwnd, [string]$name, [int]$timeoutMs) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        foreach ($e in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
            try { if (-not $e.Current.IsOffscreen -and $e.Current.BoundingRectangle.Width -gt 0) { return $e } } catch {}
        }
        Start-Sleep -Milliseconds 250
    } while ($sw.ElapsedMilliseconds -lt $timeoutMs)
    return $null
}
function Show-Bars($hwnd) {
    # the bars show while the pointer moves over the window (Decision 30)
    $r = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($hwnd, [ref]$r) | Out-Null
    $cx = [int](($r.Left + $r.Right) / 2); $cy = [int](($r.Top + $r.Bottom) / 2)
    foreach ($d in 0, 20, 40, 60) { [RdSmoke]::SetCursorPos($cx + $d, $cy + $d) | Out-Null; Start-Sleep -Milliseconds 60 }
}

# the pixels of a cursor that are not transparent: 0 for none or Qt's blank cursor
function Cursor-Pixels([IntPtr]$h) {
    if ($h -eq [IntPtr]::Zero) { return 0 }
    $icon = [System.Drawing.Icon]::FromHandle($h)
    $bmp = $icon.ToBitmap()
    try {
        $n = 0
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            for ($y = 0; $y -lt $bmp.Height; $y++) { if ($bmp.GetPixel($x, $y).A -gt 0) { $n++ } }
        }
        return $n
    } finally { $bmp.Dispose(); $icon.Dispose() }
}
# the pointer over Cone at the screen point x, y: the pixels of the cursor set by the window under
# it (its thread's cursor). A runner has no mouse: Windows suppresses the pointer there (flags 2,
# no cursor on the screen), but the cursor the app set is kept. The screen cursor, the flags and
# the window's class go into $script:PointerInfo for the check's message
$script:PointerInfo = ''
function Pointer-Pixels([int]$x, [int]$y) {
    $flags = 0; $cls = ''
    $screen = Cursor-Pixels ([RdSmoke]::ScreenCursor([ref]$flags))
    $n = Cursor-Pixels ([RdSmoke]::CursorAt($x, $y, [ref]$cls))
    $script:PointerInfo = "cursor of the window under the pointer ($cls) $n px; screen cursor $screen px, flags $flags"
    return $n
}

# the pointer over the playing video: hidden with the bars after about 3 s in a window (VLC's
# mouse-hide-timeout in fullscreen), shown again on a move, kept while paused
# (redesign/FIX_CURSOR_HIDE_NOTES.md)
function Check-Pointer($s) {
    # near the start, so the clip (30 s, repeated) does not start over during the three checks
    Rc 'seek 1' | Out-Null
    Start-Sleep -Seconds 1
    $mustPlay = {
        if ((Rc 'status') -notmatch '\( play state:') { throw 'the video is not playing (cli status), so the pointer may stay' }
    }
    $still = {
        param([int]$x, [int]$y)
        foreach ($d in 0, 10, 20, 30) { [RdSmoke]::SetCursorPos($x + $d, $y + $d) | Out-Null; Start-Sleep -Milliseconds 60 }
        Start-Sleep -Milliseconds 600
        $moved = Pointer-Pixels ($x + 30) ($y + 30)
        Start-Sleep -Milliseconds 4500
        return @($moved, (Pointer-Pixels ($x + 30) ($y + 30)))
    }
    Check "$($s.tag): pointer hides while playing (window)" {
        & $mustPlay
        Focus-Window $s.hwnd
        $r = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$r) | Out-Null
        $cx = [int](($r.Left + $r.Right) / 2); $cy = [int](($r.Top + $r.Bottom) / 2)
        $moved, $after = & $still $cx $cy
        if ($moved -eq 0) { throw "the pointer is hidden right after a move ($script:PointerInfo)" }
        if ($after -ne 0) { throw "the pointer still shows ($after pixels) 5 s after the last move while playing ($script:PointerInfo)" }
        foreach ($d in 40, 50, 60) { [RdSmoke]::SetCursorPos($cx + $d, $cy + 30) | Out-Null; Start-Sleep -Milliseconds 60 }
        Start-Sleep -Milliseconds 600
        $again = Pointer-Pixels ($cx + 60) ($cy + 30)
        if ($again -eq 0) { throw "the pointer did not show again on a move ($script:PointerInfo)" }
        "shown after a move ($moved pixels), hidden 4.5 s later, shown again on a move ($again pixels)"
    } | Out-Null
    Check "$($s.tag): pointer stays while paused" {
        Focus-Window $s.hwnd
        $r = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$r) | Out-Null
        Rc 'pause' | Out-Null
        try {
            $moved, $after = & $still ([int](($r.Left + $r.Right) / 2)) ([int](($r.Top + $r.Bottom) / 2))
            if ($after -eq 0) { throw "the pointer hid while the video was paused ($script:PointerInfo)" }
            "still shown ($after pixels) 4.5 s after the last move while paused"
        } finally {
            # 'pause' toggles; the cli's 'play' does not resume a paused player (vlc_player_Start
            # returns at once on a started player)
            Rc 'pause' | Out-Null
            Start-Sleep -Seconds 1
        }
    } | Out-Null
    Check "$($s.tag): pointer hides while playing (fullscreen)" {
        & $mustPlay
        Focus-Window $s.hwnd
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        try {
            Keys @(0x46)   # F: fullscreen
            Start-Sleep -Seconds 2
            $moved, $after = & $still ([int]($b.Left + $b.Width / 2)) ([int]($b.Top + $b.Height / 2))
            if ($moved -eq 0) { throw "the pointer is hidden right after a move ($script:PointerInfo)" }
            if ($after -ne 0) { throw "the pointer still shows ($after pixels) in fullscreen 4.5 s after the last move ($script:PointerInfo)" }
            'hidden in fullscreen 4.5 s after the last move'
        } finally {
            $w = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$w) | Out-Null
            if ($w.Left -le $b.Left -and $w.Top -le $b.Top -and $w.Right -ge $b.Right -and $w.Bottom -ge $b.Bottom) {
                Keys @(0x46)
                Start-Sleep -Seconds 1
            }
        }
    } | Out-Null
}

# ---------------------------------------------------------------- one Cone session

# starts Cone with a video and its subtitles; returns the process, its window and its log file
# $firstStart: Cone's first start (the onboarding), as on a fresh install
function Start-Cone([string]$exe, [string]$video, [string]$subs, [string]$tag, [bool]$firstStart = $false) {
    $log = Join-Path $Out "cone-$tag.log"
    Remove-Item $log -ErrorAction SilentlyContinue
    $privacy = if ($firstStart) { '--qt-privacy-ask' } else { '--no-qt-privacy-ask' }
    $a = @($privacy, '--no-qt-video-autoresize', '--input-repeat=50',
           '--file-logging', "--logfile=`"$log`"", '--log-verbose=2',
           '--extraintf=cli', "--rc-host=127.0.0.1:$RcPort", '--rc-quiet',
           "--sub-file=`"$subs`"", "`"$video`"")
    Log "start $exe $($a -join ' ')"
    $p = Start-Process -FilePath $exe -ArgumentList $a -WorkingDirectory (Split-Path -Parent $exe) -PassThru
    return @{ proc = $p; hwnd = [IntPtr]::Zero; log = $log; tag = $tag }
}
function Stop-Cone($s) {
    if (-not $s -or $s.proc.HasExited) { return }
    Log "ending $($s.tag) (pid $($s.proc.Id)) after the checks"
    try { $s.proc.Kill() } catch {}
    $s.proc.WaitForExit(5000) | Out-Null
}

function Check-Window($s) {
    Check "$($s.tag): main window appears" {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30) {
            if ($s.proc.HasExited) { throw "Cone exited during the start (exit code $($s.proc.ExitCode))" }
            $h = [RdSmoke]::FindMainWindow($s.proc.Id)
            if ($h -ne [IntPtr]::Zero) {
                $s.hwnd = $h
                $b = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
                [RdSmoke]::MoveWindow($h, $b.Left, $b.Top, $b.Width, $b.Height, $true) | Out-Null
                return "after $([math]::Round($sw.Elapsed.TotalSeconds, 1)) s"
            }
            Start-Sleep -Milliseconds 200
        }
        throw 'no Cone window within 30 s'
    }
}
function Check-Time($s) {
    Check "$($s.tag): playback time advances" {
        Wait-Rc 20
        $t1 = Rc-Number 'get_time'; Start-Sleep -Seconds 3; $t2 = Rc-Number 'get_time'
        if ($t2 -le $t1) { throw "the time stays at $t1 s, then $t2 s" }
        "$t1 s, then $t2 s three seconds later"
    }
}
function Check-Subtitle($s) {
    Check "$($s.tag): subtitle file loads" {
        $t = Rc 'strack'
        $sel = ($t -split "`n") | Where-Object { $_ -match '\|\s*\d+ - .+ \*\s*$' }
        if (-not $sel) { throw "no subtitle track selected: '$(($t -split "`n" | Where-Object { $_ -match '\|' }) -join ' / ')'" }
        "selected: $(($sel | Select-Object -First 1).Trim())"
    }
}
# Cone's on-screen message (RdOsdMessage.qml): a volume key shows it with "Volume ...", and it goes away
function Check-Osd($s) {
    # the speed key: the runner has no audio device, so a volume key shows nothing
    Check "$($s.tag): a key shows Cone's on-screen message" {
        Focus-Window $s.hwnd
        Keys @(0xDD)   # ]: faster
        $e = Uia-Find $s.hwnd 'On-screen message' 3000
        if (-not $e) { throw 'no on-screen message within 3 s after ] (faster)' }
        Shot "$($s.tag)-osd"
        # Qt reports Accessible.description as UIA's FullDescription (30159), not HelpText
        $text = ''
        try { $text = [string]$e.GetCurrentPropertyValue([System.Windows.Automation.AutomationProperty]::LookupById(30159)) } catch {}
        if (-not $text) { $text = $e.Current.HelpText }
        if (-not $text) {
            $text = (@($e.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) |
                     ForEach-Object { $_.Current.Name } | Where-Object { $_ }) -join ' '
        }
        # Qt's UI Automation bridge does not always expose the message's description (the text is
        # checked on Linux through AT-SPI); here the message must show and go, and any text it
        # does expose must be the speed
        $note = ''
        if (-not $text) {
            $note = " (text not exposed to UI Automation: HelpText, FullDescription and the inner names are empty; ItemStatus '$($e.Current.ItemStatus)')"
        } elseif ($text -notmatch 'Speed') { throw "the message says '$text', expected the speed" }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ((Uia-Find $s.hwnd 'On-screen message' 0) -and $sw.Elapsed.TotalSeconds -lt 6) { Start-Sleep -Milliseconds 250 }
        if (Uia-Find $s.hwnd 'On-screen message' 0) { throw 'the message is still shown 6 s later' }
        Keys @(0xBB)   # =: back to the normal speed for the next checks
        """$text"" shown, gone again$note"
    }
}

# fullscreen is left whichever way it was entered (redesign/FIX_FULLSCREEN_EXIT_NOTES.md): F then
# the top bar's button, and the top bar's button then Escape
function Click-Element($e) {
    $r = $e.Current.BoundingRectangle
    Click ([int]($r.Left + $r.Width / 2)) ([int]($r.Top + $r.Height / 2))
}
function Is-Fullscreen($h) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $w = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($h, [ref]$w) | Out-Null
    return ($w.Left -le $b.Left -and $w.Top -le $b.Top -and $w.Right -ge $b.Right -and $w.Bottom -ge $b.Bottom)
}
# the top bar's "Fullscreen" button (the control bar's button has the same name: take the one at
# the window's top). The pointer goes up to the top edge as a hand does, from the middle of the
# window, and rests there: in fullscreen only the top edge shows the top bar, in a window any move
function Find-TopBarFullscreen($s, [int]$timeoutMs) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($s.hwnd)
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Fullscreen')
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        $w = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$w) | Out-Null
        foreach ($e in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
            try {
                $r = $e.Current.BoundingRectangle
                if (-not $e.Current.IsOffscreen -and $r.Width -gt 0 -and $r.Top -lt $w.Top + 80) { return $e }
            } catch {}
        }
        Start-Sleep -Milliseconds 250
    } while ($sw.ElapsedMilliseconds -lt $timeoutMs)
    return $null
}
function Click-TopBarFullscreen($s) {
    $w = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$w) | Out-Null
    $cx = [int](($w.Left + $w.Right) / 2); $cy = [int](($w.Top + $w.Bottom) / 2)
    $btn = $null
    foreach ($try in 1, 2) {
        for ($y = $cy; $y -ge $w.Top; $y -= 8) { [RdSmoke]::SetCursorPos($cx, $y) | Out-Null; Start-Sleep -Milliseconds 15 }
        [RdSmoke]::SetCursorPos($cx, [Math]::Max($w.Top, 0)) | Out-Null
        $btn = Find-TopBarFullscreen $s 3000
        if ($btn) { break }
    }
    if (-not $btn) { throw 'no "Fullscreen" button in the top bar (pointer at the top edge)' }
    Click-Element $btn
}
function Check-FsExit($s) {
    Check "$($s.tag): fullscreen is left whichever way it was entered" {
        Focus-Window $s.hwnd
        try {
            Keys @(0x46)   # F: the video's fullscreen
            Start-Sleep -Seconds 2
            if (-not (Is-Fullscreen $s.hwnd)) { throw 'F did not enter fullscreen' }
            Click-TopBarFullscreen $s
            Start-Sleep -Seconds 2
            if (Is-Fullscreen $s.hwnd) { throw 'entered with F, the top bar''s Fullscreen button did not leave fullscreen' }
            Click-TopBarFullscreen $s
            Start-Sleep -Seconds 2
            if (-not (Is-Fullscreen $s.hwnd)) { throw 'the top bar''s Fullscreen button did not enter fullscreen' }
            Focus-Window $s.hwnd
            Keys @(0x1B)   # Escape
            Start-Sleep -Seconds 2
            if (Is-Fullscreen $s.hwnd) { throw 'entered with the top bar''s button, Escape did not leave fullscreen' }
            # the button, then F once: the first F leaves (it took a second F on the PC, 1.2.0)
            Click-TopBarFullscreen $s
            Start-Sleep -Seconds 2
            if (-not (Is-Fullscreen $s.hwnd)) { throw 'the top bar''s Fullscreen button did not enter fullscreen (second time)' }
            Focus-Window $s.hwnd
            Keys @(0x46)   # F, once
            Start-Sleep -Seconds 2
            if (Is-Fullscreen $s.hwnd) { throw 'entered with the top bar''s button, the first F did not leave fullscreen' }
            # and F again enters, F leaves (the video's fullscreen still follows F)
            Keys @(0x46)
            Start-Sleep -Seconds 2
            if (-not (Is-Fullscreen $s.hwnd)) { throw 'after leaving with F, F did not enter fullscreen again' }
            Keys @(0x46)
            Start-Sleep -Seconds 2
            if (Is-Fullscreen $s.hwnd) { throw 'F did not leave fullscreen after F entered it' }
            'F then the button: windowed; the button then Escape: windowed; the button then one F: windowed; F, F: in and out'
        } finally {
            if (Is-Fullscreen $s.hwnd) { Keys @(0x7A); Start-Sleep -Seconds 1 }   # F11 back to the window
            [RdSmoke]::SetCursorPos(500, 400) | Out-Null
        }
    }
}
# fullscreen: a bar shown by its edge zone stays while the pointer rests on its buttons (the top
# bar hid under the pointer on Windows when a button's tooltip, a native window pushed onto the
# button at the top of the screen, made the window report a leave)
function Check-FsTopBar($s) {
    Check "$($s.tag): fullscreen top bar stays under the pointer" {
        Focus-Window $s.hwnd
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $cx = [int]($b.Left + $b.Width / 2); $cy = [int]($b.Top + $b.Height / 2)
        try {
            Keys @(0x46)   # F: fullscreen
            Start-Sleep -Seconds 2
            # the bars hide while the pointer rests over the middle of the video
            [RdSmoke]::SetCursorPos($cx, $cy) | Out-Null; Start-Sleep -Milliseconds 100
            [RdSmoke]::SetCursorPos($cx + 5, $cy + 5) | Out-Null
            Start-Sleep -Seconds 5
            if (Uia-Find $s.hwnd 'Menu' 0) { throw 'the top bar did not hide in fullscreen' }
            # the top edge shows it
            [RdSmoke]::SetCursorPos($cx, $b.Top) | Out-Null
            $menu = Uia-Find $s.hwnd 'Menu' 3000
            if (-not $menu) { throw 'the top edge did not show the top bar' }
            $r = $menu.Current.BoundingRectangle
            $mx = [int]($r.Left + $r.Width / 2); $my = [int]($r.Top + $r.Height / 2)
            # down onto the "..." button, as a hand does, then rest there
            for ($y = $b.Top; $y -le $my; $y += 2) { [RdSmoke]::SetCursorPos($mx, $y) | Out-Null; Start-Sleep -Milliseconds 20 }
            Start-Sleep -Milliseconds 1500
            Shot "$($s.tag)-fs-topbar"
            if (-not (Uia-Find $s.hwnd 'Menu' 0)) { throw "the top bar hid while the pointer rested on its ""..."" button ($mx, $my)" }
            "shown at the top edge, still shown 1.5 s after the pointer came to rest on ""..."" ($mx, $my)"
        } finally {
            [RdSmoke]::SetCursorPos($cx, $cy) | Out-Null
            # back to the window, only if it is fullscreen (a retry starts from the window)
            $w = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$w) | Out-Null
            if ($w.Left -le $b.Left -and $w.Top -le $b.Top -and $w.Right -ge $b.Right -and $w.Bottom -ge $b.Bottom) {
                Keys @(0x46)
                Start-Sleep -Seconds 1
            }
        }
    }
}

# the top bar's "..." opens the main menu with a real click, in a window and in fullscreen (the
# menu is a Qt Quick overlay of the main window; its first row is "Open File(s)")
function Open-MainMenu($s, [bool]$fullscreen) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $cx = [int]($b.Left + $b.Width / 2); $cy = [int]($b.Top + $b.Height / 2)
    $mode = if ($fullscreen) { 'fs' } else { 'win' }
    Focus-Window $s.hwnd
    if ($fullscreen) {
        # the bars hide while the pointer rests over the video, the top edge shows the top bar
        [RdSmoke]::SetCursorPos($cx, $cy) | Out-Null; Start-Sleep -Milliseconds 100
        [RdSmoke]::SetCursorPos($cx + 5, $cy + 5) | Out-Null
        Start-Sleep -Seconds 5
        [RdSmoke]::SetCursorPos($cx, $b.Top) | Out-Null
        $button = Uia-Find $s.hwnd 'Menu' 3000
        if (-not $button) { throw 'the top edge did not show the top bar' }
        $r = $button.Current.BoundingRectangle
        $mx = [int]($r.Left + $r.Width / 2); $my = [int]($r.Top + $r.Height / 2)
        # down onto "..." as a hand does, then a short rest, as before a click
        for ($y = $b.Top; $y -le $my; $y += 2) { [RdSmoke]::SetCursorPos($mx, $y) | Out-Null; Start-Sleep -Milliseconds 20 }
        Start-Sleep -Milliseconds 600
    } else {
        Show-Bars $s.hwnd
        $button = Uia-Find $s.hwnd 'Menu' 3000
        if (-not $button) { throw 'the top bar''s "..." button is not shown' }
        $r = $button.Current.BoundingRectangle
        $mx = [int]($r.Left + $r.Width / 2); $my = [int]($r.Top + $r.Height / 2)
        [RdSmoke]::SetCursorPos($mx, $my) | Out-Null
        Start-Sleep -Milliseconds 600
    }
    if (-not (Uia-Find $s.hwnd 'Menu' 0)) { throw "the top bar hid before the click ($mx, $my)" }
    [RdSmoke]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 80
    [RdSmoke]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 300
    Shot "$($s.tag)-menu-$mode-0.3s"
    $row = Uia-Find $s.hwnd 'Open File(s)' 2000
    if (-not $row) {
        Shot "$($s.tag)-menu-$mode-fail"
        throw "a click on ""..."" ($mx, $my) did not open the main menu (no ""Open File(s)"" row within 2 s)"
    }
    # it stays open while the pointer rests on "..."
    Start-Sleep -Milliseconds 1500
    Shot "$($s.tag)-menu-$mode-1.8s"
    if (-not (Uia-Find $s.hwnd 'Open File(s)' 0)) { throw "the main menu opened, then closed by itself within 1.8 s" }
    $rr = $row.Current.BoundingRectangle
    if ($rr.Left -lt $b.Left -or $rr.Top -lt $b.Top -or $rr.Right -gt $b.Right -or $rr.Bottom -gt $b.Bottom) {
        throw "the main menu opened off the screen (""Open File(s)"" at $rr)"
    }
    # Escape closes it
    Keys @(0x1B)
    Start-Sleep -Milliseconds 500
    if (Uia-Find $s.hwnd 'Open File(s)' 0) { throw 'Escape did not close the main menu' }
    "a click on ""..."" ($mx, $my) opened the main menu (""Open File(s)"" at $([int]$rr.Left), $([int]$rr.Top)); still open 1.8 s later; Escape closed it"
}
function Check-MenuClick($s) {
    Check "$($s.tag): ""..."" opens the main menu in a window" { Open-MainMenu $s $false }
}
function Check-FsMenuClick($s) {
    Check "$($s.tag): ""..."" opens the main menu in fullscreen" {
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        Focus-Window $s.hwnd
        try {
            Keys @(0x46)   # F: fullscreen
            Start-Sleep -Seconds 2
            Open-MainMenu $s $true
        } finally {
            [RdSmoke]::SetCursorPos([int]($b.Left + $b.Width / 2), [int]($b.Top + $b.Height / 2)) | Out-Null
            # a menu left open takes an Escape first (Escape also leaves fullscreen, so the window is
            # measured again before F)
            if (Uia-Find $s.hwnd 'Open File(s)' 0) { Keys @(0x1B); Start-Sleep -Milliseconds 400 }
            $w = New-Object RdSmoke+RECT; [RdSmoke]::GetWindowRect($s.hwnd, [ref]$w) | Out-Null
            if ($w.Left -le $b.Left -and $w.Top -le $b.Top -and $w.Right -ge $b.Right -and $w.Bottom -ge $b.Bottom) {
                Keys @(0x46)
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Check-Seek($s) {
    Check "$($s.tag): seek bar responds" {
        Focus-Window $s.hwnd
        Show-Bars $s.hwnd
        $bar = Uia-Find $s.hwnd 'Progress' 8000
        if (-not $bar) { throw 'the seek bar ("Progress" slider) is not in the UI Automation tree' }
        $r = $bar.Current.BoundingRectangle
        if ($r.Width -lt 50) { throw "the seek bar is $($r.Width) px wide" }
        $len = Rc-Number 'get_length'
        Show-Bars $s.hwnd
        Click ([int]($r.Left + 0.75 * $r.Width)) ([int]($r.Top + $r.Height / 2))
        Start-Sleep -Milliseconds 1500
        $t = Rc-Number 'get_time'
        $want = 0.75 * $len
        Shot "$($s.tag)-seek"
        if ([math]::Abs($t - $want) -gt [math]::Max(3, 0.1 * $len)) { throw "clicked at 75 % of $len s, the time is $t s" }
        "clicked at 75 % of $len s, the time is $t s"
    }
}
function Open-Settings($s) {
    Focus-Window $s.hwnd
    # the dialog's search field (its "Global Settings" title is a plain text without an
    # accessible name)
    $field = 'Search settings'
    # Ctrl+P toggles the dialog: a retry closes what the first attempt opened
    if (Uia-Find $s.hwnd $field 300) { Keys @(0x1B); Start-Sleep -Milliseconds 500 }
    Keys @(0x11, 0x50)   # Ctrl+P
    $search = Uia-Find $s.hwnd $field 8000
    Start-Sleep -Milliseconds 300
    Shot "$($s.tag)-settings"
    if (-not $search) { throw 'Ctrl+P: the Settings dialog (its "Search settings" field) did not appear within 8 s' }
    if (-not (Uia-Find $s.hwnd 'General' 1000)) { throw 'the Settings dialog has no "General" category' }
    Keys @(0x1B)         # Escape closes it
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ((Uia-Find $s.hwnd $field 0) -and $sw.ElapsedMilliseconds -lt 3000) { Start-Sleep -Milliseconds 200 }
    if (Uia-Find $s.hwnd $field 0) { throw 'Escape did not close the Settings dialog' }
    'Ctrl+P opens the Settings dialog (General); Escape closes it'
}
function Check-Settings($s) {
    Check "$($s.tag): Settings opens" { Open-Settings $s }
}
# the playback speed slider (the sidebar's Playback tab): a real drag across it while the video
# plays, then Cone must still answer: its window processes messages, the cli gives the time and
# the time moves on. Before the fix each speed change made the interface lock the player twice
# and Cone froze (redesign/FIX_SPEED_FREEZE_NOTES.md)
function Check-SpeedDrag($s) {
    Check "$($s.tag): speed slider drag, Cone keeps responding" {
        if ($s.proc.HasExited) { throw "Cone is not running (exit code $($s.proc.ExitCode))" }
        Focus-Window $s.hwnd
        Show-Bars $s.hwnd
        $gear = Uia-Find $s.hwnd 'Playback Settings' 5000
        if (-not $gear) { throw 'the control bar has no "Playback Settings" button' }
        $g = $gear.Current.BoundingRectangle
        Click ([int]($g.Left + $g.Width / 2)) ([int]($g.Top + $g.Height / 2))
        $slider = $null
        $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Slider)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $slider -and $sw.ElapsedMilliseconds -lt 5000) {
            foreach ($e in [System.Windows.Automation.AutomationElement]::FromHandle($s.hwnd).FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
                try { if ($e.Current.Name -eq 'Speed' -and -not $e.Current.IsOffscreen -and $e.Current.BoundingRectangle.Width -gt 0) { $slider = $e; break } } catch {}
            }
            if (-not $slider) { Start-Sleep -Milliseconds 250 }
        }
        Shot "$($s.tag)-speed-sidebar"
        if (-not $slider) { throw 'the gear opened no "Speed" slider (sidebar, Playback tab)' }
        $r = $slider.Current.BoundingRectangle
        # the slider's track is the top of the element, its step labels are below; the thumb
        # starts at 1x (0.25 to 2: 43 % of the track)
        $y = [int]($r.Top + 0.23 * $r.Height)
        [RdSmoke]::SetCursorPos([int]($r.Left + 0.43 * $r.Width), $y) | Out-Null; Start-Sleep -Milliseconds 150
        [RdSmoke]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
        $moves = 0
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            while ($sw.Elapsed.TotalSeconds -lt 4) {
                $f = 0.05 + 0.9 * [math]::Abs((($moves % 40) / 20.0) - 1)
                [RdSmoke]::SetCursorPos([int]($r.Left + $f * $r.Width), $y) | Out-Null
                Start-Sleep -Milliseconds 30
                $moves++
            }
            # it ends near 2x: the speed then shows that the drag reached the slider
            [RdSmoke]::SetCursorPos([int]($r.Left + 0.9 * $r.Width), $y) | Out-Null
            Start-Sleep -Milliseconds 150
        } finally { [RdSmoke]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero) }
        Start-Sleep -Milliseconds 500
        if ($s.proc.HasExited) { throw "Cone exited during the drag (exit code $($s.proc.ExitCode))" }
        # Responding: the window answers a message within 5 s (a frozen interface does not)
        $s.proc.Refresh()
        if (-not $s.proc.Responding) { Shot "$($s.tag)-speed-frozen"; throw 'after the drag Cone''s window does not respond (the interface froze)' }
        try {
            $rate = [double]::Parse([regex]::Match((Rc 'rate'), '(?m)^[>\s]*([0-9]+[.,]?[0-9]*)\s*$').Groups[1].Value.Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
            Rc 'rate 1' | Out-Null
            $t1 = Rc-Number 'get_time'; Start-Sleep -Seconds 2; $t2 = Rc-Number 'get_time'
        } catch { throw "after the drag the player does not answer: $($_.Exception.Message)" }
        if ($rate -lt 1.5) { throw "the speed is $($rate)x after the drag ended near 2x: the drag did not reach the slider" }
        # the file repeats (--input-repeat): the time moves on or starts over, it does not stand still
        if ($t2 -eq $t1) { throw "after the drag the time stands still ($t1 s, then $t2 s two seconds later)" }
        Shot "$($s.tag)-speed-after"
        Keys @(0x1B)   # Escape closes the sidebar
        "$moves moves across the slider, released at $($rate)x; the window responds; time $t1 s, then $t2 s two seconds later"
    }
}
# Ctrl+Q; $hevc: a quit the watchdog ends is a warning (known HEVC quit stall), otherwise a failure
function Quit-Cone($s, [bool]$hevc) {
    if ($s.proc.HasExited) { throw 'Cone had already exited' }
    Focus-Window $s.hwnd
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Keys @(0x11, 0x51)   # Ctrl+Q
    $ended = $s.proc.WaitForExit($QuitLimitSeconds * 1000)
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    if (-not $ended) {
        Shot "$($s.tag)-quit-hang"
        try { $s.proc.Kill() } catch {}
        throw "Cone was still running $QuitLimitSeconds s after Ctrl+Q (the $WatchdogSeconds s watchdog did not end it)"
    }
    Start-Sleep -Milliseconds 300
    $wd = (Test-Path $s.log) -and (Select-String -Path $s.log -Pattern 'quit watchdog: Cone did not finish quitting' -SimpleMatch -Quiet)
    if ($wd) {
        if ($hevc) { return @('warn', "ended by the quit watchdog after $secs s (known HEVC quit stall, STATUS.md)") }
        throw "ended by the quit watchdog after $secs s"
    }
    if (-not $hevc -and $secs -ge 3) { throw "took $secs s (limit 3 s)" }
    "ended after $secs s"
}
# the retry of a failed quit is a new session of the same file: start, play 4 s, quit
function Check-Quit($s, [bool]$hevc, [string]$exe, [string]$video, [string]$subs) {
    Check "$($s.tag): quit" { Quit-Cone $s $hevc } {
        Stop-Cone $s
        $s2 = Start-Cone $exe $video $subs "$($s.tag)-again"
        try {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while (($s2.hwnd = [RdSmoke]::FindMainWindow($s2.proc.Id)) -eq [IntPtr]::Zero) {
                if ($sw.Elapsed.TotalSeconds -gt 30 -or $s2.proc.HasExited) { throw 'the new session has no window' }
                Start-Sleep -Milliseconds 200
            }
            Start-Sleep -Seconds 4
            Quit-Cone $s2 $hevc
        } finally { Stop-Cone $s2 }
    }
}

# every plug-in DLL loads: VLC logs "cannot load plug-in <path>: <reason>" for one Windows refuses
# (a missing dependency DLL: error 126). Read after the quit, when the file logger has flushed
# (fully buffered on Windows); the zip ships no plug-in cache, so its sessions load every plug-in
function Check-PluginsLoad($s) {
    Check "$($s.tag): every plug-in loads" {
        if (-not (Test-Path $s.log)) { throw "no log at $($s.log)" }
        $bad = @(Select-String -Path $s.log -Pattern 'cannot load plug-in (.+)$' | ForEach-Object {
            $_.Matches[0].Groups[1].Value -replace '^.*[\\/]plugins[\\/]', 'plugins\' })
        if ($bad.Count) { throw "$($bad.Count) plug-in(s) do not load: $($bad -join '; ')" }
        $loaded = @(Select-String -Path $s.log -Pattern 'cannot read .*plugins\.dat' -SimpleMatch:$false).Count
        if ($loaded) { 'no "cannot load plug-in" line (no plug-in cache: every plug-in was loaded at the start)' }
        else { 'no "cannot load plug-in" line' }
    }
}

# cast discovery (STATUS #131 retest): VLC's two cast discoveries, microdns (mDNS, Chromecast) and
# upnp, load on Windows and offer their "renderer probe", which the Render list asks for.
# - Their plug-ins load: Cone started without its interface (-I dummy) and both discoveries asked
#   for by name; VLC logs '... module matching "microdns": 1 candidates' when the DLL loaded.
# - Their renderer probes register: vlc-cache-gen (what the installer and Settings > Rescan run)
#   writes a plug-in cache naming each probe; on a copy of the plug-ins, so the zip keeps no cache
#   (its other sessions load every plug-in, Check-PluginsLoad). $cache: read that installed cache
#   instead (the installer ran vlc-cache-gen itself).
function Check-CastDiscovery([string]$tag, [string]$exe, [string]$cache = '') {
    Check "$tag`: cast discovery plug-ins load" {
        $log = Join-Path $Out "cone-$tag-cast.log"
        Remove-Item $log -ErrorAction SilentlyContinue
        $a = @('-I', 'dummy', '--no-qt-privacy-ask', '--services-discovery=microdns,upnp',
               '--file-logging', "--logfile=`"$log`"", '--log-verbose=2', 'vlc://quit')
        Log "start $exe $($a -join ' ')"
        $p = Start-Process -FilePath $exe -ArgumentList $a -WorkingDirectory (Split-Path -Parent $exe) -PassThru
        # the end of this run is not what is checked (under wine it stays in the shutdown)
        if (-not $p.WaitForExit(30000)) { Log "$tag cast run still running after 30 s: ended"; try { $p.Kill() } catch {}; $p.WaitForExit(5000) | Out-Null }
        if (-not (Test-Path $log)) { throw "no log at $log" }
        $found = @()
        foreach ($name in 'microdns', 'upnp') {
            $line = Select-String -Path $log -SimpleMatch "services_discovery module matching `"$name`"" | Select-Object -First 1
            if (-not $line) { throw "Cone never looked for $name (log: $log)" }
            if ($line.Line -notmatch ': 1 candidates') { throw "$name did not load: $($line.Line.Trim())" }
            $found += $name
        }
        "$($found -join ' and ') load (1 candidate each)"
    } | Out-Null
    Check "$tag`: cast discovery renderer probes register" {
        $dat = $cache
        if (-not $dat) {
            $gen = Join-Path (Split-Path -Parent $exe) 'vlc-cache-gen.exe'
            if (-not (Test-Path $gen)) { throw "no $gen" }
            $copy = Join-Path $Out "plugins-$tag"
            Remove-Item $copy -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item (Join-Path (Split-Path -Parent $exe) 'plugins') $copy -Recurse
            Remove-Item (Join-Path $copy 'plugins.dat') -ErrorAction SilentlyContinue
            $p = Start-Process -FilePath $gen -ArgumentList "`"$copy`"" -PassThru -Wait -WindowStyle Hidden
            Log "vlc-cache-gen ended with exit code $($p.ExitCode)"
            $dat = Join-Path $copy 'plugins.dat'
        }
        if (-not (Test-Path $dat)) { throw "no plug-in cache at $dat" }
        $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($dat))
        $probes = ([regex]::Matches($text, 'renderer probe')).Count
        $missing = @('microdns_renderer', 'upnp_renderer' | Where-Object { -not $text.Contains($_) })
        if ($missing.Count) { throw "the plug-in cache has no $($missing -join ', ') ($probes renderer probe entries)" }
        if ($probes -lt 2) { throw "$probes renderer probe entries in the plug-in cache (expected 2)" }
        "$probes renderer probe entries (microdns_renderer, upnp_renderer) in $(Split-Path -Leaf (Split-Path -Parent $dat))\plugins.dat"
    } | Out-Null
}

# the restore question (redesign/RETEST_FOLLOWUPS_NOTES.md section 3): after a session that ended
# abruptly, the next start asks "The application closed abruptly ... restore the playlist?". Ctrl+Q
# while it asks ends Cone and keeps the saved playlist: the next start asks again (after #128 it did
# not); No clears it, so the start after that does not ask
function Find-RestoreQuestion([int]$procId, [int]$timeoutMs) {
    # by its window title (Win32), then its UI Automation element (for the No button)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        $h = [RdSmoke]::FindWindowByTitle($procId, 'closed abruptly')
        if ($h -ne [IntPtr]::Zero) { return [System.Windows.Automation.AutomationElement]::FromHandle($h) }
        Start-Sleep -Milliseconds 250
    } while ($sw.ElapsedMilliseconds -lt $timeoutMs)
    return $null
}
function No-RestoreQuestion($s, [string]$what) {
    Shot "$($s.tag)-no-question"
    "$what (Cone's windows: $([RdSmoke]::ListWindows($s.proc.Id)))"
}
function Quit-Window($s) {
    if ($s.proc.HasExited) { return }
    # the main window found again: Check-Window may have taken the question for it
    $h = [RdSmoke]::FindMainWindow($s.proc.Id)
    if ($h -eq [IntPtr]::Zero) { $h = $s.hwnd }
    [RdSmoke]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # WM_CLOSE
    if (-not $s.proc.WaitForExit(10000)) { try { Rc 'quit' | Out-Null } catch {}; $s.proc.WaitForExit(10000) | Out-Null }
}
function Check-RestoreQuestion([string]$exe) {
    $video = Join-Path $Media 'test-h264.mp4'; $subs = Join-Path $Media 'test.srt'
    $ini = Join-Path (Split-Path -Parent $exe) 'portable\Cone\vlc-qt-interface.ini'
    try {
        $s = Start-Cone $exe $video $subs 'restore-killed'
        try {
            if (-not (Check-Window $s)) { return }
            # the playlist is saved for a restore 10 s after it last changed (on the runner it can
            # take longer): killed once the saved file has content, as only then the next start asks
            Check 'restore: the playlist is saved for a restore' {
                $sw = [Diagnostics.Stopwatch]::StartNew()
                while ($sw.Elapsed.TotalSeconds -lt 60) {
                    $line = if (Test-Path $ini) { Select-String -Path $ini -Pattern '^RecoveryFilePath=(.*)$' | Select-Object -First 1 } else { $null }
                    if ($line) {
                        $path = $line.Matches[0].Groups[1].Value.Trim('"')
                        if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -gt 0) {
                            return "saved after $([math]::Round($sw.Elapsed.TotalSeconds)) s ($((Get-Item -LiteralPath $path).Length) bytes)"
                        }
                    }
                    Start-Sleep -Milliseconds 500
                }
                throw 'the playlist was not saved for a restore within 60 s'
            } | Out-Null
        } finally { Stop-Cone $s }   # ended abruptly
        # what the next start finds: the setting naming the saved playlist, and that file
        $saved = $null
        if (Test-Path $ini) { $saved = Select-String -Path $ini -Pattern '^RecoveryFilePath=(.*)$' | Select-Object -First 1 }
        if ($saved) {
            $path = $saved.Matches[0].Groups[1].Value.Trim('"')
            $size = if (Test-Path -LiteralPath $path) { "$((Get-Item -LiteralPath $path).Length) bytes" } else { 'missing' }
            Log "restore: saved playlist $path ($size)"
        } else { Log "restore: no RecoveryFilePath in $ini after the killed session" }
        $s = Start-Cone $exe $video $subs 'restore-quit'
        try {
            if (-not (Check-Window $s)) { return }
            Check 'restore: Ctrl+Q while Cone asks to restore the playlist ends Cone' {
                $q = Find-RestoreQuestion $s.proc.Id 15000
                if (-not $q) { throw (No-RestoreQuestion $s 'no "The application closed abruptly" question after a killed session') }
                Focus-Window ([IntPtr]$q.Current.NativeWindowHandle)
                Keys @(0x11, 0x51)   # Ctrl+Q
                if (-not $s.proc.WaitForExit(20000)) { throw 'Cone did not end within 20 s of Ctrl+Q' }
                "ended (exit code $($s.proc.ExitCode))"
            } | Out-Null
        } finally { Stop-Cone $s }
        $s = Start-Cone $exe $video $subs 'restore-again'
        try {
            if (-not (Check-Window $s)) { return }
            Check 'restore: the question comes back after a quit without an answer' {
                $q = Find-RestoreQuestion $s.proc.Id 15000
                if (-not $q) { throw (No-RestoreQuestion $s 'no restore question at the start after Ctrl+Q without an answer (the quit dropped the saved playlist)') }
                $name = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'No')
                $no = $q.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $name)
                if (-not $no) { throw 'the question has no "No" button' }
                $no.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
                Start-Sleep -Seconds 1
                if (Find-RestoreQuestion $s.proc.Id 500) { throw 'the question did not close on No' }
                'asked again, answered No'
            } | Out-Null
            Quit-Window $s
        } finally { Stop-Cone $s }
        $s = Start-Cone $exe $video $subs 'restore-gone'
        try {
            if (-not (Check-Window $s)) { return }
            Check 'restore: answering No clears the saved playlist' {
                if (Find-RestoreQuestion $s.proc.Id 8000) { throw 'the restore question came back after it was answered No' }
                'no question within 8 s'
            } | Out-Null
            Quit-Window $s
        } finally { Stop-Cone $s }
    } finally {
        # the question never stands in front of the later checks' windows
        if (Test-Path $ini) {
            # UTF-8 without a BOM, as Qt writes it (Windows PowerShell's Set-Content would write ANSI)
            $lines = [string[]]@([IO.File]::ReadAllLines($ini) | Where-Object { $_ -notmatch '^RecoveryFilePath=' })
            [IO.File]::WriteAllLines($ini, $lines, (New-Object Text.UTF8Encoding($false)))
        }
    }
}

# the quit feels instant (redesign/QUIT_INSTANT_NOTES.md): closed like the window's close button (a
# WM_CLOSE, no keyboard focus needed), the window is hidden within 0.5 s and the process is gone within
# the watchdog's 5 s. With CONE_TEST_HANG_QUIT the quit blocks on purpose after the watchdog is armed:
# only the watchdog can end it, and the process must be gone within 6 s
function Close-AndTime($s, [string]$what, [double]$limit) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    [RdSmoke]::PostMessage($s.hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # WM_CLOSE
    $hidden = $null
    while ($sw.Elapsed.TotalSeconds -lt $limit + 2) {
        if ($null -eq $hidden -and -not [RdSmoke]::Visible($s.hwnd)) { $hidden = $sw.Elapsed.TotalSeconds }
        if ($s.proc.HasExited) { break }
        Start-Sleep -Milliseconds 25
    }
    $gone = if ($s.proc.HasExited) { $sw.Elapsed.TotalSeconds } else { $null }
    if ($null -eq $gone) { try { $s.proc.Kill() } catch {}; throw "$what`: Cone was still running $([math]::Round($limit + 2, 1)) s after the close" }
    if ($null -eq $hidden -or $hidden -gt 0.5) { throw "$what`: the window was hidden only after $([math]::Round([double]$hidden, 2)) s (limit 0.5 s)" }
    if ($gone -gt $limit) { throw "$what`: the process ended after $([math]::Round($gone, 2)) s (limit $limit s)" }
    "window hidden after $([math]::Round($hidden, 2)) s, process gone after $([math]::Round($gone, 2)) s"
}
function Check-QuitInstant([string]$exe) {
    $video = Join-Path $Media 'test-h264.mp4'; $subs = Join-Path $Media 'test.srt'
    $s = Start-Cone $exe $video $subs 'quit-instant'
    try {
        if (-not (Check-Window $s)) { return }
        Start-Sleep -Seconds 4
        Check 'quit-instant: the window goes at once, the process within 5 s' { Close-AndTime $s 'close' $WatchdogSeconds } | Out-Null
    } finally { Stop-Cone $s }
    $env:CONE_TEST_HANG_QUIT = '1'
    try { $s = Start-Cone $exe $video $subs 'quit-hang' } finally { Remove-Item Env:CONE_TEST_HANG_QUIT -ErrorAction SilentlyContinue }
    try {
        if (-not (Check-Window $s)) { return }
        Start-Sleep -Seconds 4
        Check 'quit-hang: a quit that never finishes is ended by the watchdog within 6 s' {
            $r = Close-AndTime $s 'hung close' 6
            if (-not (Select-String -Path $s.log -Pattern 'quit watchdog: Cone did not finish quitting' -SimpleMatch -Quiet)) { throw "$r, but the log has no watchdog line" }
            "$r (ended by the watchdog)"
        } | Out-Null
    } finally { Stop-Cone $s }
}

# Up Next (Cone extra): a click on the card's "Next episode" moves on to the next episode, and that
# episode is still playing 5 s later (on Windows it stopped at once and Cone showed the home page,
# redesign/FIX_UP_NEXT_NEXT_STOP_NOTES.md). The show's 7-minute episodes show the card in their last
# minute; no --input-repeat, which keeps autoplay away
function Episode-Of([string]$status) {
    $m = [regex]::Match($status, 'S01E0(\d)')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return 0
}
function Check-UpNextNext([string]$exe) {
    $ep1 = Join-Path $Media 'Smoke Show\Smoke Show S01E01.mp4'
    $log = Join-Path $Out 'cone-upnext.log'
    Remove-Item $log -ErrorAction SilentlyContinue
    $a = @('--no-qt-privacy-ask', '--no-qt-video-autoresize', '--file-logging', "--logfile=`"$log`"",
           '--log-verbose=2', '--extraintf=cli', "--rc-host=127.0.0.1:$RcPort", '--rc-quiet', "`"$ep1`"")
    Log "start $exe $($a -join ' ')"
    $p = Start-Process -FilePath $exe -ArgumentList $a -WorkingDirectory (Split-Path -Parent $exe) -PassThru
    $s = @{ proc = $p; hwnd = [IntPtr]::Zero; log = $log; tag = 'upnext' }
    try {
        if (-not (Check-Window $s)) { return }
        Check "upnext: the card's Next episode keeps the next episode playing" {
            Wait-Rc 20
            Start-Sleep -Seconds 2
            $before = Episode-Of (Rc 'status')
            if ($before -lt 1 -or $before -gt 2) { throw "an unexpected episode plays: $before" }
            # 6:10 of 7:00: the card shows (the last minute), the countdown has not started
            # the window in front first: a click on a window in the back only brings it forward
            Focus-Window $s.hwnd
            Rc 'seek 370' | Out-Null
            Start-Sleep -Seconds 2
            Show-Bars $s.hwnd
            $b = Uia-Find $s.hwnd 'Next episode' 6000
            if (-not $b) { Shot 'upnext-nocard'; throw "no ""Next episode"" button on the card at 6:10 of episode $before" }
            $r = $b.Current.BoundingRectangle
            Click ([int]($r.Left + $r.Width / 2)) ([int]($r.Top + $r.Height / 2))
            Start-Sleep -Seconds 5
            Shot 'upnext-after'
            $st = Rc 'status'
            $after = Episode-Of $st
            if ($after -ne $before + 1) { throw "5 s after the click episode $after is current (expected $($before + 1)): '$(($st -split "`n" | Where-Object { $_ -match 'input|state' }) -join ' / ')'" }
            if ((Rc-Number 'is_playing') -ne 1) { throw "5 s after the click episode $after does not play" }
            $t1 = Rc-Number 'get_time'; Start-Sleep -Seconds 2; $t2 = Rc-Number 'get_time'
            if ($t2 -le $t1) { throw "episode $after stands still at $t1 s, then $t2 s" }
            "episode $before -> $after, still playing 5 s after the click ($t1 s, then $t2 s)"
        } | Out-Null
    } catch {
        Add-Result 'upnext' 'fail' "unexpected error: $($_.Exception.Message)"
    } finally {
        Stop-Cone $s
    }
}

# an element whose name ends with $suffix (the update notice: "<name> <version> is available")
function Uia-FindSuffix($hwnd, [string]$suffix, [int]$timeoutMs) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        foreach ($e in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
            try {
                if ($e.Current.Name.EndsWith($suffix) -and -not $e.Current.IsOffscreen -and $e.Current.BoundingRectangle.Width -gt 0) { return $e }
            } catch {}
        }
        Start-Sleep -Milliseconds 250
    } while ($sw.ElapsedMilliseconds -lt $timeoutMs)
    return $null
}

# the notices at the bottom stack (redesign/POPUP_STACK_NOTES.md): a file watched to 2:00 opened
# again with the update notice forced on (CONE_UPDATE_CHECK_TEST_FILE) shows the resume toast and
# the update notice one above the other, never overlapping, on the same center line, 10 px apart;
# when the toast goes (it closes by itself 10 s after it shows) the notice slides down into its place.
# The earlier sessions made real update checks: their stored answer is removed first, so this one
# asks (reads the test file), and the forced answer is removed after it
function Check-PopupStack([string]$exe) {
    $tag = 'popup-stack'
    $video = Join-Path $Media 'Smoke Show\Smoke Show S01E03.mp4'
    $answer = Join-Path $Out 'update-answer.json'
    '{"tag_name": "v9.9.9", "html_url": "https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v9.9.9"}' |
        Set-Content -Path $answer -Encoding ASCII
    $ini = Join-Path $ZipDir 'ConePlayer-*\portable\Cone\vlc-qt-interface.ini'
    function Clear-UpdateAnswer {
        foreach ($f in @(Get-ChildItem $ini -ErrorAction SilentlyContinue)) {
            $keep = Get-Content $f.FullName | Where-Object { $_ -notmatch '^(AnsweredAt|LatestVersion|ReleasePage|DismissedOn|SkippedVersion)=' }
            Set-Content -Path $f.FullName -Value $keep -Encoding UTF8
        }
    }
    $s = $null
    try {
        # watch to 2:00 of 7:00 and quit: the media library keeps the progress
        $log = Join-Path $Out "cone-$tag-watch.log"
        $a = @('--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-qt-cone-update-check', '--file-logging', "--logfile=`"$log`"",
               '--log-verbose=2', '--extraintf=cli', "--rc-host=127.0.0.1:$RcPort", '--rc-quiet', "`"$video`"")
        Log "start $exe $($a -join ' ')"
        $p = Start-Process -FilePath $exe -ArgumentList $a -WorkingDirectory (Split-Path -Parent $exe) -PassThru
        $s = @{ proc = $p; hwnd = [IntPtr]::Zero; log = $log; tag = "$tag-watch" }
        if (-not (Check-Window $s)) { return }
        Wait-Rc 20
        Start-Sleep -Seconds 2
        Rc 'seek 120' | Out-Null
        Start-Sleep -Seconds 2
        try { Rc 'quit' | Out-Null } catch {}
        if (-not $s.proc.WaitForExit(15000)) { throw 'the first session did not quit' }

        # again, with the update notice forced on
        Clear-UpdateAnswer
        $log = Join-Path $Out "cone-$tag.log"
        $a = @('--no-qt-privacy-ask', '--no-qt-video-autoresize', '--file-logging', "--logfile=`"$log`"",
               '--log-verbose=2', '--extraintf=cli', "--rc-host=127.0.0.1:$RcPort", '--rc-quiet', "`"$video`"")
        Log "start $exe $($a -join ' ') (CONE_UPDATE_CHECK_TEST_FILE=$answer)"
        $env:CONE_UPDATE_CHECK_TEST_FILE = $answer
        try { $p = Start-Process -FilePath $exe -ArgumentList $a -WorkingDirectory (Split-Path -Parent $exe) -PassThru }
        finally { Remove-Item Env:CONE_UPDATE_CHECK_TEST_FILE -ErrorAction SilentlyContinue }
        $s = @{ proc = $p; hwnd = [IntPtr]::Zero; log = $log; tag = $tag }
        if (-not (Check-Window $s)) { return }
        Check "$tag`: the resume toast and the update notice stack without overlapping" {
            Wait-Rc 20
            $r = Uia-Find $s.hwnd 'Resume dialog' 15000
            $u = Uia-FindSuffix $s.hwnd ' is available' 15000
            if (-not $r -or -not $u) { Shot "$tag-missing"; throw "resume toast found: $([bool]$r), update notice found: $([bool]$u); both expected" }
            Start-Sleep -Milliseconds 600   # past a slide
            $rr = $r.Current.BoundingRectangle; $ur = $u.Current.BoundingRectangle
            Shot "$tag-two"
            $rt = "($([int]$rr.X), $([int]$rr.Y), $([int]$rr.Width), $([int]$rr.Height))"
            $ut = "($([int]$ur.X), $([int]$ur.Y), $([int]$ur.Width), $([int]$ur.Height))"
            $hOverlap = -not ($rr.Right -le $ur.Left -or $ur.Right -le $rr.Left)
            $vOverlap = -not ($rr.Bottom -le $ur.Top -or $ur.Bottom -le $rr.Top)
            if ($hOverlap -and $vOverlap) { throw "they overlap: resume toast $rt, update notice $ut" }
            if ($ur.Bottom -gt $rr.Top) { throw "the update notice is not above the resume toast: $ut / $rt" }
            $gap = [int]($rr.Top - $ur.Bottom)
            if ($gap -lt 6 -or $gap -gt 14) { throw "$gap px between them (10 expected): $ut / $rt" }
            $dc = [math]::Abs(($rr.Left + $rr.Width / 2) - ($ur.Left + $ur.Width / 2))
            if ($dc -gt 2) { throw "not on the same center line ($([int]$dc) px apart): $ut / $rt" }
            # the toast closes by itself 10 s after it shows (ResumeDialog's timeout)
            $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ((Uia-Find $s.hwnd 'Resume dialog' 0) -and $sw2.Elapsed.TotalSeconds -lt 14) { Start-Sleep -Milliseconds 250 }
            if (Uia-Find $s.hwnd 'Resume dialog' 0) { throw 'the resume toast still shows 14 s later' }
            Start-Sleep -Milliseconds 600   # past the slide
            $u2 = Uia-FindSuffix $s.hwnd ' is available' 2000
            Shot "$tag-after"
            if (-not $u2 -or [math]::Abs($u2.Current.BoundingRectangle.Bottom - $rr.Bottom) -gt 2) {
                throw "the update notice did not take the toast's place (its bottom $(if ($u2) { [int]$u2.Current.BoundingRectangle.Bottom }), the toast's $([int]$rr.Bottom))"
            }
            "resume toast $rt, update notice $ut above it, $gap px apart, centers $([int]$dc) px apart; then the notice moved down to the toast's place"
        } | Out-Null
        # a clean quit: a killed Cone makes the next start ask to restore its playlist
        try { Rc 'quit' | Out-Null } catch {}
        $s.proc.WaitForExit(15000) | Out-Null
    } catch {
        Add-Result $tag 'fail' "unexpected error: $($_.Exception.Message)"
    } finally {
        Stop-Cone $s
        Clear-UpdateAnswer
    }
}

# a full session with every check; a session whose quit failed runs once more (from the start)
function Run-Session([string]$exe, [string]$codec, [bool]$full, [string]$tag) {
    $video = Join-Path $Media "test-$codec.mp4"
    $subs = Join-Path $Media 'test.srt'
    $s = Start-Cone $exe $video $subs $tag
    try {
        if (-not (Check-Window $s)) { return }
        Start-Sleep -Seconds 2
        Shot "$tag-start"
        Check-Time $s | Out-Null
        if ($full) {
            Check-Subtitle $s | Out-Null
            Check-Osd $s | Out-Null
            Check-Settings $s | Out-Null
            Check-Seek $s | Out-Null
            Check-FsTopBar $s | Out-Null
            Check-FsExit $s | Out-Null
            Check-MenuClick $s | Out-Null
            Check-FsMenuClick $s | Out-Null
            # the shortcut again, once the seek bar has had a click (it holds the keyboard focus)
            Check "$tag`: Settings opens after a seek bar click" { Open-Settings $s } | Out-Null
            Check-SpeedDrag $s | Out-Null
            if ($codec -eq 'h264') { Check-Pointer $s }
        }
        Check-Quit $s ($codec -eq 'hevc') $exe $video $subs | Out-Null
        Check-PluginsLoad $s | Out-Null
    } catch {
        Add-Result "$tag" 'fail' "unexpected error: $($_.Exception.Message)"
    } finally {
        Stop-Cone $s
    }
}

# the playback time in seconds, $null while nothing plays (the cli gives no number)
function Rc-Time {
    try { return Rc-Number 'get_time' } catch { return $null }
}
# an element named $name inside $parent (the onboarding's own buttons, not the control bar's
# "Next" under it, which UI Automation also reports as on screen)
function Uia-FindIn($parent, [string]$name) {
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
    foreach ($e in $parent.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
        try { if (-not $e.Current.IsOffscreen -and $e.Current.BoundingRectangle.Width -gt 0) { return $e } } catch {}
    }
    return $null
}
function Click-Element($e) {
    $r = $e.Current.BoundingRectangle
    Click ([int]($r.Left + $r.Width / 2)) ([int]($r.Top + $r.Height / 2))
}
# a first start with a file (F1): the onboarding shows, the file waits at 0 while it is open, and
# plays from the beginning after Finish (on Linux the onboarding is closed with Escape)
function Run-FirstStart([string]$exe) {
    $tag = 'first-start'
    $s = Start-Cone $exe (Join-Path $Media 'test-h264.mp4') (Join-Path $Media 'test.srt') $tag $true
    try {
        if (-not (Check-Window $s)) { return }
        $shown = Check "$tag`: the onboarding shows" {
            # the onboarding's screen (Onboarding.qml: Accessible.Dialog "Welcome")
            if (-not (Uia-Find $s.hwnd 'Welcome' 15000)) { throw 'no onboarding (its "Welcome" dialog) within 15 s' }
            Shot "$tag-onboarding"
            'the onboarding is shown'
        }
        if (-not $shown) { return }
        Check "$tag`: the file waits at 0 while the onboarding is open" {
            Wait-Rc 20
            $seen = @()
            for ($i = 0; $i -lt 8; $i++) {
                $t = Rc-Time
                $seen += $(if ($null -eq $t) { '-' } else { "$t" })
                if ($t) { throw "the file plays behind the onboarding: time $($seen -join ', ') s" }
                Start-Sleep -Seconds 1
            }
            "time over 8 s: $($seen -join ' ') (- = not started)"
        } | Out-Null
        Check "$tag`: playback starts from 0 after Finish" {
            Focus-Window $s.hwnd
            # Next, Next, Finish (the media folder page only shows with the media library)
            for ($i = 0; $i -lt 3; $i++) {
                $dialog = Uia-Find $s.hwnd 'Welcome' 3000
                if (-not $dialog) { throw "the onboarding is gone before screen $($i + 1)" }
                $finish = Uia-FindIn $dialog 'Finish'
                if ($finish) { Click-Element $finish; break }
                $next = Uia-FindIn $dialog 'Next'
                if (-not $next) { throw "no Next or Finish button on screen $($i + 1)" }
                Click-Element $next
                Start-Sleep -Milliseconds 700
            }
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while (Uia-Find $s.hwnd 'Welcome' 0) {
                if ($sw.Elapsed.TotalSeconds -gt 5) { throw 'the onboarding did not close after Finish' }
                Start-Sleep -Milliseconds 300
            }
            $sw.Restart()
            $t1 = Rc-Time
            while ($null -eq $t1 -and $sw.Elapsed.TotalSeconds -lt 15) { Start-Sleep -Milliseconds 500; $t1 = Rc-Time }
            if ($null -eq $t1) { throw 'nothing plays within 15 s after Finish' }
            if ($t1 -gt 4) { throw "playback did not start from the beginning: $t1 s right after Finish" }
            Start-Sleep -Seconds 3
            $t2 = Rc-Time
            if ($null -eq $t2 -or $t2 -le $t1) { throw "the time does not advance: $t1 s, then $t2 s" }
            "$t1 s right after Finish, $t2 s three seconds later"
        } | Out-Null
    } catch {
        Add-Result "$tag" 'fail' "unexpected error: $($_.Exception.Message)"
    } finally {
        Stop-Cone $s
    }
}

# Explorer's Open with / a double-click while Cone plays (redesign/FIX_OPEN_IN_RUNNING_WINDOW_NOTES.md):
# a second start with --started-from-file hands its file to the running window and exits; the
# running window must play it at once (it was only added to the end of the queue). The first Cone
# here is started without --started-from-file, like one opened from the Start menu
function Run-OpenInRunning([string]$exe) {
    $tag = 'open-in-running'
    $first = Join-Path $Media 'test-h264.mp4'
    $second = Join-Path $Media 'test-hevc.mp4'
    $s = Start-Cone $exe $first (Join-Path $Media 'test.srt') $tag
    try {
        if (-not (Check-Window $s)) { return }
        Check "$tag`: a second start with a file plays it in the running window" {
            Wait-Rc 20
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ((Rc 'status') -notmatch 'test-h264') {
                if ($sw.Elapsed.TotalSeconds -gt 15) { throw "the first file does not play: '$((Rc 'status').Trim())'" }
                Start-Sleep -Milliseconds 500
            }
            Log "start (second) $exe --started-from-file $second"
            $p2 = Start-Process -FilePath $exe -ArgumentList @('--started-from-file', "`"$second`"") -WorkingDirectory (Split-Path -Parent $exe) -PassThru
            if (-not $p2.WaitForExit(15000)) {
                try { $p2.Kill() } catch {}
                throw 'the second start did not exit within 15 s (no hand-over to the running window)'
            }
            $sw.Restart()
            $status = ''
            while ($sw.Elapsed.TotalSeconds -lt 8) {
                $status = Rc 'status'
                if ($status -match 'test-hevc' -and $status -match 'play state: 3') { break }
                Start-Sleep -Milliseconds 500
            }
            if ($s.proc.HasExited) { throw 'the running Cone exited' }
            if ($status -notmatch 'test-hevc') {
                $queue = (Rc 'playlist') -split "`n" | Where-Object { $_ -match 'test-' } | ForEach-Object { $_.Trim() }
                throw "the running window still plays the first file after 8 s (queue: $($queue -join ' / '))"
            }
            if ($status -notmatch 'play state: 3') { throw "the second file is current but not playing: '$($status.Trim())'" }
            Shot "$tag-second"
            "the second start exited, the running window plays test-hevc.mp4 after $([math]::Round($sw.Elapsed.TotalSeconds, 1)) s"
        } | Out-Null
    } catch {
        Add-Result "$tag" 'fail' "unexpected error: $($_.Exception.Message)"
    } finally {
        Stop-Cone $s
    }
}

# ---------------------------------------------------------------- runs

Log "screen $([System.Windows.Forms.Screen]::PrimaryScreen.Bounds), Windows $([Environment]::OSVersion.Version)"

# 1. portable zip: a portable folder next to Cone.exe keeps every setting in the zip's folder
$zipExe = Get-ChildItem $ZipDir -Recurse -Filter Cone.exe | Select-Object -First 1
if (-not $zipExe) {
    Add-Result 'portable zip: Cone.exe' 'fail' "no Cone.exe in $ZipDir"
} else {
    $portable = Join-Path $zipExe.DirectoryName 'portable'
    New-Item -ItemType Directory -Force $portable | Out-Null
    $appData = Join-Path $env:APPDATA 'Cone'
    if (Test-Path $appData) { Log "note: $appData existed before the run" }
    $appDataBefore = Test-Path $appData

    Run-Session $zipExe.FullName 'h264' $true 'zip-h264'
    Check 'zip: settings land in the portable folder' {
        $ini = Join-Path $portable 'Cone\vlc-qt-interface.ini'
        if (-not (Test-Path $ini)) { throw "no $ini after the session (portable folder: $((Get-ChildItem $portable -Recurse -Name) -join ', '))" }
        if (-not $appDataBefore -and (Test-Path $appData)) { throw "$appData was created too: $((Get-ChildItem $appData -Recurse -Name) -join ', ')" }
        "portable: $((Get-ChildItem $portable -Recurse -File -Name | Select-Object -First 8) -join ', '); nothing in %APPDATA%\Cone"
    } | Out-Null
    Run-Session $zipExe.FullName 'hevc' $true 'zip-hevc'
    # before the first-start and open-in-running checks: after those (a Cone raised by a second
    # start, then ended) the runner no longer lets the next Cone take the foreground for a click
    # (build-windows #206)
    Check-CastDiscovery 'zip' $zipExe.FullName
    Check-RestoreQuestion $zipExe.FullName
    Check-UpNextNext $zipExe.FullName
    Check-QuitInstant $zipExe.FullName
    Check-PopupStack $zipExe.FullName
    Run-FirstStart $zipExe.FullName
    Run-OpenInRunning $zipExe.FullName
}

# 2. installer: silent install, the installed Cone plays, silent uninstall
$installDir = Join-Path $env:ProgramFiles 'Cone'
$installed = Check 'installer: silent install' {
    if (-not (Test-Path $Installer)) { throw "no installer at $Installer" }
    $p = Start-Process -FilePath $Installer -ArgumentList '/S' -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw "the installer ended with exit code $($p.ExitCode)" }
    if (-not (Test-Path (Join-Path $installDir 'Cone.exe'))) { throw "no $installDir\Cone.exe after the install" }
    $key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Cone'
    if (-not (Test-Path $key)) { throw "no uninstall entry $key" }
    "installed in $installDir ($((Get-ItemProperty $key).DisplayName) $((Get-ItemProperty $key).DisplayVersion))"
}
if ($installed) {
    Run-Session (Join-Path $installDir 'Cone.exe') 'h264' $false 'installed-h264'
    Check-CastDiscovery 'installed' (Join-Path $installDir 'Cone.exe') (Join-Path $installDir 'plugins\plugins.dat')
    # the desktop shortcut on a reinstall follows the install as it is (#73,
    # redesign/FIX_UPGRADE_SHORTCUT_NOTES.md): kept when it is there, not brought back once removed
    $lnk = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Cone Player.lnk'
    function Reinstall-Silent {
        $p = Start-Process -FilePath $Installer -ArgumentList '/S' -PassThru -Wait
        if ($p.ExitCode -ne 0) { throw "the installer ended with exit code $($p.ExitCode)" }
    }
    Check 'installer: desktop shortcut on a fresh install' {
        if (-not (Test-Path $lnk)) { throw "no $lnk after the install" }
        $lnk
    } | Out-Null
    Check 'installer: reinstall keeps the desktop shortcut' {
        if (-not (Test-Path $lnk)) { throw "no $lnk before the reinstall" }
        Reinstall-Silent
        if (-not (Test-Path $lnk)) { throw "the reinstall removed $lnk" }
        'still there'
    } | Out-Null
    Check 'installer: reinstall does not bring back a removed desktop shortcut' {
        Remove-Item $lnk -Force -ErrorAction SilentlyContinue
        if (Test-Path $lnk) { throw "could not remove $lnk" }
        Reinstall-Silent
        if (Test-Path $lnk) { throw "the reinstall created $lnk again" }
        if (-not (Test-Path (Join-Path $installDir 'Cone.exe'))) { throw "no $installDir\Cone.exe after the reinstall" }
        'not created again'
    } | Out-Null
    Check 'installer: silent uninstall' {
        $un = Join-Path $installDir 'uninstall.exe'
        if (-not (Test-Path $un)) { throw "no $un" }
        # _?= runs the uninstaller in place, so Start-Process waits for it
        $p = Start-Process -FilePath $un -ArgumentList '/S', "_?=$installDir" -PassThru -Wait
        if ($p.ExitCode -ne 0) { throw "the uninstaller ended with exit code $($p.ExitCode)" }
        if (Test-Path (Join-Path $installDir 'Cone.exe')) { throw "$installDir\Cone.exe is still there" }
        if (Test-Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Cone') { throw 'the uninstall entry is still there' }
        Remove-Item $un -Force -ErrorAction SilentlyContinue
        $left = if (Test-Path $installDir) { (Get-ChildItem $installDir -Recurse -Name) -join ', ' } else { '' }
        if ($left) { return @('warn', "removed; left in $installDir`: $left") }
        'removed, uninstall entry gone'
    } | Out-Null
}

# ---------------------------------------------------------------- summary

$fails = @($script:Results | Where-Object { $_.Status -eq 'fail' })
$warns = @($script:Results | Where-Object { $_.Status -eq 'warn' })
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('## Cone smoke checks (Windows runner)')
[void]$md.AppendLine('')
[void]$md.AppendLine("$(@($script:Results).Count) checks: $(@($script:Results | Where-Object { $_.Status -eq 'pass' }).Count) passed, $($warns.Count) warnings, $($fails.Count) failed.")
[void]$md.AppendLine('')
[void]$md.AppendLine('| Check | Result | Detail |')
[void]$md.AppendLine('|---|---|---|')
foreach ($r in $script:Results) {
    $icon = @{ pass = 'pass'; warn = '**warning**'; fail = '**FAILED**' }[$r.Status]
    [void]$md.AppendLine("| $($r.Check) | $icon | $($r.Detail -replace '\|', '/') |")
}
[void]$md.AppendLine('')
if ($script:Retries.Count) {
    [void]$md.AppendLine('Retries:')
    foreach ($r in $script:Retries) { [void]$md.AppendLine("- $r") }
} else { [void]$md.AppendLine('Retries: none.') }
$md.ToString() | Set-Content -Path (Join-Path $Out 'summary.md') -Encoding UTF8
if ($env:GITHUB_STEP_SUMMARY) { $md.ToString() | Add-Content -Path $env:GITHUB_STEP_SUMMARY -Encoding UTF8 }
foreach ($w in $warns) { Write-Host "::warning title=Cone smoke check::$($w.Check): $($w.Detail)" }
foreach ($f in $fails) { Write-Host "::error title=Cone smoke check failed::$($f.Check): $($f.Detail)" }
if ($fails.Count) { Log "$($fails.Count) check(s) failed"; exit 1 }
Log 'all checks passed'
exit 0
