# Siliconium — architecture

State: `main` = published 1.2.0 (1.0.0 plus the Steam Library section and CoD4X in 1.1.0; United Offensive, GLDirect rendering fixes and the Black Ops II XAudio2 fix in 1.1.1; Infinite Warfare, IW7-Mod (CBServers), the AlterWare explanation tab, CoD4X with Steam, the bash 3.2 start fix and the disk-usage fixes in 1.2.0).

## 1. Pieces

| Piece | Where | What it does |
|---|---|---|
| App | `app/` (SwiftUI, `Package.swift`; `Sources/Siliconium/{Model,Views,ControllerSupport}.swift`) | UI over the kit. Every action is `runScript("<script>.sh", args)`. A line `==> …` becomes progress text, `ERROR: …` an alert. Runs scripts at user-interactive QoS and holds an App Nap activity while a game runs. Asks for the microphone before a game starts. |
| Kit | `kit/` (bash), bundled in the app at `Contents/Resources/kit` | Installs the engine, sets up prefixes, launches every game. **The app runs its bundled kit**: after any change in `kit/`, `./build-app.sh` and reinstall `/Applications/Siliconium.app`. |
| Engine | installed to `~/Library/Application Support/Siliconium/engine` by `kit/install-engine.sh` | Own Wine build 0.2.3 (CrossOver 26.3 sources) + our modules (`kit/payload/x86_64-unix/*.so`, `kit/payload/i386-windows/*.dll`), DXVK, DXMT, MoltenVK, x87sidecar. |
| Build | `build-app.sh` → `dist/Siliconium.app` | Installing to `/Applications` is a separate copy (`rm -rf` + `ditto`). |

Data folder `~/Library/Application Support/Siliconium` (`SIL_HOME` overrides): `engine/`, `prefix/`
(Plutonium, IW4X, boiii), `prefix-iw6/` (Ghosts), `prefix-bo2c/` (BO2 campaign offline),
`prefix-steam/` (Steam for Windows: BO2 campaign tile and the Steam Library), `cache/` (DXVK state
caches, MoltenVK caches per game, `steam-<id>/` per Steam game), `logs/` (the logs every start
appends to are capped by `log_cap` in launch.sh: newest 1 MB once over 2 MB), `cod4x/` and `iw7mod/`
(clients' copies of Steam games, `kit/tools/steam-copy.sh`), `downloads/` (only during an install:
emptied after it; an update reuses the installed Wine Gecko, MoltenVK and x87sidecar and downloads
the engine archive again, and never falls back to CrossOver's runtime over an own engine of the
same version), `settings.conf` (`NAME=value`, written by the app, every key exported by launch.sh).

## 2. Graphics and CPU paths

| API | Translation | Games |
|---|---|---|
| Direct3D 9, 32-bit | our DXVK 1.10.3 (`kit/payload/i386-windows/d3d9.dll`, `patches/dxvk-d3d9.patch`, builtin) → Vulkan → MoltenVK → Metal | WaW, BO1, MW2 (IW4X), MW3 (Plutonium); Steam: CoD2, CoD4, WaW, BO1 |
| Direct3D 9, 64-bit | our x64 DXVK (`kit/payload/dxvk64/d3d9.dll`: Gcenx DXVK-macOS 1.10.3-20230507 + `dxvk-d3d9-x64.patch` + `dxvk-x64-async2.patch`), native per exe | Steam MW2, MW3 |
| Direct3D 11 | DXMT 0.80 (`kit/payload/dxmt`, 4 patches) → Metal | BO2, Ghosts, BO3 (Ezz); Steam BO2, Ghosts. Steam AW: same + upstream ab984cf (`payload/steam/aw-d3d11.dll`, native for AW's exes from `prefix-steam/drive_c/windows/system32`) and its own translator (`payload/steam/aw-winemetal.so`, tessellation fixes, run from a clone of the engine's `lib/wine`; DXMT cache `dxmt/<exe>/airconv-aw5`). Steam Infinite Warfare (`iw7_ship.exe`, `IW7_DXMT_FIX`): the same two AW files and clone |
| OpenGL | Wine's opengl32 → macOS OpenGL (Apple's GL on Metal) | Steam CoD1 |

