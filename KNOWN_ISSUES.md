# Known issues

Each entry: symptom, what is proven, what is not. Evidence details: the private notes
(`Siliconium-Notes/EVIDENCE-LOG.md`, outside the repository).

## Open

### Call of Duty (Steam)
- Warm official timedemo: 1-2 frames of 100-120 ms per 1532-frame run, at different frames each run (not shader compiles; not investigated).
- Multiplayer (now on GLDirect like the campaign) not tested in game; old PunkBuster servers could object to a non-system `opengl32.dll` (not verified).

### Call of Duty 2 (Steam)
- 3 MoltenVK "Shader library compile failed" remain (`undeclared identifier s0_3dSmplr / s0_cubeSmplr / s0_cube_shadowSmplr`) even with the CoD2-only DXVK: the SPIR-V has distinct bindings (13/35/55/75/95) and standalone `spirv-cross --msl --msl-argument-buffers` declares all five, so the difference is in what DXVK's pipeline layout gives MoltenVK. No visible effect reported by the player. Shader dumps were taken (session-4 scratchpad, may be gone).
- Multiplayer not re-tested with the fixes.
- Mouse felt odd while a script brought CoD1 to the front with `WINE_MAC_MOUSELOOK=2` (player report, not investigated).

### Black Ops II (Steam)
- Zombies: ~20 % of frames miss a 160 Hz refresh (6.25 / 12.5 ms alternation) where Plutonium's BO2 misses none, with the same GPU time (~5 ms). Not diagnosed. Untested candidates, one at a time: display capture (Plutonium's BO2 has it on, Steam's BO2 off), Steam's online threads.
- First visit of a map or effect: textures or the muzzle flash black for a moment and a ~1.1 s freeze (measured once on Survival Farm, once on a new multiplayer map before the shared cache). Shaders not yet in the cache (DXMT compiles pipelines in the background and draws nothing until ready). Plutonium's BO2 does the same the first time; `prepare-shaders.sh bo2` warms its maps, and with the shared cache it should warm Steam's BO2 too (not tested).
- Twice the game process stayed alive after quitting (window gone, no frames, stopped by hand); both times after the shader-cache changes, the earlier runs exited normally. Cause not known.
- The game keeps its settings in binary files (`players/user_*.cgp`, `hardware.chp`): no `.cfg`, so the controller aim settings written for other games do not apply.

### Ghosts (Steam and Siliconium's own)
- Ambient Occlusion (any) and Tessellation (Near) each make the GPU page-fault after 45 s - 3.5 min (`kIOGPUCommandBufferCallbackErrorPageFault`, then every command buffer ignored: frozen game); both together also crashed Apple's shader compiler (MTLCompilerService). Forced off at every start; a player can still turn them on in the game's options until the next start (the Steam tile warns). Likely cause: DXMT 0.80 reads outside texel buffers (fixed upstream after 0.80 in commit 3bcaf16, not released); not yet backported.

