/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/*
 * redesign: thread_local destructors run before the thread_local storage is freed (Windows,
 * GCC's libstdc++ with winpthreads, as in VideoLAN's win64 build image).
 *
 * There, `thread_local` variables live in emulated TLS (libgcc emutls) and the destructors of
 * the non-trivial ones are kept by libstdc++'s __cxa_thread_atexit; both are pthread keys of
 * the winpthreads copy linked into this plugin, and a thread's key destructors run at its exit
 * in the order the keys were created. Qt's first thread_local access normally creates the
 * emutls key first, so an exiting thread frees its thread_local storage and only then runs
 * the destructors of Qt's thread_local objects (animation timers, logging, ...) on the freed
 * memory. When that memory is already unmapped, the destructor faults inside the thread's
 * exit, the system loader swallows the fault, and winpthreads' key lock stays read locked by
 * a thread that is gone. At process exit libstdc++ deletes its key from this DLL's detach
 * code, waits for that lock forever, and the process never finishes terminating (bug log in
 * redesign/BUILD_NOTES.md, "Cone.exe stuck terminating after quit").
 *
 * Registering a no-op destructor before anything in this plugin touches a thread_local
 * creates libstdc++'s key first, so its destructors run while the storage is still valid.
 * It is harmless where the toolchain works differently (native TLS, the C runtime's own
 * __cxa_thread_atexit_impl): the first registration just happens earlier.
 *
 * Known limits: libstdc++ now registers its process exit handler first, so at this DLL's
 * detach the thread_local destructors of the thread that loaded the plugin run after the
 * plugin's static destructors (expected to be only the no-op one: the interface runs on its
 * own thread, the loading thread only opens and closes it). A thread_local first created by another thread_local's destructor still
 * gets freed before its own destructor runs. Other plugins with C++ thread_locals are not
 * covered (none known).
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <cstddef> /* defines __GLIBCXX__ with libstdc++ */

#if defined(_WIN32) && defined(__GLIBCXX__)

#include <cxxabi.h>

#ifndef _GLIBCXX_CDTOR_CALLABI
# define _GLIBCXX_CDTOR_CALLABI
#endif

namespace {

// the calling convention libstdc++ expects of destructors (__thiscall on 32-bit mingw)
void _GLIBCXX_CDTOR_CALLABI noDestructor(void*)
{
}

// before the default priority constructors of this plugin and of the Qt libraries in it
__attribute__((constructor(101)))
void createThreadExitKeyFirst()
{
    static char object;
    abi::__cxa_thread_atexit(noDestructor, &object, nullptr);
}

} // namespace

#endif
