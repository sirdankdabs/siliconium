/* Siliconium: x87-bundle, in front of x87sidecar (X87_SIDECAR_PATH names it).
 *
 * Wine's ntdll starts a program named in X87_SIDECAR_PROGRAMS as
 * `x87sidecar --cooperative <loader> <arguments>`, and the loader it names is
 * a bare link of Wine's loader in its temporary folder (winetemp-…/<program>),
 * not the "Siliconium Game.app" copy that launch.sh exports as WINELOADER
 * (tools/game-bundle.sh). macOS turns Game Mode on only for the executable of
 * an app bundle of the games category, and it does not let a bare program
 * become the active app from outside: Plutonium's games, IW4X and the 32-bit
 * Steam games had no Game Mode, and the menu bar stayed over the game until a
 * click (2026-11-23). This puts WINELOADER's bundle loader in place of that
 * link when both are copies of the same loader (same size), then starts the
 * real x87sidecar (SIL_X87_SIDECAR) with everything else unchanged.
 *
 *   x87-bundle --cooperative <loader> <arguments…>
 *
 * Built with: clang -O2 -arch arm64 -mmacosx-version-min=14.0 -o x87-bundle x87-bundle.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

int main(int argc, char **argv)
{
    const char *real = getenv("SIL_X87_SIDECAR"), *bundle = getenv("WINELOADER");
    struct stat a, b;

    if (!real || !*real) { fprintf(stderr, "x87-bundle: SIL_X87_SIDECAR is not set\n"); return 127; }
    /* argv[1] is --cooperative, argv[2] the loader */
    if (argc > 2 && bundle && strstr(bundle, ".app/Contents/MacOS/") && access(bundle, X_OK) == 0 &&
        strcmp(argv[2], bundle) && stat(argv[2], &a) == 0 && stat(bundle, &b) == 0 && a.st_size == b.st_size)
        argv[2] = (char *)bundle;
    argv[0] = (char *)real;
    execv(real, argv);
    perror("x87-bundle: cannot start x87sidecar");
    return 127;
}
