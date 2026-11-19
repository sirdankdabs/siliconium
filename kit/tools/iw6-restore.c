#include <windows.h>
#include <wchar.h>

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
    if (!name || _wcsicmp(name + 1, L"iw6sp64_ship.exe")) return TRUE;
    if (!ShowWindowAsync(window, SW_RESTORE)) return TRUE;

    *(BOOL *)restored = TRUE;
    return FALSE;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    BOOL restored = FALSE;
    EnumWindows(restore_game, (LPARAM)&restored);
    return restored ? 0 : 1;
}
