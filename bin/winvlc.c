/*****************************************************************************
 * winvlc.c: the Windows VLC media player
 *****************************************************************************
 * Copyright (C) 1998-2011 the VideoLAN team
 *
 * Authors: Vincent Seguin <seguin@via.ecp.fr>
 *          Samuel Hocevar <sam@zoy.org>
 *          Gildas Bazin <gbazin@videolan.org>
 *          Derk-Jan Hartman <hartman at videolan dot org>
 *          Lots of other people, see the libvlc AUTHORS file
 *
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

#ifndef UNICODE
#define UNICODE
#endif

#include <vlc/vlc.h>
#include <windows.h>
#include <shellapi.h>

#include <fcntl.h>
#include <io.h>
#include <shlobj.h>

#include "../lib/libvlc_internal.h"

/* redesign (brand layer, public profile): Cone reads its interface language from its own key
 * and writes crash dumps in its own folder, never an installed VLC's
 * (modules/gui/qt/util/brand.hpp BRAND_REGISTRY_KEY, src/win32/dirs.c APP_DIR_NAME); its audio
 * session (volume mixer entry, modules/audio_output/mmdevice.c) carries its own name, and so
 * does the message box shown when it cannot start */
#ifdef VLC_BRAND_PUBLIC
# define LANG_REGISTRY_KEY "Software\\Cone\\"
# define CRASHDUMP_DIR L"\\Cone\\crashdump"
# define USER_AGENT_NAME "Cone"
# define START_ERROR_TEXT "Cone could not start.\n"
# define START_ERROR_TITLE "Cone"
#else
# define LANG_REGISTRY_KEY "Software\\VideoLAN\\VLC\\"
# define CRASHDUMP_DIR L"\\vlc\\crashdump"
# define USER_AGENT_NAME "VLC media player"
# define START_ERROR_TEXT "VLC media player could not start.\n"
# define START_ERROR_TITLE "VLC media player"
#endif

#ifdef HAVE_BREAKPAD
void CheckCrashDump( const wchar_t* crashdump_path );
void* InstallCrashHandler( const wchar_t* crashdump_path );
void ReleaseCrashHandler( void* handler );
#endif

static char *FromWide (const wchar_t *wide)
{
    size_t len;
    len = WideCharToMultiByte (CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);

    char *out = (char *)malloc (len);
    if (out)
        WideCharToMultiByte (CP_UTF8, 0, wide, -1, out, len, NULL, NULL);
    return out;
}

static void PrioritizeSystem32(void)
{
#if _WIN32_WINNT < _WIN32_WINNT_WIN8
    BOOL (WINAPI *SetProcessMitigationPolicy)(PROCESS_MITIGATION_POLICY, PVOID, SIZE_T);
    HINSTANCE h_Kernel32 = GetModuleHandle(TEXT("kernel32.dll"));
    if ( !h_Kernel32 )
        return;
    SetProcessMitigationPolicy = (BOOL (WINAPI *)(PROCESS_MITIGATION_POLICY, PVOID, SIZE_T))
                                   GetProcAddress(h_Kernel32, "SetProcessMitigationPolicy");
    if (SetProcessMitigationPolicy == NULL)
        return;
#endif
    PROCESS_MITIGATION_IMAGE_LOAD_POLICY m = { .Flags = 0 };
    m.PreferSystem32Images = 1;
    SetProcessMitigationPolicy( ProcessImageLoadPolicy, &m, sizeof( m ) );
}

static void vlc_kill(void *data)
{
    HANDLE *semp = data;

    ReleaseSemaphore(*semp, 1, NULL);
}

int WINAPI WinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance,
                    LPSTR lpCmdLine,
                    int nCmdShow )
{
    int argc;

    /* VLC does not change the thread locale, so gettext/libintil will use the
     * user default locale as reference. */
    /* gettext versions 0.18-0.18.1 will use the Windows Vista locale name
     * if the GETTEXT_MUI environment variable is set. If not set or if running
     * on Windows 2000/XP/2003 an hard-coded language ID list is used. This
     * putenv() call may become redundant with later versions of gettext. */
    putenv("GETTEXT_MUI=1");
#ifdef TOP_BUILDDIR
    putenv("VLC_PLUGIN_PATH=Z:"TOP_BUILDDIR"/modules");
    putenv("VLC_DATA_PATH=Z:"TOP_SRCDIR"/share");
#endif

#ifndef NDEBUG
    /* Disable stderr buffering. Indeed, stderr can be buffered on Windows (if
     * connected to a pipe). */
    setvbuf (stderr, NULL, _IONBF, BUFSIZ);
#endif

    HeapSetInformation(NULL, HeapEnableTerminationOnCorruption, NULL, 0);

    /* Enable DEP */
    SetProcessDEPPolicy(PROCESS_DEP_ENABLE);

    /* Do NOT load any library from cwd. */
    SetDllDirectory(TEXT(""));

    /***
     * The LoadLibrary* calls from the modules and the 3rd party code
     * will search in SYSTEM32 only
     * */
    SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32);
    /***
     * Load DLLs from system32 before any other folder (when possible)
     */
    PrioritizeSystem32();

    /* Args */
    wchar_t **wargv = CommandLineToArgvW (GetCommandLine (), &argc);
    if (wargv == NULL)
        return 1;

    char *argv[argc + 3];
    BOOL crash_handling = TRUE;
    int j = 0;
    WCHAR *lang = NULL;

    argv[j++] = strdup("--media-library");
    argv[j++] = strdup("--no-ignore-config");
    for (int i = 1; i < argc; i++)
    {
        if(!wcscmp(wargv[i], L"--no-crashdump"))
        {
            crash_handling = FALSE;
            continue; /* don't give argument to libvlc */
        }
        if (!wcsncmp(wargv[i], L"--language", 10) )
        {
            if (i < argc - 1 && wcsncmp( wargv[i + 1], L"--", 2 ))
                lang = _wcsdup (wargv[++i]);
            continue;
        }

#ifdef VLC_BRAND_PUBLIC
        /* Decision 63: Cone has no skins interface, so libVLC does not know the skins2
         * options (skins2-*, skinned-playlist, skinned-video) and would refuse to start on
         * them (e.g. a VLC shortcut "-Iskins --skins2-last <file>"): they are dropped, with
         * the value of the two that take one;
         * the skins interface itself falls back to the default one (libvlc_InternalAddIntf
         * below) */
        if (!wcsncmp(wargv[i], L"--skins2-", 9) || !wcsncmp(wargv[i], L"--no-skins2-", 12)
         || !wcsncmp(wargv[i], L"--noskins2-", 11) || !wcsncmp(wargv[i], L"--skinned-", 10)
         || !wcsncmp(wargv[i], L"--no-skinned-", 13) || !wcsncmp(wargv[i], L"--noskinned-", 12))
        {
            if ((!wcscmp(wargv[i], L"--skins2-last") || !wcscmp(wargv[i], L"--skins2-config"))
             && i < argc - 1)
                i++;
            continue;
        }
#endif
        argv[j++] = FromWide (wargv[i]);
    }

    argc = j;
    argv[argc] = NULL;
    LocalFree (wargv);

