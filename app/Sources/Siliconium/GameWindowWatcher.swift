import CoreGraphics
import Foundation

// MARK: - Game Window Watcher

struct GameWindowTarget {
    let executable: String
    var plutoniumMode: String? = nil
    var startsOutsideScript = false
    var isBOIII = false
    var acceptsFullscreenWindows = false
    /// Call of Duty / United Offensive / Call of Duty 2 / WWII (Steam, campaign and multiplayer): their
    /// fullscreen window sits at a raised level (21; CoD2 captured: shielding
    /// level), so it was never seen and Siliconium stayed in front (menu bar
    /// shown, CoD1's intro played behind it). Such a game is also handed the
    /// activation explicitly (macOS 14 only lets the active app do it)
    var acceptsRaisedWindows = false

    static func game(_ game: Game, mode: String) -> Self {
        switch game {
        case .waw: .init(executable: mode == "mp" ? "t4mp.exe" : "t4sp.exe", plutoniumMode: mode == "mp" ? "t4mp" : "t4sp")
        case .bo1: .init(executable: mode == "mp" ? "t5mp.exe" : "t5sp.exe", plutoniumMode: mode == "mp" ? "t5mp" : "t5sp")
        case .bo2: .init(executable: mode == "mp" ? "t6mp.exe" : "t6zm.exe", plutoniumMode: mode == "mp" ? "t6mp" : "t6zm")
        case .iw5: .init(executable: "iw5mp.exe", plutoniumMode: "iw5mp")
        case .iw4: .init(executable: "iw4x.exe")
        case .boiii: .init(executable: "boiii.exe", isBOIII: true)
        case .bo3: .init(executable: "codblkops3_exe", startsOutsideScript: true)
        case .steam: .init(executable: "steam.exe", startsOutsideScript: true)
        case .battlenet: .init(executable: "Battle.net.exe", startsOutsideScript: true)
        case .cod4x: .init(executable: "iw3mp.exe")
        // IW7-Mod maps the game into its own process (iw7-mod.exe), which
        // opens the game's exclusive-fullscreen window (as Steam's iw7_ship.exe)
        case .iw7mod: .init(executable: "iw7-mod.exe", acceptsFullscreenWindows: true)
        case .plutonium, .ownFiles, .alterware: .init(executable: "")
        }
    }

    static func visibleConsoleWindows() -> Set<CGWindowID> {
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let consoles = consolePIDs(windows)
        return Set(windows.compactMap { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32, consoles.contains(pid) else { return nil }
            return window[kCGWindowNumber as String] as? CGWindowID
        })
    }

