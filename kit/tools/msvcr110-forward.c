/* Siliconium: msvcr110.dll for Black Ops III Mod Tools (kit/bo3-modtools.sh).
 *
 * The tools need Microsoft's VC++ 2012 runtime: Radiant's lighting, the
 * linker and the Asset Editor use its Concurrency Runtime (task collections,
 * cancellation tokens), which Wine's msvcr110 leaves unimplemented (the
 * lighting's workers died on ??0_Context@details@Concurrency@@... and the
 * bake hung). Steam installs that runtime with the Mod Tools
 * (_CommonRedist\vcredist\2012); the workspace holds a copy of its
 * msvcr110.dll as msvcr110_ms.dll.
 *
 * This DLL forwards every export to it (msvcr110-forward.def, generated from
 * its export table, same ordinals) except _resetstkoflw. Radiant calls that at
 * start; Microsoft's (as Wine's) puts a guard page inside the stack in use,
 * so every stack page below it faults once as the stack grows (Wine moves the
 * guard down one page at a time), and under Rosetta 2 such a fault on a push
 * inside translated code ends the process ("rosetta error: unexpectedly need
 * to EmulateForward on a synchronous exception"). Wine commits a thread's
 * whole stack and keeps one guard page at its bottom: this re-arms that one
 * (the same protection after an overflow, no faults before one).
 *
 * It also makes the Concurrency Runtime call FlushProcessWriteBuffers one
 * thread at a time. A worker of that runtime calls it before it goes idle, to
 * see work other threads have just queued; on macOS Wine does it by reading
 * the registers of every thread of the process, and two threads doing that at
 * once wait for each other for good (measured 2026-11-22: 2 threads calling it
 * together froze within 12 calls, 8 within 75; one at a time, 16 threads x
 * 5,000 calls finished). Workers go idle together at the end of each step of
 * Radiant's light bake, so the bake stopped at random ("Sun....",
 * "Probes....", after a bounce) with every worker asleep. The runtime keeps
 * the function's address encoded in its data (VC++ 2012 Update 4,
 * 11.0.61030): it is replaced with a wrapper that takes a lock around the call,
 * only after checking that it decodes to kernel32's FlushProcessWriteBuffers
 * (any other msvcr110 build is left as it is).
 *
 * And it points the program's import of ReadDirectoryChangesW at a version
 * that leaves out the change kinds Wine does not watch. The tools' asset
 * database (gdtDB, inside Radiant) watches its folders with filter 0x1ff,
 * which includes FILE_NOTIFY_CHANGE_EA; Windows accepts it, Wine (11.0 and
 * upstream) answers STATUS_INVALID_PARAMETER at once, and Radiant's watcher
 * thread then calls it again in a loop that never looks at its exit event:
 * two threads spun at 100 % each while Radiant ran, and at exit Radiant waited
 * for them for good (gdt_db_exit: WaitForMultipleObjects, INFINITE), so the
 * launcher's Build never got past Light (2026-11-22). Wine never reports
 * those kinds of change anyway; every other kind asked for is still watched.
 *
 * The 32-bit build is for the asset database's tray program (GdtDBTray, a
 * 32-bit program the tools start; it runs as bin\GdtDBTray.<n>.tmp). It has
 * the same folder watch, and it reads the output of gdtDb.exe through a
 * pipe: ReadFile with an OVERLAPPED whose event it waits on together with the
 * gdtDb process. When gdtDb ends while a read waits, the read fails
 * (broken pipe); Windows then leaves the OVERLAPPED and its event alone (an
 * error on a synchronous handle is not reported through them), but Wine
 * (11.0 and upstream: server/async.c signals the event of a failed read that
 * had to wait) signals the event and leaves the OVERLAPPED pending, so the
 * tray took it for a finished read, GetOverlappedResult answered
 * ERROR_IO_INCOMPLETE, and the tray's own log line for that case
 * ("GetLastError()=%s" with a number) crashed it: "GdtDBTray.0.tmp has
 * encountered a serious problem" at every start of the tools (2026-11-22,
 * reproduced 19 times out of 20 with a small test program). In the 32-bit
 * build ReadFile is pointed at a version that leaves the event unsignaled
 * after a read that failed at once, as Windows does.
 *
 * Build (mingw-w64):
 *   x86_64-w64-mingw32-gcc -shared -O2 -s -nostdlib -Wl,--entry,DllMain \
 *     -o msvcr110.dll msvcr110-forward.c msvcr110-forward.def -lkernel32
 *   i686-w64-mingw32-gcc -shared -O2 -s -nostdlib -Wl,--entry,_DllMain@12 \
 *     -o msvcr110.dll msvcr110-forward.c msvcr110-forward-x86.def -lkernel32
 * (the x86 .def: every export of Microsoft's 32-bit msvcr110, same ordinals)
 */
