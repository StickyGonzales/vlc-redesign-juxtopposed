# Beta gate: shared helpers (dot-sourced by gate.ps1). Windows PowerShell 5.1.
# Builds on the verification harness (..\driver.ps1: guarded input, window-only capture, started
# processes only; ..\steps.ps1: the scenario steps; ..\config.ps1: verify.local.json).
#
# Write rules (Sticky's PC): the gate writes only into
#   <outRoot>\gate-*                       (reports, screenshots, logs)
#   <TEST_MEDIA_DIR>\builds\verify-lane*   (build copies and their portable profile)
#   <TEST_MEDIA_DIR>\builds\test-media\beta (generated media, make_beta_media.py)
# Assert-GateTarget refuses anything else before every write. The gate never deletes anything:
# build copies use robocopy /E (no /MIR, no /PURGE), profiles are reset by overwriting files.

$GateHere = Split-Path -Parent $MyInvocation.MyCommand.Path
$VerifyHere = Split-Path -Parent $GateHere
. (Join-Path $VerifyHere 'driver.ps1')
. (Join-Path $VerifyHere 'steps.ps1')
. (Join-Path $VerifyHere 'config.ps1')

$script:GateCfg = Get-VerifyConfig
$script:BuildsDir = Join-Path $script:GateCfg.testMediaDir 'builds'
$script:BetaMedia = Join-Path $script:BuildsDir 'test-media\beta'
$script:GateLog = $null

function Write-GLog([string]$m) {
    $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Host $line
    if ($script:GateLog) { Add-Content -LiteralPath $script:GateLog -Value $line -Encoding utf8 }
}
# the harness driver logs through $script:Log
$script:Log = { param($m) Write-GLog $m }

# every path the gate writes, mirrors or deletes must be inside one of the allowed roots
function Assert-GateTarget([string]$path) {
    $full = [IO.Path]::GetFullPath($path).TrimEnd([char]92)
    $roots = @(
        @{ root = [IO.Path]::GetFullPath($script:GateCfg.outRoot).TrimEnd([char]92); leaf = 'gate-*' },
        @{ root = $script:BuildsDir.TrimEnd([char]92); leaf = 'verify-lane*' },
        @{ root = (Join-Path $script:BuildsDir 'test-media'); leaf = 'beta' })
    foreach ($r in $roots) {
        if ($full.StartsWith($r.root + [char]92, [StringComparison]::OrdinalIgnoreCase)) {
            $first = $full.Substring($r.root.Length + 1).Split([char]92)[0]
            if ($first -like $r.leaf) { return }
        }
    }
    throw "gate: refusing to write outside the gate folders: $full"
}

# the build under test: an exe, a folder holding Cone.exe / vlc.exe, or a key of builds in
# verify.local.json ("public")
function Resolve-GateExe([string]$build) {
    if (-not $build) { $build = 'public' }
    if ($script:GateCfg.builds.PSObject.Properties[$build]) {
        $p = [string]$script:GateCfg.builds.$build
        if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $script:GateCfg.testMediaDir $p }
        $build = $p
    }
    if (Test-Path -LiteralPath $build -PathType Leaf) { return (Resolve-Path -LiteralPath $build).Path }
    if (Test-Path -LiteralPath $build -PathType Container) {
        foreach ($n in 'Cone.exe', 'vlc.exe') {
            $e = Get-ChildItem -LiteralPath $build -Recurse -Depth 3 -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($e) { return $e.FullName }
        }
    }
    throw "gate: no Cone.exe / vlc.exe found for '$build'"
}

# players still running from a lane folder (a stuck one must not be touched: the lane is skipped)
function Get-LanePlayers([string]$laneDir) {
    @(Get-Process Cone, vlc -ErrorAction SilentlyContinue | Where-Object {
        $pp = $null; try { $pp = $_.Path } catch {}
        $pp -and $pp.StartsWith($laneDir.TrimEnd([char]92) + [char]92, [StringComparison]::OrdinalIgnoreCase) })
}

