<p align="center">
  <img src="docs/assets/icon.png" width="128" alt="Siliconium">
</p>

<h1 align="center">Siliconium</h1>

<p align="center">
  <b>Call of Duty on Apple silicon, in one app.</b><br>
  Call of Duty · United Offensive · Call of Duty 2 · Call of Duty 4 · World at War · Modern Warfare 2 · Black Ops · Modern Warfare 3 · Black Ops II · Ghosts · Advanced Warfare · Black Ops III · Infinite Warfare · WWII · Black Ops 4<br>
  (Plutonium, BOIII/Ezz, IW4X, CoD4X, IW7-Mod and Project-BO4 included)
</p>

<p align="center">
  <a href="https://github.com/sirdankdabs/siliconium/releases/latest"><b>Download</b></a> ·
  <a href="#games">Games</a> ·
  <a href="#getting-started">Getting started</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="https://discord.gg/4hpEXFqvNR">Discord</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

---

Download your games in the **Steam Library** or **Battle.net**, or choose a game folder for Plutonium, IW4X, CoD4X or BOIII, then press **Play**. Siliconium brings its own engine, built from open source, with patches tuned for Apple GPUs and Rosetta. You don't need CrossOver, a Wine install or Terminal.

<p align="center">
  <a href="docs/assets/showcase.mp4"><img src="docs/assets/showcase-poster.jpg" width="820" alt="Siliconium showcase video"></a><br>
  <a href="docs/assets/showcase.mp4"><b>▶ Watch the showcase</b></a> (1 min, all gameplay recorded on a MacBook Pro M1 Pro)
</p>

<p align="center">
  <a href="docs/assets/steam-library.jpg"><img src="docs/assets/steam-library.jpg" width="820" alt="The Siliconium app, Steam Library"></a><br>
  The Steam Library: twelve Call of Duty games from Steam, each with a button for every part
</p>

<p align="center">
  <img src="docs/assets/bo3-zombies.jpg" width="270" alt="Black Ops III Zombies">
  <img src="docs/assets/bo3-zombies-snow.jpg" width="270" alt="Black Ops III Zombies, Der Eisendrache">
  <img src="docs/assets/bo1-multiplayer.jpg" width="270" alt="Black Ops multiplayer">
</p>

## Games

