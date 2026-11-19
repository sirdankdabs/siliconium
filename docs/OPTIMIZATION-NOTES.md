# Siliconium engineering notes (evidence log)

Test machine: MacBook Pro M1 Pro (8P+2E), external 2560x1440 monitor at 154-160 Hz,
macOS 15.8.3 Sequoia (24H241). The games sat below a folder whose name ends in a
space, which found the path bug described below.

How measurements are taken: `MVKCACHE_FPS=1` makes the MoltenVK shader-cache shim
(`kit/tools/mvkcache.c`) print `[fps] avg / median / 1% low / worst` every 5 s to the
game's log (`~/Library/Application Support/Siliconium/logs/<game>-<mode>.log`).
Only for the Direct3D 9 games (DXVK/MoltenVK: WaW, BO1, MW2, MW3). Offline maps are
started with `GAME_ARGS="+devmap <map>" launch.sh <game> <mode> Tester --lan`.
"Cold" = DXVK state caches, `engine/lib64/mvkcache.bin*` and Metal's cache removed.

Pitfall when testing from a terminal: the game's voice chat opens the microphone and
macOS asks the *terminal's* app (not Siliconium). The prompt (UserNotificationCenter)
takes focus and the game drops to ~61 FPS until it is answered. Siliconium itself asks
for the microphone before starting a game (`Model.swift`, `play()`), so players do
not see this.

## 2026-11-18

### Plutonium install crashed (fixed)
- Symptom: `DirectoryNotFoundException: Could not find a part of the path
  "Z:\Users\me\Games\World At War\plutonium.exe" (the real folder was "Games " with a trailing space)`.
