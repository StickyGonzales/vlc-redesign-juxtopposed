# Beta gate for the public build (Cone): one command per part, or all of them.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File gate.ps1 -Part <part> [options]
#     parts: footprint, branding, screens, playback, quit, perf, soak, smoke, all, report
#     -Build <exe | build folder | key of builds in verify.local.json>   (default: public)
#     -Stock <exe | folder>   stock VLC 4 for -Part perf (default: stockBuild in verify.local.json)
#     -Zip <artifact zip>     for -Part branding (folder and file names inside it)
#     -Run <gate run folder>  add this part to an existing run (default: a new gate-<time> folder)
#     -Label <text>           appended to a new run folder's name
#     -SoakMin 20             soak length in minutes (dry run: 3)
#     -Quits 30               quit test tries (half Ctrl+Q, half WM_CLOSE)
#     -Accent '#8E42FF'       the non-default accent of the dark screens pass
#     -Only mkv,srt           playback: only these matrix files (ids in make_beta_media.py)
# README.md (next to verify.ps1) "Beta gate" has what each part checks and its pass rule.
param([Parameter(Mandatory)][ValidateSet('footprint', 'branding', 'screens', 'playback', 'quit', 'perf', 'soak', 'smoke', 'all', 'report')][string]$Part,
      [string]$Build = 'public', [string]$Stock = '', [string]$Zip = '', [string]$Run = '', [string]$Label = '',
      [int]$SoakMin = 20, [int]$Quits = 30, [string]$Accent = '#8E42FF', [string]$Phase = '', [string]$Only = '')
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'gatelib.ps1')
$cfg = $script:GateCfg

