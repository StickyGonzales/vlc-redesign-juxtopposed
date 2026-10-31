/*****************************************************************************
 * quit_watchdog.hpp: ends the process when a quit does not finish in time
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
#ifndef QUIT_WATCHDOG_HPP
#define QUIT_WATCHDOG_HPP

#include <functional>

struct qt_intf_t;

namespace QuitWatchdog
{

/* Called when the user quits (main window closed, Quit, Ctrl+Q). Starts a timer: if the
 * process is still running 5 s later (30 s while recording), it ends itself, so no player
 * is ever left running without a window. Then saves what a forced end would lose (the
 * interface state and window geometry, the Qt and VLC settings, the resume position of
 * the current media). Only the first arm counts. Interface thread only. */
void arm(qt_intf_t *p_intf);

/* For a quit that did not start in the interface (--play-and-exit, vlc://quit, a remote
 * control): the timer only, from the interface module's Close. */
void armWithoutSaving(qt_intf_t *p_intf);

/* Called from the interface module's Close: the interface object goes away, the watchdog
 * logs through the libvlc instance from then on. */
void interfaceClosing(qt_intf_t *p_intf);

/* redesign: what a forced end of a quit would wrongly leave for the next start. A quit is not a
 * crash: qt.cpp registers the queue's crash recovery (ModelRecoveryAgent) here in the Cone
 * build; it is dropped when a quit starts (arm, and the interface module's Close for a quit
 * that started elsewhere), so a quit the watchdog ends offers no "restore the playlist" at the
 * next start. A crash outside a quit still offers it. Interface thread only; an empty function
 * unregisters. */
void setDiscardOnQuit(std::function<void()> discard);
void discardForQuit();

}

#endif // QUIT_WATCHDOG_HPP
