/*
 * Siliconium: silrelay.exe, the in-game switch between a game's parts.
 *
 * Several Call of Duty campaigns open their Multiplayer / Zombies part from
 * their own menu with steam://run/<app>: Steam then starts that executable
 * itself, outside Siliconium (no display mode, settings, translator or
 * controller setup). Siliconium sets Steam's launch options of those apps to
 * "C:\users\Public\Siliconium\silrelay.exe %command%", so Steam starts this
 * program with the game's command line instead. It leaves the command line in
 * relay\req-<pid>.txt for kit/tools/steam-relay.sh (running beside Steam),
 * which starts the part through launch.sh and answers "launched"; any other
 * answer, or none within 20 s, runs the original command as Steam would have
 * (and waits for it, so Steam still sees the game running).
 *
 * Built with: zig cc -target x86-windows-gnu -O2 -s -Wl,--subsystem,windows -municode -o silrelay.exe silrelay.c
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static const wchar_t *skip_argv0(const wchar_t *p) {
  if (*p == L'"') {
    p++;
    while (*p && *p != L'"') p++;
    if (*p) p++;
  } else {
    while (*p && *p != L' ' && *p != L'\t') p++;
  }
  while (*p == L' ' || *p == L'\t') p++;
  return p;
}

static int run_original(const wchar_t *cmd) {
  STARTUPINFOW si = {sizeof(si)};
  PROCESS_INFORMATION pi;
  size_t n = wcslen(cmd) + 1;
  wchar_t *buf = HeapAlloc(GetProcessHeap(), 0, n * sizeof(wchar_t));
  DWORD code = 1;
  if (!buf) return 1;
  memcpy(buf, cmd, n * sizeof(wchar_t));
  if (CreateProcessW(NULL, buf, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
  }
  HeapFree(GetProcessHeap(), 0, buf);
  return (int)code;
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, LPWSTR line, int show) {
  const wchar_t *cmd = skip_argv0(GetCommandLineW());
  wchar_t dir[MAX_PATH], req[MAX_PATH + 64], tmp[MAX_PATH + 64], ans[MAX_PATH + 64];
  DWORD pid = GetCurrentProcessId();
  wchar_t *slash;
  char *utf8;
  int len;
  HANDLE f;
  DWORD wrote;
  (void)inst; (void)prev; (void)line; (void)show;

  if (!*cmd) return 1;
  if (!GetModuleFileNameW(NULL, dir, MAX_PATH) || !(slash = wcsrchr(dir, L'\\'))) return run_original(cmd);
  *slash = 0;
  swprintf(req, MAX_PATH + 64, L"%ls\\relay\\req-%lu.txt", dir, (unsigned long)pid);
  swprintf(tmp, MAX_PATH + 64, L"%ls\\relay\\req-%lu.tmp", dir, (unsigned long)pid);
  swprintf(ans, MAX_PATH + 64, L"%ls\\relay\\ans-%lu.txt", dir, (unsigned long)pid);

  len = WideCharToMultiByte(CP_UTF8, 0, cmd, -1, NULL, 0, NULL, NULL);
  utf8 = HeapAlloc(GetProcessHeap(), 0, len > 0 ? len : 1);
  if (!utf8 || len <= 0) return run_original(cmd);
  WideCharToMultiByte(CP_UTF8, 0, cmd, -1, utf8, len, NULL, NULL);
  f = CreateFileW(tmp, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  if (f == INVALID_HANDLE_VALUE) return run_original(cmd);
  WriteFile(f, utf8, (DWORD)(len - 1), &wrote, NULL);
  CloseHandle(f);
  HeapFree(GetProcessHeap(), 0, utf8);
  if (!MoveFileExW(tmp, req, MOVEFILE_REPLACE_EXISTING)) {
    DeleteFileW(tmp);
    return run_original(cmd);
  }

  for (int i = 0; i < 200; i++) {   /* 20 s */
    char buf[16] = {0};
    DWORD got = 0;
    f = CreateFileW(ans, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
    if (f != INVALID_HANDLE_VALUE) {
      ReadFile(f, buf, sizeof(buf) - 1, &got, NULL);
      CloseHandle(f);
      DeleteFileW(ans);
      if (!strncmp(buf, "launched", 8)) return 0;
      break;
    }
    Sleep(100);
  }
  DeleteFileW(req);   /* nobody took it */
  return run_original(cmd);
}
