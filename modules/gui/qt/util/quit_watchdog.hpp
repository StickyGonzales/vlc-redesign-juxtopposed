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

struct qt_intf_t;

namespace QuitWatchdog
{

/* Called when the user quits (main window closed, Quit, Ctrl+Q). Saves what a forced end
 * would lose (the Qt interface settings, the VLC settings, the resume position of the
 * current media) and starts a timer: if the process is still running 5 s later, it ends
 * itself, so no player is ever left running without a window. Only the first call arms
 * the watchdog. Interface thread only. */
void arm(qt_intf_t *p_intf);

/* Called from the interface module's Close: the interface object goes away, the watchdog
 * stops logging through it. */
void interfaceClosing();

}

#endif // QUIT_WATCHDOG_HPP
