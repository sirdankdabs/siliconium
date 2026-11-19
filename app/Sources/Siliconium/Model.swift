import AppKit
import AVFoundation
import CoreGraphics
import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Games

/// The sidebar's tabs and the games in each, in order.
enum GameTab: String, CaseIterable, Identifiable {
    case steam, plutonium, bo3, iw4x, others
    var id: String { rawValue }
    var title: String {
        switch self {
        case .plutonium: "Plutonium"
        case .bo3: "Black Ops III"
        case .iw4x: "IW4X"
        case .others: "Campaigns"
        case .steam: "Steam"
        }
    }
    var games: [Game] {
        switch self {
        case .plutonium: [.waw, .bo1, .bo2, .iw5]
        case .bo3: [.boiii, .bo3]
        case .iw4x: [.iw4]
        case .others: [.iw6, .bo2s, .bo2c]
        case .steam: [.steam]
        }
    }
    static func of(_ game: Game) -> GameTab { allCases.first { $0.games.contains(game) } ?? .plutonium }
}

enum Game: String, CaseIterable, Identifiable {
    case waw, bo1, bo2, iw5, iw4, iw6, bo2s, bo2c, bo3, boiii, steam
    var id: String { rawValue }

    var title: String {
        switch self {
        case .waw: "World at War"
        case .bo1: "Black Ops"
        case .bo2: "Black Ops II"
        case .iw5: "Modern Warfare 3"
        case .iw4: "Modern Warfare 2"
        case .iw6: "Ghosts Campaign"
        case .bo2s: "Black Ops II Campaign (Steam)"
        case .bo2c: "Black Ops II Campaign (Offline)"
        case .bo3: "Black Ops III for Mac"
        case .boiii: "Black Ops III"
        case .steam: "Steam Library"
        }
    }
    /// Release year, shown like an atomic number on the game's tile.
    var year: String {
        switch self {
        case .waw: "2008"
        case .bo1: "2010"
        case .bo2, .bo2s, .bo2c: "2012"
        case .iw5: "2011"
        case .iw4: "2009"
        case .iw6: "2013"
        case .bo3, .boiii: "2015"
        case .steam: "10"
        }
    }
    /// Who runs it, under the code on the game's tile.
    var client: String {
        switch self {
        case .waw, .bo1, .bo2, .iw5: "Plutonium"
        case .iw4: "IW4X"
        case .iw6, .bo2c: "Offline"
        case .bo2s: "Steam"
        case .bo3: "Steam"
        case .boiii: "Ezz"
        case .steam: "Steam"
        }
    }
    var subtitle: String {
        switch self {
        case .bo1: "Plutonium · Zombies, Campaign, Multiplayer"
        case .bo2: "Plutonium · Zombies, Multiplayer"
        case .iw5: "Plutonium · Multiplayer"
        case .iw4: "IW4X · Multiplayer"
        case .iw6: "Offline · Campaign · no Steam"
        case .bo2s: "Steam · Campaign"
        case .bo2c: "Offline · Campaign · no Steam"
        case .bo3: "Native Mac game · community servers"
        case .boiii: "BOIII · Ezz community servers"
        case .waw: "Plutonium · Zombies, Campaign, Multiplayer"
        case .steam: "Steam for Windows · download your Call of Duty games"
        }
    }
    var symbol: String {
        switch self {
        case .bo1: "1.circle.fill"
        case .bo2: "2.circle.fill"
        case .iw5: "5.circle.fill"
        case .iw4: "flame.fill"
        case .iw6: "flag.fill"
        case .bo2s: "2.square.fill"
        case .bo2c: "2.square.fill"
        case .bo3: "3.circle.fill"
        case .boiii: "3.square.fill"
        case .waw: "4.circle.fill"
        case .steam: "cart.fill"
        }
    }
    /// The short engine code shown in the sidebar's game badge.
    var badge: String {
        switch self {
        case .waw: "T4"
        case .bo1: "T5"
        case .bo2, .bo2s, .bo2c: "T6"
        case .iw5: "IW5"
        case .iw4: "IW4"
        case .iw6: "IW6"
        case .bo3, .boiii: "T7"
        case .steam: "St"
        }
    }
    var colors: [Color] {
        switch self {
        case .bo1: [Color(red: 0.20, green: 0.55, blue: 0.95), Color(red: 0.04, green: 0.12, blue: 0.35)]
        case .bo2: [Color(red: 0.92, green: 0.18, blue: 0.20), Color(red: 0.30, green: 0.04, blue: 0.06)]
        case .iw5: [Color(red: 0.42, green: 0.58, blue: 0.32), Color(red: 0.10, green: 0.16, blue: 0.08)]
        case .iw4: [Color(red: 0.96, green: 0.40, blue: 0.06), Color(red: 0.28, green: 0.05, blue: 0.01)]
        case .iw6: [Color(white: 0.47), Color(white: 0.15)]
        case .bo2c, .bo2s: [Color(red: 0.92, green: 0.18, blue: 0.20), Color(red: 0.30, green: 0.04, blue: 0.06)]
        case .bo3: [Color(red: 0.98, green: 0.52, blue: 0.10), Color(red: 0.35, green: 0.12, blue: 0.03)]
        case .boiii: [Color(red: 0.98, green: 0.52, blue: 0.10), Color(red: 0.35, green: 0.12, blue: 0.03)]
        case .waw: [Color(red: 0.62, green: 0.58, blue: 0.36), Color(red: 0.16, green: 0.15, blue: 0.08)]
        case .steam: [Color(red: 0.16, green: 0.47, blue: 0.80), Color(red: 0.05, green: 0.10, blue: 0.20)]
        }
    }
    /// Settings key of the game folder, for the Plutonium games.
    var folderKey: String? {
        switch self {
        case .waw: "WAW_DIR"
        case .bo1: "BO1_DIR"
        case .bo2: "BO2_DIR"
        case .iw5: "IW5_DIR"
        case .iw4: "IW4_DIR"
        case .iw6: "IW6_DIR"
        case .bo2c: "BO2C_DIR"
        case .boiii: "BOIII_DIR"
        default: nil
        }
    }
    var usesEngine: Bool { self == .waw || self == .bo1 || self == .bo2 || self == .iw5 || self == .iw4 || self == .iw6 || self == .bo2c || self == .bo2s || self == .boiii || self == .steam }
    var plutoniumID: String? {
        switch self {
        case .waw: "t4"
        case .bo1: "t5"
        case .bo2: "t6"
        case .iw5: "iw5"
        default: nil
        }
    }
    var usesPlutonium: Bool { plutoniumID != nil }
}

/// A game of the Steam Library section (kit/steam.sh's catalog, same ids).
struct SteamTitle: Identifiable {
    let id: String
    let title: String
    let year: String
    let badge: String
    let colors: [Color]
    /// The Siliconium game that can play Steam's download of it today
    var linked: Game? = nil
    /// Steam's own copy can't be used by the linked game (why)
    var note: String? = nil
    /// What Play starts (launch.sh steam <id>-<mode>): the part and its executable
    var modes: [Mode] = []
    struct Mode: Identifiable {
        let id: String       // sp | mp | zm
        let title: String
        let exe: String
        var symbol: String { id == "mp" ? "person.3.fill" : id == "zm" ? "hand.raised.fill" : "figure.walk" }
    }

