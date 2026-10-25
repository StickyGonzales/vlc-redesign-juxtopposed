@echo off
setlocal EnableExtensions
rem Test VLC Redesign: downloads the newest successful build of the redesign branch from
rem GitHub Actions and starts it in portable mode (its own settings, never the installed VLC's).
rem Builds are downloaded to "%BUILDS%\<run number>" (a run that is already there is not
rem downloaded again) and copied into a fixed folder the player runs from, so Windows Firewall
rem asks only once per program path and the portable settings stay in one place:
rem   "public" builds (Cone.exe, the default since Decision 50) -> builds\current-public
rem   "vlc" builds (vlc.exe, started by hand with the vlc profile) -> builds\current
title Test VLC Redesign

set "REPO=StickyGonzales/vlc-redesign-juxtopposed"
set "BRANCH=redesign"
rem the builds folder of this PC: set BUILDS in test-latest.local.cmd next to this script
rem (gitignored, never committed); default: a folder in the user profile
set "BUILDS=%USERPROFILE%\VLC Redesign\builds"
if exist "%~dp0test-latest.local.cmd" call "%~dp0test-latest.local.cmd"

where gh >nul 2>nul
if errorlevel 1 (
    echo The GitHub command line tool "gh" was not found.
    echo Install it from https://cli.github.com and run "gh auth login" once.
    goto :fail
)

gh auth status >nul 2>nul
if errorlevel 1 (
    echo You are not logged in to GitHub in the command line tool.
    echo Open a terminal, run:  gh auth login   and then start this again.
    goto :fail
)

echo Looking for the newest successful build of the %BRANCH% branch...
set "RUN="
for /f "usebackq delims=" %%i in (`gh run list -R %REPO% -b %BRANCH% -w build-windows -s success -L 1 --json databaseId --jq ".[0].databaseId"`) do set "RUN=%%i"
if not defined RUN (
    echo No finished successful build was found yet.
    echo A build takes about 50 minutes after a push; try again later.
    echo Builds: https://github.com/%REPO%/actions
    goto :fail
)
echo Newest successful build: run %RUN%

set "DEST=%BUILDS%\%RUN%"
call :find
if defined VLCDIR (
    echo This build is already downloaded.
) else (
    echo Downloading build %RUN% ^(about 90 MB, a few minutes^)...
    if not exist "%DEST%" mkdir "%DEST%"
    rem every artifact of the run: vlc-redesign-win64-public ^(Cone^) or vlc-redesign-win64 ^(vlc^)
    gh run download %RUN% -R %REPO% -D "%DEST%"
    if errorlevel 1 (
        echo The download failed. The build may be too old ^(builds are kept 14 days^)
        echo or the network is down. Details are above.
        goto :fail
    )
    call :find
)
if not defined VLCDIR (
    echo The download finished but neither Cone.exe nor vlc.exe was found in "%DEST%".
    goto :fail
)

rem the build in the fixed folder cannot be replaced while it runs
powershell -NoProfile -Command "if (Get-Process vlc, Cone -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '%CURRENT%\*' }) { exit 1 }"
if errorlevel 1 (
    echo The player is still running from "%CURRENT%". Close it and start this again.
    goto :fail
)

echo Copying build %RUN% into "%CURRENT%" ^(its settings in "portable" are kept^)...
rem /MIR makes the folder an exact copy of the build; /XD keeps the portable settings folder
robocopy "%VLCDIR%" "%CURRENT%" /MIR /XD "%CURRENT%\portable" /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
    echo Copying the build failed.
    goto :fail
)
> "%CURRENT%\build-run.txt" echo %RUN%

rem portable mode: a "portable" folder next to the exe keeps vlcrc, the interface settings and
rem the media library, never the installed VLC's
if not exist "%CURRENT%\portable" mkdir "%CURRENT%\portable"

echo Starting %EXE% from build %RUN%...
rem Cone builds have no update checker, so that option only goes to vlc.exe
set "EXTRA="
if /i "%EXE%"=="vlc.exe" set "EXTRA=--no-qt-updates-notif"
start "" /D "%CURRENT%" "%CURRENT%\%EXE%" --no-qt-privacy-ask %EXTRA%
exit /b 0

rem finds the downloaded player: sets VLCDIR, EXE and CURRENT (the fixed folder for that exe)
:find
set "VLCDIR="
rem public builds since the beta branding: the zip's top folder is Cone-<version>[-suffix]
for /d %%D in ("%DEST%\vlc-redesign-win64-public\Cone-*") do (
    if exist "%%D\Cone.exe" (
        set "VLCDIR=%%D"
        set "EXE=Cone.exe"
        set "CURRENT=%BUILDS%\current-public"
        exit /b 0
    )
)
if exist "%DEST%\vlc-redesign-win64-public\vlc-4.0.0-dev\Cone.exe" (
    set "VLCDIR=%DEST%\vlc-redesign-win64-public\vlc-4.0.0-dev"
    set "EXE=Cone.exe"
    set "CURRENT=%BUILDS%\current-public"
    exit /b 0
)
if exist "%DEST%\vlc-redesign-win64\vlc-4.0.0-dev\vlc.exe" (
    set "VLCDIR=%DEST%\vlc-redesign-win64\vlc-4.0.0-dev"
    set "EXE=vlc.exe"
    set "CURRENT=%BUILDS%\current"
    exit /b 0
)
rem builds downloaded by the earlier version of this script (one artifact, no subfolder)
if exist "%DEST%\vlc-4.0.0-dev\vlc.exe" (
    set "VLCDIR=%DEST%\vlc-4.0.0-dev"
    set "EXE=vlc.exe"
    set "CURRENT=%BUILDS%\current"
)
exit /b 0

:fail
echo.
pause
exit /b 1
