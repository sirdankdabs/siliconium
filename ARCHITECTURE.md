# Siliconium — architecture

State: `main` = published 1.3.0 (1.0.0 plus the Steam Library section and CoD4X in 1.1.0; United Offensive, GLDirect rendering fixes and the Black Ops II XAudio2 fix in 1.1.1; Infinite Warfare, IW7-Mod (CBServers), the AlterWare explanation tab, CoD4X with Steam, the bash 3.2 start fix and the disk-usage fixes in 1.2.0; the offline Black Ops II campaign and its DRM removal tool taken out in 1.2.1; the Battle.net section with Black Ops 4, Steam WWII, the Black Ops III Mod Tools, macOS Game Mode for every game, the game in front at start and the fast Cmd-Tab return in 1.3.0).

## 1. Pieces

| Piece | Where | What it does |
|---|---|---|
| App | `app/` (SwiftUI, `Package.swift`; `Sources/Siliconium/{Model,Views,ControllerSupport}.swift`) | UI over the kit. Every action is `runScript("<script>.sh", args)`. A line `==> …` becomes progress text, `ERROR: …` an alert. Runs scripts at user-interactive QoS and holds an App Nap activity while a game runs. Asks for the microphone before a game starts. |
| Kit | `kit/` (bash), bundled in the app at `Contents/Resources/kit` | Installs the engine, sets up prefixes, launches every game. **The app runs its bundled kit**: after any change in `kit/`, `./build-app.sh` and reinstall `/Applications/Siliconium.app`. |
| Engine | installed to `~/Library/Application Support/Siliconium/engine` by `kit/install-engine.sh` | Own Wine build 0.2.3 (CrossOver 26.3 sources) + our modules (`kit/payload/x86_64-unix/*.so`, `kit/payload/i386-windows/*.dll`), DXVK, DXMT, MoltenVK, x87sidecar. |
| Build | `build-app.sh` → `dist/Siliconium.app` | Installing to `/Applications` is a separate copy (`rm -rf` + `ditto`). |