    static let catalog: [SteamTitle] = [
        .init(id: "cod1", title: "Call of Duty", year: "2003", badge: "CoD",
              colors: [Color(red: 0.55, green: 0.47, blue: 0.33), Color(red: 0.14, green: 0.11, blue: 0.07)],
              modes: [.init(id: "sp", title: "Campaign", exe: "CoDSP.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoDMP.exe")]),
        .init(id: "cod2", title: "Call of Duty 2", year: "2005", badge: "CoD2",
              colors: [Color(red: 0.50, green: 0.52, blue: 0.48), Color(red: 0.12, green: 0.13, blue: 0.12)],
              modes: [.init(id: "sp", title: "Campaign", exe: "CoD2SP_s.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoD2MP_s.exe")]),
        .init(id: "cod4", title: "Call of Duty 4: Modern Warfare", year: "2007", badge: "IW3",
              colors: [Color(red: 0.36, green: 0.50, blue: 0.30), Color(red: 0.08, green: 0.13, blue: 0.07)],
              modes: [.init(id: "sp", title: "Campaign", exe: "iw3sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw3mp.exe")]),
        .init(id: "waw", title: "World at War", year: "2008", badge: "T4",
              colors: Game.waw.colors, linked: .waw,
              modes: [.init(id: "sp", title: "Campaign & Zombies", exe: "CoDWaW.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoDWaWmp.exe")]),
        .init(id: "mw2", title: "Modern Warfare 2", year: "2009", badge: "IW4",
              colors: Game.iw4.colors, linked: .iw4,
              modes: [.init(id: "sp", title: "Campaign", exe: "iw4sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw4mp.exe")]),
        .init(id: "bo1", title: "Black Ops", year: "2010", badge: "T5",
              colors: Game.bo1.colors, linked: .bo1,
              modes: [.init(id: "sp", title: "Campaign & Zombies", exe: "BlackOps.exe"), .init(id: "mp", title: "Multiplayer", exe: "BlackOpsMP.exe")]),
        .init(id: "mw3", title: "Modern Warfare 3", year: "2011", badge: "IW5",
              colors: Game.iw5.colors,
              note: "Steam's Modern Warfare 3 is the 64-bit update; Plutonium needs the 32-bit game.",
              modes: [.init(id: "sp", title: "Campaign", exe: "iw5sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw5mp.exe")]),
        .init(id: "bo2", title: "Black Ops II", year: "2012", badge: "T6",
              colors: Game.bo2.colors, linked: .bo2,
              modes: [.init(id: "sp", title: "Campaign", exe: "t6sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "t6mp.exe"), .init(id: "zm", title: "Zombies", exe: "t6zm.exe")]),
        .init(id: "ghosts", title: "Ghosts", year: "2013", badge: "IW6",
              colors: Game.iw6.colors, linked: .iw6,
              modes: [.init(id: "sp", title: "Campaign", exe: "iw6sp64_ship.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw6mp64_ship.exe")]),
        .init(id: "aw", title: "Advanced Warfare", year: "2014", badge: "S1",
              colors: [Color(red: 0.85, green: 0.70, blue: 0.25), Color(red: 0.22, green: 0.16, blue: 0.04)],
              modes: [.init(id: "sp", title: "Campaign", exe: "s1_sp64_ship.exe"), .init(id: "mp", title: "Multiplayer", exe: "s1_mp64_ship.exe")]),
    ]
}

struct PlayMode: Identifiable {
    let id: String      // launch.sh mode
    let title: String
    let symbol: String
}

struct GameWindowTarget {
    let executable: String
    var plutoniumMode: String? = nil
    var startsOutsideScript = false
    var isBOIII = false
    var acceptsFullscreenWindows = false

    static func game(_ game: Game, mode: String) -> Self {
        switch game {
        case .waw: .init(executable: mode == "mp" ? "t4mp.exe" : "t4sp.exe", plutoniumMode: mode == "mp" ? "t4mp" : "t4sp")
        case .bo1: .init(executable: mode == "mp" ? "t5mp.exe" : "t5sp.exe", plutoniumMode: mode == "mp" ? "t5mp" : "t5sp")
        case .bo2: .init(executable: mode == "mp" ? "t6mp.exe" : "t6zm.exe", plutoniumMode: mode == "mp" ? "t6mp" : "t6zm")
        case .iw5: .init(executable: "iw5mp.exe", plutoniumMode: "iw5mp")
        case .iw4: .init(executable: "iw4x.exe")
        case .iw6: .init(executable: "iw6sp64_ship.exe", acceptsFullscreenWindows: true)
        case .bo2c, .bo2s: .init(executable: "t6sp.exe")
        case .boiii: .init(executable: "boiii.exe", isBOIII: true)
        case .bo3: .init(executable: "codblkops3_exe", startsOutsideScript: true)
        case .steam: .init(executable: "steam.exe", startsOutsideScript: true)
        }
    }

    static func visibleConsoleWindows() -> Set<CGWindowID> {
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.compactMap { window in
            guard window[kCGWindowOwnerName as String] as? String == "conhost.exe" else { return nil }
            return window[kCGWindowNumber as String] as? CGWindowID
        })
    }

    func visiblePID(excludingConsoles existingConsoles: Set<CGWindowID>) async -> Int32? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let visibleWindows = windows.filter { window in
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 || (acceptsFullscreenWindows && layer >= Int(CGWindowLevelForKey(.mainMenuWindow))),
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            return (bounds["Width"] ?? 0) >= 300 && (bounds["Height"] ?? 0) >= 170
        }
        // The URI can open Plutonium's console before the game renderer.
        if let plutoniumMode {
            for window in visibleWindows {
                guard window[kCGWindowOwnerName as String] as? String == "conhost.exe",
                      let id = window[kCGWindowNumber as String] as? CGWindowID,
                      !existingConsoles.contains(id), let pid = window[kCGWindowOwnerPID as String] as? Int32 else { continue }
                if (window[kCGWindowName as String] as? String)?.hasPrefix("Plutonium ") == true { return pid }
                // WindowServer may omit titles. In that case require the
                // requested bootstrapper and a console created after Play.
                if (window[kCGWindowName as String] as? String ?? "").isEmpty,
                   Self.ps(["-ww", "-A", "-o", "pid=,comm="]).split(separator: "\n").contains(where: { line in
                       let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                       guard parts.count == 2, let owner = Int32(parts[0]),
                             parts[1].lowercased().hasSuffix("plutonium-bootstrapper-win32.exe") else { return false }
                       return Self.isPlutoniumMode(plutoniumMode, pid: owner)
                   }) { return pid }
            }
        }
        let owners = Set(visibleWindows.compactMap { $0[kCGWindowOwnerPID as String] as? Int32 })
        guard !owners.isEmpty else { return nil }
        let ids = owners.map(String.init).joined(separator: ",")
        for line in Self.ps(["-ww", "-p", ids, "-o", "pid=,comm="]).split(separator: "\n") {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2, let pid = Int32(parts[0]),
                  let name = parts[1].lowercased().split(whereSeparator: { $0 == "/" || $0 == "\\" }).last else { continue }
            if name == executable || (plutoniumMode != nil && name == "plutonium-launcher-win32.exe") { return pid }
            if isBOIII && (name == "blackops3.exe" || (name.hasPrefix("boiii-") && name.hasSuffix(".exe"))) {
                return pid
            }
            if let plutoniumMode, name == "plutonium-bootstrapper-win32.exe",
               Self.isPlutoniumMode(plutoniumMode, pid: pid) { return pid }
        }
        return nil
    }

    private static func isPlutoniumMode(_ mode: String, pid: Int32) -> Bool {
        ps(["-ww", "-p", String(pid), "-o", "args="]).lowercased().split(whereSeparator: \.isWhitespace)
            .contains { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) == mode }
    }

    private static func ps(_ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: output, as: UTF8.self)
    }
}

extension Game {
    var modes: [PlayMode] {
        switch self {
        case .waw: [PlayMode(id: "zombies", title: "Campaign/Zombies", symbol: "figure.walk"),
                    PlayMode(id: "mp", title: "Multiplayer", symbol: "person.3.fill")]
        case .bo1: [PlayMode(id: "zombies", title: "Campaign/Zombies", symbol: "figure.walk"),
                    PlayMode(id: "mp", title: "Multiplayer", symbol: "person.3.fill")]
        case .bo2: [PlayMode(id: "mp", title: "Multiplayer", symbol: "person.3.fill"),
                    PlayMode(id: "zombies", title: "Zombies", symbol: "figure.walk")]
        case .iw5: [PlayMode(id: "mp", title: "Multiplayer", symbol: "person.3.fill")]
        case .iw4: [PlayMode(id: "play", title: "Play IW4X", symbol: "play.fill")]
        case .iw6, .bo2c, .bo2s: [PlayMode(id: "play", title: "Play Campaign", symbol: "flag.fill")]
        case .boiii: [PlayMode(id: "launcher", title: "Open BOIII", symbol: "play.fill")]
        default: []
        }
    }
}

// MARK: - Patches

/// A fix the launcher applies; on by default. `key` is its settings.conf
/// name (read by launch.sh), `offValue` what turns it off.
struct Patch: Identifiable {
    let key: String
    var offValue = "0"
    let title: String
    let info: String
    let games: Set<Game>
    var id: String { key }
}

