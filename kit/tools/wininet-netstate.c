/* Siliconium: wininet.dll for Call of Duty: WWII multiplayer / Zombies
 * (s2_mp64_ship.exe only: launch.sh installs it in Steam's prefix as
 * system32\wininet.dll beside the engine's own Wine wininet.dll copied as
 * wininet_wine.dll, and sets wininet=native for that executable alone).
 *
 * Online, the multiplayer executable asks InternetGetConnectedState on every
 * frame (its "No network connection detected" check; stack unwind
 * 2026-11-23: s2_mp64_ship.exe+0x788d1c -> InternetGetConnectedStateExW).
 * On Windows that is answered from the network list service at once. Wine
 * answers it with GetAdaptersAddresses, twice, and on macOS every adapter
 * (27 on the test Mac: utun, bridge, awdl, ...) costs a round trip to the
 * nsiproxy driver through the wine server: 7.7-18.7 ms per call (median 10.0)
 * while the game ran. Main spent 41 % of its time there; an online custom
 * match held a ~27 ms frame (38.6 FPS) where the same match offline (no
 * call) ran 65-75 FPS.
 *
 * This DLL answers the InternetGetConnectedState family from a cached result
 * that its own thread refreshes once a second through the real function
 * (the first call waits for one real answer); a caller that wants the
 * connection's name gets the real function. Every other export goes to the
 * real DLL (wininet-netstate.def, generated from its export table).
 *
 * Build: x86_64-w64-mingw32-gcc -shared -O2 -s -nostdlib -Wl,--entry,DllMain
 *   -o wininet.dll wininet-netstate.c wininet-netstate.def -lkernel32
 */
#include <windows.h>

typedef BOOL (WINAPI *exw_fn)(LPDWORD, LPWSTR, DWORD, DWORD);
typedef BOOL (WINAPI *exa_fn)(LPDWORD, LPSTR, DWORD, DWORD);
typedef HRESULT (WINAPI *setdesc_fn)(HANDLE, PCWSTR);

static exw_fn real_exw;
static exa_fn real_exa;
static SRWLOCK lock = SRWLOCK_INIT;
static volatile LONG started, valid;
static BOOL c_ret;
static DWORD c_flags, c_err;

static BOOL load_real(void)
{
    HMODULE h;
    if (real_exw) return TRUE;
    if (!(h = LoadLibraryA("wininet_wine.dll"))) return FALSE;
    real_exa = (exa_fn)GetProcAddress(h, "InternetGetConnectedStateExA");
    real_exw = (exw_fn)GetProcAddress(h, "InternetGetConnectedStateExW");
    return real_exw != NULL;
}

static void refresh(void)
{
    DWORD flags = 0, err;
    BOOL r;
    SetLastError(ERROR_SUCCESS);
    r = real_exw(&flags, NULL, 0, 0);
    err = GetLastError();
    AcquireSRWLockExclusive(&lock);
    c_ret = r; c_flags = flags; c_err = err;
    ReleaseSRWLockExclusive(&lock);
    InterlockedExchange(&valid, 1);
}

static DWORD WINAPI refresher(void *unused)
{
    for (;;) { Sleep(1000); refresh(); }
    return 0;
}

static BOOL cached(LPDWORD status)
{
    BOOL r;
    DWORD f, e;
    if (!load_real()) { SetLastError(ERROR_MOD_NOT_FOUND); return FALSE; }
    if (InterlockedCompareExchange(&started, 1, 0) == 0)
    {
        HMODULE self;
        HANDLE t;
        setdesc_fn setdesc = (setdesc_fn)GetProcAddress(GetModuleHandleA("kernel32.dll"), "SetThreadDescription");
        refresh();
        /* the thread runs this DLL's code until the process ends: keep it loaded */
        GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN, (LPCSTR)refresher, &self);
        if ((t = CreateThread(NULL, 0, refresher, NULL, 0, NULL)))
        {
            if (setdesc) setdesc(t, L"sil-netstate");
            CloseHandle(t);
        }
    }
    else while (!valid) Sleep(1);   /* another thread is making the first real call */
    AcquireSRWLockShared(&lock);
    r = c_ret; f = c_flags; e = c_err;
    ReleaseSRWLockShared(&lock);
    if (status) *status = f;
    if (!r) SetLastError(e);
    return r;
}

BOOL WINAPI InternetGetConnectedState(LPDWORD status, DWORD reserved)
{
    return cached(status);
}

BOOL WINAPI InternetGetConnectedStateExW(LPDWORD status, LPWSTR name, DWORD len, DWORD reserved)
{
    if (name && len)
    {
        if (!load_real()) { SetLastError(ERROR_MOD_NOT_FOUND); return FALSE; }
        return real_exw(status, name, len, reserved);
    }
    return cached(status);
}

BOOL WINAPI InternetGetConnectedStateExA(LPDWORD status, LPSTR name, DWORD len, DWORD reserved)
{
    if (name && len)
    {
        if (!load_real() || !real_exa) { SetLastError(ERROR_MOD_NOT_FOUND); return FALSE; }
        return real_exa(status, name, len, reserved);
    }
    return cached(status);
}

BOOL WINAPI InternetGetConnectedStateEx(LPDWORD status, LPSTR name, DWORD len, DWORD reserved)
{
    return InternetGetConnectedStateExA(status, name, len, reserved);
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    if (reason == DLL_PROCESS_ATTACH) DisableThreadLibraryCalls(inst);
    return TRUE;
}
