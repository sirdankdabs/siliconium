# Changelog

## 1.1.0 — Steam Library

**New**
- **Steam Library**: play the Steam versions of Call of Duty, Call of Duty 2, Call of Duty 4, World at War, Modern Warfare 2, Black Ops, Modern Warfare 3, Black Ops II, Ghosts, Advanced Warfare and Black Ops III from Steam's own files, with Siliconium's setup: fullscreen at your display's size and refresh rate, controller support (also for the games without it on PC), shader caches, and no "Set Optimal Settings?" or "Safe Mode" prompts.
- **CoD4X**: a new section for Call of Duty 4 multiplayer through the CoD4X client, installed without any installer windows. With Steam's Call of Duty 4 it plays from its own copy, so Steam's files never change.
- **Fixes** menu for each Steam game: optional community fixes (IW3SP-MOD, T4Me, IW-Pad, T6SP-Mod), downloaded from their authors and checked before use. Off by default.
- IW4X, CoD4X and BOIII find your Steam downloads of Modern Warfare 2, Call of Duty 4 and Black Ops III by themselves; Settings → Change… picks another folder.
- Call of Duty runs through Siliconium's own GLDirect build (OpenGL on Direct3D 9): 137-159 FPS at 2560x1440 on an M1 Pro, about 45 before.
- Advanced Warfare: the freeze in gameplay and the crash after the first cutscene are fixed (long-session testing still in progress).
- A game's own Multiplayer or Zombies button starts the other part through Siliconium.
- Sidebar: Steam, Plutonium, CoD4X, IW4X, BOIII/EZZ, Offline.
- This window: what's new, once after each update.

