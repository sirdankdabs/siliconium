#include <windows.h>
#include <wchar.h>

/* iw6-restore.exe [--wait] [executable name]: restores that game's minimized window
   (default iw6sp64_ship.exe, Ghosts; Call of Duty 2 passes CoD2SP_s.exe;
   WWII passes s2_sp64_ship.exe / s2_mp64_ship.exe and is also brought to the
   foreground; WWII's window can also be visible but parked off screen, which
   it does itself when it loses the focus: it is moved back; a minimized WWII
   window gets WM_SYSCOMMAND/SC_RESTORE)
   --wait: stays running and restores once per line read from its standard
   input (writes "1" or "0" and a newline back), until the input ends:
   iw6-focus starts it with the game, so a Cmd-Tab back costs no Wine program
   start (2.6-3.9 s of black screen while the game runs, 2026-11-23) */
static WCHAR target[MAX_PATH] = L"iw6sp64_ship.exe";

/* WWII moves its fullscreen window to (-16000, -16000) when it loses the
   focus (a Cmd+Tab, a click on another app) and, under Wine, did not move it
   back when it was made the active app again: the Dock icon brought nothing
   (2026-11-23). */
static BOOL parked(HWND window)
{
    RECT r;
    /* (a minimized window sits at -32000, -32000 too: it is restored below,
       not moved; moving it left WWII minimized and black, 2026-11-23) */
    return _wcsnicmp(target, L"s2_", 3) == 0 && !IsIconic(window) && GetWindowRect(window, &r) &&
           r.left <= -10000 && r.top <= -10000;
}

static BOOL CALLBACK restore_game(HWND window, LPARAM restored)
{
    if (!IsWindowVisible(window) || !(IsIconic(window) || parked(window))) return TRUE;

    DWORD pid = 0;
    GetWindowThreadProcessId(window, &pid);
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!process) return TRUE;

    WCHAR path[32768];
    DWORD length = ARRAYSIZE(path);
    BOOL found = QueryFullProcessImageNameW(process, 0, path, &length);
    CloseHandle(process);
    if (!found) return TRUE;

    const WCHAR *name = wcsrchr(path, L'\\');
    if (!name || _wcsicmp(name + 1, target)) return TRUE;
    if (parked(window))
    {
        /* back over the primary display, as the game sizes it, and tell the
           game it is active again (it redraws and takes input on that) */
        SetWindowPos(window, HWND_TOP, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN),
                     SWP_SHOWWINDOW | SWP_FRAMECHANGED);
        PostMessageW(window, WM_ACTIVATEAPP, TRUE, 0);
        PostMessageW(window, WM_ACTIVATE, WA_ACTIVE, 0);
    }
    else if (!_wcsnicmp(target, L"s2_", 3))
    {
        /* WWII: restored the way Windows' taskbar button restores a minimized
           window (WM_SYSCOMMAND/SC_RESTORE, through the game's own window
           procedure); ShowWindowAsync only if that message cannot be sent */
        DWORD_PTR result;
        if (!SendMessageTimeoutW(window, WM_SYSCOMMAND, SC_RESTORE, 0, SMTO_ABORTIFHUNG, 3000, &result) &&
            !ShowWindowAsync(window, SW_RESTORE))
            return TRUE;
    }
    else if (!ShowWindowAsync(window, SW_RESTORE)) return TRUE;
    /* WWII (s2_*): its restored window stayed out of the foreground, so keys
       went nowhere until a click; make it the foreground window too */
    if (!_wcsnicmp(target, L"s2_", 3))
    {
        Sleep(100);
        SetForegroundWindow(window);
    }

    *(BOOL *)restored = TRUE;
    return FALSE;
}

static BOOL restore_once(void)
{
    BOOL restored = FALSE;
    EnumWindows(restore_game, (LPARAM)&restored);
    return restored;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    BOOL wait = FALSE;
    if (command && *command)
    {
        WCHAR arg[MAX_PATH];
        int n = MultiByteToWideChar(CP_ACP, 0, command, -1, arg, MAX_PATH);
        WCHAR *p = arg, *e;
        if (n > 0)
        {
            while (*p == L' ' || *p == L'"') p++;
            if (!wcsncmp(p, L"--wait", 6) && (p[6] == 0 || p[6] == L' '))
            {
                wait = TRUE;
                p += 6;
                while (*p == L' ' || *p == L'"') p++;
            }
            e = p + wcslen(p);
            while (e > p && (e[-1] == L' ' || e[-1] == L'"')) *--e = 0;
            if (*p) lstrcpynW(target, p, MAX_PATH);
        }
    }
    if (!wait) return restore_once() ? 0 : 1;

    HANDLE in = GetStdHandle(STD_INPUT_HANDLE), out = GetStdHandle(STD_OUTPUT_HANDLE);
    char c;
    DWORD count;
    while (ReadFile(in, &c, 1, &count, NULL) && count == 1)
    {
        if (c != '\n') continue;
        const char *answer = restore_once() ? "1\n" : "0\n";
        WriteFile(out, answer, 2, &count, NULL);
    }
    return 0;
}
