/* Siliconium: bnet-guard.exe, for the Battle.net section's games.
 *
 * Black Ops 4 checks the graphics card before it starts and asks in a Windows
 * message box, "Minimum System Requirements Warning": "At least 2 GB of video
 * memory are required … Would you like to run Call of Duty: Black Ops 4
 * anyway?". Under Wine on a Mac it always asks: Wine's display driver reports
 * the GPU's memory to Windows' WMI (Win32_VideoController.AdapterRAM, a 32-bit
 * value) as 0 when the Mac's memory is a multiple of 4 GB (a 64-bit to 32-bit
 * conversion in Wine). This answers "Yes" (play) at once, so the game starts
 * as it does on Windows. It answers "No" to "Run in Safe Mode?" (after a game
 * did not quit properly), which would lower the graphics settings, and "No" to
 * "Set Optimal Settings?" (asked when the graphics adapter the game sees changed
 * since its last start: seen 2026-11-23 with another adapter ID), which would
 * replace them. Every answer goes to launch.sh's log with the box's text.
 *
 *   bnet-guard.exe <seconds>    watches that long (launch.sh ends it with the game)
 *
 * Built with: zig cc -target x86_64-windows-gnu -O2 -s -Wl,--subsystem,windows -o bnet-guard.exe bnet-guard.c -luser32
 */
#include <windows.h>
#include <wchar.h>
#include <stdlib.h>
#include <stdio.h>

static int contains(const wchar_t *text, const wchar_t *const *keys, unsigned n)
{
    for (unsigned i = 0; i < n; i++)
        if (wcsstr(text, keys[i])) return 1;
    return 0;
}

/* the box's message (a message box's text is its static control 0xFFFF) */
static BOOL CALLBACK message_text(HWND child, LPARAM out)
{
    wchar_t cls[16];
    if (GetDlgCtrlID(child) == 0xFFFF && GetClassNameW(child, cls, 16) && !wcscmp(cls, L"Static")) {
        GetWindowTextW(child, (wchar_t *)out, 1024);
        return FALSE;
    }
    return TRUE;
}

static void press(HWND window, int id, const wchar_t *title)
{
    HWND button = GetDlgItem(window, id);
    wchar_t text[1024] = L"";
    if (!button) return;
    EnumChildWindows(window, message_text, (LPARAM)text);
    for (wchar_t *c = text; *c; c++) if (*c == L'\r' || *c == L'\n') *c = L' ';
    /* (launch.sh's log: which question was answered, and what it said) */
    printf("bnet-guard: answered %s to \"%ls\": %ls\n", id == IDYES ? "Yes" : "No", title, text);
    fflush(stdout);
    SendMessageW(window, WM_COMMAND, MAKEWPARAM(id, BN_CLICKED), (LPARAM)button);
}

static BOOL CALLBACK answer(HWND window, LPARAM unused)
{
    static const wchar_t *const play[] = { L"Minimum System Requirements" };
    /* "No" keeps the player's settings: "Run in Safe Mode?" lowers them, "Set Optimal
     * Settings?" (Black Ops 4 when the graphics adapter it sees has changed since its
     * last start: hardware_checksum in players/config.ini) replaces them */
    static const wchar_t *const safe[] = { L"Safe Mode", L"Safe mode", L"safe mode", L"Optimal Settings", L"Optimal settings" };
    wchar_t title[256], cls[64];
    (void)unused;
    if (!IsWindowVisible(window)) return TRUE;
    if (!GetClassNameW(window, cls, 64) || wcscmp(cls, L"#32770")) return TRUE;   /* a dialog box */
    if (!GetWindowTextW(window, title, 256)) return TRUE;
    if (contains(title, play, sizeof play / sizeof *play) && GetDlgItem(window, IDYES)) press(window, IDYES, title);
    else if (contains(title, safe, sizeof safe / sizeof *safe) && GetDlgItem(window, IDNO)) press(window, IDNO, title);
    return TRUE;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show)
{
    (void)instance; (void)previous; (void)show;
    int seconds = atoi(command_line);
    if (seconds <= 0) seconds = 600;
    for (int i = 0; i < seconds * 10; i++) {
        EnumWindows(answer, 0);
        Sleep(100);
    }
    return 0;
}