# copies the build into its own lane folder <builds>\verify-lane-gate-<build id> (a new folder per
# build; robocopy /E only overwrites, nothing is ever deleted or purged, so a folder is never reused
# for another build). The network discovery plugins (UPnP, mDNS, SAP) are left out of the copy:
# they open listening sockets, and a new exe path would raise a Windows Firewall prompt.
# Returns the exe inside the lane.
function Get-BuildTag([string]$exe) {
    if ($exe -match '\\(\d{6,})(-[^\\]*)?\\') { return $Matches[1] }
    $h = (Get-FileHash -LiteralPath $exe -Algorithm SHA1).Hash.Substring(0, 10).ToLower()
    return "x$h"
}
function Sync-GateLane([string]$exe, [string]$lane = '') {
    $src = Split-Path $exe
    if (-not $lane) { $lane = "verify-lane-gate-$(Get-BuildTag $exe)" }
    if ($lane -notlike 'verify-lane*') { throw "gate: bad lane name $lane" }
    $dst = Join-Path $script:BuildsDir $lane
    if ([string]::Equals($src.TrimEnd([char]92), $dst.TrimEnd([char]92), [StringComparison]::OrdinalIgnoreCase)) { return $exe }
    Assert-GateTarget $dst
    $busy = Get-LanePlayers $dst
    if ($busy) { throw "gate: $lane has a player that never ended (pid $($busy.Id -join ', ')); not touched" }
    $marker = Join-Path $dst 'gate-source.txt'
    if ((Test-Path -LiteralPath $marker) -and ((Get-Content -Raw -LiteralPath $marker).Trim() -ne $exe)) {
        throw "gate: $lane holds another build ($((Get-Content -Raw -LiteralPath $marker).Trim())); use a new lane folder"
    }
    robocopy $src $dst /E /XD (Join-Path $src 'portable') /XF libupnp_plugin.dll libmicrodns_plugin.dll libsap_plugin.dll /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "gate: copying the build to $dst failed ($LASTEXITCODE)" }
    [IO.File]::WriteAllText($marker, $exe, (New-Object System.Text.UTF8Encoding $false))
    return (Join-Path $dst (Split-Path $exe -Leaf))
}

