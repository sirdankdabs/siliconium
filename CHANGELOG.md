# Changelog

## 1.4.2 — Black Ops II Long Path Fix

**Fixed**
- **Black Ops II (Plutonium) blank menus and crash when installed through Steam Library (#3)**: when Black Ops II was installed inside Siliconium's Steam prefix and launched through Plutonium's prefix via `Z:\Users\...\prefix-steam\drive_c\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops II`, the ~167-character `.ipak` path overflowed BO2's image-pack path buffer (`ipak file not found: base`, missing menu textures/text, then crash). `winpath.sh` now automatically maps long game directories (`> 80` Windows characters) through a shared Wine drive letter (e.g. `P:\Call of Duty Black Ops II`) for Plutonium (T4, T5, T6, IW5), BOIII, and offline/custom folders, and refreshes previously saved long paths on launch or when opening Plutonium. Thanks to **Andytizer** for the detailed diagnosis and reproduction in #3.

## 1.4.1 — Improved Logs & Special-Character Home Folder Fix

**Improved**
- **Better logs for troubleshooting**: Show Log and Copy now include a non-identifying system summary at the top (Siliconium version, macOS version and build, Apple silicon chip, RAM, Rosetta 2 status, engine/x87sidecar versions, display mode, prefix status, and free disk space) and automatically attach the newest error log when a setup step fails without naming a specific file.
- **User privacy in logs**: automatically redacts the user's macOS home directory and username (both Unix `/Users/<name>` and Wine `Z:\Users\<name>` paths) before displaying or copying logs, and removes full paths from engine install messages.

**Fixed**
- **macOS home folders ending in a dot or space (e.g. `/Users/name.`)**: Wine strips trailing dots and spaces from path components, which broke every prefix, Steam, and Plutonium launch with `could not load kernel32.dll, status c0000135`. Siliconium now automatically detects this and uses a private `0700` Wine-safe data directory outside the user's home folder, migrating any already-downloaded engine automatically.

## 1.4.0 — Native Metal D3D9, SIMD Audio & Lighter App

**New**
- **Native Direct3D 9 → Metal (`mtld3d v0.15.5`)**: replaces DXVK + MoltenVK on 32-bit CoD 4, CoD4X, World at War, Black Ops, MW2 / IW4X, and MW3 — delivering locked **150–160 FPS at 2560×1440** (up to **+45% higher FPS** on WaW Zombies and CoD4X, plus a custom DXSO float-clamp fix for *Call of the Dead* frost shaders). `D3D9_MTLD3D=0` keeps DXVK + MoltenVK if needed.
- **Custom SSE2 + SIMD 32-bit Audio (`dsound.dll`)**: **7.1× faster** audio mixing (**−86% audio CPU** under 24-voice load; **14× less audio-thread CPU** live in MW2 32-bit) with zero dropouts (`DSOUND_SSE=0` restores stock Wine `dsound.dll`).
- **Unified Plutonium Launcher & Offline *Your Own Game Files***: World at War, Black Ops, Black Ops II, and Modern Warfare 3 now live in one unified **Plutonium Launcher** sidebar section, while **Offline → Your Own Game Files** plays your own CoD 4, MW2, MW3, BO2 (with **T6SP-Mod** on by default), and Ghosts folders directly without Steam — with **IW-Pad v0.1.3** (32-bit & 64-bit), **IW3SP-MOD**, and automatic folder linking to Plutonium, IW4X, and CoD4X.
- **Live download speed & ETA**: real-time MB/s and remaining time for Plutonium, IW4X, BOIII, IW7-Mod, and engine setup.
- **Smart HiDPI & Pre-warmed Wine engine**: keeps sharp HiDPI on D3D9 (`mtld3d`) and BO2 with zero display mode switch; pre-warms `wineserver` in the background to cut cold launches by **~4 seconds**.
- **Screenshots & streaming**: macOS screenshots and screen recordings (`Cmd+Shift+3/4/5`) no longer minimize fullscreen games, and a new **Hide fullscreen game on Cmd+Tab** toggle supports Discord/OBS window capture.

**Changed**
- **23% smaller app (`144 MB → 111 MB`)**: unified the tessellation-fixed DXMT translator (`winemetal.so`) engine-wide across every Direct3D 11 game, eliminated the separate `cache/aw-engine` clone, and removed unused payload DLLs.
- **Apple Silicon D3D11 tuning**: **+18% FPS**, **−62% frame-time spikes (p99)**, and **−280 MB RAM** on **WWII**; **+10–30% FPS** and **−570 MB RAM** on **Black Ops III** with balanced first-start render scale (keeping crisp native menus/HUD); **−230 MB RAM** and smooth first-start render scaling on **Black Ops 4** for base & Pro Apple silicon Macs.
- **Bundled `x87sidecar v1.9.1.2`**: includes upstream SMC memory-leak and `fild m64` fixes, auto-upgraded on existing engines.
- **Smoother SwiftUI app**: moved log streaming and filesystem status checks off the main thread so script output never causes UI redraws.

**Fixed**
- Fixed a macOS BSD `awk` first-launch bug in `cfg_batch()` that silently skipped initial defaults on brand-new Plutonium and IW4X installs (leaving BO1 at `800×600` on first launch).
- Fixed orphaned `winedevice.exe` background processes surviving game exit and case-sensitive window tracking for `BlackOps4.exe`, `BlackOps3.exe`, `BlackOps.exe`, `CoDWaW.exe`, and `T6SP-Mod.exe`.
- Fixed BO2 offline black-screen hangs on mismatched `localization.txt` (automatic repair with backup) and enabled bidirectional local `mtld3d` shader cross-seeding across sibling D3D9 installs.

## 1.3.2

**Changed**
- **Fullscreen no longer captures the display**, in every game and launcher (Plutonium, IW4X, BOIII, the Steam Library, Battle.net, the BO3 Mod Tools' map tests): the screen can be recorded while you play, a windowed game no longer has black behind it, and Cmd-Tab no longer waits for the display to be released. Games still start in real fullscreen, in the same display mode as before. The "Direct fullscreen" switch is gone (`CAPTURE_DISPLAY=2` in settings.conf brings the capture back, for comparisons).
- **Every game follows your Mac's resolution**: each start puts the game in fullscreen at the desktop's own size and refresh rate, so changing the Mac's resolution (for example from 1920x1080 to 2560x1440) needs nothing else. An unscaled HiDPI desktop (for example "looks like 1920x1080" on a 4K display) keeps its mode; a scaled one (for example "looks like 2560x1440" on a 4K display, drawn at 5K) runs at the 1x mode of its size while you play, as macOS would otherwise redraw every frame at 5K, and comes back when the game ends (`KEEP_HIDPI=2` keeps a scaled one too; `KEEP_HIDPI=0`: every HiDPI desktop at 1x). Launchers and tools (Steam, Battle.net, BOIII's launcher, the BO3 Mod Tools) stay windowed.
- BO3 Mod Tools: map tests (Run) start in macOS Game Mode as the Steam Library's games do (`MODTOOLS_GAME_MODE=0`: off), and the launcher's window comes to the front and back after Cmd-Tab like a game's.
- **Display check in the app**: Siliconium shows your main display's mode and what the games will use on it (resolution, refresh rate, HiDPI kept or 1x, frame cap) when it opens for the first time and whenever you change the display's settings; the display line at the bottom of the sidebar shows it again. It reports the same rule each game start applies.

**Fixed**
- **Black screen with sound for minutes at a game's start (intro and menu not drawn)**, in the Direct3D 9 games (Black Ops, World at War, Modern Warfare 2 and 3, IW4X, CoD4X, the Steam Library's older games): our shader cache read its saved shaders one at a time before the game could draw anything, which took minutes whenever macOS's own shader cache no longer held them (for example after a macOS update). It now reads them in the background, side by side, and the game no longer waits for it.
- **A game started from Siliconium comes to the front when its window appears**, also if you switched to another app while it loaded (until now it stayed behind that app, and Black Ops showed only black until a click). Once per start; switching away later is yours.
- **Back from Cmd-Tab, the game takes clicks, keys and the controller at once** in every game (Black Ops came back on screen but took no click until a second Cmd-Tab): the restored window is made the foreground window, as it already was for WWII.
- **Modern Warfare 3 (Plutonium) runs at the display's real refresh rate after a display change**: it kept a refresh rate saved for an earlier display setting (for example 160 Hz with the display at 144 Hz, against its vsync), and a start right after Siliconium put the desktop's mode back could read the old mode's rate. Every start now uses the rate of the mode the display is really in.
- **Cmd-Tab is stable in every game and every display mode (fullscreen, fullscreen window, windowed), also after changing it in the game's options**: a game you leave can no longer bring itself back in front (Black Ops II came back by itself a few milliseconds after each Cmd-Tab), and when you come back the game's window is restored and made the active window at once, inside the game, as a taskbar click does on Windows (a game that had minimized itself, such as Black Ops II, sometimes took no click or key until another Cmd-Tab). As on Windows, only you bring it back: Cmd-Tab, a click on it or the Dock.
- **Black Ops II (Plutonium and Steam) starts at your Mac's resolution**: it took the resolution of the previous game from its own hardware profile (not from its settings file), opened at that size and switched the display while it ran. Your display mode choice in its options (fullscreen, fullscreen window, windowed) is kept: it is no longer turned into fullscreen at each start. `BO2_SCREEN=0` leaves the resolution to the game.
- **Cmd-Tab out of a game no longer leaves a black screen behind the other app**, in every game and launcher: without display capture, macOS only deactivated the game and its fullscreen window stayed on screen. The game now hides itself when you switch to another app (as on Windows with Alt-Tab, and as before when the display was captured) and comes back with Cmd-Tab. The game keeps its 1x display mode until it quits (no display switch at each Cmd-Tab; `CMDTAB_DESKTOP_MODE=1` in settings.conf gives a HiDPI desktop its own mode back while the game is hidden, with a short display switch each way). Only for a window that covers the screen (a launcher, Steam or the Mod Tools' editors never hide) and only from the game's third second in front. `HIDE_ON_CMDTAB=0` in settings.conf turns it off.
- **The microphone is asked for once**, when Siliconium first opens, for every game, with a short reason. macOS asked again game after game (and after each update), because the answer was tied to each build of the app; it now holds across games, builds and updates.
- BO3 Mod Tools map tests: fullscreen at the desktop's size and refresh rate (no display-mode switch: seconds of black screen at each Cmd-Tab), and the window comes back at once after Cmd-Tab, as in the Steam Library.
- **Every game's refresh rate and frame cap now come from the mode the display is really in while it plays**, on any resolution, refresh rate or HiDPI setting: the frame cap, the games' refresh setting and the display hold now use one rule (a 1x desktop below its size's best rate is switched to that rate while the game runs, as the games asked for it anyway; panels that report no refresh rate get their real one instead of 0). A game started right after another one could read the previous game's display mode.
- Modern Warfare 3 (Plutonium) follows the desktop's resolution at every start, as the other games (only its first start set it), in both modes.
- A refresh rate you change while a game runs (same resolution) stays after the game ends; the display is no longer put back to the rate it had when the game started.
- BO3 Mod Tools: map tests use the refresh rate of the mode their display hold uses (as the Steam Library's Black Ops III).

## 1.3.0 — Black Ops 4 & WWII

**New**
- **Battle.net** section, below the Steam Library: Siliconium installs Battle.net for Windows in its own prefix, and **Black Ops 4** plays from it, with two Wine fixes of our own for Battle.net's games only.
- Black Ops 4: **Shield (Project-BO4)** in its **Fixes** menu: the game without Battle.net's online services (Shield's own Demonware server emulator), with an in-game console and GSC and Lua mods. Siliconium uses Build R2, the community's update for the game's current version, downloads it from GitHub the first time and takes it out of the game's folder when the game quits, with Shield's settings and log: the game's own files are never changed.
- Steam Library: **Call of Duty: WWII** (campaign, Multiplayer, Nazi Zombies). Our fixes make online Multiplayer about twice as fast (~60 FPS on an M1 Pro) and campaign missions load about 45 s sooner.
- Steam Library: a **BO3 Mod Tools** button for Black Ops III downloads Treyarch's Mod Tools; launcher, Radiant, compiling, lighting and linking work, in a workspace that never changes Steam's files, and the launcher opens in macOS Game Mode.
- Steam Library: **Clean Ops** in Black Ops III's **Fixes** menu, the community patch for Black Ops III's Multiplayer (protection against exploits and crashes, its cheater blacklist, peer-to-peer hosting with its own server browser, an in-game menu). Siliconium downloads it from its author the first time, keeps its updates and settings between games, and takes it out of the game's folder when the game quits; Steam's files are never changed. It connects to its own server with your Steam ID. Its menu key is Insert: on a Mac keyboard choose End (fn+→) in its menu. It also works in the map tests the **BO3 Mod Tools** start (Run).
- **macOS Game Mode in every game**, also Plutonium, IW4X and the 32-bit Steam games (WWII campaign: ~76 FPS instead of 53-54). `GAME_MODE=0` in settings.conf turns it off.
- Every game **comes to the front by itself** when it starts: the menu bar no longer stays over it until a click. Only once, and only while Siliconium, Steam, Battle.net or the game's launcher is in front, never over another app.

**Changed**
- **Your Mac keeps its display mode while you play** when the desktop is an unscaled HiDPI mode at the game's size (for example "looks like 1920x1080" on a 4K display): no mode switch when a game starts, ends or is left with Cmd-Tab. A scaled desktop (one that macOS draws larger than the panel) is still held in a 1x mode while the game runs. `KEEP_HIDPI=0` in settings.conf holds every fullscreen game in a 1x mode as before.
- **Steam Library: every game starts in fullscreen at your display's size, every time** (now also the profiles of Call of Duty 2, World at War, Modern Warfare 2 and 3, Advanced Warfare and WWII, whose multiplayer profile had turned windowed). `STEAM_SCREEN=0` (or `WW2_SCREEN=0` for WWII only) in settings.conf keeps a window you chose in a game's options.
- **Black Ops (all modes, Plutonium and Steam): a map you never played loads about 3x faster and no longer freezes** for 0.4-1 s when something new is drawn (on an M1 Pro: a new multiplayer map 38 s → 12 s on its loading screen; worst frame in play 56-69 ms instead of 831 ms). `BO1_ASYNC_LEVEL=1` in settings.conf brings back the old behaviour.
- **Modern Warfare 3 (Plutonium and Steam): no more freeze when a map you never played starts** (274-331 ms as play began): its shaders are prepared on the loading screen. `IW5_PRELOAD=0` in settings.conf turns it off.

**Fixed**
- **Back from Cmd-Tab within about a second**: the window-restore helper now waits in the background from the game's start (starting it took seconds of black screen, 6-8 s in Black Ops 4).
- Steam Library: a game whose campaign and multiplayer are two Steam apps in one folder (Modern Warfare 2, Modern Warfare 3) showed both parts as downloaded when only one was; games whose files were deleted showed as installed (Download now asks Steam to check them, which downloads their files again).
- Black Ops and Black Ops II (Plutonium) held the display at the resolution saved in their profiles instead of the desktop's.
- Modern Warfare 3 (Plutonium): the display is handled as in the other games (its multiplayer had no 1x mode on a scaled desktop, and the other mode's never worked).
- Steam's World at War: Siliconium's settings are written to the profile the game reads (they went to a file in the game's folder that it ignores).
- A display mode left behind by a game that crashed or was forced to quit is put back when Siliconium opens and when a game starts or stops, unless you chose another mode since.
- Black Ops' gunfire sound fix (Plutonium and Steam) also finds Microsoft's XAudio2 in Black Ops II's folder or Steam's Black Ops / Black Ops II.
- The progress notice at the bottom of the Steam Library and Battle.net pages was cut off by the window's edge.
- On a scaled desktop, the display stays in the game's 1x mode after Cmd-Tab (macOS put the scaled mode back and the game then drew at 5K: Black Ops 4 fell from 115 to 52 FPS).

## 1.2.1

**Removed**
- The Offline Black Ops II campaign section.

## 1.2.0 — Infinite Warfare

**New**
- Steam Library: **Call of Duty: Infinite Warfare**: campaign, multiplayer and Zombies from one Play button, fullscreen at your display's size and refresh rate, with the two DXMT fixes made for Advanced Warfare. The first start prepares its shaders once (about 3.5 minutes); later starts reach the menu in seconds.
- **IW7-Mod (CBServers)** section: Infinite Warfare through [CBServers' community client](https://github.com/CBServers/iw7-mod) (their servers, custom maps in `usermaps`). It finds your Steam download by itself or uses the folder you choose; Steam's files are never changed (it plays from an APFS copy that takes no extra space) and it shares its shader caches with Steam's game. Zombies: 55–70 FPS at High settings on an M1 Pro.
- Infinite Warfare's **Fixes** menu in the Steam Library: play the normal game or IW7-Mod (CBServers).
- **AlterWare** section: why AlterWare's Ghosts and Advanced Warfare clients cannot run on Apple silicon (nothing is installed).

**Fixed**
- Steam's **Call of Duty 4, Modern Warfare 2 and Modern Warfare 3** (campaign and multiplayer) and **CoD4X** did not start in 1.1.0 and 1.1.1 with controller mapping on (the default).
- CoD4X: servers that require Steam work now: Siliconium starts Steam for Windows in the background when it is set up (Settings → "Steam for servers that require it").
- BOIII and Steam's Black Ops III share Metal's compiled shaders, so the second one no longer compiles them again.
- CoD4X and IW7-Mod no longer keep a second copy of the game between games: uninstalling it in Steam gives all its space back, Time Machine never backs it up twice, and they start faster.
- Install downloads (about 270 MB) are no longer kept after setup.
- Siliconium's game logs no longer grow without limit.

## 1.1.1 — United Offensive

**New**
- Steam Library: **Call of Duty: United Offensive** (campaign and multiplayer), listed after Call of Duty, with Call of Duty's setup: GLDirect (OpenGL on Direct3D 9, sharing Call of Duty's compiled effects), fullscreen at your display's size and refresh rate, brightness kept after Cmd+Tab, controller mapping and the x87 accelerator. It installs into Call of Duty's folder, as on Windows; Steam needs Call of Duty in the same account.

**Fixed**
- Call of Duty and United Offensive (GLDirect): foliage now draws as with OpenGL — tree branches and leaves were missing and distant treelines showed as grey walls; lit models such as pine trees were drawn almost black; distant scenery had too little fog. Call of Duty's official timedemo: 138-139 FPS at 2560x1440 on an M1 Pro (141-142 before, with the trees missing). The first start after updating rebuilds some of GLDirect's compiled effects once.
- Black Ops II Zombies and Multiplayer (Plutonium and Steam): on some Macs gunfire and most weapon sounds were silent with Wine's XAudio2. Siliconium now uses Microsoft's XAudio2 2.7 from the game's own DirectX redistributable (for Plutonium, if the game folder has none: from Black Ops' folder or Black Ops / Black Ops II in Siliconium's Steam Library), as it already did for Black Ops. It can be turned off with "Gunfire sound fix" in Black Ops II's settings (Plutonium tab; Steam's Zombies and Multiplayer follow it). Steam's Black Ops II Zombies and Multiplayer are not tested in game with it yet. Thanks to [xsoapy69](https://github.com/xsoapy69) for the report and fix (issue #2).

**Not tested yet**
- United Offensive multiplayer (the campaign is verified: about 122 FPS on average in Bastogne's snow forest), and Steam's Black Ops II Zombies and Multiplayer with the new sound fix. See COMPATIBILITY.md.

**Details**

See COMPATIBILITY.md for what is verified per game.

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