Data folder `~/Library/Application Support/Siliconium` (`SIL_HOME` overrides): `engine/`, `prefix/`
(Plutonium, IW4X, boiii), `prefix-iw6/` (Ghosts), `prefix-bo2c/` (BO2 campaign offline, removed in 1.2.1: only cleaned up by uninstall.sh),
`prefix-steam/` (Steam for Windows: BO2 campaign tile and the Steam Library), `prefix-battlenet/` (Battle.net for Windows: the Battle.net section), `cache/` (DXVK state
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

- MoltenVK 1.4.1 on macOS < 26, 1.4.2 on 26+ (`kit/tools/moltenvk.sh`; 1.4.0 broke 32-bit buffers under WoW64). Wrapped by our shader-cache shim `kit/payload/lib64/libMoltenVK.dylib` (`kit/tools/mvkcache.c`, 8 shards; `MVKCACHE_FPS=1` prints FPS lines to the game log). MoltenVK compiles every Metal library of a saved cache while it reads it (fast when Metal's shader cache has them, minutes when not: after a macOS update, or libraries another game added): since 1.3.2 the shards are read in the background, one thread each, and a pipeline whose shard is not ready yet is created without a cache, so the game never waits (before: one library at a time behind one lock, and no pipeline until all 8 were read). `launch.sh` (`install_own_moltenvk`) updates the engine's copy from earlier builds.
- x87sidecar (athei, installed v1.9.1) for 32-bit x87 maths under Rosetta, per process (`X87_SIDECAR_PROGRAMS`).
- DXVK async levels (our patches): 0 sync, 1 async, 2 everything in the background (incl. render targets first bound this frame).

## 3. Launch flow (`kit/launch.sh <game> <mode> …`)

Settings → `stop_all` → folder checks → engine module updates (`install_own_engine_module`, only
when the installed sha is in the accepted list) → MoltenVK ensure → DS4 mapping → display
(`tools/displaymode`: `restore` first puts back a mode left by a hold that did not end normally; then, for
fullscreen games, an unscaled HiDPI desktop of the game's size (the panel's own pixels, `SIL_KEEP_UNSCALED=1`,
`KEEP_HIDPI=0` turns it off) is kept as it is; otherwise the 1x best-refresh mode of that size is held as the
login session's mode while the game runs, so a Cmd-Tab release of Wine's display capture keeps it; the desktop's
mode and the held one are recorded in `cache/displaymode-desktop` under a lock until it is put back; one rule,
`decide()`, serves the hold and `displaymode plan` (1x | kept | already | none, with the final mode's rate), from
which launch.sh and the Mod Tools take every refresh setting and frame cap, and `displaymode info`, which the app's
Display sheet shows; an earlier launch's hold is stopped before the desktop's mode is read) → environment + registry queued
and written in one `regedit` pass (`reg_flush`) → per-game cvars → start.

Modes: `waw|bo1|bo2|iw5 …` (Plutonium), `iw4` (IW4X), `iw6` (Ghosts), `boiii` (Ezz BO3),
`bo2c` (BO2 campaign offline: removed in 1.2.1, stops with a message), `bo2s` (BO2 campaign via Steam), `steam:<id>-<sp|mp|zm>` (Steam Library), `battlenet <id>` (Battle.net section).

Every game, every launch path (Plutonium, IW4X, BOIII, Ghosts offline, Steam Library, Battle.net):

- **macOS Game Mode**: `use_wine` (`tools/game-bundle.sh`) runs Wine's loader as the executable of a
  small games-category app bundle ("Siliconium Game"), exported as `WINELOADER`; macOS turns Game Mode
  on only for an app bundle's executable (`GAME_MODE=0` in settings.conf: off). 32-bit programs on the
  x87 list (`X87_SIDECAR_PROGRAMS`: Plutonium, IW4X, CoD4X, the 32-bit Steam games) are re-started by
  Wine's ntdll as `x87sidecar --cooperative <loader> …` with a bare link of the loader in Wine's temp
  folder, which is not a bundle: no Game Mode, and macOS refuses to make it the active app. So
  `X87_SIDECAR_PATH` names `payload/x87/x87-bundle` (`tools/x87-bundle.c`) when `WINELOADER` is set: it
  puts `WINELOADER`'s bundle copy in place of that link (only when both have the same size = the same
  loader) and execs the real sidecar named by `SIL_X87_SIDECAR`; the x87 acceleration is unchanged.
  `X87=0` clears all three.
- **Game Mode in the Black Ops III Mod Tools** (`bo3-modtools.sh`): the launcher runs on the Game Mode loader; Wine starts every program another one starts on its own loader, so a map test (BlackOps3.exe) gets Game Mode only through `payload/bo3-modtools/bundle-exec` on the x87 hook (`X87_SIDECAR_PROGRAMS=BlackOps3.exe`), which is opt-in (`MODTOOLS_GAME_MODE=1` in settings.conf) until it is seen in a real map test.
- **Front at start + Cmd-Tab return**: `focus_helper <program>[:<program>…] [pid]` (launch.sh) starts
  `payload/iw6/iw6-focus` (`tools/iw6-focus.swift`) next to the game. Pid 0 = the game's Mac process is
  found by its program name (argv[0]'s basename via `KERN_PROCARGS2`; a ':' list for a fix's executable
  and the game's) once it shows a window of at least 640x480 (it waits up to 15 minutes: launchers,
  Steam's relay); the restore target is that process's program name. With `SIL_FOCUS_FROM`
  (`io.github.siliconium`, `Steam.exe`, `Battle.net.exe`, Plutonium's and IW4X's launchers) it makes the
  game the active app once per start (within 5 minutes of its window appearing), whichever app is in
  front then (since 1.3.2: a player who switched apps while the game loaded got Black Ops' exclusive
  fullscreen left behind, black, until a click); the names only label the log line. macOS does not
  bring forward a program a background process starts, and macOS 14+ may ignore a helper's request,
  so if the game is not in front 0.5 s after `activate(from:)` it asks WindowServer
  (`_SLPSSetFrontProcessWithOptions`, looked up at run time); the log says which one did it. It keeps `iw6-restore.exe --wait` resident from the start, on the plain loader (not the
  bundle's copy: 3.9 s to start instead of 1.2 s): each activation writes one line and the helper
  restores the window (answers 1/0; exits at end of input), so the picture is back 0.4-1 s after
  Cmd-Tab instead of 6-8.6 s (the time a Wine program took to start while the game ran).

## 4. Steam Library

Goal: every Steam CoD plays from Steam's **original files** (no DRM removal, no file changes) with
the same Siliconium setup as its Plutonium/IW4X counterpart, fullscreen at the display's size and
best refresh, controller support, achievements/playtime through Steam.

- `kit/steam.sh`: Steam for Windows in `prefix-steam` (status, library with parts + DLC count, setup, open, download, store, start, gamedir, state). Steam overlay off through `tools/steam-overlay-off.py` (edits `localconfig.vdf` with Steam closed; overlay DLLs are never moved — Steam re-installs or refuses with "Corrupt file signature").
- `kit/tools/steam-games.sh`: the table (exe, appid, API, `s_own`, `s_kind` q3|iw|t6|iw6, `s_async`, `s_pad` map|native), command line (`steam_args`), config writers (`steam_config`, `steam_q3_config` for CoD1, a `cod2` branch for CoD2 profiles), controller binds (`steam_pad_binds`).
- `launch.sh steam:*`: everything gated on `t=steam` (Plutonium paths untouched). Steam is killed and restarted so it inherits the environment; then the game exe is started **directly** with `SteamAppId`/`SteamGameId` (`s_own=0`, all parts): Steam-started games (`-applaunch`) open behind other apps (Windows foreground rule) and MW2 ignored `-applaunch` arguments. `STEAM_APPLAUNCH=1` in settings.conf forces `-applaunch` for tests. CoD1/CoD2 get `WINEPATH=C:\Program Files (x86)\Steam` (they load `steam.dll` by name).
- Per game: DXVK cache/config in `cache/steam-<id>/`, `WINE_LARGE_ADDRESS_AWARE=1` for 32-bit, x87 sidecar, display capture setting per exe, `WINE_MAC_MOUSELOOK=2` (all but Ghosts/AW: 0), dialog guard (`payload/steam/dialog-guard.exe` answers No to "Set Optimal Settings?"/"Safe Mode"), pad mapper (`payload/steam/pad-mapper.exe`: XInput → numpad keys bound to exact commands, for games without PC pad support), per-exe native DLLs from `prefix-steam/drive_c/windows/syswow64` with `AppDefaults\<exe>\DllOverrides` (BO1 MP: Plutonium's `mp-d3d9.dll` with the builtin mark replaced; CoD2: `payload/steam/cod2-d3d9.dll`; XAudio2 for BO1/WaW from the game's own redist cab). Every other 32-bit D3D9 exe gets an explicit `d3d9=builtin`.
- No game captures the display (2026-11-24; `CAPTURE_DISPLAY=2`: as before). Ghosts: borderless. AW: exclusive fullscreen at the desktop's size, display held as above (`d3d11x64:s1`: the 1x mode, or the unscaled HiDPI desktop kept), its profile written by `steam_config aw`.
- Ghosts: `kit/payload/iw6/iw6-focus` + `iw6-restore.exe` restore the minimized window when the game's Mac app is activated (hide-on-deactivate only for Ghosts, both parts: no executable name or an `iw6…` one; every other game gets restore only, through `focus_helper`, section 3).
- Community clients on the Steam Library's setup (`s_client`, `t=steam`; started without Steam, except CoD4X, which starts Steam for Windows in the background when it is set up: `COD4X_STEAM`): `launch.sh cod4x play` (`kit/tools/cod4x.sh`, Steam's CoD4 MP setup from a clone copy) and `launch.sh iw7mod play` and `launch.sh steam iw-sp` with `STEAM_MOD_IW=iw7mod` (`kit/tools/iw7mod.sh`: CBServers' iw7-mod.exe (fork of AuroraMod's) from CBServers/updater at a pinned commit, SHA-256 pinned, a non-CBServers exe replaced; a Steam download is played from an APFS-clone copy in `Siliconium/iw7mod/` (Steam's folder never changed itself); no clone possible → refused, never a full copy; `s_exe=iw7-mod.exe` because the game runs inside it; `-nosteam`; its own switches `IW7MOD_*` mapped onto `IW7_*`/`DISPLAY_MODE`; profile `iw7-mod/players2/config_mp.cfg` with `seta r_mode` / `seta r_refreshRate` by name; DXMT database and Metal folder shared with Steam's `iw7_ship.exe` through `DXMT_SHADER_CACHE_PATH` + a `com.apple.metal` link, `iw7_shared_metal`). The AlterWare section is an explanation page only (`GameTab.alterware` / `Game.alterware` → `AlterWareInfoView`; nothing in the kit): AlterWare's Ghosts client cannot sign in online under Rosetta 2 and its Advanced Warfare client was discontinued.
- Clients' copies of Steam games (`kit/tools/steam-copy.sh`, sourced by cod4x.sh/iw7mod.sh): `sil_copy_make` clones Steam's folder whole (`cp -cRp`, ~0.3-0.7 s for IW's 1753 files; the old per-file re-sync took 8.5 s), lists Steam's files in `.siliconium-steam-files` (`f <path>` / `d <folder>`), carries the client's files over from the previous copy (its skip list: CoD4X `iw3mp.exe mss32.dll miles32.dll players/ __* *.log`, IW7-Mod `iw7-mod.exe(.old) iw7-mod/ players2/ minidumps/ *.log`, plus anything not from Steam; a path in Steam's folder is Steam's current file, as the old re-sync did), marks it in use (`.siliconium-in-use` = launch.sh's PID) and excluded from Time Machine (sticky xattr `com_apple_backup_excludeItem`, as `tmutil addexclusion` writes it; tmutil itself took 11 s), then swaps it in (`.part`/`.old`, recovered after an interruption; one change at a time: `<copy>.lock` with the holder's PID). launch.sh's EXIT trap (`copy_release`, also on Stop's SIGTERM) runs `steam-copy.sh release <client> <copy> <generation> 60`: a minute later, unless the copy was made again (list inode changed) or is in use (in-use PID alive or the client's exe running), Steam's listed files and empty folders are removed, the list emptied and the TM exclusion dropped. `steam-copy.sh tidy` (each launch.sh start, in the background; the app at launch) does the same for every copy nobody uses, and empties copies made before the list existed by reading Steam's folder (settings or the default library). No clones (another volume): CoD4X keeps a real copy (`.siliconium-full-copy`), synced in place, emptied only once the game is gone from Steam; IW7-Mod refuses. `uninstall.sh cod4x|iw7mod` releases before trashing.

## 4b. Battle.net section

Battle.net for Windows for the Call of Duty games sold only there (Black Ops 4), right below the
Steam Library in the sidebar (`GameTab.battlenet` / `Game.battlenet`, `BattleNetView` and
`BattleNetTitle.catalog` in `app/Sources/Siliconium/BattleNetViews.swift` / `Model.swift`).

- **Its own prefix, `prefix-battlenet`**, not Steam's: every game start stops everything in its prefix
  (`stop_all`, and Steam's restart), so in `prefix-steam` each Steam game (and the Mod Tools) would
  have closed Battle.net and its downloads, and each Battle.net game Steam. Its Wine server runs
  through the same link as Steam's (`campaign/wineserver`), so the app does not count Battle.net open
  in the background as a game; `launch.sh stop` stops it too.
- `kit/battlenet.sh`: status, library (`<id>|<state>|<folder>` from the Agent's `product.db`, read by
  `tools/battlenet-products.py`, a plain protocol-buffer reader), setup (prefix, Blizzard's installer
  checked for its signer, Battle.net, then its login window), open, download (the game's page in
  Battle.net: `--game=<product>`), start, wait, launch (`--exec="launch <code>"`), stop.
  `kit/tools/battlenet-games.sh`: the catalog (`bo4 viper VIPR BlackOps4.exe`), Battle.net's
  start and the play flow (`bnet_play`).
- Battle.net 2.53.8 is a 32-bit Qt + Chromium 108 app. It is started with
  `WINE_SIMULATE_WRITECOPY=1` (CrossOver's copy-on-write hack in our ntdll: Chromium checks that a
  page it makes read-only was read-write, and its page process stopped itself every few seconds) and
  `--in-process-gpu` (its separate GPU process could not draw into Battle.net's window: "cross-process
  swapchain not supported"). Wine's crash dialog is off in this prefix.
- `launch.sh battlenet <id>` (`t=bnet`): the shared setup (engine modules, controller mapping,
  display held as for the other fullscreen games (1x of the desktop's size, or the unscaled HiDPI desktop kept), cursor fix, `CX_GRAPHICS_BACKEND=dxmt`,
  `DXMT_CONFIG` from `BO4_ASYNC` / `BO4_FRAME_PACING`), then `bnet_play`: Battle.net (stopped with its
  prefix) starts again with this environment, the script waits for this start's login in Battle.net's
  log, asks it to launch the game, waits for the game's executable to work the CPU and returns when it
  quits. Battle.net stays open in the background. Battle.net starts with `--autostarted` (what
  Windows' log-in start passes): with its default "start minimized" setting its window stays
  minimized, as Steam's `-silent`.
- **Battle.net's engine, `battlenet/engine`**: an APFS clone of the engine made at each Play while
  Battle.net is closed (links to the engine's folders, a copy of `lib/wine`, well under a second) with
  two Wine modules of our own from `kit/payload/battlenet/`, so no other game's Wine changes:
  - `ntdll.so`: (1) Rosetta raises #UD for privileged instructions (`mov` from a debug register,
    …) where an x86 CPU raises #GP; Windows reports the latter as `EXCEPTION_PRIV_INSTRUCTION`, which
    Black Ops 4's anti-debugging handler expects (it reads `dr0` on its own stack and the game quit
    2-8 s into fullscreen when Wine reported an illegal instruction); (2) the programs named in
    `SIL_GAME_EXES` (set by `bnet_play` to the game's executable unless `GAME_MODE=0`) run from a
    copy of Wine's loader inside `<Wine's temp folder>/<exe>.app` (games category), not from Wine's
    bare link: macOS Game Mode needs the frontmost process to be an app bundle's executable, and the
    game is a child of Battle.net, not started by `launch.sh` (see `tools/game-bundle.sh`).
  - `win32u.so`: the GPU's memory in the registry's 32-bit `HardwareInformation.MemorySize` is
    clamped to 4 GB-1 (Wine wrote 0 when the Mac's memory is a multiple of 4 GB: `ULONG_MAX` is
    64-bit on the Mac); Black Ops 4 read 0, asked "Minimum System Requirements" at every start and
    its first start chose the lowest graphics preset.
  - Built from CrossOver 26.3's sources with `kit/patches/wine-ntdll*.patch` (as the engine) plus
    `kit/patches/battlenet/*.patch` (TESTING.md, "Battle.net's Wine modules").
- Helpers during a Battle.net game: `payload/battlenet/bnet-guard.exe` (`tools/bnet-guard.c`)
  answers the game's Windows message boxes (Yes to the requirements warning, kept for Macs whose GPU
  memory still reads low; No to Safe Mode, which lowers the graphics, and to "Set Optimal Settings?", which
  replaces them) and logs each answer with the box text; Ghosts'
  `iw6-focus` + `iw6-restore.exe` (restore-only mode) bring the fullscreen window back after Cmd-Tab
  or minimizing (it stayed minimized on a black screen); with `SIL_FOCUS_FROM=io.github.siliconium:Battle.net.exe:…`
  `iw6-focus` also makes the game the active app once its window is on screen (≥ 640x480), once per start,
  whichever app is in front (section 3).
- Installed state: Battle.net's own "playable" flag is not used. Under Wine its Agent clears it at
  every start after an install ("Permissions check failure (2123)": its helper service, which checks
  and fixes the folder's permissions, cannot run), while the game is complete and Battle.net still
  starts it. A game is installed when the Agent recorded its installed version (empty during the first
  download) and its executable is in its folder.

## 5. Decisions and why (keep them)

- **Never touch Plutonium/IW4X/BOIII paths** when changing the Steam Library: gate on `t=steam` or the Steam exe. Shared engine files (e.g. `i386-windows/d3d9.dll`) stay as they are; Steam-only variants go per exe (syswow64 + AppDefaults). `WINEDLLPATH` cannot be used for that: Wine searches its own dll dir first.
- **Port the Plutonium/IW4X setup per game line by line** (warming, pipelines, dvars, audio, mouse), then add Steam-only things (controller, mouselook 2, direct launch, resolution).
- **Original game files only**: no DRM removal, no edits inside the game folder except the game's own config files.
- **Direct launch (`s_own=0`)** for every part: games come to the front from the first start.
- **Config files are written before every start**: Steam does not pass Play's arguments to every game, and Q3/IW games exec their profile config after the command line.
- Patched Mach-O engine modules must be re-signed (`codesign -fs -`); the accepted-sha list lets existing engines update.