**Fixed**
- BOIII (Ezz) v3.1.0 closed as the lobby loaded with Siliconium's default player name: the name is no longer padded with "^7", and the default name is now "Siliconium".
- Ghosts (also Siliconium's own): Ambient Occlusion and Tessellation are turned off at every start (both could freeze the GPU).
- Black Ops III: its "Safe mode" box no longer stops the start.
- Steam Library rows keep their buttons readable in a narrow window.

**Not tested yet**
- See COMPATIBILITY.md: the multiplayer parts of several Steam games; Modern Warfare 3 and Advanced Warfare multiplayer stay at "Connecting to online services".

**Details**

See COMPATIBILITY.md for what is verified per game.

**New (details)**
- A Steam section: Steam for Windows in its own prefix, the ten Call of Duty games with their parts and DLC, Play through Steam's own files with Siliconium's setup (direct launch with the Steam app id, per-game DXVK caches and settings, 1x display mode, display capture per game).
- 64-bit DXVK for Modern Warfare 2 and 3 (Steam's 64-bit executables), with async level 2 (`dxvk-x64-async2.patch`).
- Controller support for the games without it on PC (pad mapper: every button holds a key bound to the exact command).
- "Set Optimal Settings?" / "Safe Mode" answered No automatically (dialog guard).
- Settings files written before every start (resolution, refresh rate, frame cap, no vsync where needed), including Call of Duty and Call of Duty 2 profiles.
- Black Ops III from the Steam Library: its own setup (BOIII's settings in Steam's `players/config.ini`: first-start detail once, fullscreen at the display's size and refresh rate with the frame cap every start; 1x display mode; Media Foundation video decoders). A Workshop button (Steam's Workshop page for mods and maps) and "Play with BOIII", which opens the Black Ops III tab; BOIII uses Steam's Black Ops III folder by itself when it has no folder of its own.
- Depth of Field warning on Black Ops II (Plutonium, offline and Steam): it makes the game lag badly on a Mac.
- Sidebar: "Campaigns" is now "Offline" (Ghosts, Black Ops II); the Steam Black Ops II campaign tile is gone (the Steam Library plays it).
- Fixes picker per Steam game (one choice per game, off by default): IW3SP-MOD (CoD 4 campaign), T4Me (World at War campaign and zombies), IW-Pad (Modern Warfare 2 and 3 campaigns), T6SP-Mod (Black Ops II campaign). Each is downloaded once from its author's official source and checked against pinned SHA-256s (never shipped in the app); its files go into the game's folder only while that part runs and only where the game has no file of that name, and are removed when it quits.
- A game's own Multiplayer / Zombies button now starts the other part through Siliconium (Steam launch option `silrelay.exe %command%` + `steam-relay.sh`), so it gets its setup instead of Steam's plain start. Verified: Advanced Warfare campaign → Exo Zombies. Other games' buttons not tested yet.
- New **CoD4X** section: Call of Duty 4 multiplayer through the CoD4X community client (cod4x.ovh). Siliconium installs it from CoD4X's official releases (checked against pinned SHA-256s; no installer dialogs) and starts it with the Steam Library's Call of Duty 4 setup (DXVK, x87 accelerator, display mode, controller mapping), without Steam. CoD4X replaces two of the game's files (iw3mp.exe, mss32.dll), so with Steam's download it plays from its own copy in Siliconium's folder (APFS clones: no extra disk space); Steam's files are never changed. Verified: installs and starts without dialogs, a CoD4X server joined (the game asks once for the Call of Duty 4 key code, which Steam shows under Manage → CD Keys), 83-120 FPS in play at 2560x1440 (about 120 once its shaders were compiled; M1 Pro); Steam's folder identical afterwards.
- Sidebar order: Steam, Plutonium, CoD4X, IW4X, BOIII/EZZ, Offline.
- IW4X and CoD4X use Steam's Modern Warfare 2 / Call of Duty 4 when their tab has no game folder (as BOIII does with Black Ops III), with a note on the page; Settings has "Change…" for the game folder of IW4X, CoD4X and BOIII. The Fixes menus of Modern Warfare 2 and Call of Duty 4 open the IW4X / CoD4X tab.

**Fixed (details)**
- Black Ops III's own "Safe mode" box (after a game that did not quit properly) stopped the start: the dialog guard now matches its title.
- Modern Warfare 2: menu pointer no longer jumps to the centre (winemac mouse-look position patch, `WINE_MAC_MOUSELOOK=2`).
- Black Ops: Plutonium's T5 setup ported (shader warming, shipped pipelines, XAudio2, video memory, mouse dvars); audio crackle (`wine-coreaudio-bo1-steam.patch`); multiplayer renderer as native DLL.
- Call of Duty: "Failed to find Steam." (Steam's folder on its search path).
- Call of Duty: draws through our GLDirect build (OpenGL on Direct3D 9, then DXVK) instead of Apple's OpenGL: ~45 → 137-159 FPS at 2560x1440. GLDirect fixes: compiled-effect cache (d3dcompiler_43), direct glDrawElements, effect table bound (a full table crashed), fewer effect variants (disabled texture units and lights out of the key, sampler states set on the device: −63 % effects), effects compiled on a worker thread (no hitch on a new state), intro movies visible on non-4:3 displays (the game covers them with a black quad there, Apple's OpenGL included). `COD1_GLDIRECT=0` goes back to Apple's OpenGL. Source: `patches/gldirect-cod1.patch` on GLDirect 5 (MIT, notices in `payload/steam/cod1-gl/LICENSE.txt`).
- Call of Duty: brightness halved after Cmd+Tab or minimize (Wine restored macOS's gamma when the game lost focus; the game sets its ramp once): winemac applies the game's ramp again (`wine-winemac-reapply-gamma.patch`, `SIL_REAPPLY_GAMMA`, Call of Duty only).
- Call of Duty and Call of Duty 2 campaigns: black screen / lost mouse and keyboard after Cmd+Tab (the focus helper watched Wine's start.exe instead of the game); the game now starts in front, fullscreen, without the menu bar (Siliconium did not recognise their fullscreen window and stayed in front).
- Steam Library, every part gets its sibling's setup (not yet tested in game): Call of Duty Multiplayer draws through GLDirect like the campaign; Call of Duty and Call of Duty 2 Multiplayer get the campaigns' focus and fullscreen fixes; World at War Multiplayer gets the shipped pipeline list and the controller layout fix; Ghosts Multiplayer gets the campaign's settings (Ambient Occlusion and Tessellation off at every start) and focus helper.
- Call of Duty 2: menus drawn (own bindings for the 3D/cube variants of shader-model-1 samplers, `dxvk-d3d9-sm1-samplers.patch`, Call of Duty 2 only); random freeze at the start (startup cinematics skipped, `com_introPlayed 1`); new profiles open at the display's size and refresh rate, with trilinear texture filtering (the game's first-start detection picks bilinear).
- Black Ops II: stutter in Steam's BO2 → held at the display's 1x mode like Plutonium's BO2 (it ran on the scaled desktop).
- Black Ops II: Steam's parts share Plutonium's BO2 shader caches (DXMT database via `DXMT_SHADER_CACHE_PATH`, Metal's cache folder linked); they started cold and froze ~1 s at the first shot of a new effect (`BO2_SHARED_CACHE=0` keeps them apart).
- Ghosts: Ambient Occlusion and Tessellation are turned off at every start (both froze the GPU within minutes; Tessellation was only turned off the first time), also for Siliconium's own Ghosts; the Steam tile warns about them.
- Advanced Warfare: its own setup (it had inherited Ghosts' settings, whose names AW does not have); its profile is written before each start so it opens at the display's size and 1x refresh rate instead of 3840x2160 at 60 Hz.
- Advanced Warfare: the campaign closed after the first cutscene (Metal assertion in DXMT 0.80's tessellation pipeline) → upstream DXMT fix ab984cf backported for AW only (verified: the cutscene ends).
- Advanced Warfare: no longer freezes in gameplay. DXMT's emulated tessellation wrote one mesh workload past its payload when a patch's two inner tessellation factors differed (8 and 7), and dispatched more mesh threadgroups than declared (GPU page fault); fixed with two related bugs in the same code, for AW only (`aw-winemetal.so`, its own shader-translation cache; `dxmt-airconv-ts-workloads-v0.80.patch`). The three bugs are still in upstream DXMT (main, 2026-11-10).
- The app opens on the sidebar row that was selected when it was last closed (`-openSettings <game>` still wins).
- Steam Library: a game started with no extra arguments stopped the launcher (empty list under `set -u` in macOS's bash 3.2).
- Steam re-installed itself or refused games: overlay turned off in Steam's settings instead of moving its DLLs.

## 1.0.0 — Siliconium

The project has a new name and a new look. An existing installation moves over on its own the first time the app opens: the engine, Wine prefixes, Plutonium sign-in, shader caches and every game's settings stay as they were.

**New**
- New name, icon and interface. Every game sits in one sidebar, grouped by client, each shown as a tile with its engine code (T4, T5, T6, T7, IW4, IW5, IW6).
- Black Ops III for Mac (Steam's Mac version) is now optional and hidden. Ezz is the recommended way to play Black Ops III; turn the Mac version on in **View → Show Black Ops III for Mac (Steam)**.
- **Prepare all maps** (Settings → Shaders) for World at War, Black Ops, Black Ops II and Modern Warfare 2. It loads every map once, offline, so the first real visit to a map is complete: no late weapons or textures.
- Games open fullscreen at your display's size and its real refresh rate. A HiDPI desktop limited to 154 Hz now gets the 160 Hz of its native mode.

**Fixed**
- World at War, Black Ops, Modern Warfare 2 and Modern Warfare 3 open again on macOS 15. MoltenVK 1.4.0 rejected the memory 32-bit games use; the engine now uses 1.4.1 there and updates older engines by itself.
- Ghosts:
  - no longer freezes after a few minutes (its ambient occlusion pass read outside its buffer on the GPU);
  - no longer lags (character subdivision);
  - streams full-resolution textures;
  - no longer asks "Run In Safe Mode?" after being stopped.
- Black Ops III (Ezz):
  - no longer crashes when a match starts with a player name shorter than 16 characters;
  - no longer stops at 60 FPS (Ezz's `com_maxfps`);
  - starts the version chosen in the Ezz launcher, Stable or Beta.
- "Set Optimal Settings?" no longer waits hidden behind the game (Modern Warfare 2 looked frozen), and answering Yes keeps your settings, as No does.
- Modern Warfare 3 says right away when the game folder is missing its data (`main/iw_00.iwd`).
- Plutonium installs again when a folder in the path ends in a space. Siliconium now downloads `plutonium.exe` itself.
- "winemetal.so Not Opened": the engine no longer inherits the quarantine flag of a browser-downloaded app.
- Games start in about 8 s instead of 18: registry settings are written in one pass.
- Intro movies are skipped in World at War, Black Ops and Black Ops II.

## 0.9.5
- Plutonium installs again when the game folders sit below a folder whose name ends in a space or a dot.
- `plutonium.exe` is downloaded from plutonium.pw.
- Games run at the highest macOS priority (performance cores), and the app no longer naps while a game runs.
- macOS 26 and later: Black Ops II's cursor fix (a 1000 Hz mouse no longer lowers the frame rate) applies to every game.
- Ghosts: NVIDIA-only libraries are never loaded; tessellation and motion blur start off.
- Bluetooth controllers: Xbox Series (Bluetooth LE), Switch Pro, Joy-Con and 8BitDo are recognised for Input Monitoring.

## 0.9.4
- PlayStation controller detection in Wine games: DualSense and DualSense Edge over USB and Bluetooth. Thanks to cothromachd for the report.

## 0.9.3
- Ghosts (Campaign, Offline).
- DualShock 4 support; better Bluetooth controller responsiveness.
- Performance and bug fixes for World at War, Black Ops, Black Ops II, Modern Warfare 2 and Modern Warfare 3.
- Black Ops audio no longer crackles.