- MoltenVK 1.4.1 on macOS < 26, 1.4.2 on 26+ (`kit/tools/moltenvk.sh`; 1.4.0 broke 32-bit buffers under WoW64). Wrapped by our shader-cache shim `kit/payload/lib64/libMoltenVK.dylib` (`kit/tools/mvkcache.c`, 8 shards; `MVKCACHE_FPS=1` prints FPS lines to the game log).
- x87sidecar (athei, installed v1.9.1) for 32-bit x87 maths under Rosetta, per process (`X87_SIDECAR_PROGRAMS`).
- DXVK async levels (our patches): 0 sync, 1 async, 2 everything in the background (incl. render targets first bound this frame).

## 3. Launch flow (`kit/launch.sh <game> <mode> …`)

Settings → `stop_all` → folder checks → engine module updates (`install_own_engine_module`, only
when the installed sha is in the accepted list) → MoltenVK ensure → DS4 mapping → display (1x
best-refresh mode held by `tools/displaymode` for D3D9/GL games) → environment + registry queued
and written in one `regedit` pass (`reg_flush`) → per-game cvars → start.

Modes: `waw|bo1|bo2|iw5 …` (Plutonium), `iw4` (IW4X), `iw6` (Ghosts), `boiii` (Ezz BO3),
`bo2c` (BO2 campaign offline), `bo2s` (BO2 campaign via Steam), `steam:<id>-<sp|mp|zm>` (Steam Library).

## 4. Steam Library

Goal: every Steam CoD plays from Steam's **original files** (no Steamless, no file changes) with
the same Siliconium setup as its Plutonium/IW4X counterpart, fullscreen at the display's size and
best refresh, controller support, achievements/playtime through Steam.