extension Patch {
    static let all: [Patch] = [
        // Both games
        Patch(key: "X87", title: "x87 acceleration",
              info: "Runs the games' old x87 floating-point maths as native ARM code with athei's x87sidecar (based on Lifeisawful's rosettax87), instead of Rosetta's slow emulation. The biggest frame-rate gain.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .bo2c, .bo2s]),
        Patch(key: "EXEC_ON_DEMAND", title: "Fast code execution",
              info: "Plutonium turns off DEP, so Wine would make the game's whole memory executable at once, which makes Rosetta re-check it constantly (BO2 ran in slow motion). Our engine makes each page executable only when it is first run.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .bo2c, .bo2s, .boiii]),
        Patch(key: "RUMBLE_FIX", title: "Controller vibration without input delay",
              info: "Every vibration command is a round trip to the controller, and Wine made the controller's input wait for it twice: in XInput (the game waited too) and in its HID bus driver (winebus), which held the device lock during the write and so held back every stick and button report. Aiming and shooting lagged whenever the controller rumbled. Ours sends vibration from its own thread and writes it without blocking input.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .bo2c, .bo2s, .boiii]),
        Patch(key: "RAW_INPUT", title: "Raw mouse input",
              info: "Reads the mouse directly, without macOS pointer acceleration or smoothing, so aim follows your hand 1:1.",
              games: [.waw, .bo1, .bo2]),
        Patch(key: "CONSOLE_AIM", title: "Console controller aim",
              info: "Makes the controller aim like on the consoles: turn acceleration, the console's turn speeds (slower up/down and while aiming down sights) and aim assist (slowdown and lock-on over targets). Applies to zombies, campaign and multiplayer; mouse aim is not affected.",
              games: [.waw, .bo1, .bo2, .bo2c, .bo2s]),
        Patch(key: "CAPTURE_DISPLAY", title: "Direct fullscreen",
              info: "In fullscreen the game takes over the display, so macOS shows its frames directly instead of compositing them with the desktop: lower latency and steadier frame times.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .bo2c, .bo2s, .boiii]),
        Patch(key: "DISPLAY_MODE", title: "Native display mode in fullscreen",
              info: "While the game runs fullscreen, the display switches to a 1x mode of the game's resolution, so a scaled (HiDPI) desktop does not make macOS draw every frame at twice the size.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .bo2c, .bo2s, .boiii]),
        Patch(key: "MSAA_FIX", title: "Supported anti-aliasing",
              info: "Apple GPUs support up to 4x MSAA; higher settings in the games' configs are lowered to 4x so the game does not fall back or render wrongly.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4]),
        // Black Ops
        Patch(key: "BO1_ASYNC", title: "Background shader compilation",
              info: "New shaders compile on separate threads instead of stopping the frame that needs them.",
              games: [.waw, .bo1, .iw4]),
        Patch(key: "BO1_WARM", title: "Compile shaders while the map loads",
              info: "Enables the game's shader preparation pass. On supported T5 Multiplayer builds, faster map loading runs this pass in parallel.",
              games: [.bo1]),
        Patch(key: "BO1_SHADER_CACHE", title: "Persistent shader caches",
              info: "Keeps compiled shaders between runs (DXVK's pipeline list and MoltenVK's translated shaders, in eight parallel caches) and merges pipeline lists from older setups, so maps you have played load and run without compiling again.",
              games: [.waw, .bo1, .iw4]),
        Patch(key: "BO1_MP_FAST_LOAD", title: "Faster Multiplayer map loading",
              info: "Compiles shaders in parallel during the server map's loading pass on supported versions. On other versions, DXVK uses its existing cache during loading.",
              games: [.bo1]),
        Patch(key: "BO1_METAL_PARALLEL", title: "Parallel Metal compilation",
              info: "Lets Metal compile shaders on every CPU core at once instead of a few at a time.",
              games: [.waw, .bo1, .iw4]),
        Patch(key: "BO1_NO_SHADOWS", title: "Shadow freeze fix",
              info: "Turns off the dynamic shadow maps, which froze Black Ops under DXVK on Apple GPUs.",
              games: [.bo1]),
        Patch(key: "STREAM", offValue: "1", title: "Load all textures up front",
              info: "Turns off texture streaming: every texture loads at full detail with the map instead of popping in (late-loading or black textures). Uses about 1.4 GB of memory.",
              games: [.bo1]),
        Patch(key: "BO1_VIDMEM", title: "Full video memory",
              info: "Black Ops reads its video memory through DirectDraw, where Wine reported 128 MB and the game capped texture quality to fit. It now sees 4 GB.",
              games: [.waw, .bo1]),
        Patch(key: "BO1_XAUDIO", title: "Gunfire sound fix",
              info: "Uses the XAudio2 from the game's own DirectX redistributable: with Wine's, Black Ops plays no gunfire sounds.",
              games: [.bo1]),
        // Black Ops II
        Patch(key: "BO2_MOUSE_LAG_FIX", title: "Fix mouse lag",
              info: "Enables Plutonium's fix for hitches when aiming with high-polling-rate mice in Black Ops II Zombies and Multiplayer.",
              games: [.bo2]),
        Patch(key: "BO2_ASYNC", title: "Background shader compilation",
              info: "DXMT compiles new Metal pipelines on separate threads instead of stopping the frame that needs them.",
              games: [.bo2, .bo2c, .bo2s, .boiii]),
        Patch(key: "BO2_FRAME_PACING", title: "Frame pacing",
              info: "DXMT paces frames evenly at the frame-rate cap (the monitor's refresh rate by default) instead of letting them bunch up.",
              games: [.bo2, .bo2c, .bo2s, .boiii]),
        Patch(key: "BO2_HW_PROFILE", title: "Safe hardware profile",
              info: "Starts Black Ops II with a blank hardware profile so it detects settings Apple GPUs support (otherwise it can pick 8x MSAA, which they do not have).",
              games: [.bo2, .bo2c, .bo2s]),
        // Ghosts uses the same DXMT features with its own settings.
        Patch(key: "IW6_ASYNC", title: "Background shader compilation",
              info: "DXMT compiles new Metal pipelines on separate threads instead of stopping the frame that needs them.",
              games: [.iw6]),
        Patch(key: "IW6_FRAME_PACING", title: "Frame pacing",
              info: "DXMT paces frames evenly at the selected frame-rate cap.",
              games: [.iw6]),
        // Modern Warfare 3 (Direct3D 9: DXVK, like Black Ops)
        Patch(key: "IW5_GRAPHICS", title: "Full-detail first start",
              info: "On its first start Modern Warfare 3 gets fullscreen at your display's size, VSync, 2x anti-aliasing, 16x anisotropic filtering and full-resolution textures. (Native resolution looked sharp but was too heavy on an M1 Pro; the game's Video options can raise it.) Only once: the game's options rule.",
              games: [.iw5]),
        Patch(key: "IW5_ASYNC", title: "Background shader compilation",
              info: "DXVK compiles Modern Warfare 3's new Direct3D 9 pipelines on separate threads instead of stopping the frame that needs them, so first-time effects, explosions and new areas do not stutter. If a weapon or effect is briefly invisible the first time it appears, its pipeline is still compiling: turn this off and the game waits for each shader instead (brief hitches, but nothing appears late).",
              games: [.iw5]),
        Patch(key: "IW5_SHADER_CACHE", title: "Persistent shader caches",
              info: "Keeps compiled shaders between runs: DXVK's pipeline state cache and MoltenVK's translated Metal shaders. Maps you have played load and run without compiling every shader again.",
              games: [.iw5]),
        Patch(key: "IW5_METAL_PARALLEL", title: "Parallel Metal compilation",
              info: "Lets Metal compile shaders on every CPU core at once instead of a few at a time, so the first map load and new effects compile faster.",
              games: [.iw5]),
        // Modern Warfare 2 (IW4X; Direct3D 9: DXVK, like Black Ops)
        Patch(key: "IW4_GRAPHICS", title: "Full-detail first start",
              info: "Uses Direct3D 9Ex under DXVK. On the first start, sets up fullscreen, VSync, 4x anti-aliasing and full-resolution textures.",
              games: [.iw4]),
        Patch(key: "IW4_SCREEN", title: "Fit the display",
              info: "Sets Modern Warfare 2 to your display's resolution and refresh rate every time it starts, and marks its \"Set Optimal Settings?\" check as done, so it neither waits on that question nor opens in a small 960×600 window.",
              games: [.iw4]),
        Patch(key: "IW4_MENU_CURSOR", title: "Native menu cursor",
              info: "Uses the system pointer in IW4X menus. In-game raw mouse input is unaffected.",
              games: [.iw4]),
        Patch(key: "WAW_SCREEN", title: "Fit the display",
              info: "World at War's \"Set Optimal Settings?\" prompt can leave it at 960×600 even in fullscreen; every launch it runs fullscreen at your display's resolution instead.",
              games: [.waw]),
        Patch(key: "SKIP_INTRO", title: "Skip the intro movies",
              info: "Goes straight to the menu: the publisher and studio logo movies are not played when the game starts.",
              games: [.waw, .bo1, .bo2]),
        Patch(key: "SETTINGS_GUARD", title: "Keep settings on \"Set Optimal Settings?\"",
              info: "When the game thinks the hardware changed (for example a profile copied from a Windows PC), it asks \"Set Optimal Settings?\". Answering Yes would replace Siliconium's settings with the game's guesses for an unknown GPU (lower resolution, no anti-aliasing, a 60 Hz mode). With this on, Yes keeps your settings exactly like No.",
              games: [.waw, .bo1, .iw5, .iw4]),
        Patch(key: "CURSOR_FIX", title: "Smooth frame rate with fast mice (macOS 26+)",
              info: "On macOS 26 and later, hiding the cursor makes every frame wait on mouse movement, so a 1000 Hz mouse lowered the frame rate. Black Ops II's invisible-cursor fix is applied to this game too. No effect on macOS 15.",
              games: [.waw, .bo1, .iw5, .iw4, .boiii]),
        Patch(key: "IW6_TUNE", title: "Apple GPU tuning",
              info: "Ghosts never loads NVIDIA's HBAO+, TXAA and APEX libraries (NVIDIA-only), and starts once with tessellation and motion blur off, the heaviest work for Apple GPUs. The game's options can turn them back on.",
              games: [.iw6]),
        // Black Ops III (Windows)
        Patch(key: "BOIII_GRAPHICS", title: "Full-detail first start",
              info: "On its first start Black Ops III's auto-detect does not know Apple GPUs and picks half resolution with no shadows. Instead it starts fullscreen at your display's size and refresh rate with full resolution, shadows, ambient occlusion and SMAA (volumetric lighting and subsurface scattering start off: they cost the most frame time on Apple GPUs). Only once: the game's own options rule afterwards.",
              games: [.boiii]),
        Patch(key: "BOIII_SCREEN", title: "Fullscreen at your display's refresh rate",
              info: "Every start: fullscreen at your display's size and refresh rate, and the frame cap at that rate. Black Ops III's own default cap is 60 FPS (MaxFPS, and Ezz's com_maxfps), and a crash or the launcher could leave it in a window.",
              games: [.boiii]),
        Patch(key: "BOIII_SAFE_LUA", title: "Ask before unsafe Lua",
              info: "Some Workshop mods and modded servers use \"unsafe\" Lua functions: reading and writing files, running system commands, loading DLLs. boiii asks first (\"Unsafe Lua Function Called\"). If a mod needs them and the question gets in its way, turn this off: boiii then starts with -unsafe-lua and lets them run without asking. The risk: any mod from any server can then use them, and under Wine that reaches your whole Mac (drive Z:). Only turn it off if you trust the servers and mods you play.",
              games: [.boiii]),
    ]

    static func `for`(_ game: Game) -> [Patch] { all.filter { $0.games.contains(game) } }
}

// MARK: - Paths

enum Paths {
    /// ~/Library/Application Support/Siliconium. The first time, an install of
    /// the app's previous name is moved here whole (engine, prefixes,
    /// Plutonium, caches, settings), so nothing has to be set up again.
    static let home: URL = {
        let fm = FileManager.default
        let support = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let home = support.appendingPathComponent("Siliconium")
        let legacy = support.appendingPathComponent(["Black", "Ops", "Mac"].joined(separator: " "))
        if !fm.fileExists(atPath: home.path), fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: home)
        }
        let version = home.appendingPathComponent("engine/siliconium.version")
        let legacyVersion = home.appendingPathComponent("engine/" + ["black", "ops", "mac"].joined(separator: "-") + ".version")
        if !fm.fileExists(atPath: version.path), fm.fileExists(atPath: legacyVersion.path) {
            try? fm.moveItem(at: legacyVersion, to: version)
        }
        return home
    }()
    static var engine: URL { home.appendingPathComponent("engine") }
    static var prefix: URL { home.appendingPathComponent("prefix") }
    static var iw6Prefix: URL { home.appendingPathComponent("prefix-iw6") }
    static var settings: URL { home.appendingPathComponent("settings.conf") }
    static var plutonium: URL {
        prefix.appendingPathComponent("drive_c/users/crossover/AppData/Local/Plutonium")
    }
    /// The Mac path a Windows path of the main prefix stands for. Folders whose
    /// names Windows cannot use (a trailing space, as in "CoD ") are given a
    /// drive letter by kit/tools/winpath.sh, so this follows dosdevices.
    static func macPath(ofWindowsPath windows: String) -> String? {
        let chars = Array(windows)
        guard chars.count >= 2, chars[1] == ":", chars[0].isLetter else { return nil }
        let drive = prefix.appendingPathComponent("dosdevices/\(chars[0].lowercased()):")
        let root: String
        if chars[0].lowercased() == "z" {
            root = "/"
        } else if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: drive.path) {
            root = target
        } else {
            return nil
        }
        let rest = String(chars.dropFirst(2)).replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true).joined(separator: "/")
        let url = rest.isEmpty ? URL(fileURLWithPath: root) : URL(fileURLWithPath: root).appendingPathComponent(rest)
        return url.standardizedFileURL.path
    }
    /// The kit (scripts and engine payload): in the app bundle, or the one
    /// SIL_KIT points at while developing.
    static var kit: URL {
        if let dev = ProcessInfo.processInfo.environment["SIL_KIT"] { return URL(fileURLWithPath: dev) }
        return Bundle.main.resourceURL!.appendingPathComponent("kit")
    }
}

// MARK: - Settings (settings.conf, read by launch.sh)

struct Settings {
    var values: [String: String] = [:]

    static func load() -> Settings {
        var s = Settings()
        guard let text = try? String(contentsOf: Paths.settings, encoding: .utf8) else { return s }
        for line in text.split(separator: "\n") {
            // Only leading blanks go: a folder's name can end in a space ("CoD ").
            let l = line.drop { $0 == " " || $0 == "\t" }
            guard !l.hasPrefix("#"), let eq = l.firstIndex(of: "=") else { continue }
            let key = l[..<eq].trimmingCharacters(in: .whitespaces)
            var value = String(l[l.index(after: eq)...])
            if !key.hasSuffix("_DIR") { value = value.trimmingCharacters(in: .whitespaces) }
            s.values[key] = value
        }
        return s
    }

    func save() {
        try? FileManager.default.createDirectory(at: Paths.home, withIntermediateDirectories: true)
        let body = values.keys.sorted().map { "\($0)=\(values[$0]!)" }.joined(separator: "\n")
        try? ("# Siliconium settings (written by the app)\n" + body + "\n")
            .write(to: Paths.settings, atomically: true, encoding: .utf8)
    }

    subscript(key: String) -> String? {
        get { values[key] }
        set { values[key] = (newValue?.isEmpty ?? true) ? nil : newValue }
    }
}

// MARK: - App state

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var settings = Settings.load()
    @Published var log: [String] = []
    @Published var progress: String?          // a running setup step
    @Published var running: Game?             // a game started from here
    @Published var error: String? {
        didSet {
            // "(see logs/wineboot.log)": the log the error points at, shown under Show log
            if let e = error, let r = e.range(of: #"logs/[A-Za-z0-9._-]+\.(log|txt)"#, options: .regularExpression) {
                errorLog = String(e[r])
            }
        }
    }
    @Published var errorLog: String?          // a file under Paths.home the last error named
    @Published var bo3Latest: String?
    @Published var bo3: [String: String] = [:]   // bo3.sh status: game, state, installed
    @Published var zd: [String: String] = [:]    // zombies-declassified.sh status: installed, latest
    @Published var settingsGame: Game?           // the settings panel shown over the window
    @Published var x87Latest: String?
    @Published var refreshToken = 0           // bumped to re-read statuses
    /// The Bluetooth/Input Monitoring explanation was shown in this run.
    var didOfferBluetoothAccess = false
    var didRequestBluetoothAccess = false
    var didRelaunchForBluetooth = false

    private var checkedForAppUpdateOnLaunch = false
    private var checkingForAppUpdate = false
    private var task: Process?
    private var gameWindowTask: Task<Void, Never>?
    private var setupNote: NSPanel?
    private var setupNoteModel: SetupNoteModel?

    init() {
        // A game left running from an earlier session of the app
        if Self.engineRunning {
            running = settings["LAST_GAME"].flatMap(Game.init(rawValue:)) ?? .bo1
            watchUntilStopped()
        }
        refreshCampaign()
    }

    // Statuses
    var engineInstalled: Bool {
        FileManager.default.fileExists(atPath: Paths.engine.appendingPathComponent("siliconium.version").path)
    }
    var engineInfo: [String: String] {
        guard let t = try? String(contentsOf: Paths.engine.appendingPathComponent("siliconium.version"), encoding: .utf8) else { return [:] }
        var d: [String: String] = [:]
        for l in t.split(separator: "\n") { let p = l.split(separator: "=", maxSplits: 1); if p.count == 2 { d[String(p[0])] = String(p[1]) } }
        return d
    }
    var prefixReady: Bool {
        FileManager.default.fileExists(atPath: Paths.prefix.appendingPathComponent("system.reg").path)
    }
    var iw6PrefixReady: Bool {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        return fm.fileExists(atPath: Paths.iw6Prefix.appendingPathComponent("system.reg").path)
            && fm.fileExists(atPath: Paths.iw6Prefix.appendingPathComponent("drive_c").path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
    private var plutoniumConfig: [String: Any]? {
        let p = Paths.plutonium
        let fm = FileManager.default
        guard fm.fileExists(atPath: p.appendingPathComponent("bin/plutonium-launcher-win32.exe").path),
              fm.fileExists(atPath: p.appendingPathComponent("bin/plutonium-bootstrapper-win32.exe").path),
              let data = try? Data(contentsOf: p.appendingPathComponent("config.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return json
    }
    var plutoniumInstalled: Bool { plutoniumConfig != nil }
    func plutoniumLinked(_ game: Game) -> Bool {
        guard let id = game.plutoniumID, let folder = folder(for: game) else { return false }
        guard let saved = plutoniumConfig?["\(id)Path"] as? String else { return false }
        return Paths.macPath(ofWindowsPath: saved) == folder.standardizedFileURL.path
    }
    var crossOverVersion: String? {
        let plist = URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/Info.plist")
        guard let d = NSDictionary(contentsOf: plist) else { return nil }
        return d["CFBundleShortVersionString"] as? String
    }
    var rosettaInstalled: Bool { FileManager.default.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime") }
    func folder(for game: Game) -> URL? {
        guard let key = game.folderKey, let path = settings[key] else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("zone").path) ? url : nil
    }

    /// Checks that the selected folder really is the requested game, not just
    /// any folder with a zone/ directory. Plutonium brings its own game
    /// executables, so this looks at the game's data and libraries:
    /// WaW has nazi_zombie_*.ff, BO1 has zombie_*.ff, BO2 has mp_hijacked.ff
    /// or zm_*.ff, and IW5 has main/, zone/ and mss32.dll.
    func gameFolderProblem(_ game: Game, _ url: URL) -> String? {
        let fm = FileManager.default
        let zone = url.appendingPathComponent("zone")
        guard fm.fileExists(atPath: zone.path) else {
            return "That folder has no zone folder: choose the \(game.title) game folder."
        }
        func has(_ path: String) -> Bool { fm.fileExists(atPath: url.appendingPathComponent(path).path) }
        func anyFile(_ test: (String) -> Bool) -> Bool {
            guard let e = fm.enumerator(at: zone, includingPropertiesForKeys: [.isRegularFileKey]) else { return false }
            var seen = 0
            while let u = e.nextObject() as? URL {
                seen += 1
                if seen > 50_000 { break }
                if test(u.lastPathComponent.lowercased()) { return true }
            }
            return false
        }
        switch game {
        case .waw:
            guard has("binkw32.dll") else {
                return "That is not a World at War folder: binkw32.dll is missing."
            }
            guard anyFile({ $0.hasPrefix("nazi_zombie_") && $0.hasSuffix(".ff") }) else {
                return "That folder has zone/, but no World at War Zombies maps (nazi_zombie_*.ff): choose the World at War game folder."
            }
        case .bo1:
            guard has("binkw32.dll") else {
                return "That is not a Black Ops folder: binkw32.dll is missing."
            }
            guard anyFile({ $0.hasPrefix("zombie_") && !$0.hasPrefix("nazi_zombie_") && $0.hasSuffix(".ff") }) else {
                return "That folder has zone/, but no Black Ops Zombies maps (zombie_*.ff): choose the Black Ops game folder."
            }
        case .bo2:
            guard has("binkw32.dll") else {
                return "That is not a Black Ops II folder: binkw32.dll is missing."
            }
            guard anyFile({ $0 == "mp_hijacked.ff" }) || anyFile({ $0.hasPrefix("zm_") && $0.hasSuffix(".ff") }) else {
                return "That folder has zone/, but no Black Ops II maps (mp_hijacked.ff or zm_*.ff): choose the Black Ops II game folder."
            }
        case .iw5:
            return iw5Problem(url)
        case .iw4:
            // iw4x-launcher.exe is downloaded by launch.sh when missing
            guard has("main") else {
                return "Choose the Modern Warfare 2 folder with main/ and zone/."
            }
        case .iw6:
            for file in ["iw6sp64_ship.exe", "zone/prologue.ff", "bink2w64.dll", "steam_api64.dll"] {
                let path = url.appendingPathComponent(file).resolvingSymlinksInPath()
                guard (try? path.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    return "The Ghosts campaign folder is missing \(file)."
                }
            }
        case .bo2c:
            guard has("t6sp.exe") || has("t6sp.exe.steam") else {
                return "That is not a Black Ops II campaign folder: t6sp.exe is missing."
            }
        case .boiii:
            guard has("BlackOps3.exe") else {
                return "That is not a Windows Black Ops III folder: BlackOps3.exe is missing."
            }
        case .bo2s, .bo3, .steam:
            return nil
        }
        return nil
    }

    /// Why the chosen Modern Warfare 3 folder cannot run under Plutonium's
    /// 32-bit IW5 client; nil when the folder is fine (or none is chosen).
    /// Plutonium brings its own iw5mp.exe, so the folder needs the games' data
    /// and the 32-bit libraries, not the original executable.
    func iw5Problem(_ f: URL) -> String? {
        let fm = FileManager.default
        func has(_ p: String) -> Bool { fm.fileExists(atPath: f.appendingPathComponent(p).path) }
        if !has("main") || !has("zone") {
            return "It has no main/ and zone/ folders: pick the Modern Warfare 3 game folder."
        }
        if !has("mss32.dll") {
            if has("bink2w64.dll") || has("steam_api64.dll") || has("iw5mp_server.exe") {
                return "It is Steam's 64-bit Modern Warfare 3 (the September 2026 update). Plutonium's IW5 client only runs the 32-bit game."
            }
            return "It has no mss32.dll: the 32-bit game files are missing (Plutonium needs the 32-bit Modern Warfare 3, not the 64-bit update)."
        }
        // The game's data packs (iw_00.iwd, iw_01.iwd…). A copy with only the
        // localized_*.iwd files stops at start-up with "Couldn't load
        // fileSysCheck.cfg".
        let mainFiles = (try? fm.contentsOfDirectory(atPath: f.appendingPathComponent("main").path)) ?? []
        if !mainFiles.contains(where: { $0.lowercased().hasPrefix("iw_") && $0.lowercased().hasSuffix(".iwd") }) {
            return "Its main folder has no iw_00.iwd (only the localized files): the game's data is missing. Copy the whole main folder of Modern Warfare 3."
        }
        let zone = f.appendingPathComponent("zone")
        guard let e = fm.enumerator(at: zone, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return "That folder has no readable zone folder: pick the Modern Warfare 3 game folder."
        }
        var seen = 0
        var survival = false
        while let u = e.nextObject() as? URL {
            seen += 1
            if seen > 50_000 { break }
            let n = u.lastPathComponent.lowercased()
            if n.hasPrefix("so_survival_") && n.hasSuffix(".ff") { survival = true; break }
        }
        if !survival {
            return "That folder has zone/, but no Modern Warfare 3 Survival maps (so_survival_*.ff): choose the Modern Warfare 3 game folder."
        }
        return nil
    }
    var iw5Problem: String? {
        guard let f = folder(for: .iw5) else { return nil }
        return iw5Problem(f)
    }
    var iw5Usable: Bool { folder(for: .iw5) != nil && iw5Problem == nil }
    func folderUsable(for game: Game) -> Bool {
        guard let f = folder(for: game) else { return false }
        return gameFolderProblem(game, f) == nil
    }
    func folderProblem(for game: Game) -> String? {
        guard let f = folder(for: game) else { return nil }
        return gameFolderProblem(game, f)
    }
    func folderDetail(for game: Game) -> String {
        guard let f = folder(for: game) else { return expectedFolderDetail(game) }
        return gameFolderProblem(game, f) ?? expectedFolderDetail(game)
    }
    func expectedFolderDetail(_ game: Game) -> String {
        switch game {
        case .waw: "The World at War folder: zone/ with the Zombies maps (nazi_zombie_*.ff) and binkw32.dll."
        case .bo1: "The Black Ops folder: zone/ with the Zombies maps (zombie_*.ff) and binkw32.dll."
        case .bo2: "The Black Ops II folder: zone/ with the Black Ops II maps (mp_hijacked.ff or zm_*.ff) and binkw32.dll."
        case .iw5: "The 32-bit folder with main/, zone/ and mss32.dll inside."
        case .iw4: "Choose the Modern Warfare 2 folder (Windows game files, with main/ and zone/). Siliconium downloads the IW4X launcher, which keeps IW4X up to date."
        case .iw6: "Choose the Ghosts folder containing iw6sp64_ship.exe, zone/prologue.ff, bink2w64.dll and steam_api64.dll."
        case .bo2c: "Your Black Ops II folder, with t6sp.exe and zone/ inside (it can be anywhere: copied from a PC, an external drive, the Mac Steam app's folder…)."
        case .boiii: "The Windows game's folder, with BlackOps3.exe and zone/ inside."
        default: ""
        }
    }
    /// Explains why the 64-bit Steam folder cannot be used. It deliberately
    /// does not tell where to get the 32-bit files: the player brings them.
    func showIW5FilesHelp() {
        let alert = NSAlert()
        alert.messageText = "Modern Warfare 3 requires the 32-bit game files"
        alert.informativeText = """
            Steam updated Modern Warfare 3 to 64-bit in September 2026. Plutonium's IW5 client only runs the 32-bit game, so the 64-bit folder Steam installs cannot be used.

            Siliconium needs a 32-bit copy of the game: a folder with main/, zone/ and mss32.dll. It does not download game files. Plutonium brings its own iw5mp.exe, so the original executable is not needed.
            """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    var steamInstalled: Bool { FileManager.default.fileExists(atPath: "/Applications/Steam.app") }
    /// "ready", "downloading" (in Steam) or "missing"
    var bo3GameState: String { bo3["state"] ?? "missing" }
    var bo3Installed: Bool { !(bo3["installed"] ?? "").isEmpty }
    var bo3Version: String? { bo3Installed ? bo3["installed"] : nil }
    /// boiii.exe in the Windows Black Ops III folder
    var boiiiInstalled: Bool {
        guard let f = folder(for: .boiii) else { return false }
        return FileManager.default.fileExists(atPath: f.appendingPathComponent("boiii.exe").path)
    }
    /// Loads every map of a Direct3D 9 game once, offline, so its shaders are
    /// compiled before the first real visit (kit/prepare-shaders.sh).
    func prepareShaders(_ game: Game) {
        let id: String
        switch game {
        case .waw: id = "waw"
        case .bo1: id = "bo1"
        case .iw4: id = "iw4"
        default: return
        }
        guard progress == nil, running == nil else { return }
        runScript("prepare-shaders.sh", [id, "all"], title: "Preparing \(game.title)'s shaders")
    }
    func downloadBoiii() { runScript("boiii.sh", ["download"], title: "Downloading boiii.exe") }

    /// BOIII stats, loadouts and identity keys, saved in one zip / put back.
    func backupBoiii() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        panel.message = "Choose where to save your BOIII backup (stats, loadouts and identity). Keep it private."
        panel.prompt = "Save Backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runScript("boiii.sh", ["backup", url.path], title: "Backing up your BOIII stats")
    }

    func restoreBoiii() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        panel.message = "Choose a BOIII backup. Your current stats and identity go to the Trash."
        panel.prompt = "Restore"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runScript("boiii.sh", ["restore", url.path], title: "Restoring your BOIII stats")
    }
    /// Black Ops II's campaign: the game folder made Steam-free by
    /// bo2-campaign.sh (Steam-free: t6sp.exe runs directly)
    @Published var campaign: [String: String] = [:]
    /// bo2-steam.sh status: steam, signedin, running, game, dir
    @Published var steamCampaign: [String: String] = [:]
    /// A game the sidebar should switch to (its tab too), e.g. from BO2's Campaign button
    @Published var goTo: Game?
    /// BO2's Campaign button: Plutonium has no campaign, so show the two ways
    /// Siliconium offers in the Others tab and say why.
    func showCampaignOptions() {
        goTo = .bo2s
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Plutonium doesn't support the Black Ops II campaign"
            alert.informativeText = """
                Siliconium can play the campaign in two ways (Others tab):

                •  T6 - BO2 (Campaign, Steam): Steam for Windows, with your Steam account and its download of Black Ops II.
                •  T6 - BO2 (Campaign, Offline): from your own Black Ops II folder, without Steam.
                """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    func refreshSteamCampaign() {
        Task.detached {
            var d: [String: String] = [:]
            for line in Self.capture("bo2-steam.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                if p.count == 2 { d[String(p[0])] = String(p[1]) }
            }
            let result = d
            await MainActor.run { self.steamCampaign = result }
        }
    }
    /// Installs Steam for Windows in its own prefix and opens it to sign in.
    func setupSteamCampaign() {
        runScript("bo2-steam.sh", ["setup"], title: "Installing Steam for Windows") { [weak self] in
            self?.refreshSteamCampaign()
        }
    }
    func openSteam() { runScript("bo2-steam.sh", ["open"], title: nil) { [weak self] in self?.refreshSteamCampaign() } }
    func downloadInSteam() { runScript("bo2-steam.sh", ["download"], title: nil) { [weak self] in self?.refreshSteamCampaign() } }

    // MARK: Steam Library (steam.sh)

    /// steam.sh library: a catalog game's download in Steam
    struct SteamEntry {
        var state = "missing"          // installed|downloading|missing
        var folder = ""
        var parts: [(name: String, state: String)] = []   // Campaign, Multiplayer, Zombies…
        var dlc = 0                    // DLC (map packs…) Steam installed with it
    }
    @Published var steamLibrary: [String: SteamEntry] = [:]
    func refreshSteamLibrary() {
        refreshSteamCampaign()
        Task.detached {
            var d: [String: SteamEntry] = [:]
            for line in Self.capture("steam.sh", ["library"]).split(separator: "\n") {
                let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard p.count >= 5 else { continue }
                let parts = p[3].split(separator: ",").compactMap { part -> (name: String, state: String)? in
                    let kv = part.split(separator: ":", maxSplits: 1).map(String.init)
                    return kv.count == 2 ? (kv[0], kv[1]) : nil
                }
                d[p[0]] = SteamEntry(state: p[1], folder: p[2], parts: parts, dlc: Int(p[4]) ?? 0)
            }
            let result = d
            await MainActor.run { self.steamLibrary = result }
        }
    }
    func setupSteam() {
        runScript("steam.sh", ["setup"], title: "Installing Steam for Windows") { [weak self] in self?.refreshSteamLibrary() }
    }
    func openSteamLibrary() { runScript("steam.sh", ["open"], title: nil) { [weak self] in self?.refreshSteamLibrary() } }
    func downloadSteamGame(_ id: String) {
        runScript("steam.sh", ["download", id], title: nil) { [weak self] in self?.refreshSteamLibrary() }
    }
    /// Plays a Steam Library game: Steam's own files, started through Steam (launch.sh steam).
    func playSteam(_ title: SteamTitle, _ mode: SteamTitle.Mode) {
        guard progress == nil, running == nil else { return }
        // as in play(): the microphone question shows over this window, not behind the game
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.playSteam(title, mode) }
            }
            return
        }
        running = .steam
        runScript("launch.sh", ["steam", "\(title.id)-\(mode.id)"], title: "Loading…",
                  gameWindow: .init(executable: mode.exe, acceptsFullscreenWindows: title.id == "ghosts" || title.id == "aw")) { [weak self] in
            self?.running = nil
        }
    }
    func downloadAllSteamGames() {
        runScript("steam.sh", ["download-all"], title: "Asking Steam to download every game") { [weak self] in
            self?.refreshSteamLibrary()
        }
    }
    func openSteamStore(_ id: String) { runScript("steam.sh", ["store", id], title: nil) }
    /// Points a Siliconium game (Plutonium, IW4X, Ghosts) at Steam's download of it.
    func useSteamFolder(_ game: Game, _ path: String) {
        guard let key = game.folderKey, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        if let problem = gameFolderProblem(game, url) { error = problem; return }
        settings[key] = url.path
        settings.save()
        refreshToken += 1
        goTo = game
    }
    func refreshCampaign() {
        Task.detached {
            var d: [String: String] = [:]
            for line in Self.capture("bo2-campaign.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                if p.count == 2 { d[String(p[0])] = String(p[1]) }
            }
            let result = d
            await MainActor.run { self.campaign = result }
        }
    }
    /// Removes SteamStub from t6sp.exe (a backup is kept) and sets the game
    /// folder up to run without Steam. Only the game folder is touched.
    func prepareCampaign() {
        guard let folder = settings["BO2C_DIR"] else {
            error = "Choose the Black Ops II game folder first."
            return
        }
        runScript("bo2-campaign.sh", ["patch", folder], title: "Preparing the campaign (no Steam)") { [weak self] in
            self?.refreshCampaign()
        }
    }
    func createEmptyPrefix() { runScript("setup-prefix.sh", ["init"], title: "Creating the Wine prefix") }
    func createIW6Prefix() {
        runScript("setup-prefix.sh", ["init-iw6"], title: "Creating the Ghosts Wine prefix")
    }

    func isReady(_ game: Game) -> Bool {
        switch game {
        // Signing in to Plutonium once is enough for all four games: launch.sh
        // links the chosen folder in Plutonium's settings every time it starts
        // one, so no game needs its own "Install" after the first.
        case .waw, .bo1, .bo2, .iw5:
            engineInstalled && prefixReady && folderUsable(for: game) && plutoniumInstalled
        case .iw4: engineInstalled && prefixReady && folderUsable(for: .iw4)
        case .iw6: engineInstalled && iw6PrefixReady && folderUsable(for: .iw6)
        // boiii.exe is downloaded by launch.sh when Play finds none
        case .boiii: engineInstalled && prefixReady && folderUsable(for: .boiii)
        case .bo2c: engineInstalled && folderUsable(for: .bo2c) && campaign["ready"] == "yes"
        case .bo2s: engineInstalled && steamCampaign["steam"] == "installed" && steamCampaign["game"] == "installed"
        case .bo3: bo3Installed
        case .steam: engineInstalled && steamCampaign["steam"] == "installed"
        }
    }

    // MARK: Actions

    func chooseFolder(for game: Game) {
        guard let key = game.folderKey else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        switch game {
        case .waw: panel.message = "Choose the World at War folder: zone/ with the Zombies maps and binkw32.dll."
        case .bo1: panel.message = "Choose the Black Ops folder: zone/ with the Zombies maps and binkw32.dll."
        case .bo2: panel.message = "Choose the Black Ops II folder: zone/ with the Black Ops II maps and binkw32.dll."
        case .iw5: panel.message = "Choose the 32-bit Modern Warfare 3 folder: main/, zone/ and mss32.dll."
        case .iw4: panel.message = "Choose the Modern Warfare 2 folder with main/ and zone/ (Siliconium downloads the IW4X launcher)."
        case .iw6:
            panel.message = expectedFolderDetail(game)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            panel.directoryURL = folder(for: game) ?? downloads
        case .bo2c: panel.message = "Choose the Black Ops II campaign folder: t6sp.exe and zone/."
        case .boiii: panel.message = "Choose the Windows Black Ops III folder: BlackOps3.exe and zone/."
        default: panel.message = "Choose the \(game.title) game folder."
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let problem = gameFolderProblem(game, url) {
            error = problem
            return
        }
        settings[key] = url.path
        settings.save()
        refreshToken += 1
        if game == .bo2c { refreshCampaign() }
    }

    func installEngine() { runScript("install-engine.sh", [], title: "Installing the engine") }
    func updateX87() { runScript("install-engine.sh", ["--update-x87"], title: "Updating the x87 accelerator") }
    func choosePrefixToImport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an older Wine prefix with Plutonium (the folder that contains system.reg). Siliconium imports it with its Plutonium login and game settings."
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url { importPrefix(url) }
    }
    func importPrefix(_ url: URL) { runScript("setup-prefix.sh", ["import", url.path], title: "Importing your Plutonium setup", stepAside: true) }
    func setupPlutonium(_ game: Game) {
        guard let id = game.plutoniumID, let folder = folder(for: game), folderUsable(for: game) else { return }
        let needsSignIn = !plutoniumInstalled
        // setup-prefix.sh downloads Plutonium's installer from plutonium.pw (as
        // boiii.exe is downloaded); a plutonium.exe in the game folder is only
        // its fallback when plutonium.pw cannot be reached.
        let installer = folder
        runScript("setup-prefix.sh", ["setup", id, folder.path, installer.path],
                  title: needsSignIn ? "Setting up Plutonium" : "Linking the game folder", stepAside: needsSignIn)
    }
    func installBO3() {
        runScript("bo3.sh", ["install"], title: "Installing BO3 Mac Client") { [weak self] in self?.refreshBO3() }
    }
    func openBO3() {
        runScript("bo3.sh", ["open"], title: "Loading…",
                  gameWindow: .init(executable: "bo3macclient", startsOutsideScript: true))
    }
    func playBO3OnSteam() {
        runScript("bo3.sh", ["steam"], title: "Loading…", gameWindow: .game(.bo3, mode: "steam"))
    }

    // Zombies Declassified (Black Ops II mod)
    var zdInstalled: String? { (zd["installed"] ?? "").isEmpty ? nil : zd["installed"] }
    var zdLatest: String? { (zd["latest"] ?? "").isEmpty ? nil : zd["latest"] }
    func zombiesDeclassified(_ action: String) {
        let titles = ["install": "Installing Zombies Declassified", "verify": "Checking Zombies Declassified",
                      "remove": "Removing Zombies Declassified"]
        runScript("zombies-declassified.sh", [action], title: titles[action]) { [weak self] in self?.refreshZD() }
    }
    func refreshZD() {
        Task.detached {
            var d: [String: String] = [:]
            for line in Self.capture("zombies-declassified.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                d[String(p[0])] = p.count == 2 ? String(p[1]) : ""
            }
            let status = d
            await MainActor.run { self.zd = status }
        }
    }

    /// Update the client through IW4X's own launcher without starting the game.
    func updateIW4() { runScript("iw4-update.sh", [], title: "Updating IW4X") }

    /// IW4X's local stats (players/iw4x.stat): one zip to keep, put back later.
    /// The client writes them locally; settings (iw4x_config.cfg) stay out of it.
    func backupIW4Stats() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        panel.message = "Choose where to save your IW4X stats backup (XP, level, unlocks)."
        panel.prompt = "Save Backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runScript("iw4-stats.sh", ["backup", url.path], title: "Backing up your IW4X stats")
    }

    func restoreIW4Stats() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        panel.message = "Choose an IW4X stats backup. Close IW4X first; the stats it replaces go to the Trash."
        panel.prompt = "Restore"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runScript("iw4-stats.sh", ["restore", url.path], title: "Restoring your IW4X stats")
    }