# --- run folder ------------------------------------------------------------------------------
if ($Run) { $RunDir = $Run } else {
    $RunDir = Join-Path $cfg.outRoot ('gate-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + $(if ($Label) { "-$Label" } else { '' }))
}
Assert-GateTarget $RunDir
New-Item -ItemType Directory -Force $RunDir | Out-Null
$script:GateLog = Join-Path $RunDir 'gate.log'
$exeSource = Resolve-GateExe $Build
Write-GLog "gate ${Part}: build $exeSource, run folder $RunDir"
$mediaList = (& python (Join-Path $GateHere 'make_beta_media.py') --list | ConvertFrom-Json)
$Media = @{}; foreach ($m in $mediaList.media) { $Media[$m.id] = $m | Add-Member -NotePropertyName path -NotePropertyValue (Join-Path $mediaList.dir $m.file) -PassThru }
function Assert-Media {
    $missing = @($Media.Values | Where-Object { -not (Test-Path -LiteralPath $_.path) } | ForEach-Object { $_.file })
    if ($missing) { throw "gate: media missing ($($missing -join ', ')): run python make_beta_media.py" }
}
function New-PartDir([string]$name) { $d = Join-Path $RunDir $name; Assert-GateTarget $d; New-Item -ItemType Directory -Force $d | Out-Null; return $d }
function Save-PartResult([string]$name, $result) { Save-Json $result (Join-Path (Join-Path $RunDir $name) 'result.json'); Write-GLog "${name}: $($result.verdict)" }
# no other test player may run from the builds folder while a part sends input
function Wait-Quiet {
    $end = (Get-Date).AddMinutes(30)
    while ($true) {
        $f = @(Get-ForeignTestPlayers $script:BuildsDir @($cfg.ignorePids | ForEach-Object { [int]$_ }))
        if (-not $f) { return }
        if ((Get-Date) -gt $end) { throw "another test player is still running (pid $($f.Id -join ', '))" }
        Write-GLog "  waiting: another test player is running (pid $($f.Id -join ', '))"; Start-Sleep 15
    }
}
# every shot also records the window titles and every UI Automation name on screen (branding)
function Save-GateShot($ctx, [string]$name, [string]$windows = 'main') {
    $step = [pscustomobject]@{ shot = $name; windows = $windows }
    Save-ScenarioShot $step $ctx
    $meta = $ctx.Shots[$ctx.Shots.Count - 1]
    $texts = New-Object System.Collections.ArrayList
    foreach ($w in (Get-PlayerWindows)) { if ($w.Class -ne 'Static' -and $w.Title) { [void]$texts.Add("window title: $($w.Title)") } }
    foreach ($r in (Get-UiaRects)) { if ($r.n) { [void]$texts.Add([string]$r.n) } }
    $meta.texts = @($texts | Select-Object -Unique)
    $meta.rel = (Join-Path $ctx.OutDir $meta.file).Substring($RunDir.Length + 1).Replace('\', '/')
}
function Invoke-GateSteps($steps, $ctx, [switch]$NoShots, [string]$prefix = '') {
    foreach ($s in @($steps)) {
        if (-not $s) { continue }
        if ($s.PSObject.Properties['shot']) {
            if (-not $NoShots) { Save-GateShot $ctx ($prefix + [string]$s.shot) ([string](Get-StepProp $s 'windows' 'main')) }
            continue
        }
        # gate step: {"hoverAbove": "<UIA name>", "dy": 150}: the pointer goes dy logical px above
        # that element's centre (the mini player's picture shows its buttons on hover)
        if ($s.PSObject.Properties['hoverAbove']) {
            $el = Find-UiaElement ([string]$s.hoverAbove) '' 3000
            if (-not $el) { throw "UIA element '$($s.hoverAbove)' not found" }
            $r = $el.Current.BoundingRectangle; $sc = Get-Scale (Get-MainWindow).Handle
            Move-Mouse ($r.X + $r.Width / 2) ($r.Y + $r.Height / 2 - [double]$s.dy * $sc) -Screen | Out-Null
            Start-Sleep -Milliseconds ([int](Get-StepProp $s 'after' 700)); continue
        }
        Invoke-Step $s $ctx
    }
}
function Start-GateSession([string]$exe, [string[]]$playerArgs, [double]$w = 1280, [double]$h = 720) {
    Wait-Quiet
    $m = Start-Player $exe $playerArgs
    Start-Sleep -Milliseconds 1500
    Set-PlayerSize $w $h | Out-Null
    $m = Get-MainWindow
    Invoke-FocusPlayer $m.Handle | Out-Null
    if (-not (Find-UiaElement 'Main interface' '' 15000)) { Write-GLog '  note: UI Automation did not show the interface within 15 s' }
    Test-UpdateDialog
    return $m
}
# the public build has no update checker: an update dialog / banner is a finding (screenshot of
# that window, listed by the branding part); a dialog is closed so it does not cover the player
$script:UpdateSeen = New-Object System.Collections.ArrayList
function Test-UpdateDialog([int]$timeoutMs = 2500) {
    $el = Find-UiaElement 'checking for updates' '' $timeoutMs 'contains'
    if (-not $el) { return }
    $text = [regex]::Replace([string]$el.Current.Name, '<[^>]+>', '')
    $main = Get-MainWindow 3
    # the dialog: another top-level window of the player (Qt widgets dialog); a banner inside the
    # main window has none
    $win = $null
    foreach ($w in (Get-PlayerWindows)) { if ($w.Class -ne 'Static' -and $w.Handle -ne $main.Handle -and $w.Width -gt 100 -and $w.Height -gt 60) { $win = $w } }
    $key = "$text|$(if ($win) { 'dialog' } else { 'banner' })"
    if (-not ($script:UpdateSeen | Where-Object { $_.key -eq $key })) {
        $dir = Join-Path $RunDir 'update-dialog'; New-Item -ItemType Directory -Force $dir | Out-Null
        $f = Join-Path $dir ('update-{0:D2}.png' -f ($script:UpdateSeen.Count + 1))
        try { if ($win) { Save-WindowShot $win.Handle $f | Out-Null } else { Save-WindowShot $main.Handle $f -Client | Out-Null } } catch {}
        [void]$script:UpdateSeen.Add([ordered]@{ key = $key; text = $text; window = $(if ($win) { $win.Title } else { 'banner in the main window' }); shot = "update-dialog/$(Split-Path $f -Leaf)" })
        Save-Json @($script:UpdateSeen) (Join-Path $dir 'seen.json')
        Write-GLog "  FINDING: update check $(if ($win) { "dialog '$($win.Title)'" } else { 'banner' }): '$text' ($(Split-Path $f -Leaf))"
    }
    if ($win) {
        $close = $null; $p = $null
        try { $root = [System.Windows.Automation.AutomationElement]::FromHandle($win.Handle); $close = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Close'))) } catch {}
        if ($close -and $close.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$p)) { Assert-Guard; $p.Invoke(); Start-Sleep -Milliseconds 600 }
        else { [RdVerifyWin2]::PostMessage($win.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null; Start-Sleep -Milliseconds 600 }
    }
}function Get-LogErrors([string]$logFile) {
    if (-not (Test-Path -LiteralPath $logFile)) { return @() }
    @(Select-String -LiteralPath $logFile -Pattern ' error: ' -SimpleMatch | Select-Object -First 30 | ForEach-Object { $_.Line.Trim() })
}

# --- footprint: read-only snapshots of the folders a non-portable player would write --------
function Get-FootprintTargets([string]$laneDir) {
    $t = [ordered]@{}
    foreach ($n in 'vlc', 'Cone') {
        $t["APPDATA\$n"] = Join-Path $env:APPDATA $n
        $t["LOCALAPPDATA\$n"] = Join-Path $env:LOCALAPPDATA $n
    }
    $t['ProgramFiles\VideoLAN\VLC'] = Join-Path $env:ProgramFiles 'VideoLAN\VLC'
    if (${env:ProgramFiles(x86)}) { $t['ProgramFiles(x86)\VideoLAN\VLC'] = Join-Path ${env:ProgramFiles(x86)} 'VideoLAN\VLC' }
    $t['lane (outside portable)'] = $laneDir
    return $t
}
function Get-FolderSnapshot([string]$dir, [string]$skip = '') {
    $files = [ordered]@{}
    if (-not (Test-Path -LiteralPath $dir)) { return $null }
    foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        if ($skip -and $f.FullName.StartsWith($skip + [char]92, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $h = $null; try { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA1).Hash } catch { $h = "unreadable: $($_.Exception.Message)" }
        $files[$f.FullName.Substring($dir.Length).TrimStart([char]92)] = [ordered]@{ size = $f.Length; mtime = $f.LastWriteTimeUtc.ToString('o'); sha1 = $h }
    }
    return $files
}
function Get-RegistrySnapshot {
    $out = [ordered]@{}
    foreach ($k in 'HKCU:\Software\VideoLAN', 'HKCU:\Software\Cone', 'HKCU:\Software\Classes\Applications\Cone.exe', 'HKCU:\Software\Classes\Applications\vlc.exe') {
        if (-not (Test-Path $k)) { $out[$k] = $null; continue }
        $vals = [ordered]@{}
        foreach ($item in @(Get-Item $k) + @(Get-ChildItem $k -Recurse -ErrorAction SilentlyContinue)) {
            foreach ($p in $item.Property) { $vals["$($item.Name)\$p"] = [string]$item.GetValue($p) }
        }
        $out[$k] = $vals
    }
    return $out
}
function Invoke-Footprint([string]$phase) {
    $dir = New-PartDir 'footprint'
    $exe = Sync-GateLane $exeSource
    $lane = Split-Path $exe
    $snap = [ordered]@{ time = (Get-Date).ToString('o'); phase = $phase; targets = [ordered]@{}; registry = Get-RegistrySnapshot }
    foreach ($e in (Get-FootprintTargets $lane).GetEnumerator()) {
        $skip = if ($e.Key -like 'lane*') { Join-Path $lane 'portable' } else { '' }
        $snap.targets[$e.Key] = [ordered]@{ path = $e.Value; files = (Get-FolderSnapshot $e.Value $skip) }
    }
    Save-Json $snap (Join-Path $dir "snapshot-$phase.json")
    Write-GLog "footprint: $phase snapshot ($(@($snap.targets.Values | ForEach-Object { if ($_.files) { $_.files.Count } else { 0 } } | Measure-Object -Sum).Sum) files)"
    if ($phase -ne 'after') { return }
    $before = Get-Content -Raw -LiteralPath (Join-Path $dir 'snapshot-before.json') | ConvertFrom-Json
    $changes = @()
    foreach ($k in $snap.targets.Keys) {
        $a = $before.targets.$k.files; $b = $snap.targets[$k].files
        $an = if ($a) { @($a.PSObject.Properties.Name) } else { @() }
        $bn = if ($b) { @($b.Keys) } else { @() }
        foreach ($n in $bn) { if ($an -notcontains $n) { $changes += "${k}: added $n" } elseif ($a.$n.sha1 -ne $b[$n].sha1 -or $a.$n.size -ne $b[$n].size) { $changes += "${k}: changed $n" } }
        foreach ($n in $an) { if ($bn -notcontains $n) { $changes += "${k}: removed $n" } }
        if (($null -eq $a) -ne ($null -eq $b)) { $changes += "${k}: folder $(if ($b) { 'created' } else { 'gone' })" }
    }
    foreach ($k in $snap.registry.Keys) {
        $a = $before.registry.$k; $b = $snap.registry[$k]
        if (($null -eq $a) -ne ($null -eq $b)) { $changes += "registry ${k}: $(if ($b) { 'created' } else { 'gone' })"; continue }
        if ($b) { foreach ($n in $b.Keys) { if (-not $a.PSObject.Properties[$n] -or $a.$n -ne $b[$n]) { $changes += "registry ${k}: $n" } } }
    }
    $res = [ordered]@{ part = 'footprint'; verdict = $(if ($changes) { 'FAIL' } else { 'pass' }); rule = 'nothing changed outside the build''s portable folder (APPDATA / LOCALAPPDATA vlc and Cone, installed VLC, the build folder, HKCU VideoLAN / Cone)'
        before = $before.time; after = $snap.time; targets = [ordered]@{}; changes = @($changes | Select-Object -First 200); change_count = $changes.Count }
    foreach ($k in $snap.targets.Keys) { $res.targets[$k] = $(if ($snap.targets[$k].files) { "$($snap.targets[$k].files.Count) files" } else { 'absent' }) }
    Save-PartResult 'footprint' $res
}

# --- branding: the build's names and version info; the texts collected by the screen parts ---
$UpdateBanner = '(?i)checking for updates|update is available|new version of|Re-check'
$BrandAllow = @('based on VLC media player', 'based on VLC \d[\w.\-]*', 'VLC media player by VideoLAN')
function Find-BrandHits([string]$text) {
    if ($text -notmatch '(?i)vlc') { return $false }
    $t = $text
    foreach ($a in $BrandAllow) { $t = [regex]::Replace($t, $a, '', 'IgnoreCase') }
    return ($t -match '(?i)vlc')
}
function Invoke-Branding {
    $dir = New-PartDir 'branding'
    $hits = @(); $internal = 0
    # exe version info
    $vi = (Get-Item -LiteralPath $exeSource).VersionInfo
    $ver = [ordered]@{}
    foreach ($p in 'ProductName', 'FileDescription', 'CompanyName', 'LegalCopyright', 'OriginalFilename', 'InternalName', 'ProductVersion', 'FileVersion', 'Comments') {
        $ver[$p] = [string]$vi.$p
        if (Find-BrandHits $ver[$p]) { $hits += [ordered]@{ where = 'exe version info'; what = "${p}: $($ver[$p])" } }
    }
    # folder and file names: the zip if given, else the build folder as extracted
    $names = @()
    if ($Zip) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $z = [IO.Compression.ZipFile]::OpenRead($Zip)
        try { $names = @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() }
        $nameSource = "zip $(Split-Path $Zip -Leaf)"
    } else {
        $root = Split-Path $exeSource
        while ((Split-Path $root -Leaf) -notmatch '^\d{6,}' -and (Split-Path $root)) { if ((Split-Path (Split-Path $root) -Leaf) -match '^\d{6,}') { $root = Split-Path $root; break }; $root = Split-Path $root }
        $names = @(Get-ChildItem -LiteralPath $root -Recurse -Force | Where-Object { $_.FullName -notlike '*\portable\*' -and $_.Name -ne 'portable' } | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') + $(if ($_.PSIsContainer) { '/' } else { '' }) })
        $nameSource = "build folder $(Split-Path $root -Leaf)"
    }
    foreach ($n in $names) {
        $leaf = ($n.TrimEnd('/') -split '/')[-1]
        if ($leaf -notmatch '(?i)vlc') { continue }
        # libVLC's own libraries and plugins keep their names (the engine); everything else a user sees is a hit
        if ($n -match '(?i)(^|/)plugins/|(^|/)lua/|^.*libvlc(core)?\.dll$') { $internal++; continue }
        $hits += [ordered]@{ where = $nameSource; what = $n }
    }
    # texts on screen: every shot of the screens / playback / smoke parts of this run
    $shotTexts = 0
    foreach ($rj in (Get-ChildItem -LiteralPath $RunDir -Recurse -Filter shots.json -ErrorAction SilentlyContinue)) {
        $shotList = Get-Content -Raw -LiteralPath $rj.FullName | ConvertFrom-Json
        foreach ($s in $shotList) {
            foreach ($t in @($s.texts)) {
                $shotTexts++
                if (Find-BrandHits $t) { $hits += [ordered]@{ where = 'screen'; what = $t; shot = $s.rel } }
                # the public build has no update checker: its banner must never appear
                if ($t -match $UpdateBanner) { $hits += [ordered]@{ where = 'screen (update banner)'; what = $t; shot = $s.rel } }
            }
        }
    }
    $us = Join-Path $RunDir 'update-dialog\seen.json'
    if (Test-Path -LiteralPath $us) { $seen = Get-Content -Raw -LiteralPath $us | ConvertFrom-Json; foreach ($x in $seen) { $hits += [ordered]@{ where = 'update check dialog at start'; what = $x.text; shot = $x.shot } } }
    $uniq = @($hits | Group-Object { "$($_.where)|$($_.what)" } | ForEach-Object { $x = $_.Group[0]; $x.count = $_.Count; $x.shots = @($_.Group | ForEach-Object { $_.shot } | Where-Object { $_ } | Select-Object -Unique -First 5); $x })
    $res = [ordered]@{ part = 'branding'; verdict = $(if ($uniq) { 'FAIL' } else { 'pass' })
        rule = "no user-visible 'VLC' where it should say Cone, and no update-check banner (the public build has no update checker); allowed: $($BrandAllow -join ' | '); libVLC's own DLL and plugin names are internal"
        version_info = $ver; names_checked = $names.Count; names_source = $nameSource; internal_names = $internal; screen_texts_checked = $shotTexts
        hits = $uniq; note = $(if ($shotTexts -eq 0) { 'no screen texts in this run yet: run -Part screens (or all) first' } else { '' }) }
    Save-PartResult 'branding' $res
}

# back to the plain player between screens: Escape, then the full library, the library sidebar
# or Settings closed if one is still open (so one failing close does not fail the next screens)
function Reset-PlayerView($table, $ctx) {
    Test-UpdateDialog 200
    Invoke-GateSteps $table.reset $ctx -NoShots
    if (Find-UiaElement 'beta' 'Button' 300) {
        Invoke-GateSteps @([pscustomobject]@{ hoverAbove = 'beta'; dy = 150 }) $ctx -NoShots
        Invoke-Step ([pscustomobject]@{ uia = 'Open the player'; optional = $true; after = 1000 }) $ctx
    }
    if (Find-UiaElement 'Library' 'Pane' 300) {
        Wiggle-Mouse 640 25; Start-Sleep -Milliseconds 400
        Invoke-Step ([pscustomobject]@{ uia = 'Library'; role = 'Button'; optional = $true; after = 900 }) $ctx
    }
    if (Find-UiaElement 'Search settings' '' 300) { Send-Keys '{ESC}'; Start-Sleep -Milliseconds 600 }
}


# --- screens --------------------------------------------------------------------------------
function Invoke-Screens {
    Assert-Media
    $table = Get-Content -Raw -Encoding UTF8 (Join-Path $GateHere 'screens.json') | ConvertFrom-Json
    $dir = New-PartDir 'screens'
    $exe = Sync-GateLane $exeSource
    $passes = @(@{ id = 'dark'; theme = 'dark'; accent = $Accent; full = $true }, @{ id = 'light'; theme = 'light'; accent = ''; full = $false })
    $items = @(); $shots = New-Object System.Collections.ArrayList
    foreach ($ps in $passes) {
        $pdir = Join-Path $dir $ps.id; New-Item -ItemType Directory -Force $pdir | Out-Null
        New-GateProfile $exe $ps.theme $ps.accent | Out-Null
        $logFile = Join-Path $pdir 'player-log.txt'
        $a = Get-GateArgs $exe @($table.args) @($Media[$table.media].path) $logFile
        Write-GLog "screens: $($ps.id) pass (theme $($ps.theme), accent $(if ($ps.accent) { $ps.accent } else { 'default' }))"
        try {
            Start-GateSession $exe $a ([double]$table.size[0]) ([double]$table.size[1]) | Out-Null
            foreach ($st in $table.states) {
                $ctx = New-StepContext $pdir $st.id
                $it = [ordered]@{ pass = $ps.id; id = $st.id; title = $st.title; source = $st.source; should = $st.should; status = 'ok'; error = $null; checks = @(); shots = @() }
                try {
                    Reset-PlayerView $table $ctx
                    Invoke-GateSteps $st.open $ctx
                    Invoke-GateSteps $st.action $ctx
                    if ($ps.full) {
                        $vi = 0
                        foreach ($v in @($st.close)) {
                            if ($vi -gt 0) { Reset-PlayerView $table $ctx; Invoke-GateSteps $st.open $ctx -NoShots }
                            Invoke-GateSteps $v.steps $ctx -NoShots
                            if ($st.PSObject.Properties['closed']) { Invoke-Step ([pscustomobject]@{ expect = $st.closed; check = "closes ($($v.id))" }) $ctx }
                            $vi++
                        }
                    } else {
                        foreach ($v in @($st.close | Select-Object -First 1)) { Invoke-GateSteps $v.steps $ctx -NoShots }
                    }
                } catch {
                    $it.status = 'error'; $it.error = $_.Exception.Message; Write-GLog "    ERROR $($st.id): $($it.error)"
                    if ($it.error -like 'GUARD:*') { throw }
                    try { Reset-PlayerView $table $ctx } catch {}
                }
                $it.checks = @($ctx.Checks); $it.shots = @($ctx.Shots | ForEach-Object { "$($ps.id)/$($_.file)"; foreach ($e in @($_.extra)) { if ($e) { "$($ps.id)/$($e.file)" } } })
                if (@($ctx.Checks | Where-Object { -not $_.pass }).Count) { $it.status = 'check failed' }
                foreach ($s in $ctx.Shots) { $s.pass = $ps.id; $s.state = $st.id; $s.should = $st.should; [void]$shots.Add($s) }
                $items += $it
            }
        } finally { Write-GLog "  quit: $(Stop-Players)" }
        $it2 = Get-LogErrors $logFile
        if ($it2) { Write-GLog "  player log: $($it2.Count) error line(s) (player-log.txt)" }
    }
    Save-Json @($shots) (Join-Path $dir 'shots.json')
    $bad = @($items | Where-Object { $_.status -ne 'ok' })
    $res = [ordered]@{ part = 'screens'; verdict = $(if ($bad) { 'FAIL' } else { 'measured pass, needs viewing' })
        rule = 'each screen opens, does its action and closes with each close variant (UI Automation checks), dark + accent and a light pass; a UI item passes only after its screenshots are viewed and match (review.json)'
        accent = $Accent; items = $items; shots = $shots.Count }
    Save-PartResult 'screens' $res
}

# --- playback matrix ------------------------------------------------------------------------
function Get-TrackState([string]$tab) {
    # the tracks popup on its tab: the radio buttons and which one is chosen
    $out = @()
    foreach ($w in (Get-PlayerWindows)) {
        if ($w.Class -eq 'Static') { continue }
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle)
        $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::RadioButton)
        foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
            $sel = $null; $p = $null
            if ($el.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$p)) { $sel = $p.Current.IsSelected }
            elseif ($el.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$p)) { $sel = ($p.Current.ToggleState -eq 'On') }
            if ($el.Current.IsOffscreen) { continue }
            $out += [pscustomobject]@{ Name = $el.Current.Name; Selected = $sel; El = $el }
        }
    }
    return $out
}
# chooses another track in the tracks popup. The switch is read from the player log after the
# player has quit (VLC writes its log file in blocks): a user's choice is logged as "ES track
# selected (forced): 'audio/3'". The popup's radio buttons do not report their checked state to
# UI Automation (noted in the detail).
function Invoke-TrackSwitch($ctx, [string]$button, [string]$tab, [string]$prefer, [string]$logFile, [string]$esKind) {
    Wiggle-Mouse 208 692; Start-Sleep -Milliseconds 400
    Invoke-Step ([pscustomobject]@{ uia = $button; role = 'Button'; after = 900 }) $ctx
    Invoke-Step ([pscustomobject]@{ uia = $tab; role = 'TabItem'; after = 700 }) $ctx
    $before = @(Get-TrackState $tab | Where-Object { $_.Name -and $_.Name -ne 'None' })
    $cur = @($before | Where-Object { $_.Selected }) | Select-Object -First 1
    $target = @($before | Where-Object { -not $_.Selected -and (-not $prefer -or $_.Name -like "*$prefer*") }) | Select-Object -First 1
    if (-not $target) { $target = @($before | Where-Object { -not $_.Selected }) | Select-Object -First 1 }
    if (-not $target) { Send-Keys '{ESC}'; return [ordered]@{ pass = $false; detail = "no other $tab track to choose (tracks: $(@($before.Name) -join ', '))" } }
    # subtitles: "None" first, so a track that is already on (an autodetected .srt) is chosen again
    if ($tab -eq 'Subtitles') {
        $none = @(Get-TrackState $tab | Where-Object { $_.Name -eq 'None' }) | Select-Object -First 1
        if ($none) { Invoke-UiaElement $none.El | Out-Null; Start-Sleep -Milliseconds 800 }
        $target = @(Get-TrackState $tab | Where-Object { $_.Name -eq $target.Name }) | Select-Object -First 1
    }
    Invoke-UiaElement $target.El | Out-Null; Start-Sleep -Milliseconds 1200
    Save-GateShot $ctx "$($tab.ToLower())-switched"
    $sel = @(Get-TrackState $tab | Where-Object { $_.Selected })
    Send-Keys '{ESC}'; Start-Sleep -Milliseconds 500
    $uiaNote = if ($sel) { "popup shows '$(@($sel.Name) -join ', ')' chosen" } else { 'the popup does not report the chosen track to UI Automation' }
    return [ordered]@{ pass = $null; es = $esKind; detail = "$tab track -> '$($target.Name)'; $uiaNote" }
}
# after the quit: the log shows the user's track choice
function Complete-TrackSwitch($r, [string]$logFile) {
    if (-not $r -or $null -ne $r.pass) { return $r }
    $hit = @(Select-String -LiteralPath $logFile -Pattern "ES track selected \(forced\): '([^']*/)?$($r.es)/" -ErrorAction SilentlyContinue)
    $r.pass = ($hit.Count -gt 0)
    $r.detail += "; player log: $(if ($hit) { ($hit[-1].Line -replace '^.*(ES track selected)', '$1') } else { 'no forced selection' })"
    return $r
}function Wait-ShownTime([int]$timeoutMs = 4000) {
    $end = (Get-Date).AddMilliseconds($timeoutMs)
    do { Wiggle-Mouse 640 30; $t = Get-ShownTime; if ($t) { return $t }; Start-Sleep -Milliseconds 300 } while ((Get-Date) -lt $end)
    return $null
}
function Invoke-Playback {
    Assert-Media
    $dir = New-PartDir 'playback'
    $exe = Sync-GateLane $exeSource
    $rows = @(); $shots = New-Object System.Collections.ArrayList
    $ids = @('mp4', 'mkv', 'avi', 'avi-noindex', 'mp3', 'flac', 'm4a', '4k60', 'srt')
    if ($Only) { $ids = @($ids | Where-Object { $Only.Split(',') -contains $_ }) }
    foreach ($id in $ids) {
        $m = $Media[$id]
        New-GateProfile $exe 'dark' '' | Out-Null
        $logFile = Join-Path $dir "$id-log.txt"
        $a = Get-GateArgs $exe @('--restore-playback-pos=0') @($m.path) $logFile
        $ctx = New-StepContext $dir $id
        $ra = $null; $rs = $null
        $row = [ordered]@{ id = $id; file = $m.file; about = $m.about; plays = $null; seeks = $null; audio_track = $null; subtitle_track = $null; dialog = $null; error = $null; log = (Split-Path $logFile -Leaf); log_errors = @(); checks = [ordered]@{} }
        Write-GLog "playback: $($m.file)"
        try {
            Start-GateSession $exe $a | Out-Null
            if ($id -eq 'avi-noindex') {
                # VLC asks what to do with the broken index: "Play as is" through UI Automation
                $btn = $null; $end = (Get-Date).AddSeconds(10)
                while (-not $btn -and (Get-Date) -lt $end) { $btn = Find-UiaElement 'Play as is' '' 500 'contains' }
                if ($btn) { Save-GateShot $ctx 'index-dialog' 'all'; Invoke-UiaElement $btn | Out-Null; $row.dialog = 'broken index dialog shown, answered "Play as is"' }
                else { $row.dialog = 'no index dialog seen within 10 s' }
                Start-Sleep -Milliseconds 800
            }
            Start-Sleep -Seconds 2
            $t1 = Wait-ShownTime; Start-Sleep -Seconds 3; $t2 = Wait-ShownTime
            $row.plays = [bool]($t1 -and $t2 -and $t2.Seconds -ge $t1.Seconds + 2)
            $row.checks.plays = "time $(if ($t1) { $t1.Text } else { '?' }) -> $(if ($t2) { $t2.Text } else { '?' }) over 3 s"
            Save-GateShot $ctx 'playing'
            $key = if ($m.duration -ge 120) { '^{RIGHT}' } else { '{RIGHT}' }; $jump = if ($m.duration -ge 120) { 60 } else { 10 }
            $note = ''
            for ($k = 0; $k -lt 2; $k++) {
                $s1 = Wait-ShownTime; Send-Keys $key; Start-Sleep -Milliseconds 1200; $s2 = Wait-ShownTime
                $d = if ($s1 -and $s2) { $s2.Seconds - $s1.Seconds } else { $null }
                if ($null -ne $d -and $d -ge $jump - 3) { break }
                $note = ' (the first key press was not taken)'
            }
            $row.seeks = [bool]($null -ne $d -and $d -ge $jump - 3 -and $d -le $jump + 5)
            $row.checks.seeks = "$(if ($key -eq '^{RIGHT}') { 'Ctrl+Right' } else { 'Right' }) (+$jump s): $(if ($s1) { $s1.Text } else { '?' }) -> $(if ($s2) { $s2.Text } else { '?' })$note"
            Save-GateShot $ctx 'seeked'
            if ($m.audio -ge 2) { $ra = Invoke-TrackSwitch $ctx 'Audio' 'Audio' 'Japanese' $logFile 'audio' }
            if ($m.subs -ge 1) { $rs = Invoke-TrackSwitch $ctx 'Subtitles' 'Subtitles' $(if ($id -eq 'mkv') { 'German' } else { '' }) $logFile 'spu'
                Start-Sleep -Seconds 4; Save-GateShot $ctx 'subtitle-shown' }
        } catch { $row.error = $_.Exception.Message; Write-GLog "    ERROR: $($row.error)"; if ($row.error -like 'GUARD:*') { Write-GLog "  quit: $(Stop-Players)"; throw } }
        finally { $row.quit = Stop-Players; Write-GLog "  quit: $($row.quit)" }
        $row.log_errors = @(Get-LogErrors $logFile)
        if ($ra) { $ra = Complete-TrackSwitch $ra $logFile; $row.audio_track = $ra.pass; $row.checks.audio_track = $ra.detail }
        if ($rs) { $rs = Complete-TrackSwitch $rs $logFile; $row.subtitle_track = $rs.pass; $row.checks.subtitle_track = $rs.detail }
        foreach ($s in $ctx.Shots) { $s.state = $id; $s.should = "playing $($m.file): picture (video) or the music view (audio), control bar with the current time; after a switch the chosen track"; [void]$shots.Add($s) }
        $row.shots = @($ctx.Shots | ForEach-Object { $_.file })
        $want = @($row.plays, $row.seeks) + $(if ($m.audio -ge 2) { @($row.audio_track) } else { @() }) + $(if ($m.subs -ge 1) { @($row.subtitle_track) } else { @() })
        $row.verdict = if (-not $row.error -and @($want | Where-Object { $_ -ne $true }).Count -eq 0) { 'pass' } else { 'FAIL' }
        Write-GLog "  ${id}: $($row.verdict) ($(($row.checks.Values) -join '; '))"
        $rows += $row
    }
    Save-Json @($shots) (Join-Path $dir 'shots.json')
    $res = [ordered]@{ part = 'playback'; verdict = $(if ($rows | Where-Object { $_.verdict -ne 'pass' }) { 'FAIL' } else { 'pass' })
        rule = 'each file plays (shown time advances), seeks (Ctrl+Right +60 s, the 60 s file Right +10 s, read on the time label) and switches audio / subtitle tracks where it has them (the chosen track is selected in the tracks popup); player log per file'
        rows = $rows }
    Save-PartResult 'playback' $res
}

