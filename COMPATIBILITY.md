# Compatibility

Test machine for every number here: MacBook Pro M1 Pro, macOS 15.8.3, external 2560x1440 display
(HiDPI desktop 154 Hz, native 1x mode 160 Hz). "Verified" = measured in a log or confirmed by the
player in that run. Nothing below is verified on another Mac.

## Published path (1.0.0: Plutonium, IW4X, Ezz, own Ghosts / BO2 campaign)

| Game | Renderer | Status | Measured |
|---|---|---|---|
| World at War (Plutonium T4) | DXVK, async 2 + warm | Works | Zombies ~104 (CPU-bound in Rosetta), MP ~136 |
| Black Ops (Plutonium T5) | DXVK, async 1 + warm wait | Works | Zombies 152-154, MP ~131 |
| Black Ops II (Plutonium T6) | DXMT | Works | Zombies Survival Town: 159-160 FPS, 1 % low 160, 0 % missed refreshes (Metal HUD log). Audio: Microsoft's XAudio2 2.7 from the game's redist (issue #2: silent gunfire with Wine's XAudio2 on the reporter's Mac; not reproduced on the test Mac). With it, Zombies and Multiplayer played by the player: all sounds present, no crackle (loaded DLL confirmed in Wine's log). |
| Modern Warfare 2 (IW4X) | DXVK, async 2 | Works | 158-160 |
| Modern Warfare 3 (Plutonium IW5) | DXVK, async 1 | Works | 138-156 |
| Ghosts (own prefix) | DXMT | Works | stable, 0 GPU errors |
| Black Ops III (Ezz) | DXMT | Works | 120+ with lower settings; max settings GPU-bound 40-50 |

## CoD4X and IW4X with Steam's games (1.1.0)

| Game / client | Status | Evidence |
|---|---|---|
| Call of Duty 4 MP (CoD4X 21.8, from Steam's download) | **Works (player confirmed)** | Installs and starts without dialogs; CoD4X server joined online (asks once for the CoD4 key code); 2560x1440 at 160 Hz: 83-120 FPS in play, about 120 (1 % low 89-105) once its shaders were compiled; menus ~55 FPS (cause not checked yet). Plays from its own APFS-clone copy: Steam's folder identical afterwards; Steam's own CoD 4 campaign started normally after it. Controller not tested. Servers that require Steam (the server's `sv_steamforce`): Steam for Windows now starts in the background for CoD4X when it is set up (Unreleased). Verified on an M1 Pro: Steam signed in by itself (~40 s after Play), CoD4X loaded Steam's client (Steam registered the game as app 7940), a server joined, Steam's folder unchanged; a server that requires Steam was not identified, so that check itself is still open. |
| Modern Warfare 2 MP (IW4X with Steam's 64-bit MW2) | Not tested in game | IW4X's x86 client converts Steam's 64-bit maps on its first start (about 4.4 GB) and its launcher adds about 3 GB of DLC to the folder; Steam's own files are not changed (IW4X source). |

## IW7-Mod (CBServers) (Infinite Warfare community client, Unreleased)

| Game / client | Status | Evidence |
|---|---|---|
| Infinite Warfare (IW7-Mod (CBServers), build of 2026-10-23, Steam's download 2715288) | **Starts; a custom map loads** (validation in progress) | M1 Pro, 2560x1440 at 160 Hz: Play replaced the earlier client with CBServers' build, its updater fetched its scripts from CBServers, no "Preloading Shaders" (shared shader caches), both DXMT fixes; a player's custom Zombies map in `usermaps` (Nacht der Untoten remake) loaded from the Zombies lobby (its intro text shows raw labels: that map ships no English text file). **Zombies: 55-70 FPS at High settings** (player). Steam's folder unchanged during the run. Campaign, multiplayer on CBServers' servers and a long session: not verified yet. |
| Infinite Warfare (AuroraMod's IW7-Mod v1.1.0, the original client; replaced by CBServers' fork) | **Starts; main menu verified** (in-game validation in progress) | M1 Pro, macOS 15, 2560x1440 at 160 Hz: Play → its own APFS copy of Steam's folder (made in seconds, no disk space used; Steam's 1752 files unchanged in size and date, its players2 byte-identical) → updater downloaded its data (354 MB) in seconds → main menu (Campaign, Multiplayer, Zombies) about 60 s after Play, **no "Preloading Shaders"** (it uses Steam's game's shader caches: 11 272 translated shaders, none added for the menu). Running as iw7-mod.exe with both DXMT fixes (system32 d3d11.dll + the engine clone's translator), DXMT preferredMaxFrameRate 160 + async, "Setting display mode: 2560x1440@160", started without Steam (`-nosteam`). Player played Zombies in Spaceland (~3 min, closed normally, no GPU fault): "all good". Steam's folder unchanged after the run too. Campaign, multiplayer, server browser, custom maps (usermaps) and a long session: not verified yet. |

## AlterWare (not included, Unreleased)

The AlterWare section only explains why these clients are not in Siliconium; nothing is installed.

| Game / client | Status | Evidence |
|---|---|---|
| Ghosts multiplayer (AlterWare's iw6-mod, Steam's August 2026 game files with the April 2018 multiplayer executable iw6-mod requires) | **Not supported on Apple silicon** | M1 Pro, macOS 15: installed by AlterWare's launcher under Siliconium's Wine, starts in about 7 s and its menus draw at 2560x1440, but Online Play stops at "Connecting to Online Services", then "The Call of Duty: Ghosts server is not available"; iw6-mod joins a server only after that sign-in. The game's copy protection (Arxan) sets the processor's hardware breakpoints on its online code, and under Rosetta 2 they are accepted but never fire (test programs under Siliconium's Wine). Removed from Siliconium. |
| Advanced Warfare (AlterWare's s1-mod) | **Not supported** | AlterWare discontinued s1-mod (archived in August 2026); its version check rejects both of Steam's current (August 2026) executables and AlterWare provides no older build. |

## Steam Library (1.1.0)

| Game / part | Status | Evidence |
|---|---|---|
| CoD 1 SP | **Works (player confirmed)** | Through our GLDirect build (OpenGL → Direct3D 9 → DXVK): fullscreen 2560x1440 at 160 Hz, 137-159 FPS (official timedemo, warm: 137-139); no hitch on new effects (compiled on a worker thread); brightness kept after Cmd+Tab. On Apple's OpenGL (`COD1_GLDIRECT=0`) it ran at 44 FPS. Foliage, lit models and fog now draw as with Apple's OpenGL (before: tree leaves missing, distant treelines grey); official timedemo with the fix 138-139 FPS (141-142 before, with the trees missing); campaign play: average 148, median 157. |
| CoD 1 MP | Not tested | Now on GLDirect like the campaign (same switch, `COD1_GLDIRECT`); the GLDirect benchmark was this executable (official Timedemo1). CD key prompt possible. On its first start the game replaces Siliconium's config_mp.cfg with its own auto-detected settings (texture quality reduced; not fixed yet). |
| United Offensive SP | **Works (player confirmed)** | Steam app 2640, installed into Call of Duty's folder (its files in `uo/`). Gets Call of Duty's setup: GLDirect (`UO_GLDIRECT`, shares Call of Duty's compiled-effect cache), fullscreen 2560x1440 at 160 Hz, brightness kept after Cmd+Tab, focus helper, controller mapping, x87 accelerator. Bastogne (snow forest): picture checked against Apple's OpenGL from fixed camera positions (same brightness per screen area within a few percent); campaign play: average 122 FPS, median 118, lowest tenth 106 (dense forest is the heaviest view). On Apple's OpenGL (`UO_GLDIRECT=0`): 15-21 FPS. |
| United Offensive MP | Not tested in game yet | Same setup as the campaign (`CoDUOMP.exe`). CD key prompt possible (Steam lists a key location for it). |
| CoD 2 SP | **Works (player confirmed)** | Fullscreen 2560x1440, 133-160 FPS in game; needs the CoD2-only DXVK (`cod2-d3d9.dll`) for its menus and `com_introPlayed 1` against the startup-cinematic freeze. Keyboard after minimize + return: works (player). |
| CoD 2 MP | Not re-tested since the fixes | Earlier run: black after the intro (same causes as SP); the campaign's focus fixes now apply to it too. |
| CoD 4 SP | Works | 137-153 FPS, 1 % lows 87-106. |
| CoD 4 MP | Not tested | |
| WaW SP | Runs | 101-160 FPS after the 4 GB fix; then async 1 against a half-invisible weapon (not re-verified). |
| WaW MP | Not tested | Gets the campaign's shipped pipeline list and controller layout fix. |
| MW2 SP | **Works (player: "corre excelente")** | 151-160 FPS, worst frame 7-15 ms (x64 DXVK async 2, mouselook 2). |
| MW2 MP | Runs, in front from the first start (player) | Menus ~90 FPS; in-map FPS and online play not verified. |
| MW3 SP | Works | Survival: 150 FPS, menus ~60; async 1 (2 broke the world/HUD). |
| MW3 MP | **Blocked** | Stays at "Connecting to online services", also via `-applaunch` (not our launch). Parked by the player. |
| Black Ops SP | **Accepted by the player** | Plutonium t5 setup ported; r_vsync 0 removed a 120 cap. |
| Black Ops MP | **Accepted by the player** | ~91 FPS = the game's own `com_maxfps 85` in online MP (game files, not fixable without changing them); cold first map load 181 s, warm 60 s; crackle fixed. |
| Black Ops II Campaign (Steam) | Runs (player: "todo bien") | First start from the app; direct launch works with Steam's DRM wrapper. FPS not measured. ~3 min only. |
| Black Ops II Zombies (Steam) | Runs well (player) | Survival Town, warm cache, display held at 1x 160 Hz: 129-138 FPS, 1 % low 80, ~20 % of frames miss a refresh (Plutonium BO2, same map: 160 steady, 0 %). Some textures black for ~1 s now and then (open). Audio: since issue #2 uses Microsoft's XAudio2 2.7 from the game's redist, like Plutonium BO2 ("Gunfire sound fix"): not tested in game yet. |
| Black Ops II Multiplayer (Steam) | Not tested | Same XAudio2 2.7 as Zombies (issue #2), not tested in game. |
| Ghosts Campaign (Steam) | Runs (player) | Borderless on the desktop (154 Hz here): 150-154 FPS, 1 % low 77-154, 0-1 % missed refreshes. SSAO and Tessellation freeze the GPU (page fault) within minutes: forced off at every start, warning on the tile. |
| Ghosts Multiplayer (Steam) | Not tested | Gets the campaign's settings file (`players2/config_mp.cfg`: SSAO and Tessellation off every start) and focus helper. |
| Advanced Warfare Campaign (Steam) | **Playable** (validation in progress) | Fullscreen 2560x1440 at 160 Hz (its profile is set before each start; it chose 3840x2160 at 60 Hz by itself). Two DXMT fixes for AW only: the first cutscene's Metal assertion (upstream ab984cf, `aw-d3d11.dll`) and the gameplay GPU freeze (tessellation workload overflow, `aw-winemetal.so`). First mission: 15 min without a fault, 108 FPS average (median frame 6.25 ms, GPU median 8.7 ms) at Extra textures. Still to verify: long session with the shipped build, controller, audio, load time (~100 s after the cinematic). |
| Black Ops III (Steam) | Runs (player, Zombies) | Its own setup; fullscreen 2560x1440 at 160 Hz, intro videos, Zombies played ~25 min over several runs without a freeze. At Extra detail GPU-bound at about 55 FPS (61-64 with order-independent transparency off); profile in KNOWN_ISSUES. One crash on the very first start (not repeated). Controller, audio checks, multiplayer and campaign not verified yet. |
| Infinite Warfare (Steam) | **Playable** (campaign; validation in progress) | One executable for every mode. Fullscreen 2560x1440 at 160 Hz (resolution and refresh rate written into its settings before each start; it chose 1920x1080 at 60 Hz by itself on a 1080p display). Needs both of Advanced Warfare's DXMT fixes (same files, run for its executable too): without them it closed during the first shader preload (Metal assertion) and its GPU page-faulted ~1.5 min into the first mission (tessellation on by default). With them: campaign missions 1-2 played (scripted and by a player) with no GPU fault. First start: ~3.5 min "Preloading Shaders"; later starts reach the menu in ~2 s. At the game's own settings (High textures, AO, volumetric lighting, tessellation Near, native 2560x1440) GPU-bound: ~50-58 FPS in most areas, ~37-40 in heavy fights (M1 Pro). Not verified yet: multiplayer, Zombies in Spaceland, controller, audio, a long session. |
| Advanced Warfare Multiplayer / Exo Zombies (Steam) | **Blocked** | Choosing Exo Zombies in the campaign's menu starts it through Siliconium (its own setup, 2560x1440 at 160 Hz); it stays at "Connecting to online services" (not investigated). |
| Achievements / playtime | Not verified | |