    func removeSetup(_ what: String) {
        let titles = ["waw": "Removing the World at War setup", "bo1": "Removing the Black Ops setup", "bo2": "Removing the Black Ops II setup",
                      "iw5": "Removing the Modern Warfare 3 setup", "iw4": "Removing the Modern Warfare 2 setup",
                      "all": "Removing the engine and Plutonium", "bo3": "Removing BO3 Mac Client",
                      "bo2c": "Removing the campaign setup", "bo2s": "Removing Steam and its campaign",
                      "iw6": "Removing the Ghosts campaign setup"]
        if what != "iw6" { running = nil }
        runScript("uninstall.sh", [what], title: titles[what] ?? "Removing") { [weak self] in
            guard let self else { return }
            self.settings = Settings.load()
            self.refreshBO3(); self.refreshCampaign(); self.refreshSteamCampaign()
        }
    }

    /// BO3MacFix's ranked spoofing: opt-in (see BO3View for the risks).
    var bo3SpoofRanked: Bool { settings["BO3_SPOOF_RANKED"] == "1" }
    func setBO3SpoofRanked(_ on: Bool) {
        settings["BO3_SPOOF_RANKED"] = on ? "1" : "0"
        settings.save()
        runScript("bo3.sh", ["spoof", on ? "on" : "off"], title: nil) { [weak self] in self?.refreshBO3() }
    }