# --- quit test --------------------------------------------------------------------------------
function Invoke-Quit {
    Assert-Media
    $dir = New-PartDir 'quit'
    $exe = Sync-GateLane $exeSource
    $lane = Split-Path $exe
    $files = @('mp4', 'mkv', 'avi', 'mp3', 'flac', 'm4a', '4k60', 'srt')
    $t0 = Get-Date; $tries = @()
    New-GateProfile $exe 'dark' '' | Out-Null
    for ($i = 1; $i -le $Quits; $i++) {
        $how = if ($i % 2) { 'Ctrl+Q' } else { 'WM_CLOSE' }
        $m = $Media[$files[($i - 1) % $files.Count]]
        $state = '?'; $sec = $null; $procId = $null; $note = ''
        try {
            Start-GateSession $exe (Get-GateArgs $exe @('--restore-playback-pos=0') @($m.path)) | Out-Null
            $proc = $script:StartedProcs[$script:StartedProcs.Count - 1]; $procId = $proc.Id
            Start-Sleep -Seconds 4
            $w = Get-MainWindow 3
            $sw = [Diagnostics.Stopwatch]::StartNew()
            if ($how -eq 'Ctrl+Q') {
                if (Invoke-FocusPlayer $w.Handle) { Send-Keys '^q' } else { throw 'GUARD: the player is not in front; Ctrl+Q not sent' }
            } else { [RdVerifyWin2]::PostMessage($w.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
            while ($sw.Elapsed.TotalSeconds -lt 15) {
                $q = Get-Process -Id $procId -ErrorAction SilentlyContinue
                if (-not $q -or $q.StartTime -ne $proc.StartTime) { break }
                Start-Sleep -Milliseconds 100
            }
            $q = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if (-not $q -or $q.StartTime -ne $proc.StartTime) { $state = 'clean'; $sec = [math]::Round($sw.Elapsed.TotalSeconds, 2) }
            elseif (Test-NoWindow $procId) { $state = 'stuck (no window, left untouched)'; $script:StuckPids += $procId; [void]$script:StartedProcs.Remove($proc) }
            else { $state = 'hung with a window'; $note = Stop-Players }
        } catch { $state = 'error'; $note = $_.Exception.Message; Write-GLog "    ERROR: $note"; if ($note -like 'GUARD:*') { Write-GLog "  $(Stop-Players)"; break } ; Write-GLog "  $(Stop-Players)" }
        $script:StartedProcs.Clear(); Update-Started
        $tries += [ordered]@{ try = $i; quit = $how; file = $m.file; state = $state; exit_seconds = $sec; pid = $procId; note = $note }
        Write-GLog ("quit {0}/{1} {2} ({3}): {4}{5}" -f $i, $Quits, $how, $m.file, $state, $(if ($sec) { " in $sec s" } else { '' }))
    }
    Start-Sleep -Seconds 3
    $left = @(Get-LanePlayers $lane)
    $events = @(Get-PlayerCrashEvents $t0 (Split-Path $exe -Leaf))
    $res = [ordered]@{ part = 'quit'; tries = $tries.Count
        clean = @($tries | Where-Object { $_.state -eq 'clean' }).Count
        ctrl_q_clean = @($tries | Where-Object { $_.state -eq 'clean' -and $_.quit -eq 'Ctrl+Q' }).Count
        wm_close_clean = @($tries | Where-Object { $_.state -eq 'clean' -and $_.quit -eq 'WM_CLOSE' }).Count
        exit_seconds_max = (@($tries | ForEach-Object { $_.exit_seconds } | Where-Object { $_ }) | Measure-Object -Maximum).Maximum
        players_left = @($left | ForEach-Object { "$($_.Id) ($($_.Threads.Count) threads)" }); crash_events = $events; detail = $tries
        rule = "$Quits quits over the matrix files, half Ctrl+Q, half WM_CLOSE: every one exits within 15 s, 0 Cone.exe left from the lane folder, 0 Application Error / WER / Application Hang events for the exe since the start (Get-WinEvent, read only)" }
    $res.verdict = if ($res.clean -eq $Quits -and $left.Count -eq 0 -and $events.Count -eq 0) { 'pass' } else { 'FAIL' }
    Save-PartResult 'quit' $res
}

# --- performance against stock VLC 4 ----------------------------------------------------------
# no input at all: the players start minimized and are shown without taking the foreground
# (SW_SHOWNOACTIVATE), the first frame is read from PrintWindow images of the player window only
function Get-CentreBrightness([IntPtr]$h) {
    $wr = New-Object RdVerifyWin2+RECT; [RdVerifyWin2]::GetWindowRect($h, [ref]$wr) | Out-Null
    $w = $wr.Right - $wr.Left; $ht = $wr.Bottom - $wr.Top
    if ($w -lt 50 -or $ht -lt 50) { return 0 }
    $bmp = New-Object System.Drawing.Bitmap $w, $ht
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
        [RdVerifyWin2]::PrintWindow($h, $hdc, 2) | Out-Null
        $g.ReleaseHdc($hdc); $g.Dispose()
        $sum = 0; $n = 0
        for ($y = [int]($ht * 0.4); $y -lt [int]($ht * 0.6); $y += 8) { for ($x = [int]($w * 0.4); $x -lt [int]($w * 0.6); $x += 8) { $sum += $bmp.GetPixel($x, $y).GetBrightness(); $n++ } }
        return $sum / [math]::Max(1, $n)
    } finally { $bmp.Dispose() }
}
function Measure-Build([string]$exe, [string]$kind, [string]$dir) {
    New-GateProfile $exe 'dark' '' | Out-Null
    $r = [ordered]@{ kind = $kind; exe = $exe }
    # startup: launch -> the centre of the window shows the light video picture
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $m = Start-Player $exe (Get-GateArgs $exe @('--restore-playback-pos=0') @($Media['mp4'].path)) -Minimized
    $r.window_ms = $sw.ElapsedMilliseconds
    $first = $null
    while ($sw.ElapsedMilliseconds -lt 20000) { if ((Get-CentreBrightness $m.Handle) -gt 0.3) { $first = $sw.ElapsedMilliseconds; break }; Start-Sleep -Milliseconds 20 }
    $r.first_frame_ms = $first
    $proc = $script:StartedProcs[$script:StartedProcs.Count - 1]
    foreach ($case in @(@{ id = 'mp4'; restart = $false }, @{ id = '4k60'; restart = $true })) {
        if ($case.restart) {
            Write-GLog "  $(Stop-Players -NoKeys)"; Start-Sleep 2
            $m = Start-Player $exe (Get-GateArgs $exe @('--restore-playback-pos=0') @($Media[$case.id].path)) -Minimized
            $proc = $script:StartedProcs[$script:StartedProcs.Count - 1]
        }
        Set-PlayerSize 1600 900 | Out-Null
        Start-Sleep -Seconds 5
        $lc = [ref]$null; $lt = [ref]$null; Get-ProcSample $proc $lc $lt | Out-Null
        $samples = @(); for ($i = 0; $i -lt 20; $i++) { Start-Sleep -Seconds 1; $samples += Get-ProcSample $proc $lc $lt }
        $cpu = @($samples | ForEach-Object { $_.cpu_pct })
        $mean = ($cpu | Measure-Object -Average).Average
        $sd = [math]::Sqrt((($cpu | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Average).Average)
        $r[$case.id] = [ordered]@{ cpu_pct = [math]::Round($mean, 2); cpu_sd = [math]::Round($sd, 2)
            private_mb = [math]::Round(($samples | Measure-Object private_mb -Average).Average, 0); private_spread_mb = [math]::Round(($samples | Measure-Object private_mb -Maximum).Maximum - ($samples | Measure-Object private_mb -Minimum).Minimum, 0)
            ws_mb = [math]::Round(($samples | Measure-Object ws_mb -Average).Average, 0) }
        $shot = Join-Path $dir "$kind-$($case.id).png"
        try { Save-WindowShot (Get-MainWindow).Handle $shot -Client | Out-Null; $r[$case.id].shot = (Split-Path $shot -Leaf) } catch {}
    }
    Write-GLog "  $(Stop-Players -NoKeys)"
    return $r
}
function Invoke-Perf {
    Assert-Media
    $dir = New-PartDir 'perf'
    $stockExe = Resolve-GateExe $(if ($Stock) { $Stock } elseif ($cfg.PSObject.Properties['stockBuild']) { [string]$cfg.stockBuild } else { throw 'gate: set stockBuild in verify.local.json or pass -Stock' })
    $coneExe = Sync-GateLane $exeSource
    $stockLane = Sync-GateLane $stockExe "verify-lane-stock-$(Get-BuildTag $stockExe)"
    # the PC must be quiet (total CPU of all processes over 3 s)
    $c0 = (Get-Process | ForEach-Object { try { $_.TotalProcessorTime.TotalSeconds } catch { 0 } } | Measure-Object -Sum).Sum; Start-Sleep 3
    $c1 = (Get-Process | ForEach-Object { try { $_.TotalProcessorTime.TotalSeconds } catch { 0 } } | Measure-Object -Sum).Sum
    $bg = [math]::Round(($c1 - $c0) / 3 / [Environment]::ProcessorCount * 100, 1)
    Wait-Quiet
    Write-GLog "perf: background CPU $bg %; stock first, then the build, back to back"
    $s = Measure-Build $stockLane 'stock' $dir
    $c = Measure-Build $coneExe 'build' $dir
    # tolerances: the noise seen between launches and within a 20 s sample (redesign/PERF.md
    # rounds 1-3: startup varies 150-300 ms launch to launch, RAM drifts 20-30 MB with the
    # machine state); CPU: twice the per-second spread of the stock sample, at least 1 point
    $cmp = @()
    $cmp += [ordered]@{ measure = 'startup to first frame (ms)'; stock = $s.first_frame_ms; build = $c.first_frame_ms; limit = [math]::Round($s.first_frame_ms + [math]::Max(150, 0.15 * $s.first_frame_ms), 0) }
    foreach ($k in 'mp4', '4k60') {
        $cmp += [ordered]@{ measure = "CPU playing $k (% of all cores)"; stock = $s[$k].cpu_pct; build = $c[$k].cpu_pct; limit = [math]::Round($s[$k].cpu_pct + [math]::Max(1.0, 2 * [math]::Max($s[$k].cpu_sd, $c[$k].cpu_sd)), 2) }
        $cmp += [ordered]@{ measure = "RAM private playing $k (MB)"; stock = $s[$k].private_mb; build = $c[$k].private_mb; limit = [math]::Round($s[$k].private_mb + [math]::Max(30, 0.10 * $s[$k].private_mb), 0) }
    }
    foreach ($x in $cmp) { $x.pass = ($null -ne $x.build -and $null -ne $x.stock -and $x.build -le $x.limit) }
    $res = [ordered]@{ part = 'perf'; background_cpu_pct = $bg; stock = $s; build = $c; comparison = $cmp
        rule = 'one back-to-back comparison with stock VLC 4 (same generated media, portable, window 1600x900, no input): the build is no worse than stock plus the noise allowance (startup max(150 ms, 15 %); CPU max(1 point, 2 x per-second spread); RAM max(30 MB, 10 %))' }
    $res.verdict = if ($bg -gt 30) { 'invalid (PC busy)' } elseif (@($cmp | Where-Object { -not $_.pass }).Count) { 'FAIL' } else { 'pass' }
    Save-PartResult 'perf' $res
}

# --- soak -------------------------------------------------------------------------------------
function Invoke-Soak {
    Assert-Media
    $dir = New-PartDir 'soak'
    $exe = Sync-GateLane $exeSource
    New-GateProfile $exe 'dark' '' @{ 'qt-pin-controls' = '1' } | Out-Null
    $files = @('mp4', 'mkv', 'avi', 'mp3', 'flac', 'm4a', '4k60', 'srt') | ForEach-Object { $Media[$_].path }
    $logFile = Join-Path $dir 'player-log.txt'
    $t0 = Get-Date
    $samples = @(); $resp = @(); $shots = @(); $died = $null
    Write-GLog "soak: $SoakMin min of continuous playback (loop over the matrix files), no input"
    try {
        $m = Start-Player $exe (Get-GateArgs $exe @('--loop', '--restore-playback-pos=0') $files $logFile) -Minimized
        $proc = $script:StartedProcs[$script:StartedProcs.Count - 1]
        # off every monitor (like the harness's UIA lanes): nothing covers the user's windows
        Set-PlayerSize 1280 720 -Offscreen 6 | Out-Null
        $lc = [ref]$null; $lt = [ref]$null; Get-ProcSample $proc $lc $lt | Out-Null
        $end = $t0.AddMinutes($SoakMin); $next = $t0.AddSeconds(30); $nextResp = $t0.AddSeconds(60); $nextShot = $t0.AddMinutes(1); $lastShown = ''
        while ((Get-Date) -lt $end) {
            Start-Sleep -Milliseconds 500
            if ($proc.HasExited) { $died = "the player exited (code $($proc.ExitCode)) after $([math]::Round(((Get-Date) - $t0).TotalMinutes, 1)) min"; break }
            if ((Get-Date) -ge $next) { $s = Get-ProcSample $proc $lc $lt; $s.min = [math]::Round(((Get-Date) - $t0).TotalMinutes, 2); $samples += $s; $next = $next.AddSeconds(30); Save-Json @($samples) (Join-Path $dir 'samples.json') }
            if ((Get-Date) -ge $nextResp) {
                $proc.Refresh(); $mw = $null; try { $mw = Get-MainWindow 2 } catch {}
                $hung = if ($mw) { [RdVerifyHang]::IsHungAppWindow($mw.Handle) } else { $true }
                $shown = Get-ShownTime
                $r = [ordered]@{ min = [math]::Round(((Get-Date) - $t0).TotalMinutes, 2); responding = $proc.Responding; hung_window = $hung; shown = $(if ($shown) { $shown.Text } else { $null }); title = $(if ($mw) { $mw.Title } else { $null }) }
                $r.progress = [bool]($shown -and ($shown.Text -ne $lastShown)); if ($shown) { $lastShown = $shown.Text }
                $resp += $r; $nextResp = $nextResp.AddSeconds(60)
            }
            if ((Get-Date) -ge $nextShot) {
                try { $f = Join-Path $dir ("soak-{0:D3}min.png" -f [int]((Get-Date) - $t0).TotalMinutes); Save-WindowShot (Get-MainWindow 2).Handle $f -Client | Out-Null; $shots += [ordered]@{ file = (Split-Path $f -Leaf); state = 'soak'; should = 'a matrix file playing (picture or music view) with the pinned control bar; never a frozen or empty window' } } catch {}
                $nextShot = $nextShot.AddMinutes($(if ($SoakMin -le 5) { 1 } else { 5 }))
            }
        }
    } finally { $quit = Stop-Players -NoKeys; Write-GLog "  quit: $quit" }
    $events = @(Get-PlayerCrashEvents $t0 (Split-Path $exe -Leaf))
    Save-Json @($shots) (Join-Path $dir 'shots.json')
    # memory: warm-up = the first 5 minutes (a quarter of a short dry run); growth = the highest
    # private bytes after the warm-up minus the mean of the first minute after it; trend = the
    # slope of a least-squares line through the samples after the warm-up
    $warm = [math]::Min(5, $SoakMin / 4)
    $post = @($samples | Where-Object { $_.min -ge $warm })
    $base = @($post | Where-Object { $_.min -lt $warm + 1 }); if (-not $base) { $base = @($post | Select-Object -First 2) }
    $baseMb = ($base | Measure-Object private_mb -Average).Average
    $growth = if ($post) { ($post | Measure-Object private_mb -Maximum).Maximum - $baseMb } else { $null }
    $slope = $null
    if ($post.Count -ge 4) {
        $mx = ($post | Measure-Object min -Average).Average; $my = ($post | Measure-Object private_mb -Average).Average
        $num = 0; $den = 0; foreach ($p in $post) { $num += ($p.min - $mx) * ($p.private_mb - $my); $den += ($p.min - $mx) * ($p.min - $mx) }
        if ($den -gt 0) { $slope = $num / $den * 60 }
    }
    $hGrowth = if ($post) { ($post | Measure-Object handles -Maximum).Maximum - ($base | Measure-Object handles -Average).Average } else { $null }
    $tGrowth = if ($post) { ($post | Measure-Object threads -Maximum).Maximum - ($base | Measure-Object threads -Average).Average } else { $null }
    $freezes = @($resp | Where-Object { -not $_.responding -or $_.hung_window })
    $stalls = @($resp | Select-Object -Skip 1 | Where-Object { -not $_.progress })
    $res = [ordered]@{ part = 'soak'; minutes = $SoakMin; samples = $samples.Count; checks = $resp.Count
        crash = $died; crash_events = $events; freezes = $freezes.Count; playback_stalls = $stalls.Count
        private_base_mb = [math]::Round($baseMb, 1); private_growth_mb = $(if ($null -ne $growth) { [math]::Round($growth, 1) } else { $null }); private_trend_mb_per_hour = $(if ($null -ne $slope) { [math]::Round($slope, 1) } else { $null })
        handle_growth = $hGrowth; thread_growth = $tGrowth; quit = $quit
        rule = 'no crash (process alive, no WER / Application Error event), no freeze (window responding and not hung at every minute check), the shown time moves at every minute check, private bytes after the 5 min warm-up grow < 50 MB and trend < 60 MB/h (a leak of 1 KB per frame at 30 fps is ~108 MB/h), handles grow < 500, threads < 20'
        sample_detail = $samples; check_detail = $resp; shots = @($shots | ForEach-Object { $_.file }) }
    $ok = (-not $died) -and (-not $events) -and (-not $freezes) -and (-not $stalls) -and ($null -ne $growth) -and ($growth -lt 50) -and (($null -eq $slope) -or ($slope -lt 60)) -and ($hGrowth -lt 500) -and ($tGrowth -lt 20)
    $res.verdict = if ($ok) { 'pass' } else { 'FAIL' }
    Save-PartResult 'soak' $res
}
if (-not ('RdVerifyHang' -as [type])) {
    Add-Type 'using System; using System.Runtime.InteropServices; public static class RdVerifyHang { [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr h); }'
}

# the Volume slider's value (1.0 = 100 %), waking the bars over the top bar, else over the bottom bar
function Get-VolumeShown {
    foreach ($p in @(@(640, 30), @(200, 700))) {
        Wiggle-Mouse $p[0] $p[1]; Start-Sleep -Milliseconds 400
        $el = Find-UiaElement 'Volume' 'Slider' 1500
        if ($el) { $v = Get-UiaValue $el; if ($v) { return [double]$v.Value } }
    }
    return $null
}
# --- smoke: 5 minutes after every fix -----------------------------------------------------------
function Invoke-Smoke {
    Assert-Media
    $dir = New-PartDir 'smoke'
    $exe = Sync-GateLane $exeSource
    New-GateProfile $exe 'dark' '' | Out-Null
    $logFile = Join-Path $dir 'player-log.txt'
    $ctx = New-StepContext $dir 'smoke'
    $c = [ordered]@{}
    $t0 = Get-Date
    $proc = $null
    try {
        Start-GateSession $exe (Get-GateArgs $exe @('--restore-playback-pos=0') @($Media['mkv'].path) $logFile) | Out-Null
        $proc = $script:StartedProcs[$script:StartedProcs.Count - 1]
        Start-Sleep 2; $a = Wait-ShownTime; Start-Sleep 3; $b = Wait-ShownTime
        $c.open_and_play = [ordered]@{ pass = [bool]($a -and $b -and $b.Seconds -ge $a.Seconds + 2); detail = "time $($a.Text) -> $($b.Text)" }
        Save-GateShot $ctx 'playing'
        # a key that is not taken is retried once and noted (a second press needed is a finding)
        $note = ''
        for ($k = 0; $k -lt 2; $k++) {
            Send-Keys ' '; Start-Sleep -Milliseconds 800; $a = Wait-ShownTime; Start-Sleep 2; $b = Wait-ShownTime
            if ($a -and $b -and $b.Seconds -eq $a.Seconds) { break }
            $note = ' (the first Space was not taken)'
        }
        $c.pause = [ordered]@{ pass = [bool]($a -and $b -and $b.Seconds -eq $a.Seconds); detail = "Space: paused at $($a.Text), 2 s later $($b.Text)$note" }
        Save-GateShot $ctx 'paused'
        $note = ''
        for ($k = 0; $k -lt 2; $k++) {
            $a = Wait-ShownTime; Send-Keys '^{RIGHT}'; Start-Sleep 1; $b = Wait-ShownTime
            if ($a -and $b -and ($b.Seconds - $a.Seconds) -ge 55) { break }
            $note = ' (the first Ctrl+Right was not taken)'
        }
        $c.seek = [ordered]@{ pass = [bool]($a -and $b -and ($b.Seconds - $a.Seconds) -ge 55 -and ($b.Seconds - $a.Seconds) -le 65); detail = "Ctrl+Right: $($a.Text) -> $($b.Text)$note" }
        Send-Keys ' '; Start-Sleep 1
        # volume with the keyboard (Ctrl+Down / Ctrl+Up), read back on the Volume slider
        $v0 = Get-VolumeShown
        for ($k = 0; $k -lt 6; $k++) { Send-Keys '^{DOWN}'; Start-Sleep -Milliseconds 150 }
        Start-Sleep -Milliseconds 500; $v1 = Get-VolumeShown
        for ($k = 0; $k -lt 6; $k++) { Send-Keys '^{UP}'; Start-Sleep -Milliseconds 150 }
        Start-Sleep -Milliseconds 500; $v2 = Get-VolumeShown
        $c.volume = [ordered]@{ pass = [bool]($null -ne $v0 -and $null -ne $v1 -and $v1 -lt $v0 - 0.1 -and [math]::Abs($v2 - $v0) -lt 0.03); detail = ("6x Ctrl+Down: {0:N2} -> {1:N2}, 6x Ctrl+Up: {2:N2}" -f $v0, $v1, $v2) }
        Wiggle-Mouse 640 30; Invoke-Step ([pscustomobject]@{ uia = 'Playback Settings'; role = 'Button'; after = 900 }) $ctx
        $tabs = @()
        foreach ($tab in 'Playback', 'Video', 'Audio', 'Subtitles') { Invoke-Step ([pscustomobject]@{ uia = $tab; role = 'TabItem'; after = 600 }) $ctx; Save-GateShot $ctx "sidebar-$($tab.ToLower())"; $tabs += $tab }
        Send-Keys '{ESC}'; Start-Sleep -Milliseconds 600
        $c.sidebar_tabs = [ordered]@{ pass = (-not (Find-UiaElement 'Open Advanced Settings' '' 800)); detail = "opened $($tabs -join ', '), closed with Escape" }
        Send-Keys '^p'; Start-Sleep -Milliseconds 1500
        $open = [bool](Find-UiaElement 'Search settings' '' 3000); Save-GateShot $ctx 'settings'
        Send-Keys '{ESC}'; Start-Sleep -Milliseconds 800
        $c.settings = [ordered]@{ pass = ($open -and -not (Find-UiaElement 'Search settings' '' 800)); detail = "open $open, closed with Escape" }
        $w = Get-MainWindow 3; Invoke-FocusPlayer $w.Handle | Out-Null; Send-Keys '^q'
        $sw = [Diagnostics.Stopwatch]::StartNew(); while (-not $proc.HasExited -and $sw.Elapsed.TotalSeconds -lt 15) { Start-Sleep -Milliseconds 100 }
        $c.quit = [ordered]@{ pass = $proc.HasExited; detail = $(if ($proc.HasExited) { "Ctrl+Q: exited in $([math]::Round($sw.Elapsed.TotalSeconds, 1)) s" } else { 'still running 15 s after Ctrl+Q' }) }
    } catch { $c.error = [ordered]@{ pass = $false; detail = $_.Exception.Message } }
    finally { $q = Stop-Players; Write-GLog "  quit: $q" }
    $events = @(Get-PlayerCrashEvents $t0 (Split-Path $exe -Leaf))
    if ($events) { $c.crash_events = [ordered]@{ pass = $false; detail = "$($events.Count) event(s)" } }
    foreach ($s in $ctx.Shots) { $s.state = 'smoke'; $s.should = 'the MKV in the player; the named sidebar tab / Settings dialog open' }
    Save-Json @($ctx.Shots) (Join-Path $dir 'shots.json')
    $res = [ordered]@{ part = 'smoke'; seconds = [math]::Round(((Get-Date) - $t0).TotalSeconds, 0); checks = $c; log_errors = @(Get-LogErrors $logFile)
        rule = 'open a file, play, pause, seek, volume, each sidebar tab, Settings, quit: each step checked through the time label / UI Automation, no crash event' }
    $res.verdict = if (@($c.Values | Where-Object { -not $_.pass }).Count) { 'FAIL' } else { 'pass' }
    Save-PartResult 'smoke' $res
}

# --- run the part(s) ----------------------------------------------------------------------------
$parts = if ($Part -eq 'all') { @('footprint-before', 'screens', 'playback', 'quit', 'perf', 'branding', 'soak', 'footprint-after') } else { @($Part) }
foreach ($p in $parts) {
    try {
        switch ($p) {
            'footprint' { Invoke-Footprint $(if ($Phase) { $Phase } elseif (Test-Path -LiteralPath (Join-Path $RunDir 'footprint\snapshot-before.json')) { 'after' } else { 'before' }) }
            'footprint-before' { Invoke-Footprint 'before' }
            'footprint-after' { Invoke-Footprint 'after' }
            'branding' { Invoke-Branding }
            'screens' { Invoke-Screens }
            'playback' { Invoke-Playback }
            'quit' { Invoke-Quit }
            'perf' { Invoke-Perf }
            'soak' { Invoke-Soak }
            'smoke' { Invoke-Smoke }
            'report' { }
        }
    } catch {
        Write-GLog "$p stopped: $($_.Exception.Message)"
        $name = ($p -replace '-(before|after|pre)$', '')
        try { Save-Json ([ordered]@{ part = $name; verdict = 'error'; error = $_.Exception.Message }) (Join-Path (New-PartDir $name) "error-$p.json") } catch {}
        if ($_.Exception.Message -like 'GUARD:*' -and $Part -eq 'all') { Write-GLog 'input guard: the remaining input parts are skipped; the no-input parts go on' }
    } finally {
        $left = Stop-Players -NoKeys
        if ($left -ne 'none running') { Write-GLog "cleanup: $left" }
    }
}
& python (Join-Path $GateHere 'report.py') $RunDir
"run folder: $RunDir"
