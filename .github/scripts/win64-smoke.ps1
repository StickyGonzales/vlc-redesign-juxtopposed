# Smoke checks of a Cone Player Windows build on a GitHub Windows runner (redesign/CI_SMOKE_NOTES.md).
#
#   powershell -File win64-smoke.ps1 -ZipDir <unpacked portable zip> -Installer <setup .exe> -Media <dir> -Out <dir>
#
# Checks, each with one retry when it fails (the summary lists every retry):
#   portable zip, H.264 and HEVC: the main window appears, the playback time advances, the
#   subtitle file loads, a click on the seek bar moves playback, Settings opens (Ctrl+P), quitting
#   (Ctrl+Q) ends the process; H.264: within 3 s and without the quit watchdog; HEVC: a quit the
#   watchdog ends is a warning (known HEVC quit stall, STATUS.md), only a process that outlives the
#   watchdog fails; the settings land in the zip's portable folder, none in %APPDATA%\Cone.
#   installer: a silent install, the installed Cone plays, a silent uninstall removes it.
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
# a key with modifiers: virtual-key codes, e.g. Keys 0x11 0x50 = Ctrl+P. With the hardware scan
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

# ---------------------------------------------------------------- one Cone session

# starts Cone with a video and its subtitles; returns the process, its window and its log file
function Start-Cone([string]$exe, [string]$video, [string]$subs, [string]$tag) {
    $log = Join-Path $Out "cone-$tag.log"
    Remove-Item $log -ErrorAction SilentlyContinue
    $a = @('--no-qt-privacy-ask', '--no-qt-video-autoresize', '--input-repeat=50',
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
            Check-Settings $s | Out-Null
            Check-Seek $s | Out-Null
            Check-FsTopBar $s | Out-Null
            Check-MenuClick $s | Out-Null
            Check-FsMenuClick $s | Out-Null
            # the shortcut again, once the seek bar has had a click (it holds the keyboard focus)
            Check "$tag`: Settings opens after a seek bar click" { Open-Settings $s } | Out-Null
        }
        Check-Quit $s ($codec -eq 'hevc') $exe $video $subs | Out-Null
        Check-PluginsLoad $s | Out-Null
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