    func refreshBO3() {
        Task.detached {
            var d: [String: String] = [:]
            for line in Self.capture("bo3.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                d[String(p[0])] = p.count == 2 ? String(p[1]) : ""
            }
            let status = d
            await MainActor.run {
                self.bo3 = status
                self.bo3Latest = status["latest"].flatMap { $0.isEmpty ? nil : $0 }
            }
        }
    }

    /// Open Plutonium to manage the shared session.
    func openPlutonium(_ game: Game) {
        runScript("launch.sh", [game.rawValue, "online"], title: nil, stepAside: true,
                  noteHint: "Manage your Plutonium session here. Siliconium brings its window back when you close Plutonium.")
    }

    /// Opens the Discord invite with the user's default handler: the Discord
    /// app when it is installed, the browser otherwise.
    func openDiscord() {
        guard let url = URL(string: "https://discord.gg/4hpEXFqvNR") else { return }
        NSWorkspace.shared.open(url)
    }

    func play(_ game: Game, mode: PlayMode, lan: Bool = false) {
        guard progress == nil, running == nil else { return }
        // The games open the microphone (voice chat); Wine then waits for
        // macOS's answer. Ask here, once, so the question shows over this
        // window instead of behind the game's fullscreen loading screen.
        if game != .iw6 && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.play(game, mode: mode, lan: lan) }
            }
            return
        }
        running = game
        settings["LAST_GAME"] = game.rawValue
        settings.save()
        let name = settings["PLAYER_NAME"] ?? "Player"
        let args = [game.rawValue, mode.id, name] + (lan ? ["--lan"] : [])
        runScript("launch.sh", args, title: "Loading…", gameWindow: .game(game, mode: mode.id)) { [weak self] in
            // The Plutonium launcher may exit while the game it started
            // keeps running: the game is over when the engine's Wine is.
            self?.watchUntilStopped()
        }
    }

    func stop() {
        gameWindowTask?.cancel()
        if gameWindowTask != nil { progress = nil }
        task?.terminate()
        runScript("launch.sh", running == .iw6 ? ["stop", "iw6"] : ["stop"], title: nil)
        running = nil
    }

    /// A game (or Plutonium's launcher) running in Wine. Not just any Wine
    /// process: Steam for Windows stays open in the background for the
    /// campaign, and its Wine server runs from the engine too.
    nonisolated static var engineRunning: Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-if", #"t4mp\.exe|t4sp\.exe|t5mp\.exe|t5sp\.exe|t6mp\.exe|t6zm\.exe|t6sp\.exe|iw5mp\.exe|iw5sp\.exe|boiii(-[[:alnum:]._-]+)?\.exe|blackops3\.exe|iw4x(-launcher)?\.exe|iw6sp64_ship\.exe([[:space:]]|$)"#]
        p.standardOutput = Pipe()
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func watchUntilStopped() {
        Task.detached {
            while Self.engineRunning { try? await Task.sleep(for: .seconds(2)) }
            await MainActor.run { self.running = nil }
        }
    }

    // MARK: App updates (GitHub releases of the repository)

    nonisolated static let repository = "sirdankdabs/siliconium"
    var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
    var kitVersion: String? {
        (try? String(contentsOf: Paths.kit.appendingPathComponent("VERSION"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct Release: Sendable {
        let version: String
        let download: URL
        let digest: String
    }

    func checkForAppUpdate(manual: Bool) {
        guard !checkingForAppUpdate else { return }
        if !manual {
            guard !checkedForAppUpdateOnLaunch else { return }
            checkedForAppUpdateOnLaunch = true
        }
        checkingForAppUpdate = true
        Task {
            defer { checkingForAppUpdate = false }
            do {
                let release = try await Self.latestRelease()
                guard Self.isNewer(release.version, than: appVersion) else {
                    if manual {
                        let alert = NSAlert()
                        alert.messageText = "You're up to date"
                        alert.informativeText = "Siliconium \(appVersion) is the latest version."
                        alert.runModal()
                    }
                    return
                }
                guard running == nil, progress == nil, task?.isRunning != true else {
                    if manual { error = "Finish the current setup or quit the game, then check for updates again." }
                    return
                }
                await installUpdate(release)
            } catch {
                if manual { self.error = "Couldn't check for updates. Check your internet connection and try again." }
            }
        }
    }

    nonisolated static func latestRelease() async throws -> Release {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String, tag.hasPrefix("v"),
              let assets = json["assets"] as? [[String: Any]] else { throw CocoaError(.fileReadCorruptFile) }
        let version = String(tag.dropFirst())
        guard let zip = assets.first(where: { ($0["name"] as? String) == "Siliconium-\(version).zip" }),
              let link = zip["browser_download_url"] as? String, let download = URL(string: link),
              download.scheme == "https", download.host == "github.com",
              download.path == "/\(repository)/releases/download/\(tag)/Siliconium-\(version).zip",
              let digest = zip["digest"] as? String,
              digest.range(of: #"^sha256:[0-9a-f]{64}$"#, options: .regularExpression) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return Release(version: version, download: download, digest: String(digest.dropFirst("sha256:".count)))
    }

    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    /// Keep the current app in place until the new bundle is verified and ready.
    private func installUpdate(_ release: Release) async {
        progress = "Downloading Siliconium \(release.version)"
        let current = Bundle.main.bundleURL
        do {
            let (file, response) = try await URLSession.shared.download(from: release.download)
            let fm = FileManager.default
            defer { try? fm.removeItem(at: file) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let directory = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                       appropriateFor: current, create: true)
            var keepPreviousApp = false
            defer { if !keepPreviousApp { try? fm.removeItem(at: directory) } }
            let app = try await Task.detached {
                try Self.prepareUpdate(release, archive: file, directory: directory)
            }.value
            // A game or setup might have started elsewhere while we downloaded.
            guard running == nil, task?.isRunning != true, !Self.engineRunning,
                  !NSWorkspace.shared.runningApplications.contains(where: {
                      $0.executableURL?.lastPathComponent == "codblkops3_exe"
                  }) else {
                progress = nil
                return
            }

            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", """
                for attempt in $(/usr/bin/seq 1 100); do
                    if ! kill -0 "$1" 2>/dev/null; then exec /usr/bin/open -n "$2"; fi
                    sleep 0.2
                done
                """, "siliconium-update", String(ProcessInfo.processInfo.processIdentifier), current.path]
            try relaunch.run()
            guard renamex_np(app.path, current.path, UInt32(RENAME_SWAP)) == 0 else {
                let failure = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                relaunch.terminate()
                throw failure
            }
            // After the swap, the staging path holds the previous version.
            do { try fm.trashItem(at: app, resultingItemURL: nil) }
            catch { keepPreviousApp = true }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        } catch {
            progress = nil
            self.error = "The update could not be installed: \(error.localizedDescription)"
        }
    }

    nonisolated static func prepareUpdate(_ release: Release, archive: URL, directory: URL) throws -> URL {
        let file = try FileHandle(forReadingFrom: archive)
        defer { try? file.close() }
        var hash = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hash.update(data: chunk)
        }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == release.digest else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", archive.path, directory.path]
        try unzip.run()
        unzip.waitUntilExit()
        let app = directory.appendingPathComponent("Siliconium.app", isDirectory: true)
        guard unzip.terminationStatus == 0, let bundle = Bundle(url: app),
              bundle.bundleIdentifier == "io.github.siliconium",
              bundle.infoDictionary?["CFBundleShortVersionString"] as? String == release.version,
              let min = bundle.infoDictionary?["LSMinimumSystemVersion"] as? String else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if Self.isNewer(min, than: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)") {
            throw NSError(domain: "Siliconium", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Siliconium \(release.version) needs macOS \(min) or later. Update macOS in System Settings → General → Software Update."])
        }

        let verify = Process()
        verify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verify.arguments = ["--verify", "--deep", "--strict", app.path]
        try verify.run()
        verify.waitUntilExit()
        guard verify.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
        return app
    }

    /// After an update: the files this app installs (engine modules, BO3 Mac
    /// Client) are replaced with the ones it now carries. Settings, Plutonium
    /// and shader caches are kept.
    func refreshInstalledFiles() {
        guard running == nil, progress == nil else { return }
        if engineInstalled, let kit = kitVersion, engineInfo["kit"] != kit {
            runScript("install-engine.sh", [], title: "Updating the game files") { [weak self] in self?.refreshBO3Files() }
        } else {
            refreshBO3Files()
        }
    }

    private func refreshBO3Files() {
        Task.detached {
            var status: [String: String] = [:]
            for line in Self.capture("bo3.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                status[String(p[0])] = p.count == 2 ? String(p[1]) : ""
            }
            let installed = status["installed"] ?? "", bundled = status["latest"] ?? ""
            let current = status, ready = status["state"] == "ready"
            await MainActor.run {
                self.bo3 = current
                if self.progress == nil, self.running == nil, !installed.isEmpty, !bundled.isEmpty, installed != bundled, ready {
                    self.runScript("bo3.sh", ["install"], title: "Updating BO3 Mac Client", env: ["NO_OPEN": "1"]) {
                        self.refreshBO3()
                    }
                }
            }
        }
    }

    /// macOS 14: DXMT (Direct3D 11: Black Ops II and the Windows Black Ops III)
    /// needs macOS 15, so those games cannot run. Said once per launch until
    /// the user ticks "Don't show this again".
    func warnOldMacOS() {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 15,
              !UserDefaults.standard.bool(forKey: "hideMacOS14Warning") else { return }
        DispatchQueue.main.async {
            let os = ProcessInfo.processInfo.operatingSystemVersion
            let v = "\(os.majorVersion).\(os.minorVersion)"
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "macOS 15 or later is recommended"
            alert.informativeText = """
                This Mac runs macOS \(v). Games that need DXMT (Direct3D 11) cannot run on macOS 14:
                •  T6 - BO2
                •  T6 - BO2 (Campaign, Steam and Offline)
                •  IW6 - Ghosts (Campaign, Offline)
                •  T7 - BO3 (EZZ/BOIII Client)

                T4 - WaW, T5 - BO1, IW5 - MW3, IW4 - MW2 and T7 - BO3 (Steam macOS) can still be used.

                To play every game, update to macOS 15 Sequoia or later in System Settings → General → Software Update.
                """
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Don't show this again"
            alert.addButton(withTitle: "OK")
            alert.runModal()
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "hideMacOS14Warning")
            }
        }
    }

    func checkUpdates() {
        refreshBO3()
        refreshZD()
        Task.detached {
            let x87 = Self.latestX87()
            await MainActor.run { self.x87Latest = x87 }
        }
    }

    nonisolated static func latestX87() -> String? {
        guard let url = URL(string: "https://api.github.com/repos/athei/x87sidecar/releases/latest"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["tag_name"] as? String
    }

    nonisolated static func capture(_ script: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [Paths.kit.appendingPathComponent(script).path] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// Siliconium steps aside while Plutonium installs and asks to sign in: its
    /// window opens where Siliconium was, so the main window is put away instead
    /// of the whole app being hidden (a hidden app and no Plutonium window in
    /// front looked exactly like a crash). A floating note keeps the current
    /// step and the way back on screen.
    private func showSetupNote(hint: String? = nil) {
        dismissSetupNote()
        let model = SetupNoteModel()
        if let hint { model.hint = hint }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let hosting = NSHostingView(rootView: SetupNoteView(model: model) { [weak self] in
            self?.showMainWindow()
        })
        let fitted = hosting.fittingSize
        let size = NSSize(width: max(fitted.width, 360), height: max(fitted.height, 120))
        hosting.frame = NSRect(origin: .zero, size: size)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.setFrameTopLeftPoint(NSPoint(x: screen.maxX - size.width - 24, y: screen.maxY - 24))
        panel.orderFrontRegardless()
        setupNote = panel
        setupNoteModel = model
    }

    private func dismissSetupNote() {
        setupNote?.orderOut(nil)
        setupNote?.close()
        setupNote = nil
        setupNoteModel = nil
    }

    private func mainWindow() -> NSWindow? { NSApp.windows.first { !($0 is NSPanel) } }

    /// Puts the window back (automatic when the step ends, or from the note).
    private func showMainWindow() {
        dismissSetupNote()
        mainWindow()?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func watchForGameWindow(_ target: GameWindowTarget, launch process: Process) {
        gameWindowTask?.cancel()
        let existingConsoles = target.plutoniumMode == nil ? [] : GameWindowTarget.visibleConsoleWindows()
        gameWindowTask = Task { [weak self] in
            defer { if !Task.isCancelled { self?.gameWindowTask = nil } }
            let deadline = ContinuousClock.now + .seconds(180)
            while !Task.isCancelled && self != nil {
                guard process.isRunning || (target.startsOutsideScript && process.terminationStatus == 0) else { return }
                if let pid = await target.visiblePID(excludingConsoles: existingConsoles), !Task.isCancelled,
                   process.isRunning || (target.startsOutsideScript && process.terminationStatus == 0) {
                    self?.progress = nil
                    self?.mainWindow()?.orderOut(nil)
                    NSApp.hide(nil)
                    if target.startsOutsideScript {
                        while !Task.isCancelled && kill(pid, 0) == 0 {
                            try? await Task.sleep(for: .seconds(1))
                        }
                        if !Task.isCancelled { self?.showMainWindow() }
                    }
                    return
                }
                if target.startsOutsideScript && ContinuousClock.now >= deadline {
                    self?.progress = nil
                    self?.error = "The game window hasn't opened yet. Check the launcher for prompts."
                    return
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    /// Run a kit script, streaming its output to the log; "==> " lines show
    /// as the current step, "ERROR: " lines as an alert.
    func runScript(_ script: String, _ args: [String], title: String?, env: [String: String] = [:],
                   stepAside: Bool = false, noteHint: String? = nil,
                   gameWindow: GameWindowTarget? = nil, done: (() -> Void)? = nil) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [Paths.kit.appendingPathComponent(script).path] + args
        if !env.isEmpty { p.environment = ProcessInfo.processInfo.environment.merging(env) { $1 } }
        let launchesGame = gameWindow != nil || script == "launch.sh"
        // Every process of a game (the script, Wine, the game's threads) takes
        // its QoS from here. At the default QoS macOS may run game threads on
        // the efficiency cores and throttle them with Siliconium in the
        // background; user-interactive keeps them on the performance cores.
        p.qualityOfService = launchesGame ? .userInteractive : .userInitiated
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        if let title { progress = title; log.append("— \(title)") }
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            if data.isEmpty {
                // Games redirect their output to their own logs.
                if gameWindow != nil { h.readabilityHandler = nil }
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                guard let self else { return }
                for line in text.split(separator: "\n") {
                    let l = String(line)
                    self.log.append(l)
                    if l.hasPrefix("==> ") { self.progress = String(l.dropFirst(4)); self.setupNoteModel?.step = String(l.dropFirst(4)) }
                    if l.hasPrefix("ERROR: ") { self.error = String(l.dropFirst(7)) }
                }
                if self.log.count > 2000 { self.log.removeFirst(self.log.count - 2000) }
            }
        }
        // While a game runs Siliconium is hidden behind it: keep App Nap from
        // slowing the app's side of the launch (its log pipe and the window
        // watcher that brings the game forward).
        let activity = launchesGame
            ? ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                    reason: "A game started by Siliconium is running")
            : nil
        p.terminationHandler = { [weak self] process in
            if let activity { ProcessInfo.processInfo.endActivity(activity) }
            Task { @MainActor in
                pipe.fileHandleForReading.readabilityHandler = nil
                let waitingForExternalGame = gameWindow?.startsOutsideScript == true && process.terminationStatus == 0
                if gameWindow != nil && !waitingForExternalGame, self?.task === process {
                    self?.gameWindowTask?.cancel()
                    self?.gameWindowTask = nil
                }
                if title != nil && !waitingForExternalGame { self?.progress = nil }
                if stepAside || (gameWindow != nil && !waitingForExternalGame) { self?.showMainWindow() }
                self?.refreshToken += 1
                done?()
            }
        }
        do {
            if stepAside {
                mainWindow()?.orderOut(nil)
                showSetupNote(hint: noteHint)
            }
            try p.run()
            if title == nil || script == "launch.sh" || gameWindow != nil { task = p }
            if let gameWindow { watchForGameWindow(gameWindow, launch: p) }
        } catch {
            if let activity { ProcessInfo.processInfo.endActivity(activity) }
            if stepAside || gameWindow != nil { showMainWindow() }
            if gameWindow != nil { running = nil }
            self.error = "Cannot run \(script): \(error.localizedDescription)"
            progress = nil
        }
    }
}

/// The floating note shown while Plutonium installs and asks to sign in.
@MainActor
final class SetupNoteModel: ObservableObject {
    @Published var step = "Starting…"
    @Published var hint = "Sign in in Plutonium's window; Siliconium closes it when you are in. If you cannot see it, click it in the Dock."
}
