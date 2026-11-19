/* Siliconium: dialog-guard.exe, for the Steam Library's games.
 *
 * The games ask "Set Optimal Settings?" (their hardware check: Wine's
 * graphics adapter looks new to them) and "Run In Safe Mode?" (after a game
 * did not quit properly) in Windows message boxes, before reading their
 * settings. "Yes" replaces the player's video settings with low "safe" or
 * detected ones. This answers "No" to both as soon as they appear, so the
 * settings Siliconium and the player chose are kept, whatever is clicked.
 *
 *   dialog-guard.exe <seconds>    watches that long (the app ends it with the game)
 *
 * Built with: zig cc -target x86-windows-gnu -O2 -s -Wl,--subsystem,windows -o dialog-guard.exe dialog-guard.c -luser32
 */
#include <windows.h>
#include <wchar.h>

static int asks(const wchar_t *title)
{
    static const wchar_t *const keys[] = { L"Optimal Settings", L"Safe Mode", L"safe mode", L"Optimal settings" };
    for (unsigned i = 0; i < sizeof keys / sizeof *keys; i++)
        if (wcsstr(title, keys[i])) return 1;
    return 0;
}

static BOOL CALLBACK answer_no(HWND window, LPARAM unused)
{
    wchar_t title[256], cls[64];
    (void)unused;
    if (!IsWindowVisible(window)) return TRUE;
    if (!GetClassNameW(window, cls, 64) || wcscmp(cls, L"#32770")) return TRUE;   /* a dialog box */
    if (!GetWindowTextW(window, title, 256) || !asks(title)) return TRUE;
    HWND no = GetDlgItem(window, IDNO);
    if (no) SendMessageW(window, WM_COMMAND, MAKEWPARAM(IDNO, BN_CLICKED), (LPARAM)no);
    else PostMessageW(window, WM_COMMAND, IDNO, 0);
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
