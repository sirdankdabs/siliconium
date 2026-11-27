/* Siliconium: dialog-guard.exe, for the Steam Library and Offline games.
 *
 * The games ask "Set Optimal Settings?" / "Recommended Settings Updated"
 * (their hardware check: Wine's graphics adapter looks new to them) and
 * "Run In Safe Mode?" (after a game did not quit properly) in Windows
 * message boxes, before reading their settings. "Yes" replaces the player's
 * video settings with low "safe" or detected ones. This answers "No" to
 * both as soon as they appear — in any language or codepage — so the
 * settings Siliconium and the player chose are kept.
 *
 *   dialog-guard.exe <seconds>    watches that long (the app ends it with the game)
 *
 * Built with: zig cc -target x86-windows-gnu -O2 -s -Wl,--subsystem,windows -o dialog-guard.exe dialog-guard.c -luser32
 */
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>
#include <wctype.h>

static void to_lower(wchar_t *dst, const wchar_t *src, size_t n)
{
    size_t i = 0;
    for (; i + 1 < n && src[i]; i++)
        dst[i] = towlower(src[i]);
    dst[i] = 0;
}

static int asks_title(const wchar_t *raw_title)
{
    wchar_t title[256];
    to_lower(title, raw_title, 256);
    static const wchar_t *const keys[] = {
        L"optimal settings", L"recommended settings", L"safe mode",
        L"modo seguro", L"ajustes recomendados", L"configuraci",
        L"mode sans", L"recommand",
        L"abgesicherten", L"empfohlenen",
        L"consigliate", L"modalit",
        L"trybie awaryjnym", L"zalecanych", L"optymalne",
        L"modo de seguran", L"recomendadas"
    };
    for (unsigned i = 0; i < sizeof keys / sizeof *keys; i++)
        if (wcsstr(title, keys[i])) return 1;
    return 0;
}

static int is_cod_game_window(HWND window)
{
    DWORD pid = 0;
    GetWindowThreadProcessId(window, &pid);
    if (!pid) return 0;
    HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!proc) return 0;
    wchar_t path[512];
    DWORD len = 512;
    int ok = QueryFullProcessImageNameW(proc, 0, path, &len);
    CloseHandle(proc);
    if (!ok || !len) return 0;
    const wchar_t *base = wcsrchr(path, L'\\');
    base = base ? base + 1 : path;
    wchar_t exe[256];
    to_lower(exe, base, 256);
    /* Never touch dialogs from Steam, Battle.net or system shells */
    if (wcsstr(exe, L"steam") || wcsstr(exe, L"battle.net") ||
        wcsstr(exe, L"blizzard") || wcsstr(exe, L"explorer")) return 0;
    static const wchar_t *const prefixes[] = {
        L"cod", L"iw3", L"iw4", L"iw5", L"iw6", L"iw7",
        L"t4", L"t5", L"t6", L"blackops", L"s1_", L"s2_",
        L"plutonium", L"boiii"
    };
    for (unsigned i = 0; i < sizeof prefixes / sizeof *prefixes; i++)
        if (wcsncmp(exe, prefixes[i], wcslen(prefixes[i])) == 0) return 1;
    return 0;
}

static BOOL CALLBACK answer_no(HWND window, LPARAM unused)
{
    wchar_t title[256], cls[64];
    (void)unused;
    if (!IsWindowVisible(window)) return TRUE;
    if (!GetClassNameW(window, cls, 64) || wcscmp(cls, L"#32770")) return TRUE;   /* a dialog box */
    HWND no = GetDlgItem(window, IDNO);
    if (!no) return TRUE;
    int matched = 0;
    if (GetWindowTextW(window, title, 256) && asks_title(title)) matched = 1;
    /* Any Call of Duty startup Yes/No MessageBox (handles every language & codepage) */
    else if (GetDlgItem(window, IDYES) && is_cod_game_window(window)) matched = 1;
    if (!matched) return TRUE;
    SendMessageW(window, WM_COMMAND, MAKEWPARAM(IDNO, BN_CLICKED), (LPARAM)no);
    return TRUE;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show)
{
    (void)instance; (void)previous; (void)show;
    int seconds = atoi(command_line);
    if (seconds <= 0) seconds = 600;
    for (int i = 0; i < seconds * 10; i++) {
        EnumWindows(answer_no, 0);
        Sleep(100);
    }
    return 0;
}