- Cause: folder a folder whose name ends in a space ends in a space; .NET/Mono (Plutonium's installer, Steamless)
  strips trailing spaces/dots from every path component.
- Fix: `kit/tools/winpath.sh` maps the deepest folder Windows cannot name to a Wine
  drive letter (`P:` -> the folder with the trailing space); games see `P:\...`.
  Wine matches drive roots by inode, so working directories map too.
  `plutonium.exe` is now downloaded from `https://cdn.plutonium.pw/updater/plutonium.exe`
  and run from `cache/plutonium-installer/`.

### "winemetal.so Not Opened" (fixed)
- Cause: Siliconium downloaded with Safari is quarantined; every file it writes inherits
  `com.apple.quarantine` (80 engine files). Gatekeeper blocks Wine loading them.
- Fix: install-engine.sh and launch.sh clear the flag on the engine.

### Black Ops 1 did not open on macOS 15 (fixed)
- Evidence: `plutonium-bootstrapper-win32_d3d9.log` — 80x `DxvkBuffer: Failed to
  create buffer` ; MoltenVK: `vkCreateBuffer(): Only external memory handle type
  ..._MTLBUFFER_BIT_EXT and ..._MTLHEAP_BIT_EXT are supported`.
- Cause: WoW64 winevulkan creates buffers with host-allocation external memory;
  MoltenVK **1.4.0** (what the kit installed on macOS < 26) rejects it. 1.4.2 (macOS 26+)
  accepts it, which is why it worked on macOS 26/27.
- Fix: MoltenVK **1.4.1** (built with SDK 15.5, accepts host memory) on macOS < 26;
  `kit/tools/moltenvk.sh` records the version and launch.sh upgrades old engines.
- Result, BO1 Zombies:
  - Ascension (warm): 153.8 FPS avg, 1% low ~120, worst 9-14 ms (display 154 Hz).
  - Five, cold caches: first map load ~50 s (19 026 shipped pipelines compiled on the
    load screen), then 151.7-153.9 FPS, 1% low 102-140.
  - Five, warm: map load ~1.5 s, 154.1 FPS avg, 1% low 140, worst 8.8 ms.

### Launch overhead (fixed)
- Evidence: `bash -x` timing — 18.5 s from launch.sh start to the game process, ~12 s
  of it in ~40 separate `wine reg` calls (0.3 s each).
- Fix: `reg` queues values; `reg_flush` writes them with one `regedit /S` (UTF-16 .reg).
- Result: 7.6 s to the game process.

### Other changes in 0.9.5
- Games run at user-interactive QoS (performance cores); App Nap off while a game runs.
- macOS 26+: BO2's transparent-cursor winemac fix for every game (`CURSOR_FIX=0` off).
- Ghosts: never load NVIDIA HBAO+/TXAA/APEX; tessellation and motion blur off once.
- BO3 first run: volumetric lighting and subsurface scattering off.
- Bluetooth controller detection: GamePad/Joystick/MultiAxis usages, BLE transport.
- DXVK compiler threads = performance cores (max 8).

### Session 2 findings (2026-11-18, afternoon)
- **Refresh rate**: the HiDPI desktop (2560x1440 on 5120x2880) stops at 154 Hz;
  the 1x mode Siliconium holds for fullscreen runs at 160 Hz. launch.sh used the
  desktop's 154 for the FPS cap and r_displayRefresh. New `displaymode best W H`;
  WaW/BO1/MW2/MW3/BO3 now use the 1x mode's rate. MW2 then ran 158-160 FPS.
- **Intro movies**: com_introPlayed/com_startupIntroPlayed set to 1 (WaW, BO1, BO2).
- **"Set Optimal Settings?" (IW4X)**: shown when sys_gpu/sys_configureGHz in the
  profile do not match (a profile from a Windows PC: "NVIDIA GeForce GTX 1650",
  8.7 GHz). The dialog waited for a click before the game window opened (MW2
  looked frozen; main thread was in a message loop — repeated
  STATUS_LONGJUMP unwinds are Wine's user-callback dispatch, not an error).
  Probe: sys_configureGHz 17.4 (what this Mac measures) = no prompt; 8.7 and 999 =
  prompt. Fix: "Yes" runs `exec configure_mp.cfg`; Siliconium writes a no-op
  configure[_mp].cfg in the folder searched first (IW4X userraw/, Plutonium
  storage/t4|t5/raw/, storage/iw5/), so "Yes" keeps settings exactly like "No".
  Verified: "execing configure_mp.cfg from disk", settings unchanged.
  Configure files are never exec'd at normal start (checked every game's log).
- **MW3 folder incomplete**: main/ has only localized_*.iwd (no iw_00.iwd) ->
  "Couldn't load fileSysCheck.cfg". Not a Siliconium bug; app and launch.sh now say so.
- **MW2 first-visit pop-in**: DXVK_ASYNC=2 never stalls, so the first visit draws
  materials as their pipelines finish (weapon ~15 s on a cold cache). Tried
  IW4_ASYNC_LEVEL=1 + r_preloadShaders 1: menus at 5-20 FPS and up to 1 s freezes
  in game — rejected (user felt the stutter). Kept 2. Fix: prepare-shaders.sh now
  supports waw/bo1/iw4/bo2 and the app has "Prepare all maps" (Settings -> Shaders).
  mp_rust after preparing: 160 FPS, 1% low 142-146, worst 8 ms.
- **BO2 flashes on first effects**: DXMT async pipelines on first sight; DXMT keeps
  a persistent cache in $(getconf DARWIN_USER_CACHE_DIR)/dxmt/<exe> (488 MB for BO2),
  so it happens once per effect. prepare-shaders.sh bo2 compiles maps ahead.
- **BO2 train lights only when aiming (Express)**: user's cg_fovScale 1.55 makes
  BO2 switch to far LOD models sooner; aiming narrows the FOV. r_lodBias* are
  cheat protected in Plutonium and r_lodScale* rejects values < 1 ("not a valid
  value") — no legitimate fix; same behaviour on Windows. Change reverted.
- **pipefail + `grep -q` in a pipe**: grep exits early, the writer gets SIGPIPE and
  the pipeline fails. Broke map detection in prepare-shaders.sh on long logs and
  could break Steam sign-in detection in launch.sh (bo2s). Both fixed.
- Engine patch audit: every patched module in the engine has identical code and
  data to kit/payload (only the ad-hoc signature differs).
- WaW Shi No Numa (cold): ~104 FPS, 1% low ~85, worst 12 ms — CPU-bound (two
  threads at 97% in Rosetta-translated game code), not rendering. WaW MP Castle
  (cold): ~136 FPS, 1% low 115, worst 9 ms. BO1 MP Nuketown (cold): ~131 FPS,
  1% low 118, map load ~1 s.

### Ghosts deep dive (2026-11-18, evening)
- Froze after 1-3 min: `Device error ... kIOGPUCommandBufferCallbackErrorPageFault`, then
  every command buffer "Ignored (for causing prior/excessive GPU errors)".
- `MTL_SHADER_VALIDATION=1` named the culprits:
  - `cs_*_9069ca78...` compute kernels: "Invalid device load at offset 18446743983515238400"
    -> the SSAO pass (gone with `r_ssao "0_Off"`). This was the page fault / freeze.
  - `vshs_*` object functions (DXMT tessellation emulation): ~800 000 "Invalid threadgroup
    store at offset 4" in a few minutes -> heavy lag. Caused by Catmull-Clark subdivision of
    models; `r_subdivLimit "0"` cut it to ~3 800 (r_subdiv is not saved in the profile, so it
    goes on the command line: `+set r_subdiv 0 +set r_adaptiveSubdiv 0`).
- Low textures: `r_picmip_manual 0` (automatic) plus an unknown GPU vendor (Apple 0x106b).
  Manual full-res picmip + DXMT `dxgi.customVendorId=1002;dxgi.customDeviceId=67df` (AMD).
- "Run In Safe Mode?": Ghosts writes `__iw6sp64_ship` while running; a stop/crash leaves it.
  launch.sh removes it before start (IW4X: `__iw4x`, `__iw4mp`, ...). Plutonium games use none.
- DXMT 0.80 is the latest release; 100 later commits add D3D12/GS work but not multi-slot
  stream output ("CreateEmulatedVertexStreamOutputShader: only slot 0 supported").
- Result (user, normal mode): "se siente bastante bien", 0 Device errors.
- Also: never put an apostrophe in comments inside the single-quoted awk program in
  launch.sh's Ghosts block (it broke the script once).

### Black Ops III (Ezz/boiii) — 2026-11-18
- Crash on the server thread at match start (v3.0.0 `boiii.exe+0xE76D2`, beta-73
  `boiii-beta.exe+0x10E1B`): the name's bytes are read as a pointer (+0x250) whenever
  `playerName` is shorter than 16 bytes ("Tester" -> r14=0x726574736554, "Player" ->
  0x726579616C50). 16+ characters: no crash. launch.sh pads short names with "^7"
  (invisible colour code). Report for Ezz: a crash report + dumps.
- `-launch` always started the Stable build ("Connection Interrupted"). Play now starts
  the version chosen in Ezz's launcher (properties.json "selectedVersion"; beta =
  versions/boiii-beta.exe -noupdate). The user prefers opening Ezz's launcher first.
- 60 FPS cap: config.ini `MaxFPS "60"` AND Ezz's `boiii_players/user/config.cfg`
  `set com_maxfps "60"` (this one wins). Both set to the refresh rate every launch
  (BOIII_SCREEN), plus FullScreenMode 1, WindowSize = desktop, RefreshRate.
- Profile at max settings (2560x1440): GPU 99-100 %, CPU threads < 60 % -> GPU-bound,
  40-50 FPS. Volumetric samples 40/80 -> 16/32 and spot shadows 4096 -> 2048 are cheap.
  ResolutionPercent 75 looked too soft to the user. With lower in-game settings: 120+ FPS.
- DXMT's MetalFX swapchain (`DXMT_METALFX_SPATIAL_SWAPCHAIN=1`,
  `d3d11.metalSpatialUpscaleFactor`) scales the game's back buffer UP (output =
  desc * factor, d3d11_swapchain.cpp:515-584): 1440p -> 4K at 1.5, slower. Removed.