# the lane's portable profile, reset for a session by overwriting the gate's own files (nothing is
# deleted): vlcrc with the gate's settings (VLC fills in its defaults for the rest) and the Qt
# settings file (theme). The owner's profile is never used. The media library database, presets
# and profiles files the player writes stay in the lane's portable folder between sessions; the
# gate never finishes the onboarding, so no library folder is ever added.
#   $theme: 'dark' (Night, index 2, the default), 'light' (Day, index 1), 'system' (0)
#   $accent: '' (default) or '#RRGGBB' (qt-accent-color)
function New-GateProfile([string]$exe, [string]$theme = 'dark', [string]$accent = '', [hashtable]$vlcrc = @{}) {
    $portable = Join-Path (Split-Path $exe) 'portable'
    Assert-GateTarget $portable
    $busy = Get-LanePlayers (Split-Path $exe)
    if ($busy) { throw "gate: a player still runs from $(Split-Path $exe) (pid $($busy.Id -join ', '))" }
    New-Item -ItemType Directory -Force $portable | Out-Null
    $opts = [ordered]@{
        'qt-privacy-ask' = '0'          # no onboarding (its screen is tested with --qt-privacy-ask)
        'qt-cast-discovery' = '0'       # no renderer discovery socket (Windows Firewall prompt)
        'metadata-network-access' = '0' # no network lookups for the generated media
        'qt-accent-color' = $(if ($accent) { $accent } else { 'default' })
        'qt-pin-controls' = '0'
        'avi-index' = '0'               # ask (the matrix answers the dialog)
    }
    foreach ($k in $vlcrc.Keys) { $opts[$k] = [string]$vlcrc[$k] }
    $text = "# gate profile (redesign/tools/verify/gate)`n[core]`n"
    foreach ($k in $opts.Keys) { $text += "$k=$($opts[$k])`n" }
    [IO.File]::WriteAllText((Join-Path $portable 'vlcrc'), $text, (New-Object System.Text.UTF8Encoding $false))
    $scheme = @{ system = 0; light = 1; dark = 2 }[$theme]
    if ($null -eq $scheme) { throw "gate: unknown theme $theme" }
    # Qt settings: portable\<config dir>\vlc-qt-interface.ini; the folder is "Cone" or "vlc"
    # depending on the build's brand layer version, so both get the same file (the player keeps
    # the rest of its Qt settings, geometry and so on, at their defaults)
    $ini = "[MainWindow]`r`ncolor-scheme-index=$scheme`r`n"
    foreach ($d in 'Cone', 'vlc') {
        $qtDir = Join-Path $portable $d
        New-Item -ItemType Directory -Force $qtDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $qtDir 'vlc-qt-interface.ini'), $ini, (New-Object System.Text.UTF8Encoding $false))
    }
    return $portable
}
# player arguments the gate always passes (as the harness: no one-instance hand-over, no
# autoresize; vlc.exe also gets --no-qt-updates-notif, Cone has no update checker)
function Get-GateArgs([string]$exe, [string[]]$extra = @(), [string[]]$media = @(), [string]$logFile = '') {
    $a = @('--no-one-instance', '--no-qt-video-autoresize', '--no-video-title-show')
    if ((Split-Path $exe -Leaf) -like 'vlc*') { $a += '--no-qt-updates-notif' }
    if ($logFile) { $a += @('--file-logging', "--logfile=`"$logFile`"", '--log-verbose=2') }
    $a += @($extra | Where-Object { $_ })
    foreach ($m in $media) { $a += ('"{0}"' -f $m) }
    return $a
}

# Windows' own crash / hang records for the player since $since (read only)
function Get-PlayerCrashEvents([datetime]$since, [string]$exeName = 'Cone.exe') {
    $pat = [regex]::Escape($exeName)
    try {
        @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $since } -ErrorAction SilentlyContinue |
            Where-Object { ($_.ProviderName -in 'Application Error', 'Windows Error Reporting', 'Application Hang') -and $_.Message -match $pat } |
            ForEach-Object { [ordered]@{ time = $_.TimeCreated.ToString('o'); provider = $_.ProviderName; id = $_.Id; message = (($_.Message -split "`n" | Select-Object -First 4) -join ' ').Trim() } })
    } catch { @() }
}

# the current time shown by the control bar: the UIA element whose name is a time ("01:02",
# "00:01:02"), the left-most one on screen (the right one is the duration or "-remaining")
function Get-ShownTime {
    $best = $null
    foreach ($w in (Get-PlayerWindows)) {
        if ($w.Class -eq 'Static') { continue }
        try { $root = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle) } catch { continue }
        $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($el in $all) {
            try {
                $n = $el.Current.Name
                if ($n -notmatch '^(\d{1,2}:)?\d{1,2}:\d{2}$') { continue }
                $r = $el.Current.BoundingRectangle
                if ($r.IsEmpty) { continue }
                if (-not $best -or $r.X -lt $best.X) { $best = [pscustomobject]@{ Text = $n; X = $r.X } }
            } catch {}
        }
    }
    if (-not $best) { return $null }
    $p = $best.Text.Split(':') | ForEach-Object { [int]$_ }
    $sec = 0; foreach ($v in $p) { $sec = $sec * 60 + $v }
    return [pscustomobject]@{ Text = $best.Text; Seconds = $sec }
}

# process figures for the soak / perf samples
function Get-ProcSample($proc, [ref]$lastCpu, [ref]$lastTime) {
    $proc.Refresh()
    $now = Get-Date; $cpu = $proc.TotalProcessorTime
    $pct = $null
    if ($lastTime.Value) {
        $dt = ($now - $lastTime.Value).TotalSeconds
        if ($dt -gt 0) { $pct = [math]::Round(($cpu - $lastCpu.Value).TotalSeconds / $dt / [Environment]::ProcessorCount * 100, 2) }
    }
    $lastCpu.Value = $cpu; $lastTime.Value = $now
    # an object, not a dictionary: Measure-Object reads properties (perf and soak summaries)
    [pscustomobject][ordered]@{ t = $now.ToString('o'); min = $null; private_mb = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1); ws_mb = [math]::Round($proc.WorkingSet64 / 1MB, 1)
        handles = $proc.HandleCount; threads = $proc.Threads.Count; cpu_pct = $pct }
}

function Save-Json($obj, [string]$path) {
    Assert-GateTarget $path
    $obj | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
}