#include <windows.h>

#ifdef _WIN64
/* msvcr110.dll 11.0.61030.0 (x64): the encoded FlushProcessWriteBuffers
 * pointer of its Concurrency Runtime and the cookie it is XORed with */
#define FPWB_SLOT_RVA   0xc80b0
#define FPWB_COOKIE_RVA 0xc25a0

static void (WINAPI *real_flush)(void);
static SRWLOCK flush_lock = SRWLOCK_INIT;

static void WINAPI flush_one_at_a_time(void)
{
    AcquireSRWLockExclusive(&flush_lock);
    real_flush();
    ReleaseSRWLockExclusive(&flush_lock);
}

static void serialize_flush(HMODULE ms)
{
    BYTE *base = (BYTE *)ms;
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(base + ((IMAGE_DOS_HEADER *)base)->e_lfanew);
    FARPROC flush = GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "FlushProcessWriteBuffers");
    ULONG_PTR *slot, cookie;

    if (!flush || nt->OptionalHeader.SizeOfImage < FPWB_SLOT_RVA + sizeof(ULONG_PTR)) return;
    slot = (ULONG_PTR *)(base + FPWB_SLOT_RVA);
    cookie = *(ULONG_PTR *)(base + FPWB_COOKIE_RVA);
    if ((*slot ^ cookie) != (ULONG_PTR)flush)
    {
        OutputDebugStringA("Siliconium msvcr110: unknown runtime build, FlushProcessWriteBuffers left as it is\n");
        return;
    }
    real_flush = (void (WINAPI *)(void))flush;
    *slot = (ULONG_PTR)flush_one_at_a_time ^ cookie;   /* .data: writable */
}
#endif

/* The change kinds Wine's NtNotifyChangeDirectoryFile accepts (its
 * FILE_NOTIFY_ALL): file and folder names, attributes, size, last write, last
 * access, creation, security. Windows also takes EA (0x80) and the stream
 * kinds (0x200, 0x400, 0x800) */
#define WINE_NOTIFY_KINDS 0x17f

static BOOL WINAPI read_directory_changes(HANDLE dir, void *buffer, DWORD len, BOOL subtree, DWORD filter,
                                          DWORD *returned, OVERLAPPED *overlapped,
                                          LPOVERLAPPED_COMPLETION_ROUTINE completion)
{
    if (filter & WINE_NOTIFY_KINDS) filter &= WINE_NOTIFY_KINDS;   /* none left: Wine's answer as before */
    return ReadDirectoryChangesW(dir, buffer, len, subtree, filter, returned, overlapped, completion);
}

#ifndef _WIN64
static BOOL WINAPI read_file(HANDLE file, void *buffer, DWORD len, DWORD *done, OVERLAPPED *overlapped)
{
    BOOL ok = ReadFile(file, buffer, len, done, overlapped);
    DWORD error;

    if (ok || !overlapped || !overlapped->hEvent) return ok;
    if ((error = GetLastError()) == ERROR_IO_PENDING) return ok;   /* still going: its event tells */
    ResetEvent((HANDLE)((ULONG_PTR)overlapped->hEvent & ~(ULONG_PTR)1));   /* low bit: no completion port */
    SetLastError(error);
    return ok;
}
#endif

