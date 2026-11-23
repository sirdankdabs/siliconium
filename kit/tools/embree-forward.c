/* Siliconium: embree64r.dll for Black Ops III Mod Tools (kit/bo3-modtools.sh).
 *
 * Radiant's lighting (and the Asset Editor) ray-trace with Intel Embree 2.3.3
 * (bin\embree64r.dll). Embree starts its worker threads the first time it
 * builds a scene and pins each one with SetThreadGroupAffinity and
 * SetThreadIdealProcessorEx; when either fails it throws ("cannot set ideal
 * processor") after the first worker. Wine's SetThreadIdealProcessorEx is a
 * stub that fails (wine-11.0, kernelbase/thread.c), so Embree was left with
 * one worker while its build waits in a lock-step barrier for all of them:
 * the light bake stopped for good at "Probes...." (2026-11-22).
 *
 * This DLL forwards every Embree export to Steam's DLL, kept beside it in the
 * workspace as embree64r_steam.dll (embree-forward.def, same ordinals), and
 * gives that DLL a SetThreadIdealProcessorEx that does what Windows' does for
 * the one processor group Wine has: sets the ideal processor (Wine's
 * SetThreadIdealProcessor, a scheduling hint) and reports success. Nothing
 * else changes, and only the programs that load Embree from the workspace use
 * it: the engine and the games keep Wine's own function.
 *
 * Build (mingw-w64):
 *   x86_64-w64-mingw32-gcc -shared -O2 -s -nostdlib -Wl,--entry,DllMain \
 *     -o embree64r.dll embree-forward.c embree-forward.def -lkernel32
 */
#include <windows.h>

static BOOL WINAPI ideal_processor_ex(HANDLE thread, PROCESSOR_NUMBER *ideal, PROCESSOR_NUMBER *previous)
{
    DWORD old;

    if (!ideal || ideal->Group)   /* Wine has one processor group */
    {
        SetLastError(ERROR_INVALID_PARAMETER);
        return FALSE;
    }
    if ((old = SetThreadIdealProcessor(thread, ideal->Number)) == (DWORD)-1) return FALSE;
    if (previous)
    {
        previous->Group = 0;
        previous->Number = (BYTE)old;
        previous->Reserved = 0;
    }
    return TRUE;
}

static int same(const char *a, const char *b)
{
    while (*a && *a == *b) a++, b++;
    return *a == *b;
}

/* Points the module's import of SetThreadIdealProcessorEx (any DLL) at ours */
static void patch_imports(HMODULE module)
{
    BYTE *base = (BYTE *)module;
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
            DWORD prot;

            if (IMAGE_SNAP_BY_ORDINAL(name->u1.Ordinal)) continue;
            if (!same((const char *)((IMAGE_IMPORT_BY_NAME *)(base + name->u1.AddressOfData))->Name,
                      "SetThreadIdealProcessorEx")) continue;
            if (!VirtualProtect(&slot->u1.Function, sizeof(slot->u1.Function), PAGE_READWRITE, &prot)) continue;
            slot->u1.Function = (ULONG_PTR)ideal_processor_ex;
            VirtualProtect(&slot->u1.Function, sizeof(slot->u1.Function), prot, &prot);
        }
    }
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    static const WCHAR real_name[] = L"embree64r_steam.dll";
    WCHAR path[MAX_PATH];
    DWORD n, i, cut = 0;
    HMODULE real;

    (void)reserved;
    if (reason != DLL_PROCESS_ATTACH) return TRUE;
    /* Steam's Embree from this DLL's own folder (the forwarded exports then
     * resolve to that same module) */
    n = GetModuleFileNameW(instance, path, MAX_PATH);
    if (!n || n >= MAX_PATH) return FALSE;
    for (i = 0; i < n; i++) if (path[i] == L'\\' || path[i] == L'/') cut = i + 1;
    if (cut + sizeof(real_name) / sizeof(WCHAR) > MAX_PATH) return FALSE;
    for (i = 0; i < sizeof(real_name) / sizeof(WCHAR); i++) path[cut + i] = real_name[i];
    if (!(real = LoadLibraryW(path))) return FALSE;
    patch_imports(real);
    return TRUE;
}