- `kit/steam.sh`: Steam for Windows in `prefix-steam` (status, library with parts + DLC count, setup, open, download, store, start, gamedir, state). Steam overlay off through `tools/steam-overlay-off.py` (edits `localconfig.vdf` with Steam closed; overlay DLLs are never moved — Steam re-installs or refuses with "Corrupt file signature").
- `kit/tools/steam-games.sh`: the table (exe, appid, API, `s_own`, `s_kind` q3|iw|t6|iw6, `s_async`, `s_pad` map|native), command line (`steam_args`), config writers (`steam_config`, `steam_q3_config` for CoD1, a `cod2` branch for CoD2 profiles), controller binds (`steam_pad_binds`).
- `launch.sh steam:*`: everything gated on `t=steam` (Plutonium paths untouched). Steam is killed and restarted so it inherits the environment; then the game exe is started **directly** with `SteamAppId`/`SteamGameId` (`s_own=0`, all parts): Steam-started games (`-applaunch`) open behind other apps (Windows foreground rule) and MW2 ignored `-applaunch` arguments. `STEAM_APPLAUNCH=1` in settings.conf forces `-applaunch` for tests. CoD1/CoD2 get `WINEPATH=C:\Program Files (x86)\Steam` (they load `steam.dll` by name).
- Per game: DXVK cache/config in `cache/steam-<id>/`, `WINE_LARGE_ADDRESS_AWARE=1` for 32-bit, x87 sidecar, display capture setting per exe, `WINE_MAC_MOUSELOOK=2` (all but Ghosts/AW: 0), dialog guard (`payload/steam/dialog-guard.exe` answers No to "Set Optimal Settings?"/"Safe Mode"), pad mapper (`payload/steam/pad-mapper.exe`: XInput → numpad keys bound to exact commands, for games without PC pad support), per-exe native DLLs from `prefix-steam/drive_c/windows/syswow64` with `AppDefaults\<exe>\DllOverrides` (BO1 MP: Plutonium's `mp-d3d9.dll` with the builtin mark replaced; CoD2: `payload/steam/cod2-d3d9.dll`; XAudio2 for BO1/WaW from the game's own redist cab). Every other 32-bit D3D9 exe gets an explicit `d3d9=builtin`.
- Ghosts: borderless (no display capture). AW: exclusive fullscreen at the desktop's size, held at the 1x mode (`d3d11x64:s1`), display capture per `CAPTURE_DISPLAY`, its profile written by `steam_config aw`.
- Ghosts: `kit/payload/iw6/iw6-focus` + `iw6-restore.exe` restore the minimized window when the game's Mac app is activated (hide-on-deactivate only for Ghosts, both parts: no executable name or an `iw6…` one; CoD1 and United Offensive with GLDirect and CoD2, all parts, get restore only).
- Community clients on the Steam Library's setup (`s_client`, `t=steam`; started without Steam, except CoD4X, which starts Steam for Windows in the background when it is set up: `COD4X_STEAM`): `launch.sh cod4x play` (`kit/tools/cod4x.sh`, Steam's CoD4 MP setup from a clone copy) and `launch.sh iw7mod play` and `launch.sh steam iw-sp` with `STEAM_MOD_IW=iw7mod` (`kit/tools/iw7mod.sh`: CBServers' iw7-mod.exe (fork of AuroraMod's) from CBServers/updater at a pinned commit, SHA-256 pinned, a non-CBServers exe replaced; a Steam download is played from an APFS-clone copy in `Siliconium/iw7mod/` (Steam's folder never changed itself); no clone possible → refused, never a full copy; `s_exe=iw7-mod.exe` because the game runs inside it; `-nosteam`; its own switches `IW7MOD_*` mapped onto `IW7_*`/`DISPLAY_MODE`; profile `iw7-mod/players2/config_mp.cfg` with `seta r_mode` / `seta r_refreshRate` by name; DXMT database and Metal folder shared with Steam's `iw7_ship.exe` through `DXMT_SHADER_CACHE_PATH` + a `com.apple.metal` link, `iw7_shared_metal`). The AlterWare section is an explanation page only (`GameTab.alterware` / `Game.alterware` → `AlterWareInfoView`; nothing in the kit): AlterWare's Ghosts client cannot sign in online under Rosetta 2 and its Advanced Warfare client was discontinued.
- Clients' copies of Steam games (`kit/tools/steam-copy.sh`, sourced by cod4x.sh/iw7mod.sh): `sil_copy_make` clones Steam's folder whole (`cp -cRp`, ~0.3-0.7 s for IW's 1753 files; the old per-file re-sync took 8.5 s), lists Steam's files in `.siliconium-steam-files` (`f <path>` / `d <folder>`), carries the client's files over from the previous copy (its skip list: CoD4X `iw3mp.exe mss32.dll miles32.dll players/ __* *.log`, IW7-Mod `iw7-mod.exe(.old) iw7-mod/ players2/ minidumps/ *.log`, plus anything not from Steam; a path in Steam's folder is Steam's current file, as the old re-sync did), marks it in use (`.siliconium-in-use` = launch.sh's PID) and excluded from Time Machine (sticky xattr `com_apple_backup_excludeItem`, as `tmutil addexclusion` writes it; tmutil itself took 11 s), then swaps it in (`.part`/`.old`, recovered after an interruption; one change at a time: `<copy>.lock` with the holder's PID). launch.sh's EXIT trap (`copy_release`, also on Stop's SIGTERM) runs `steam-copy.sh release <client> <copy> <generation> 60`: a minute later, unless the copy was made again (list inode changed) or is in use (in-use PID alive or the client's exe running), Steam's listed files and empty folders are removed, the list emptied and the TM exclusion dropped. `steam-copy.sh tidy` (each launch.sh start, in the background; the app at launch) does the same for every copy nobody uses, and empties copies made before the list existed by reading Steam's folder (settings or the default library). No clones (another volume): CoD4X keeps a real copy (`.siliconium-full-copy`), synced in place, emptied only once the game is gone from Steam; IW7-Mod refuses. `uninstall.sh cod4x|iw7mod` releases before trashing.

## 5. Decisions and why (keep them)

- **Never touch Plutonium/IW4X/BOIII paths** when changing the Steam Library: gate on `t=steam` or the Steam exe. Shared engine files (e.g. `i386-windows/d3d9.dll`) stay as they are; Steam-only variants go per exe (syswow64 + AppDefaults). `WINEDLLPATH` cannot be used for that: Wine searches its own dll dir first.
- **Port the Plutonium/IW4X setup per game line by line** (warming, pipelines, dvars, audio, mouse), then add Steam-only things (controller, mouselook 2, direct launch, resolution).
- **Original game files only**: no Steamless, no edits inside the game folder except the game's own config files.
- **Direct launch (`s_own=0`)** for every part: games come to the front from the first start.
- **Config files are written before every start**: Steam does not pass Play's arguments to every game, and Q3/IW games exec their profile config after the command line.
- Patched Mach-O engine modules must be re-signed (`codesign -fs -`); the accepted-sha list lets existing engines update.