static const struct { const char *name; void *ours; } hooks[] =
{
    { "ReadDirectoryChangesW", read_directory_changes },
#ifndef _WIN64
    { "ReadFile", read_file },
#endif
};

static int same(const char *a, const char *b)
{
    while (*a && *a == *b) a++, b++;
    return *a == *b;
}

/* Points the program's imports named in hooks[] (any DLL) at ours */
static void patch_imports(void)
{
    BYTE *base = (BYTE *)GetModuleHandleW(NULL);
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(base + ((IMAGE_DOS_HEADER *)base)->e_lfanew);
    IMAGE_DATA_DIRECTORY *dir = &nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    IMAGE_IMPORT_DESCRIPTOR *imp;

    if (!dir->VirtualAddress) return;
    for (imp = (IMAGE_IMPORT_DESCRIPTOR *)(base + dir->VirtualAddress); imp->Name; imp++)
    {
        IMAGE_THUNK_DATA *name, *slot;

        if (!imp->OriginalFirstThunk) continue;   /* no names left to match */
        name = (IMAGE_THUNK_DATA *)(base + imp->OriginalFirstThunk);
        slot = (IMAGE_THUNK_DATA *)(base + imp->FirstThunk);
        for (; name->u1.AddressOfData; name++, slot++)
        {
            const char *imported;
            DWORD prot, h;

            if (IMAGE_SNAP_BY_ORDINAL(name->u1.Ordinal)) continue;
            imported = (const char *)((IMAGE_IMPORT_BY_NAME *)(base + name->u1.AddressOfData))->Name;
            for (h = 0; h < sizeof(hooks) / sizeof(hooks[0]); h++)
            {
                if (!same(imported, hooks[h].name)) continue;
                if (!VirtualProtect(&slot->u1.Function, sizeof(slot->u1.Function), PAGE_READWRITE, &prot)) break;
                slot->u1.Function = (ULONG_PTR)hooks[h].ours;
                VirtualProtect(&slot->u1.Function, sizeof(slot->u1.Function), prot, &prot);
                break;
            }
        }
    }
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    static const WCHAR ms_name[] = L"msvcr110_ms.dll";
    WCHAR path[MAX_PATH];
    DWORD n, i, cut = 0;
    HMODULE ms;

    (void)reserved;
    if (reason != DLL_PROCESS_ATTACH) return TRUE;
    patch_imports();
    /* Microsoft's runtime from this DLL's folder (the forwarded exports
     * resolve to that same module), initialized by this load */
    n = GetModuleFileNameW(instance, path, MAX_PATH);
    if (!n || n >= MAX_PATH) return TRUE;
    for (i = 0; i < n; i++) if (path[i] == L'\\' || path[i] == L'/') cut = i + 1;
    if (cut + sizeof(ms_name) / sizeof(WCHAR) > MAX_PATH) return TRUE;
    for (i = 0; i < sizeof(ms_name) / sizeof(WCHAR); i++) path[cut + i] = ms_name[i];
    ms = LoadLibraryW(path);
#ifdef _WIN64
    if (ms) serialize_flush(ms);
#else
    (void)ms;   /* the 32-bit runtime's FlushProcessWriteBuffers: not looked at (the tray has no use for it) */
#endif
    return TRUE;
}

int __cdecl _resetstkoflw(void)
{
    MEMORY_BASIC_INFORMATION mbi;
    SYSTEM_INFO si;
    DWORD old;
    volatile char here = 0;
    char *guard;

    if (!VirtualQuery((const void *)&here, &mbi, sizeof(mbi)) || !mbi.AllocationBase) return 0;
    GetSystemInfo(&si);
    guard = (char *)mbi.AllocationBase + si.dwPageSize;   /* above the no-access page */
    if ((char *)&here < guard + 2 * si.dwPageSize) return 0;   /* no room left */
    return VirtualProtect(guard, si.dwPageSize, PAGE_READWRITE | PAGE_GUARD, &old) != 0;
}