There are three ways to play. The **Steam Library** plays Steam's own files with Siliconium's setup, and the **Battle.net** section does the same for the games sold only on Battle.net (Black Ops 4, also offline with Project-BO4's **Shield**). The **community clients** (Plutonium, IW4X, CoD4X, BOIII, IW7-Mod) and the **Offline** campaign (Ghosts) play your game folder, and IW4X, CoD4X, BOIII and IW7-Mod can also use your Steam download. The **AlterWare** section explains why AlterWare's Ghosts and Advanced Warfare clients cannot be played on Apple silicon.

FPS numbers come from a MacBook Pro M1 Pro (macOS 15.8.3) at 2560×1440, in game, with the display at 160 Hz. A range is the lowest and highest the FPS counter showed during play; "avg" is the average over a play session. Your numbers depend on your Mac and settings. Test conditions and what is verified for each game: [COMPATIBILITY.md](COMPATIBILITY.md).

### Steam Library

| Game | Campaign | Multiplayer | Zombies |
|---|---|---|---|
| **Call of Duty** (2003) | Works (player confirmed)<br>**148 FPS** avg, median 157 | Not tested<br>not measured yet | – |
| **Call of Duty: United Offensive** (2004)<br>*new in 1.1.1* | Works (player confirmed)<br>**122 FPS** avg, median 118 | Not tested<br>not measured yet | – |
| **Call of Duty 2** (2005) | Works (player confirmed)<br>**133–160 FPS** | Not re-tested since the fixes<br>not measured yet | – |
| **Call of Duty 4: Modern Warfare** (2007) | Works<br>**137–153 FPS** | Not tested<br>not measured yet (CoD4X: see below) | – |
| **World at War** (2008) | Runs<br>not measured yet | Not tested<br>not measured yet | Runs<br>**101–160 FPS** (Verrückt) |
| **Modern Warfare 2** (2009) | Works (player confirmed)<br>**151–160 FPS** | Runs<br>menus ~90 FPS; not measured in a match yet | – |
| **Black Ops** (2010) | Accepted by the player<br>**~120 FPS** in a mission, with 10–15 s stretches at 48–62 (not solved yet) | Accepted by the player<br>**~91 FPS** (the game's own cap online) | Accepted by the player<br>**147–160 FPS** |
| **Modern Warfare 3** (2011) | Works<br>**115–160 FPS** (first mission), Survival 150 | Blocked: stays at "Connecting to online services" | – |
| **Black Ops II** (2012) | Runs (player)<br>**156–158 FPS** | Not tested<br>not measured yet | Runs well (player)<br>**129–138 FPS** (Town) |
| **Ghosts** (2013) | Runs (player)<br>**150–154 FPS** (borderless, on the 154 Hz desktop) | Not tested<br>not measured yet | – |
| **Advanced Warfare** (2014) | Playable (validation in progress)<br>**108 FPS** avg (first mission, 15 min) | Blocked: stays at "Connecting to online services" | Exo Zombies: blocked, as Multiplayer |
| **Black Ops III** (2015) | Not verified yet<br>not measured yet | Not verified yet<br>not measured yet | Runs (player)<br>**~55 FPS** at Extra detail (GPU-bound) |
| **Infinite Warfare** (2016) | Playable<br>**~50–58 FPS** at the game's own settings (GPU-bound) | Not tested<br>not measured yet | Not tested in Steam's game<br>(IW7-Mod: see below) |
| **WWII** (2017)<br>*new in 1.3.0* | Playable<br>**74–78 FPS** at the game's own settings (first mission, GPU-bound) | Runs<br>**~60 FPS** online (Team Deathmatch) | Runs (player)<br>**52–63 FPS** (The Final Reich, solo) |

Call of Duty's official timedemo runs at 138–139 FPS. Black Ops III has one **Play** button: Campaign, Multiplayer and Zombies are chosen in its own menu; its **Fixes** menu offers **Clean Ops**, the community Multiplayer patch (also in the Mod Tools' map tests). Its **Mod Tools** button downloads Treyarch's Black Ops III Mod Tools from Steam: the launcher, Radiant, compiling, lighting and linking work, in a workspace that never changes Steam's files (your maps and mods are linked from `Documents/Black Ops III Mod Tools`).

### Battle.net

| Game | Multiplayer | Zombies | Blackout |
|---|---|---|---|
| **Black Ops 4** (2018)<br>*new in 1.3.0* | Not tested yet | Plays (player)<br>**~62 FPS** at 1920x1080, 100 % render resolution (Blood of the Dead, GPU-bound); also offline with **Shield** (player) | Not tested yet |

### Community clients and offline

| | Game | Client | Modes | Status | FPS |
|---|---|---|---|---|---|
| **T4** | World at War | Plutonium | Zombies, Campaign, Multiplayer | Works | Zombies ~104 (CPU-bound), Multiplayer ~136; Campaign not measured yet |
| **T5** | Black Ops | Plutonium | Zombies, Campaign, Multiplayer | Works | Zombies 152–154, Multiplayer ~131; Campaign not measured yet |
| **T6** | Black Ops II | Plutonium | Zombies, Multiplayer | Works | Zombies 159–160 (Town); Multiplayer not measured yet |
| **IW5** | Modern Warfare 3 | Plutonium | Multiplayer | Works | 138–156 |
| **IW3** | Call of Duty 4 | CoD4X | Multiplayer | Works (player confirmed) | about 120 once its shaders are compiled (83–120 in play) |
| **IW4** | Modern Warfare 2 | IW4X | Multiplayer | Works | 158–160 (with Steam's 64-bit game: not tested yet) |
| **T7** | Black Ops III | Ezz (BOIII) | Zombies, Campaign, Multiplayer | Works | 120+ at High with lighter shadows and effects; 40–50 with everything at maximum (GPU-bound) |
| **IW7** | Infinite Warfare | IW7-Mod (CBServers) | Zombies, Campaign, Multiplayer, custom maps | Zombies works (player) | Zombies 55–70 at High settings |
| **IW6** | Ghosts | Offline | Campaign | Works | not measured yet (Steam Library copy: 150–154) |

**New in 1.3.0**
- **Battle.net** section with **Black Ops 4**: Siliconium installs Battle.net for Windows, you sign in and install the game there, and **Play** starts it with Siliconium's setup.
- **Call of Duty: WWII** in the Steam Library (campaign, Multiplayer, Nazi Zombies), and a **BO3 Mod Tools** button for Black Ops III.
- **macOS Game Mode in every game**, the game comes to the front by itself when it starts, and it is back within about a second after Cmd-Tab.
- Optional fixes: **Shield (Project-BO4)** for Black Ops 4 (offline, without Battle.net's online services) and **Clean Ops** for Black Ops III (also in the Mod Tools' map tests).
- Your Mac keeps its HiDPI display mode while you play (no mode switch at start, at the end or after Cmd-Tab).

**New in 1.2.0**
- **Call of Duty: Infinite Warfare** in the Steam Library, and the **IW7-Mod (CBServers)** section: CBServers' community client with its servers and custom maps, from your Steam download (Steam's files are never changed) or your own folder.
- Steam's Call of Duty 4, Modern Warfare 2 and Modern Warfare 3 and CoD4X start again (they did not start in 1.1.0 and 1.1.1 with controller mapping on).

**New in 1.1.1**
- **Call of Duty: United Offensive** in the Steam Library (campaign and multiplayer), with Call of Duty's setup. It installs into Call of Duty's folder, as on Windows, so Steam needs Call of Duty in the same account.
- Call of Duty and United Offensive draw trees, lit models and distant fog as with OpenGL (tree leaves were missing).

**New in 1.1.0**
- **Steam Library:** play the Steam versions from Steam's own files, with Siliconium's setup: fullscreen at your display's size and refresh rate, controller support (also for the games without it on PC), shader caches, and an optional **Fixes** menu for some games (IW3SP-MOD, T4Me, IW-Pad, T6SP-Mod, Clean Ops).
- **CoD4X:** Call of Duty 4 multiplayer through the CoD4X client, also from your Steam download (Steam's files are never changed).

All changes: [CHANGELOG.md](CHANGELOG.md).

> **Optional: Black Ops III for Mac.** Siliconium can also run the Mac version of Black Ops III from Steam on the community servers (BO3 Mac Client with BO3MacFix). It is hidden by default because Ezz is the recommended way to play. Turn it on in **View → Show Black Ops III for Mac (Steam)**.

## Highlights

- **Fast and steady.** Direct3D 9 runs on DXVK + MoltenVK and Direct3D 11 on DXMT. Call of Duty and United Offensive draw through Siliconium's own GLDirect build (OpenGL on Direct3D 9). Shaders compile in the background and are kept between sessions. The games run on the performance cores, and x87 maths is accelerated by [x87sidecar](https://github.com/athei/x87sidecar).
- **Fullscreen done right.** Games open at your display's resolution and true refresh rate. On a HiDPI desktop drawn at the panel's own resolution (for example "looks like 1920x1080" on a 4K display) your Mac keeps its display mode: no switch when a game starts, ends or is left with Cmd-Tab. A scaled desktop (one that macOS draws larger than the panel) is held in a 1x mode while the game runs, so it doesn't cost frames. Every game runs in macOS Game Mode, comes to the front by itself, and is back within about a second after Cmd-Tab.
- **Controllers.** Xbox, PlayStation (DualShock 4, DualSense, DualSense Edge), Switch Pro, Joy-Con and 8BitDo, wired or Bluetooth, also in the Steam games that have no controller support on PC. Optional console-style aim assist.
- **No surprises.** "Set Optimal Settings?" and "Safe Mode" prompts never undo your settings. Intro movies are skipped.
- **Ready the first time.** *Prepare all maps* compiles every map's shaders once, so even a first visit loads complete.
- **Keeps itself up to date:** the app, Plutonium, IW4X, CoD4X, boiii and the x87 accelerator.

## Getting started

**You need**
- A Mac with Apple silicon and Rosetta 2.
- macOS 15 Sequoia or later. macOS 14 runs the Direct3D 9 games of Plutonium and IW4X only (World at War, Black Ops, MW2, MW3); the Steam Library and CoD4X were tested on macOS 15 only.
- Your own copies of the games. For the Steam Library, a Steam account that owns them. For online play on Plutonium, a free [Plutonium](https://plutonium.pw) account.

**Install**
1. Download `Siliconium.dmg` from [Releases](https://github.com/sirdankdabs/siliconium/releases/latest), open it and drag **Siliconium** to Applications. The first time, right-click it and choose **Open**, or allow it in System Settings → Privacy & Security → **Open Anyway**.
2. Pick a game, press **Install** for the engine, then **Choose…** your game folder.
3. Press **Play**.

**Steam Library:** press **Install** for the engine and **Install Steam** (Steam for Windows, in its own prefix), then sign in to Steam and tick *Remember me*. Download your games in Steam (**Open Steam**, or **Download all**); each one then gets a button for every part (**Campaign**, **Multiplayer**, **Zombies**).

**Battle.net:** press **Install** for the engine and **Install Battle.net** (Battle.net for Windows, in its own prefix), then sign in to Battle.net and tick *Keep me logged in*. **Install** opens the game's page in Battle.net to download it there; then press **Play**. To play Black Ops 4 offline, choose **Shield (Project-BO4)** in its **Fixes** menu (Battle.net must have started the game once).

Plutonium games ask you to sign in once; Siliconium downloads Plutonium for you. CoD4X installs from its official releases without any installer windows. For Black Ops III (Windows), Siliconium downloads boiii and opens Ezz's launcher. Pick **Beta** there.

### Game folders

| Game | The folder needs |
|---|---|
| World at War, Black Ops, Black Ops II | `zone/` (and `main/`) |
| Modern Warfare 3 | the **32-bit** game: `main/` (with `iw_00.iwd`…), `zone/`, `mss32.dll` |
| Modern Warfare 2 | `main/`, `zone/`, `iw4x-launcher.exe` |
| Call of Duty 4 (CoD4X) | `iw3mp.exe`, `main/`, `zone/` |
| Infinite Warfare (IW7-Mod, CBServers) | `iw7_ship.exe`, `common.ff`, `main/` |
| Ghosts | `iw6sp64_ship.exe`, `zone/prologue.ff`, `bink2w64.dll`, `steam_api64.dll` |
| Black Ops III (Windows) | `BlackOps3.exe` and `zone/` |

The Steam Library needs no folder: it plays the games where Steam downloaded them. IW4X, CoD4X, BOIII and IW7-Mod use your Steam download of Modern Warfare 2, Call of Duty 4, Black Ops III and Infinite Warfare when their tab has no folder; **Settings → Change…** picks another.

## FAQ

**A map looks incomplete the first time I play it.**
Its shaders are still compiling; every later visit is instant. Run **Settings → Shaders → Prepare all maps** once to compile them all ahead of time.

**My Bluetooth controller doesn't work.**
macOS asks for **Input Monitoring** the first time. Allow Siliconium in System Settings → Privacy & Security → Input Monitoring, then start the game again. Wired controllers and USB dongles don't need it.

**macOS says a file "could not be verified".**
Open Siliconium once more and start the game again. The app clears the download quarantine from its engine. Never choose "Move to Trash".

**CoD4X asks for a key code.**
It asks once for the Call of Duty 4 key. Steam shows it under **Manage → CD Keys**.

**Where are my files?**
In `~/Library/Application Support/Siliconium`: the engine, the Wine prefixes (Steam's and Battle.net's too), Plutonium and the shader caches. Your game folders are never modified, except for the settings each game keeps there. A fix chosen in a Steam game's **Fixes** menu puts its files in the game's folder only while that part runs. IW4X's launcher adds its own files next to the game's, and CoD4X and IW7-Mod play Steam's Call of Duty 4 and Infinite Warfare from their own copy (APFS clones made at each start: no extra disk space, and between games the copy keeps only the client's own files). Siliconium keeps no installers once it is set up, and its game logs keep only their newest part.

**I used BO-Mac before.**
Siliconium is its new name. Your installation moves over on its own the first time the app opens.

## Building from source

```bash
./build-app.sh
```
Builds `dist/Siliconium.app` (Xcode command line tools, macOS 14 SDK or later). The engine itself is built with [`engine/build-engine.sh`](engine/build-engine.sh). The patches applied on top of Wine, DXVK and DXMT are in [`kit/patches`](kit/patches), and engineering notes with measurements are in [`docs/OPTIMIZATION-NOTES.md`](docs/OPTIMIZATION-NOTES.md).

```
app/      the macOS app (SwiftUI)
kit/      launch and setup scripts, patches and payload, shipped inside the app
engine/   how the Wine engine is built and packed
bo3/      BO3 Mac Client and BO3MacFix sources (optional Black Ops III for Mac)
```

## Credits

- **Plutonium**: the World at War, Black Ops, Black Ops II and Modern Warfare 3 clients.
- **IW4X**: the Modern Warfare 2 client (GPL-3.0).
- **CoD4X team**: the [CoD4X](https://cod4x.ovh) Call of Duty 4 client.
- **Ezz / BOIII**: [boiii-free](https://github.com/Ezz-lol/boiii-free), built on momo5502's BOIII.
- **CBServers**: [IW7-Mod (CBServers)](https://github.com/CBServers/iw7-mod), their fork of **AuroraMod**'s [IW7-Mod](https://github.com/auroramod/iw7-mod) Infinite Warfare client (GPL-3.0), downloaded from CBServers' official link.
- Optional fixes, downloaded from their authors and never shipped: **JerryALT** ([IW3SP-MOD](https://gitea.com/JerryALT/iw3sp_mod)), **JBShady** ([T4M Enhanced](https://github.com/JBShady/T4M-Enhanced)), **GalvarinoDev** ([IW-Pad](https://github.com/GalvarinoDev/IW-Pad)), **Rattpak** ([T6SP-Mod](https://github.com/Rattpak/T6SP-Mod-Release)), **nxghtwolf** ([Clean Ops](https://cleanops.dev)), **project-bo4** ([Shield](https://github.com/project-bo4/shield-development); Build R2 by **Scroptss**).
- **The Wine project**, **CodeWeavers** (open-source CrossOver Wine) and **WineHQ** (Wine Mono, Wine Gecko).
- **Sikarugir** (Gcenx and contributors): the engine's x86_64 libraries.
- **athei**: [x87sidecar](https://github.com/athei/x87sidecar). **Lifeisawful**: [rosettax87](https://github.com/Lifeisawful/rosettax87).
- **DXVK** (Philip Rebohle and contributors), **Sporif** (dxvk-async), **3Shain**: [DXMT](https://github.com/3Shain/dxmt). **Khronos**: MoltenVK.
- **SciTech Software** (GLDirect, original author Keith Harrison), **MrRendroc** ([GLDirect 5](https://github.com/MrRendroc/gldirect)) and **Brian Paul** (Mesa 6.0): Call of Duty's OpenGL on Direct3D 9 (MIT; notices in `kit/payload/steam/cod1-gl/LICENSE.txt`).
- **BO3MacFix** by Emma / InvoxiPlayGames and Anthony / serious, with **T7Patch** work by its authors.
- **Logo-2K**: [Zombies Declassified](https://github.com/Logo-2K/zombies-declassified).
- **GStreamer** contributors.
- **kopyl** and **cothromachd**, for testing and reports.

## Legal

Siliconium does not include game files, Steam or any Steam API replacement; you need your own copies of the games.

Not affiliated with Activision, Blizzard, Treyarch, Infinity Ward, Sledgehammer Games, Gray Matter Interactive, Aspyr, Valve, CodeWeavers, Plutonium, IW4X, CoD4X or Ezz. Call of Duty, Black Ops and Modern Warfare are trademarks of Activision Publishing, Inc.

## License

The app and scripts are MIT ([LICENSE](LICENSE)). The patches follow the licenses of what they patch (Wine: LGPL-2.1+, DXVK: zlib, DXMT: its license). Downloaded and included components keep their own licenses.
