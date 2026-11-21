# Siliconium — working notes for Claude Code

Siliconium is a SwiftUI Mac app (`app/`) over a bash kit (`kit/`) that runs Call of
Duty games on Apple silicon through our own Wine build (CrossOver 26.3 sources) with DXVK, DXMT,
MoltenVK and x87sidecar, plus our patches. Read in this order: ARCHITECTURE.md, COMPATIBILITY.md,
KNOWN_ISSUES.md, TESTING.md, CHANGELOG.md (newest section).

## Branches

- `main`: published 1.1.1 (1.1.0 Steam Library + CoD4X; 1.1.1 United Offensive, GLDirect rendering fixes, Black Ops II XAudio2 fix). Do not commit or push anything without the owner asking.
- `steam-library`: where 1.1.x is developed (merged into `main` for each release).

## Hard rules

1. Never change Plutonium / IW4X / BOIII behaviour: gate Steam work on `t=steam` or the Steam exe; Steam-only DLL variants go per exe (`prefix-steam/.../syswow64` + `AppDefaults\<exe>\DllOverrides`), never into the engine's shared files.
2. Each Steam game must match its Plutonium/IW4X counterpart (port that setup line by line), from Steam's original files (no Steamless, no edits in the game folder other than its config files).
3. One change at a time; diagnose from logs, window state and profiles **before** changing anything; justify every patch with measurements; measure before and after (TESTING.md).
4. After any change in `kit/`: quit game + app, `./build-app.sh`, reinstall `/Applications/Siliconium.app`.
5. Never steal focus or hide the game while the owner plays; ask before tests that take the screen; window-only screenshots.
6. Back up a game's config before experiments (Q3/IW games save changed cvars at once).
7. Don't mark anything done that was not verified (log numbers or the owner's confirmation).
8. Patched Mach-O modules: re-sign (`codesign -fs -`) and add the old payload sha to the accepted list in launch.sh.

## Where to continue (priority order agreed with the owner)

1. Call of Duty (CoD1) performance — in progress, see KNOWN_ISSUES "low FPS (OpenGL)". Next step: trace the game's vertex-buffer calls (`glBufferDataARB` / `glBufferSubDataARB`: sizes, offsets, rewrites per frame) and only then decide a fix in Wine's `glBufferSubData` path; `r_vbo_stream_draw 0` (+18-25 %, measured) is not applied yet.
2. Ghosts (Steam): re-test the black-screen fix (`iw6-focus` changed).
3. Advanced Warfare.
4. World at War, CoD4 MP, Black Ops II.
Target: 120+ FPS wherever the game allows it.