    /// Owners of Wine console (conhost.exe) windows. Wine's processes started
    /// from Siliconium's Game Mode bundle (kit/tools/game-bundle.sh) all show
    /// the owner name "Siliconium Game", so a window's owner is told by its
    /// process's command name, as before by the owner name "conhost.exe".
    static func consolePIDs(_ windows: [[String: Any]]) -> Set<Int32> {
        var consoles = Set<Int32>(), others = Set<Int32>()
        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32 else { continue }
            switch window[kCGWindowOwnerName as String] as? String {
            case "conhost.exe": consoles.insert(pid)
            case "Siliconium Game": others.insert(pid)
            default: break
            }
        }
        others.subtract(consoles)
        guard !others.isEmpty else { return consoles }
        for line in ps(["-ww", "-p", others.map(String.init).joined(separator: ","), "-o", "pid=,comm="]).split(separator: "\n") {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            if parts.count == 2, let pid = Int32(parts[0]), parts[1].lowercased().hasSuffix("conhost.exe") { consoles.insert(pid) }
        }
        return consoles
    }

    func visiblePID(excludingConsoles existingConsoles: Set<CGWindowID>) async -> Int32? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let visibleWindows = windows.filter { window in
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 || (acceptsFullscreenWindows && layer >= Int(CGWindowLevelForKey(.mainMenuWindow))) ||
                  (acceptsRaisedWindows && layer > 0),
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            return (bounds["Width"] ?? 0) >= 300 && (bounds["Height"] ?? 0) >= 170
        }
        // The URI can open Plutonium's console before the game renderer.
        if let plutoniumMode {
            let consoles = Self.consolePIDs(visibleWindows)
            for window in visibleWindows {
                guard let owner = window[kCGWindowOwnerPID as String] as? Int32, consoles.contains(owner),
                      let id = window[kCGWindowNumber as String] as? CGWindowID,
                      !existingConsoles.contains(id), let pid = window[kCGWindowOwnerPID as String] as? Int32 else { continue }
                if (window[kCGWindowName as String] as? String)?.hasPrefix("Plutonium ") == true { return pid }
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
        let targetExe = executable.lowercased()
        for line in Self.ps(["-ww", "-p", ids, "-o", "pid=,comm="]).split(separator: "\n") {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2, let pid = Int32(parts[0]),
                  let name = parts[1].lowercased().split(whereSeparator: { $0 == "/" || $0 == "\\" }).last else { continue }
            if name == targetExe || (plutoniumMode != nil && name == "plutonium-launcher-win32.exe") { return pid }
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

// MARK: - Paths & Settings

enum Paths {
    /// True when launched with an explicit SIL_HOME sandbox (e.g. fresh-user testing).
    static let isCustomHome: Bool = {
        if let custom = ProcessInfo.processInfo.environment["SIL_HOME"], !custom.isEmpty { return true }
        return false
    }()
    /// True when any component of a Unix path ends with "." or " " (Windows/Wine
    /// strips trailing dots/spaces in RtlDosPathNameToNtPathName_U, causing
    /// kernel32.dll status c0000135 on every Wine launch).
    static func hasWineUnsafeComponent(_ path: String) -> Bool {
        path.split(separator: "/").contains { comp in
            comp != "." && comp != ".." && (comp.hasSuffix(".") || comp.hasSuffix(" "))
        }
    }
    /// True when Siliconium moved its data folder outside $HOME because the Mac
    /// user folder ends in a trailing dot or space.
    static let usesIsolatedHome: Bool = {
        !isCustomHome && hasWineUnsafeComponent(FileManager.default.homeDirectoryForCurrentUser.path)
    }()
    private static func darwinUserCacheDir() -> String? {
        let len = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
        guard len > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: len)
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buf, len) > 0 else { return nil }
        return String(cString: buf)
    }
    /// ~/Library/Application Support/Siliconium (or $SIL_HOME, or a private 0700
    /// Wine-safe folder when the Mac username ends in "." or " ").
    static let home: URL = {
        if let custom = ProcessInfo.processInfo.environment["SIL_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        let fm = FileManager.default
        let support = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let defaultHome = support.appendingPathComponent("Siliconium")
        if hasWineUnsafeComponent(fm.homeDirectoryForCurrentUser.path) {
            let safeShared = URL(fileURLWithPath: "/Users/Shared/Siliconium-\(getuid())")
            let target: URL
            if fm.fileExists(atPath: safeShared.path) ||
               (try? fm.createDirectory(at: safeShared, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])) != nil {
                target = safeShared
            } else if let cache = darwinUserCacheDir() {
                let cURL = URL(fileURLWithPath: cache).appendingPathComponent("Siliconium")
                try? fm.createDirectory(at: cURL, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
                target = cURL
            } else {
                target = defaultHome
            }
            if target != defaultHome {
                let oldEngine = defaultHome.appendingPathComponent("engine")
                let newEngine = target.appendingPathComponent("engine")
                if fm.fileExists(atPath: oldEngine.path), !fm.fileExists(atPath: newEngine.path) {
                    try? fm.moveItem(at: oldEngine, to: newEngine)
                }
                let oldSettings = defaultHome.appendingPathComponent("settings.conf")
                let newSettings = target.appendingPathComponent("settings.conf")
                if fm.fileExists(atPath: oldSettings.path), !fm.fileExists(atPath: newSettings.path) {
                    try? fm.moveItem(at: oldSettings, to: newSettings)
                }
            }
            return target
        }
        let home = defaultHome
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
    /// Environment for child kit scripts and tools: propagates SIL_HOME whenever
    /// running isolated or in a custom sandbox.
    static func processEnvironment(merging extra: [String: String] = [:]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if isCustomHome || usesIsolatedHome {
            env["SIL_HOME"] = home.path
        }
        for (k, v) in extra { env[k] = v }
        return env
    }
    /// Scrubs the user's Mac home path and username from logs before display or
    /// clipboard copy (both Unix `/Users/<name>` and Wine `Z:\Users\<name>`).
    static func redact(_ text: String) -> String {
        let userHome = FileManager.default.homeDirectoryForCurrentUser.path
        let trimmedHome = userHome.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        var out = text
        if !userHome.isEmpty {
            out = out.replacingOccurrences(of: userHome, with: "~")
        }
        if !trimmedHome.isEmpty && trimmedHome != userHome {
            out = out.replacingOccurrences(of: trimmedHome, with: "~")
        }
        let keepUsers: Set<String> = ["shared", "public", "crossover", "runner", "<user>"]
        if let unixRe = try? NSRegularExpression(pattern: #"/Users/([^/\s:"']+)"#) {
            let matches = unixRe.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed()
            for m in matches {
                guard let r = Range(m.range(at: 1), in: out) else { continue }
                if !keepUsers.contains(out[r].lowercased()) {
                    out.replaceSubrange(r, with: "<user>")
                }
            }
        }
        if let winRe = try? NSRegularExpression(pattern: #"(?i)([A-Z]:\\{1,2}Users\\{1,2})([^\\/\s:"']+)"#) {
            let matches = winRe.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed()
            for m in matches {
                guard let r = Range(m.range(at: 2), in: out) else { continue }
                if !keepUsers.contains(out[r].lowercased()) {
                    out.replaceSubrange(r, with: "<user>")
                }
            }
        }
        return out
    }
    /// Non-identifying hardware & OS summary shown at the top of LogView for
    /// faster troubleshooting when users share logs.
    static func cpuBrand() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple silicon" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0) == 0 else { return "Apple silicon" }
        return String(cString: buf)
    }
    static func freeDiskGB() -> Int? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: home.deletingLastPathComponent().path),
              let free = attrs[.systemFreeSize] as? NSNumber else { return nil }
        return Int(free.uint64Value / 1_073_741_824)
    }
    static var engine: URL { home.appendingPathComponent("engine") }
    static var prefix: URL { home.appendingPathComponent("prefix") }
    static var steamPrefix: URL { home.appendingPathComponent("prefix-steam") }
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
            root = target.hasPrefix("/")
                ? target
                : drive.deletingLastPathComponent().appendingPathComponent(target).standardizedFileURL.path
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

struct Settings: Equatable, Sendable {
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

// MARK: - Isolated Log Store

/// Holds session logs in its own ObservableObject so streaming script output
/// only redraws LogView when open, never the sidebar or game views.
@MainActor
final class LogStore: ObservableObject {
    @Published var lines: [String] = []

    func append(_ line: String) {
        lines.append(line)
        if lines.count > 2000 { lines.removeFirst(lines.count - 2000) }
    }

    func append(contentsOf batch: [String]) {
        guard !batch.isEmpty else { return }
        lines.append(contentsOf: batch)
        if lines.count > 2000 { lines.removeFirst(lines.count - 2000) }
    }
}

// MARK: - Setup Note & Display Info

/// The floating note shown while Plutonium installs and asks to sign in.
@MainActor
final class SetupNoteModel: ObservableObject {
    @Published var step = "Starting…"
    @Published var hint = "Sign in in Plutonium's window; Siliconium closes it when you are in. If you cannot see it, click it in the Dock."
}

/// The main display as `displaymode info` describes it, and what a game
/// started now gets on it (see AppState.refreshDisplay).
struct DisplayInfo: Equatable {
    var width = 0, height = 0, pixelWidth = 0, pixelHeight = 0, hz = 0
    var kind = ""                       // 1x | hidpi | hidpi-scaled
    var gameWidth = 0, gameHeight = 0, gamePixelWidth = 0, gamePixelHeight = 0, gameHz = 0
    var plan = ""                       // 1x | kept | already | none
    var holds = true                    // DISPLAY_MODE is not 0
    var keepMode = "1"                  // KEEP_HIDPI: 0 (1x all) | 1 (Smart HiDPI) | 2 (keep all)
    var maxfps: Int?                    // MAXFPS set in Settings
    var name = ""

    init?(parsing text: String) {
        var d: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let kv = line.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { d[String(kv[0])] = String(kv[1]) }
        }
        func int(_ k: String) -> Int { Int(d[k] ?? "") ?? 0 }
        width = int("desktop_width"); height = int("desktop_height")
        pixelWidth = int("desktop_pixel_width"); pixelHeight = int("desktop_pixel_height")
        hz = int("desktop_hz"); kind = d["desktop_kind"] ?? ""
        gameWidth = int("game_width"); gameHeight = int("game_height")
        gamePixelWidth = int("game_pixel_width"); gamePixelHeight = int("game_pixel_height")
        gameHz = int("game_hz"); plan = d["plan"] ?? ""
        guard width > 0, height > 0, gameHz > 0 else { return nil }
    }

    var signature: String { "\(width)x\(height)@\(pixelWidth)x\(pixelHeight)/\(hz)/\(plan)/\(gameHz)/\(holds)/\(keepMode)" }
    var isSmartHiDPI: Bool { holds && kind == "hidpi-scaled" && keepMode == "1" && plan == "1x" && gameHz <= hz }
    var runWidth: Int { holds ? gameWidth : width }
    var runHeight: Int { holds ? gameHeight : height }
    var runHz: Int { holds ? gameHz : hz }
    var runIs1x: Bool { holds ? (gamePixelWidth == gameWidth) : (kind == "1x") }
    var cap: Int { maxfps ?? runHz }
    var badgeModeText: String {
        if isSmartHiDPI { return " · Smart HiDPI" }
        return runIs1x ? " · 1x" : " · HiDPI"
    }

    var desktopText: String {
        switch kind {
        case "hidpi": return "\(width)×\(height) HiDPI (drawn at \(pixelWidth)×\(pixelHeight), the panel's own pixels), \(hz) Hz"
        case "hidpi-scaled": return "\(width)×\(height) HiDPI scaled (drawn at \(pixelWidth)×\(pixelHeight)), \(hz) Hz"
        default: return "\(width)×\(height) at 1x, \(hz) Hz"
        }
    }
    var gameText: String {
        if isSmartHiDPI {
            return "\(runWidth)×\(runHeight) HiDPI (mtld3d / BO2) · 1x (heavy D3D11), \(runHz) Hz"
        }
        return "\(runWidth)×\(runHeight) " + (runIs1x ? "at 1x" : "HiDPI") + ", \(runHz) Hz"
    }
    var whyText: String {
        if !holds { return "Display mode switching is off in Settings (DISPLAY_MODE=0): games use the desktop's mode as it is." }
        if isSmartHiDPI {
            return "Smart HiDPI is active on your scaled desktop: Direct3D 9 games on mtld3d (CoD 1, UO, CoD 2, CoD4, WaW, BO1, MW2, MW3) and Black Ops II keep your sharp HiDPI desktop at full \(runHz) Hz with no mode switch. Heavy Direct3D 11 games (BO3, AW, IW, WWII, BO4) and DXVK fallback switch to 1x so macOS doesn't render them at \(pixelWidth)×\(pixelHeight); your mode comes back when the game ends."
        }
        switch plan {
        case "kept":
            return kind == "hidpi-scaled"
                ? "Your scaled HiDPI mode is kept (KEEP_HIDPI=2). Heavy D3D11 or DXVK games may draw at \(pixelWidth)×\(pixelHeight), which can reduce FPS."
                : "Your HiDPI mode is kept: it already uses the panel's own pixels and no 1x mode of this size is faster, so there is no mode switch and the desktop stays sharp after Cmd-Tab."
        case "1x":
            if kind == "hidpi-scaled" {
                return "Your desktop is scaled: kept, macOS would draw every frame at \(pixelWidth)×\(pixelHeight) (up to half the FPS). While a game runs the display uses the 1x mode of the same size; your mode comes back when the game ends."
            }
            if kind == "1x" {
                return "A faster mode of the same size exists: while a game runs the display runs at \(gameHz) Hz; your \(hz) Hz comes back when the game ends."
            }
            if gameHz > hz {
                return "The 1x mode of this size runs at \(gameHz) Hz, faster than your HiDPI mode's \(hz) Hz: it is used while a game runs, and your mode comes back when the game ends."
            }
            return "HiDPI is not kept (KEEP_HIDPI=0): while a game runs the display uses the 1x mode of the same size; your mode comes back when the game ends."
        case "already":
            return "Your desktop already runs at 1x at its best refresh rate: nothing changes."
        default:
            return "There is no 1x mode of this size: games run in your desktop's mode."
        }
    }
}