### Black Ops III (Steam)
- Performance at Extra detail, 2560x1440, M1 Pro (Zombies, snow map): about 55 FPS, GPU-bound (≈17 ms of GPU work per frame; Metal System Trace with the shader timeline). Largest costs: an always-on full-screen pass (depth-of-field-like, ~25 %), order-independent transparency resolve (~23 %; OIT off: 61-64 FPS), tiled deferred lighting. Limiter counters show those passes latency-bound, not saturated. Tried without gain: OITLayers 16 → 8; one counter atomic per SIMD-group in DXMT's translator (no gain on M1 Pro in a microbenchmark). The two busiest game threads use ~8.5 ms per frame under Rosetta: about 110-120 FPS at most even with a faster GPU.
- Frames are composited by the window server (Metal HUD "Composited"; direct-to-display "display rejected"): costs latency, not measurable throughput. Cause not investigated.
- One crash on the very first start (null read in the game's code, ~45 s in, while it downloaded its first-run content); not repeated in later starts.
- Something in the game's process tree runs `curl` (progress meters in the game log); not identified.

### Advanced Warfare (Steam)
- **Fixed (2026-11-20): froze 10 s - 1.5 min into gameplay** (GPU page fault, `kIOGPUCommandBufferCallbackErrorPageFault`, then every command buffer ignored), in every run, also with upstream DXMT (main, 2026-11-10). Cause: DXMT's emulated tessellation (D3D11 hull/domain → Metal object/mesh shaders) declares at most 8 mesh workloads per quad patch at tessellation factor 8, but its generator emits 9 when the two inner factors differ with one odd (8 and 7, 8 and 5); the extra workload is written past the object payload and the object stage dispatches more mesh threadgroups than the pipeline declared. Metal shader validation does not instrument the payload or the mesh grid, so it never showed. Every AW hull shader is quad/integer. Found with per-encoder error status: only the encoders with tessellated draws were affected. Fixed together with two related DXMT bugs in the same code (the two patches of an object threadgroup raced on a shared workload counter; the mesh-threadgroup limit was declared for one patch while two patches' workloads are dispatched): `patches/dxmt-airconv-ts-workloads-v0.80.patch` → `payload/steam/aw-winemetal.so`, used by AW only from a clone of the engine (its own translated-shader cache `airconv-aw5`). First mission: 15 min of play without a fault (M1 Pro, macOS 15.8.3, 2560x1440 at 160 Hz, Extra textures), 108 FPS average, GPU median 8.7 ms. A long session with the shipped build is still to be done.
- Ruled out on the way (each tested): ambient occlusion, the tessellation factor, the translator's bounds handling, the dispatch-argument kernel, index-format pipeline reuse, out-of-range index/vertex reads (checked on the CPU for every draw), DXMT packing two patches per object threadgroup.
- On DXVK (MoltenVK) instead: the mission never finishes loading: MoltenVK cannot compile AW's tessellation control shaders (`redefinition of 'gl_PrimitiveID'` in the generated Metal source).
- Mission loads: ~100 s loading screen after the intro cinematic even with warm caches (the game's shader preload; one game thread CPU-bound under Rosetta, the other threads idle); a cold shader cache adds minutes. To try: preloading during the cinematic, or no preload (warm DXMT/Metal caches).
- Closed when the first mission's cutscene ended: `Mesh Render Pipeline Descriptor Validation: fragmentFunction must not be nil` (Metal assertion). DXMT 0.80 builds a tessellation pipeline with colour attachments and no pixel shader; upstream fixed it in commit ab984cf (after 0.80, not released). **Fixed (owner saw the cutscene end)**: an AW-only `d3d11.dll` (DXMT 0.80 + our 4 patches + `dxmt-mesh-no-ps-v0.80.patch` = ab984cf unchanged), `payload/steam/aw-d3d11.dll`, native for `s1_sp64_ship.exe`/`s1_mp64_ship.exe` only (`AW_DXMT_FIX=0`: the engine's DXMT). Every other game keeps the engine's DXMT.
- Exo Zombies / Multiplayer chosen from the campaign's menu now start through Siliconium (own setup, fullscreen at the display's mode), but stay at "Connecting to online services" (not investigated: Activision's online services for AW on PC, or Wine networking). After that switch the campaign crashed on its way out once (page fault in the game's code, Wine's "Program Error" box). Steam's launch-option dialog can open behind other apps (bringing it forward is built, not tested).

### Others
- MW3 MP: stuck at "Connecting to online services" (also via `-applaunch`); Steam's service log shows "Failed to load Steam Service (GLE 126)" at every start. Cause not proven.
- BO1 MP: ~91 FPS cap = the game's own `com_maxfps 85` (game files). Accepted.
- Ghosts (Steam): `iw6-focus` now runs for its campaign as for Siliconium's own Ghosts; the first Steam runs came up on screen (no black screen seen).
- Not tested: CoD1 MP, CoD2 MP, CoD4 MP, WaW MP, BO2 MP, MW2 MP in a map/online, Ghosts Multiplayer, AW in a long session with the shipped build, other games' in-game Multiplayer/Zombies buttons, achievements and playtime.
- mvkcache shim: "Failed to write 4 bytes … VK_INCOMPLETE" while compiling is a harmless race (save skipped, retried later). Not changed.

## Solved in 1.1.0 (cause → fix)
- BOIII (Ezz) v3.1.0 closed as the lobby loaded (`EXCEPTION_ACCESS_VIOLATION`, its server thread, reading the name's letters as an address) → Siliconium 1.0.0 padded short player names with `^7` to 16 bytes (Ezz v3.0.0 crashed with shorter names); with v3.1.0 the padded default name crashed and an unpadded 11-character name played → the padding is no longer added and 1.0.0's is removed; the default name is "Siliconium". Not re-tested in game with a name shorter than 11 characters (the default "Siliconium" has 10).
- Call of Duty (Steam) at 44 FPS → Apple's OpenGL waited for the GPU inside `glBufferSubData` (41 % of the render thread, `sample`) → the game draws through our GLDirect build (OpenGL → Direct3D 9 → DXVK): 137-159 FPS at 2560x1440. Rejected on the way: QindieGL (crashed CoD1 at start: fake `wglCreateContextAttribsARB` pointer).
- Black Ops II (Steam) stutter → it ran composited on the scaled desktop (here a 3840x2160 panel mode at 153 Hz) while Plutonium's BO2 holds the 1x mode (2560x1440 at 160 Hz) → Steam's BO2 parts now hold the 1x mode too. Zombies: 113-136 → 129-138 FPS, 1 % low 51-77 → 80, worst frame 39-136 → 12.5-37.5 ms (before: cold cache).
- CoD2 black screen after the intro, with the menu's sound → its menu shaders (shader model 1, implicit sampler type) failed to compile on Metal → `dxvk-d3d9-sm1-samplers.patch`, CoD2 only (`payload/steam/cod2-d3d9.dll` as native for `CoD2SP_s.exe`/`CoD2MP_s.exe`). The engine's shared `d3d9.dll` is unchanged.
- CoD2 random freeze (no frame presented, game thread alive) → its console log showed the startup cinematics (`cinematic IW_logo / cod_intro`) → `com_introPlayed 1` every start (`SKIP_INTRO=0` keeps them).
- CoD2 640x480/60 Hz on a new profile → the profile config loads after the command line → `steam_config` writes the active profile.
- CoD2 "minimized" after the intro → it was the player's Cmd+Tab (Cmd acts as Alt); Wine restores correctly when the app is reactivated. Not a bug.
- MW2 MP "black screen" → game window behind other apps (Steam-started) → direct launch.
- Steam reinstalling itself → overlay DLLs had been moved → overlay off via `localconfig.vdf`.
