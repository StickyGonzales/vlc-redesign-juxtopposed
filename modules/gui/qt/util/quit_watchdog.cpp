/*****************************************************************************
 * quit_watchdog.cpp: ends the process when a quit does not finish in time
 *****************************************************************************
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "quit_watchdog.hpp"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <thread>

#include <QSettings>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_media_library.h>

#include "qt.hpp"
#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"

#ifdef _WIN32
# include <windows.h>
#else
# include <unistd.h>
#endif

/* redesign (Decision (Claude) 2026-10-20, quit watchdog): a quit that never finishes (a
 * player thread stuck in teardown, redesign/QUIT_WATCHDOG_NOTES.md) must not leave Cone
 * running without a window. The plug-in is never unloaded (cannot_unload_broken_library in
 * qt.cpp), so the detached threads below always have their code. */

namespace {

constexpr auto kQuitTimeout = std::chrono::seconds(5);
/* a recording through the player is finalised when its input stops: give it time */
constexpr auto kQuitTimeoutRecording = std::chrono::seconds(30);
/* how long the error message may take before the process ends anyway */
constexpr auto kLogGrace = std::chrono::milliseconds(300);
/* at or past this position the core's own end-of-file handling owns the media's state */
constexpr double kResumeMaxPosition = 0.9;

std::atomic<bool> s_armed{false};

/* the interface object, for logging, while it exists; guarded by s_logLock */
std::mutex s_logLock;
qt_intf_t *s_intf = nullptr;

/* the resume position of the current media, as the core saves it when an input stops
 * (vlc_player_UpdateMLStates); only the player controller's cached values are read, so
 * nothing here waits for the player's lock, which a stuck player thread may hold */
void saveResumePosition(qt_intf_t *p_intf)
{
    PlayerController *player = p_intf->p_mainPlayerController;
    vlc_medialibrary_t *ml = vlc_ml_instance_get(p_intf);
    if (player == nullptr || ml == nullptr)
        return;
    if (player->getPlayingState() == PlayerController::PLAYING_STATE_STOPPED)
        return;
    if (!var_InheritBool(p_intf, "save-recentplay"))
        return;
    const double position = player->getPosition();
    if (!(position > 0. && position < kResumeMaxPosition))
        return;
    const QByteArray mrl = player->getMrl();
    if (mrl.isEmpty())
        return;
    vlc_ml_media_t *media = vlc_ml_get_media_by_mrl(ml, mrl.constData());
    if (media == nullptr)
    {
        msg_Dbg(p_intf, "quit watchdog: the media library does not know the current media, "
                        "its resume position is left to the core");
        return;
    }
    vlc_ml_media_update_progress(ml, media->i_id, position);
    vlc_ml_release(media);
}

void saveState(qt_intf_t *p_intf)
{
    if (p_intf->p_mi != nullptr)
        p_intf->p_mi->saveSettings(true);
    if (p_intf->mainSettings != nullptr)
        p_intf->mainSettings->sync();
    /* the core saves the VLC settings at exit unless they are ignored (src/libvlc.c) */
    if (!var_InheritBool(p_intf, "ignore-config") && config_SaveConfigFile(p_intf) != 0)
        msg_Warn(p_intf, "quit watchdog: could not save the settings");
    saveResumePosition(p_intf);
}

/* through the VLC logger (the Cone log) while the interface object exists; never blocks
 * the caller for long: the caller ends the process after kLogGrace whatever happens here */
void logFired(long long seconds)
{
    std::unique_lock<std::mutex> lock(s_logLock, std::try_to_lock);
    if (lock.owns_lock() && s_intf != nullptr)
        msg_Err(s_intf, "quit watchdog: Cone did not finish quitting within %lld s, ending the "
                        "process (the settings and the resume position were saved when the "
                        "quit started)", seconds);
}

[[noreturn]] void endProcess()
{
    fflush(nullptr);
#ifdef _WIN32
    TerminateProcess(GetCurrentProcess(), 0);
#endif
    _exit(0);
}

void startTimer(std::chrono::seconds timeout)
{
    std::thread([timeout]() {
        std::this_thread::sleep_for(timeout);
        const long long seconds = static_cast<long long>(timeout.count());
        fprintf(stderr, "quit watchdog: quit did not finish within %lld s, ending the process\n",
                seconds);
#ifdef _WIN32
        OutputDebugStringW(L"quit watchdog: quit did not finish in time, ending the process\n");
#endif
        std::thread(logFired, seconds).detach();
        std::this_thread::sleep_for(kLogGrace);
        endProcess();
    }).detach();
}

}

void QuitWatchdog::arm(qt_intf_t *p_intf)
{
    if (s_armed.exchange(true))
        return;

    PlayerController *player = p_intf->p_mainPlayerController;
    const bool recording = player != nullptr && player->isRecording();
    {
        std::lock_guard<std::mutex> lock(s_logLock);
        s_intf = p_intf;
    }
    /* the timer runs before anything else, so a save that blocks cannot keep Cone alive */
    startTimer(recording ? kQuitTimeoutRecording : kQuitTimeout);
    msg_Dbg(p_intf, "quit watchdog: armed, Cone ends itself if it is still running in %lld s",
            static_cast<long long>((recording ? kQuitTimeoutRecording : kQuitTimeout).count()));

    saveState(p_intf);
}

void QuitWatchdog::armWithoutSaving()
{
    if (s_armed.exchange(true))
        return;
    startTimer(kQuitTimeout);
}

void QuitWatchdog::interfaceClosing()
{
    std::lock_guard<std::mutex> lock(s_logLock);
    s_intf = nullptr;
}
