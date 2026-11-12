# Quit and audio-switch stall check on this PC (redesign/QUIT_STALLS_NOTES.md): plays a file,
# switches the audio track every 2.5 s, notes whether the time keeps moving after each switch,
# then quits through the cli and times how long the process takes to end. Run it on the same file
# with the plain VLC 4 build (vlc profile, vlc.exe) and with Cone (Cone.exe) to see whose bug a
# stall is: a stall with vlc.exe is VLC 4 core, a stall with Cone only is ours.
#
#   powershell -File quit-stall-repro.ps1 -Exe <vlc.exe or Cone.exe> -Video <file> [-Rounds 5] [-Switches 6] [-Out <dir>]
#
# Input goes only through VLC's cli on 127.0.0.1 (no keys, no mouse), so it can run while the PC is
# in use. Every process it starts is ended before it returns. Logs: <Out>\round<N>.log.
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Video,
    [int]$Rounds = 5,
    [int]$Switches = 6,
    [string]$Out = (Join-Path (Split-Path -Parent $Exe) 'quit-stall-repro')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Out | Out-Null
$Port = 42131

function Rc([string]$cmd) {
    $c = New-Object Net.Sockets.TcpClient
    $c.Connect('127.0.0.1', $Port)
    try {
        $s = $c.GetStream(); $s.ReadTimeout = 2000
        $w = New-Object IO.StreamWriter($s); $w.NewLine = "`n"; $w.AutoFlush = $true
        Start-Sleep -Milliseconds 250
        $buf = New-Object byte[] 65536
        while ($s.DataAvailable) { $null = $s.Read($buf, 0, $buf.Length) }
        $w.WriteLine($cmd)
        Start-Sleep -Milliseconds 400
        $text = ''
        while ($s.DataAvailable) { $n = $s.Read($buf, 0, $buf.Length); $text += [Text.Encoding]::UTF8.GetString($buf, 0, $n) }
        return $text
    } finally { $c.Close() }
}
function Rc-Time {
    $m = [regex]::Match((Rc 'get_time'), '(?m)^[>\s]*(\d+)\s*$')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $null
}

$summary = @()
for ($r = 1; $r -le $Rounds; $r++) {
    $log = Join-Path $Out "round$r.log"
    Remove-Item $log -ErrorAction SilentlyContinue
    $a = @('--no-qt-privacy-ask', '--input-repeat=50', '--file-logging', "--logfile=`"$log`"", '--log-verbose=2',
           '--extraintf=cli', "--rc-host=127.0.0.1:$Port", '--rc-quiet', "`"$Video`"")
    $p = Start-Process -FilePath $Exe -ArgumentList $a -WorkingDirectory (Split-Path -Parent $Exe) -PassThru
    $stalls = @(); $quit = $null
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $Port); $c.Close(); break }
            catch { if ($sw.Elapsed.TotalSeconds -gt 20) { throw 'the cli did not open' }; Start-Sleep -Milliseconds 300 }
        }
        Start-Sleep -Seconds 3
        $ids = @([regex]::Matches((Rc 'atrack'), '(?m)^\s*\|\s*(\d+) - ') | ForEach-Object { $_.Groups[1].Value })
        for ($k = 0; $k -lt $Switches -and $ids.Count -ge 2; $k++) {
            $target = $ids[($k + 1) % $ids.Count]
            $t1 = Rc-Time
            Rc "atrack $target" | Out-Null
            Start-Sleep -Milliseconds 2500
            $t2 = Rc-Time
            if ($null -eq $t1 -or $null -eq $t2 -or $t2 -eq $t1) { $stalls += "switch $($k + 1): $t1 -> $t2" }
        }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try { Rc 'quit' | Out-Null } catch {}
        if ($p.WaitForExit(12000)) { $quit = [math]::Round($sw.Elapsed.TotalSeconds, 2) }
    } finally {
        if (-not $p.HasExited) { try { $p.Kill() } catch {}; $p.WaitForExit(5000) | Out-Null }
    }
    Start-Sleep -Milliseconds 300
    $wd = (Test-Path $log) -and (Select-String -Path $log -Pattern 'did not finish quitting' -SimpleMatch -Quiet)
    $line = "round $r`: tracks $($ids -join ',') | stalls: $(if ($stalls) { $stalls -join '; ' } else { 'none' }) | quit: $(if ($null -ne $quit) { "$quit s" } else { 'HUNG, killed' })$(if ($wd) { ' (quit watchdog)' })"
    Write-Host $line
    $summary += $line
}
$summary | Set-Content -Path (Join-Path $Out 'summary.txt') -Encoding UTF8
