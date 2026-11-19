# Changelog

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
