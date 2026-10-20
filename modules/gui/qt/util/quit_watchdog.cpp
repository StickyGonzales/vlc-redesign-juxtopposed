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
#include "player/player_controller.hpp"

#ifdef _WIN32
# include <windows.h>
#else
# include <unistd.h>
#endif

/* redesign (Decision (Claude) 2026-10-20, quit watchdog): a quit that never finishes (a
 * player thread stuck in teardown, redesign/QUIT_WATCHDOG_NOTES.md) must not leave Cone
 * running without a window. The plug-in is never unloaded (cannot_unload_broken_library in
 * qt.cpp), so the detached thread below always has its code. */

namespace {

constexpr auto kQuitTimeout = std::chrono::seconds(5);

std::atomic<bool> s_armed{false};

/* the interface object, for logging, while it exists; guarded by s_logLock */
std::mutex s_logLock;
qt_intf_t *s_intf = nullptr;

/* the resume position of the current media, as the core saves it when an input stops
 * (vlc_player_UpdateMLStates), read from the player controller's cached values so that
 * nothing here waits for the player's lock */
void saveResumePosition(qt_intf_t *p_intf)
{
    PlayerController *player = p_intf->p_mainPlayerController;
    vlc_medialibrary_t *ml = vlc_ml_instance_get(p_intf);
    if (player == nullptr || ml == nullptr || !player->hasInput())
        return;
    if (!var_InheritBool(p_intf, "save-recentplay"))
        return;
    const double position = player->getPosition();
    if (!(position > 0. && position < 1.))
        return;
    const QByteArray mrl = player->getUrl().toEncoded();
    if (mrl.isEmpty())
        return;
    vlc_ml_media_t *media = vlc_ml_get_media_by_mrl(ml, mrl.constData());
    if (media == nullptr)
        return; /* unknown to the media library: the core adds it when the input stops */
    vlc_ml_media_update_progress(ml, media->i_id, position);
    vlc_ml_release(media);
}

void logFired()
{
    {
        std::lock_guard<std::mutex> lock(s_logLock);
        if (s_intf != nullptr)
        {
            msg_Err(s_intf, "quit watchdog: Cone did not finish quitting within %lld s, "
                            "ending the process (settings and resume position were saved "
                            "when the quit started)",
                    static_cast<long long>(kQuitTimeout.count()));
            return;
        }
    }
    /* the interface is gone: VLC's logger may be going too */
    fprintf(stderr, "quit watchdog: quit did not finish within %lld s, ending the process\n",
            static_cast<long long>(kQuitTimeout.count()));
#ifdef _WIN32
    OutputDebugStringW(L"quit watchdog: quit did not finish in time, ending the process\n");
#endif
}

[[noreturn]] void endProcess()
{
    fflush(nullptr);
#ifdef _WIN32
    TerminateProcess(GetCurrentProcess(), 0);
#endif
    _exit(0);
}

}

void QuitWatchdog::arm(qt_intf_t *p_intf)
{
    if (s_armed.exchange(true))
        return;

    if (p_intf->mainSettings != nullptr)
        p_intf->mainSettings->sync();
    if (config_SaveConfigFile(p_intf) != 0)
        msg_Warn(p_intf, "quit watchdog: could not save the settings");
    saveResumePosition(p_intf);

    {
        std::lock_guard<std::mutex> lock(s_logLock);
        s_intf = p_intf;
    }
    msg_Dbg(p_intf, "quit watchdog: armed, Cone ends itself if it is still running in %lld s",
            static_cast<long long>(kQuitTimeout.count()));

    std::thread([]() {
        std::this_thread::sleep_for(kQuitTimeout);
        logFired();
        endProcess();
    }).detach();
}

void QuitWatchdog::interfaceClosing()
{
    std::lock_guard<std::mutex> lock(s_logLock);
    s_intf = nullptr;
}