#ifdef HAVE_BREAKPAD
    void* eh = NULL;
    if(crash_handling)
    {
        PWSTR copath;
        if( S_OK != SHGetKnownFolderPath(&FOLDERID_RoamingAppData, KF_FLAG_CREATE, 0, &copath) )
            fprintf( stderr, "Can't open the vlc conf PATH\n" );
        else
        {
            const size_t pathlen = wcslen( copath );
            wchar_t *path = malloc( ( pathlen + wcslen(CRASHDUMP_DIR) + 1 ) * sizeof(*path) );
            if ( path != NULL)
            {
                memcpy( path, copath, pathlen * sizeof(*path) );
                memcpy( &path[pathlen], CRASHDUMP_DIR, (wcslen(CRASHDUMP_DIR) + 1)  * sizeof(*path) );
                CheckCrashDump( path );
                eh = InstallCrashHandler( path );
                free( path );
            }
            CoTaskMemFree( copath );
        }
    }
#else
    (void)crash_handling;
#endif

    _setmode( _fileno( stdin ), _O_BINARY ); /* Needed for pipes */

    /* */
    if (!lang)
    {
        HKEY h_key;
        if( RegOpenKeyEx( HKEY_CURRENT_USER, TEXT(LANG_REGISTRY_KEY), 0, KEY_READ, &h_key )
                == ERROR_SUCCESS )
        {
            WCHAR szData[256];
            DWORD len = 256;
            if( RegQueryValueEx( h_key, TEXT("Lang"), NULL, NULL, (LPBYTE) &szData, &len ) == ERROR_SUCCESS )
                lang = _wcsdup( szData );
        }
    }

    if (lang && wcsncmp( lang, L"auto", 4 ) )
    {
        char tmp[11];
        snprintf(tmp, 11, "LANG=%ls", lang);
        putenv(tmp);
    }
    free(lang);

    /* Initialize libvlc */
    libvlc_instance_t *vlc;
    vlc = libvlc_new (argc, (const char **)argv);
    if (vlc != NULL)
    {
        HANDLE sem = CreateSemaphore(NULL, 0, 1, NULL);

        libvlc_SetExitHandler(vlc->p_libvlc_int, vlc_kill, &sem);
        libvlc_set_app_id (vlc, "org.VideoLAN.VLC", PACKAGE_VERSION,
                           PACKAGE_NAME);
        libvlc_set_user_agent (vlc, USER_AGENT_NAME, "VLC/"PACKAGE_VERSION);
#ifdef VLC_BRAND_PUBLIC
        /* Decision 63: an interface Cone does not have (the skins interface asked for by
         * "-I skins" or by settings copied from VLC, "intf=skins2") opens the default Qt
         * interface instead of no window at all; a failing Qt interface is not tried twice */
        if (libvlc_InternalAddIntf (vlc->p_libvlc_int, NULL) != VLC_SUCCESS)
        {
            char *intf = var_InheritString (vlc->p_libvlc_int, "intf");
            if (intf != NULL && strncmp (intf, "qt", 2) != 0)
                libvlc_InternalAddIntf (vlc->p_libvlc_int, "qt");
            free (intf);
        }
#else
        libvlc_InternalAddIntf (vlc->p_libvlc_int, NULL);
#endif
        libvlc_InternalPlay (vlc->p_libvlc_int);

        WaitForSingleObject(sem, INFINITE);
        CloseHandle(sem);

        libvlc_release (vlc);
    }
    else
        MessageBox (NULL, TEXT(START_ERROR_TEXT
                    "Either the command line options were invalid or no plugins were found.\n"),
                    TEXT(START_ERROR_TITLE),
                    MB_OK|MB_ICONERROR);


#ifdef HAVE_BREAKPAD
    ReleaseCrashHandler( eh );
#endif
    for (int i = 0; i < argc; i++)
        free (argv[i]);

    (void)hInstance; (void)hPrevInstance; (void)lpCmdLine; (void)nCmdShow;
    return 0;
}
