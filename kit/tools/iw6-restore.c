#include <windows.h>
#include <wchar.h>

/* iw6-restore.exe [executable name]: restores that game's minimized window
   (default iw6sp64_ship.exe, Ghosts; Call of Duty 2 passes CoD2SP_s.exe) */
static WCHAR target[MAX_PATH] = L"iw6sp64_ship.exe";

static BOOL CALLBACK restore_game(HWND window, LPARAM restored)
{
    if (!IsWindowVisible(window) || !IsIconic(window)) return TRUE;

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
    if (!ShowWindowAsync(window, SW_RESTORE)) return TRUE;

    *(BOOL *)restored = TRUE;
    return FALSE;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    BOOL restored = FALSE;
    if (command && *command)
    {
        WCHAR arg[MAX_PATH];
        int n = MultiByteToWideChar(CP_ACP, 0, command, -1, arg, MAX_PATH);
        WCHAR *p = arg, *e;
        if (n > 0)
        {
            while (*p == L' ' || *p == L'"') p++;
            e = p + wcslen(p);
            while (e > p && (e[-1] == L' ' || e[-1] == L'"')) *--e = 0;
            if (*p) lstrcpynW(target, p, MAX_PATH);
        }
    }
    EnumWindows(restore_game, (LPARAM)&restored);
    return restored ? 0 : 1;
}