- DXMT config set from launch.sh must go through the registry environment (set_env):
  Wine gives Windows programs HKCU\Environment over the exported Unix variable.
- The "Windows config / Power saving / High performance" option is Windows' GPU
  preference for dual-GPU laptops: no effect on a Mac.
- TODO: map intro cinematics stutter (Bink video decode on Rosetta?); Ezz has
  boiii_skipIntro / boiii_skipCinematics in user/config.cfg.

### Modern Warfare 3 (Plutonium IW5) — 2026-11-18, night
- Game data re-downloaded (main/iw_00..iw_34). Plutonium IW5 ignores `+devmap`/`+map` at
  start (offline -lan): earlier "Seatown" numbers were the main menu; maps must be opened
  by hand, so prepare-shaders.sh cannot do MW3.
- 6 s freezes in those sessions were map loads the user started in the same session
  (console.log showed mp_mogadishu), not a bug. Not x87 (same with X87=0).
- DXVK_ASYNC=2 for MW3 (IW5_ASYNC_LEVEL=2): duplicated/ghosted HUD numbers and worse
  pop-in — keep 1 (default). Knob kept for testing.
- Cold run, user-driven, Village: 138-156 FPS in play, 1% low ~95-115, worst 10-20 ms; a
  few 0.5-0.8 s first-compile hitches (~2 s of late textures). Later 120.0 FPS exactly
  (likely the end-of-match lobby).
- Plutonium's console for IW5: AppData/Local/Plutonium/console.log ("maps/mp/<map>_fx.gsc").
- MW3 records every match to storage/iw5/demo/*.demo (theater).
- zsh: an unmatched glob in `rm` prints "no matches found" and skips that rm; use bash
  or (N) qualifiers when clearing caches.
- **Intro video glitch (MW3)**: Plutonium's splash `storage/iw5/video/plutonium.bik` is Bink 1,
  1920x1080 at 24 fps (205 frames, 8.5 s). During it one thread sits at 85-95 % (Bink
  decodes on one CPU thread, translated by Rosetta) with the GPU idle; the loop runs ~27 fps
  (36.6-37.2 ms, very even), so a 24 fps video on a 160 Hz display repeats a frame every
  ~9 frames (~3 hitches/s). Same with X87=0, so not x87. `intro 0` (MW3's "Intro movie
  should play") is set but Plutonium's splash plays regardless; it is Plutonium's branding,
  so it is not replaced. Same mechanism likely behind BO3's map-intro cinematic stutter
  (Bink 2). A clean fix would need a faster Bink decode path (native, multi-threaded);
  noted as future work.
- **x87sidecar**: Siliconium uses v1.9.1 (latest release, 2026-11-03); the app's "Update to …"
  button runs `install-engine.sh --update-x87`. Master has #54 "Split x87 runs on pages that
  rewrite their code" (2026-11-13), which targets the `rosettax87 ... resetting cache`
  messages seen in MW3/BO1 logs. Building it needs cmake; the user chose to wait for the
  official release (1.9.2) and update with the app's button.
- Alternatives checked (2026-11): FEX + ARM64 Wine (CrossOver Preview, macOS 26.5+,
  testing-only, no D3DMetal, x87sidecar not applicable); D3DMetal is proprietary. Rosetta
  full through macOS 27, reduced subset from macOS 28.
