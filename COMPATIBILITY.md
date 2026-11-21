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
| Call of Duty 4 MP (CoD4X 21.8, from Steam's download) | **Works (player confirmed)** | Installs and starts without dialogs; CoD4X server joined online (asks once for the CoD4 key code); 2560x1440 at 160 Hz: 83-120 FPS in play, about 120 (1 % low 89-105) once its shaders were compiled; menus ~55 FPS (cause not checked yet). Plays from its own APFS-clone copy: Steam's folder identical afterwards; Steam's own CoD 4 campaign started normally after it. Controller not tested. |
| Modern Warfare 2 MP (IW4X with Steam's 64-bit MW2) | Not tested in game | IW4X's x86 client converts Steam's 64-bit maps on its first start (about 4.4 GB) and its launcher adds about 3 GB of DLC to the folder; Steam's own files are not changed (IW4X source). |

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
| Advanced Warfare Multiplayer / Exo Zombies (Steam) | **Blocked** | Choosing Exo Zombies in the campaign's menu starts it through Siliconium (its own setup, 2560x1440 at 160 Hz); it stays at "Connecting to online services" (not investigated). |
| Achievements / playtime | Not verified | |
