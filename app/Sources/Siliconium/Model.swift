import AppKit
import AVFoundation
import CoreGraphics
import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Cached Status Snapshot (computed off main thread)

/// Immutable filesystem/config status snapshot computed off the main thread so
/// SwiftUI sidebar/detail renders do zero FileManager or JSON disk I/O.
struct StatusSnapshot: Equatable, Sendable {
    var engineInstalled = false
    var engineInfo: [String: String] = [:]
    var prefixReady = false
    var steamPrefixReady = false
    var plutoniumInstalled = false
    var plutoniumPaths: [String: String] = [:]
    var crossOverVersion: String? = nil
    var rosettaInstalled = false
    var steamAppInstalled = false
    var kitVersion: String? = nil
    var folders: [Game: URL] = [:]
    var folderProblems: [Game: String] = [:]
    var boiiiInstalled = false
    var ownFolders: [String: URL] = [:]

    /// Instant lightweight seed for Frame 1 (no recursive directory scans).
    nonisolated static func computeFast(settings: Settings) -> StatusSnapshot {
        let fm = FileManager.default
        var snap = StatusSnapshot()
        snap.engineInstalled = fm.fileExists(atPath: Paths.engine.appendingPathComponent("siliconium.version").path)
        snap.prefixReady = fm.fileExists(atPath: Paths.prefix.appendingPathComponent("system.reg").path)
        snap.steamPrefixReady = fm.fileExists(atPath: Paths.steamPrefix.appendingPathComponent("system.reg").path)
        snap.rosettaInstalled = fm.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
        snap.steamAppInstalled = fm.fileExists(atPath: "/Applications/Steam.app")
        snap.kitVersion = (try? String(contentsOf: Paths.kit.appendingPathComponent("VERSION"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = try? String(contentsOf: Paths.engine.appendingPathComponent("siliconium.version"), encoding: .utf8) {
            for l in t.split(separator: "\n") {
                let p = l.split(separator: "=", maxSplits: 1)
                if p.count == 2 { snap.engineInfo[String(p[0])] = String(p[1]) }
            }
        }
        let p = Paths.plutonium
        if fm.fileExists(atPath: p.appendingPathComponent("bin/plutonium-launcher-win32.exe").path),
           fm.fileExists(atPath: p.appendingPathComponent("bin/plutonium-bootstrapper-win32.exe").path),
           let data = try? Data(contentsOf: p.appendingPathComponent("config.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String,
           !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            snap.plutoniumInstalled = true
            for id in ["t4", "t5", "t6", "iw5"] {
                if let win = json["\(id)Path"] as? String, let mac = Paths.macPath(ofWindowsPath: win) {
                    snap.plutoniumPaths[id] = mac
                }
            }
        }
        let plist = URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/Info.plist")
        if let d = NSDictionary(contentsOf: plist) {
            snap.crossOverVersion = d["CFBundleShortVersionString"] as? String
        }
        for game in Game.allCases {
            guard let key = game.folderKey, let path = settings[key], !path.isEmpty else { continue }
            let url = URL(fileURLWithPath: path)
            let marker = game == .iw7mod ? "iw7_ship.exe" : "zone"
            if fm.fileExists(atPath: url.appendingPathComponent(marker).path) {
                snap.folders[game] = url
            }
        }
        if let f = snap.folders[.boiii] {
            snap.boiiiInstalled = fm.fileExists(atPath: f.appendingPathComponent("boiii.exe").path)
        }
        for title in OwnGameTitle.catalog {
            let path = [title.folderKey, title.legacyFolderKey]
                .compactMap { $0 }.compactMap { settings[$0] }.first { !$0.isEmpty }
            if let path {
                let url = URL(fileURLWithPath: path)
                if fm.fileExists(atPath: url.path) {
                    snap.ownFolders[title.id] = url
                }
            }
        }
        return snap
    }

    /// Complete validation snapshot (including zone/ and IW5 checks), run off-main-thread.
    nonisolated static func computeFull(settings: Settings) -> StatusSnapshot {
        var snap = computeFast(settings: settings)
        for (game, url) in snap.folders {
            if let problem = AppState.checkGameFolderProblem(game, url) {
                snap.folderProblems[game] = problem
            }
        }
        var validOwn: [String: URL] = [:]
        for title in OwnGameTitle.catalog {
            guard let url = snap.ownFolders[title.id] else { continue }
            if AppState.checkOwnFolderProblem(title, url) == nil {
                validOwn[title.id] = url
            }
        }
        snap.ownFolders = validOwn
        return snap
    }
}

// MARK: - App state

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var settings: Settings
    @Published private(set) var snapshot: StatusSnapshot
    let logStore = LogStore()
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
    @Published var whatsNew: String?          // this version's release notes, once after an update
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
    private var snapshotTask: Task<Void, Never>?
    private var task: Process?
    private var gameWindowTask: Task<Void, Never>?
    private var setupNote: NSPanel?
    private var setupNoteModel: SetupNoteModel?

    init() {
        let loaded = Settings.load()
        self.settings = loaded
        self.snapshot = StatusSnapshot.computeFast(settings: loaded)
        // A game left running from an earlier session of the app
        if Self.engineRunning {
            running = loaded["LAST_GAME"].flatMap(Game.init(rawValue:)) ?? .bo1
            watchUntilStopped()
        } else {
            Self.restoreDisplayMode { AppState.shared.refreshDisplay() }
            prewarmWine(delay: .seconds(1))
        }
        refreshStatusSnapshot()
    }

    /// Recomputes filesystem/Plutonium/folder validation off the main thread.
    func refreshStatusSnapshot() {
        let currentSettings = settings
        snapshotTask?.cancel()
        snapshotTask = Task.detached(priority: .userInitiated) {
            let computed = StatusSnapshot.computeFull(settings: currentSettings)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self.snapshot != computed {
                    self.snapshot = computed
                }
            }
        }
    }

    /// Quietly boots Wine's background server while the player browses Siliconium
    /// so clicking Play skips ~4 s of cold Wine startup (prewarms `prefix-steam`
    /// when the last-played game used `prefix-steam`, otherwise `prefix`).
    func prewarmWine(delay: Duration = .zero) {
        let lastGame = settings["LAST_GAME"] ?? ""
        let useSteamPrefix = (lastGame == "ownFiles" || lastGame == "cod4x" || lastGame == "iw7mod") && snapshot.steamPrefixReady
        guard engineInstalled, (useSteamPrefix ? snapshot.steamPrefixReady : prefixReady) else { return }
        Task.detached(priority: .utility) {
            if delay > .zero { try? await Task.sleep(for: delay) }
            let busy = await MainActor.run { AppState.shared.running != nil || AppState.shared.progress != nil }
            guard !busy, !Self.engineRunning else { return }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [Paths.kit.appendingPathComponent("launch.sh").path, "prewarm"] + (useSteamPrefix ? ["steam"] : [])
            p.environment = Paths.processEnvironment()
            p.standardInput = FileHandle.nullDevice
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    /// A game's display mode hold (kit/tools/displaymode) that was killed
    /// before it could put the desktop's mode back: put it back now, unless the
    /// player chose another mode since. A hold that is still on is left alone.
    nonisolated static func restoreDisplayMode(then done: (@MainActor @Sendable () -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            defer { if let done { Task { @MainActor in done() } } }
            let fm = FileManager.default
            let tool = Paths.kit.appendingPathComponent("tools/displaymode")
            guard fm.isExecutableFile(atPath: tool.path) else { return }
            let log = Paths.home.appendingPathComponent("logs/displaymode.log")
            try? fm.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: log.path) { fm.createFile(atPath: log.path, contents: nil) }
            let p = Process()
            p.executableURL = tool
            p.arguments = ["restore"]
            p.environment = Paths.processEnvironment()
            if let h = try? FileHandle(forWritingTo: log) {
                h.seekToEndOfFile()
                p.standardOutput = h
                p.standardError = h
            }
            try? p.run()
            p.waitUntilExit()
        }
    }

    @Published var display: DisplayInfo?
    @Published var showDisplayInfo = false
    var customHomeDisplayShown = false

    func refreshDisplay() {
        guard running == nil else { return }
        let s = settings
        let keep: String = {
            switch s["KEEP_HIDPI"] { case "0": return "0"; case "2": return "2"; default: return "1" }
        }()
        let holds = s["DISPLAY_MODE"] != "0"
        let maxfps = s["MAXFPS"]
        DispatchQueue.global(qos: .utility).async {
            let tool = Paths.kit.appendingPathComponent("tools/displaymode")
            guard FileManager.default.isExecutableFile(atPath: tool.path), !AppState.engineRunning else { return }
            let p = Process()
            p.executableURL = tool
            p.arguments = ["info"]
            p.environment = Paths.processEnvironment(merging: ["SIL_KEEP_UNSCALED": keep])
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0, let text = String(data: data, encoding: .utf8),
                  var info = DisplayInfo(parsing: text) else { return }
            info.holds = holds
            info.keepMode = keep
            info.maxfps = Int(maxfps ?? "")
            info.name = NSScreen.main?.localizedName ?? ""
            Task { @MainActor in
                let shared = AppState.shared
                guard shared.running == nil else { return }
                shared.display = info
                if Paths.isCustomHome {
                    if !shared.customHomeDisplayShown {
                        shared.customHomeDisplayShown = true
                        shared.showDisplayInfo = true
                    }
                } else {
                    let defaults = UserDefaults.standard
                    if defaults.string(forKey: "lastDisplaySeen") != info.signature {
                        defaults.set(info.signature, forKey: "lastDisplaySeen")
                        shared.showDisplayInfo = true
                    }
                }
            }
        }
    }

    // MARK: Cached Status Accessors (O(1), zero main-thread disk I/O)

    var engineInstalled: Bool { snapshot.engineInstalled }
    var engineInfo: [String: String] { snapshot.engineInfo }
    var prefixReady: Bool { snapshot.prefixReady }
    var plutoniumInstalled: Bool { snapshot.plutoniumInstalled }
    func plutoniumLinked(_ game: Game) -> Bool {
        guard let id = game.plutoniumID, let folder = folder(for: game) else { return false }
        return snapshot.plutoniumPaths[id] == folder.standardizedFileURL.path
    }
    var crossOverVersion: String? { snapshot.crossOverVersion }
    var rosettaInstalled: Bool { snapshot.rosettaInstalled }
    func folder(for game: Game) -> URL? { snapshot.folders[game] }

    /// Checks that the selected folder really is the requested game, not just
    /// any folder with a zone/ directory. Safe to run on any thread.
    nonisolated static func checkGameFolderProblem(_ game: Game, _ url: URL) -> String? {
        let fm = FileManager.default
        func has(_ path: String) -> Bool { fm.fileExists(atPath: url.appendingPathComponent(path).path) }
        if game == .iw7mod {
            guard has("iw7_ship.exe"), has("common.ff"), has("main") else {
                return "That is not a Windows Infinite Warfare folder: choose the one with iw7_ship.exe, common.ff and main/."
            }
            return nil
        }
        let zone = url.appendingPathComponent("zone")
        guard fm.fileExists(atPath: zone.path) else {
            return "That folder has no zone folder: choose the \(game.title) game folder."
        }
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
            return checkIW5Problem(url)
        case .iw4:
            guard has("main") else {
                return "Choose the Modern Warfare 2 folder with main/ and zone/."
            }
        case .boiii:
            guard has("BlackOps3.exe") else {
                return "That is not a Windows Black Ops III folder: BlackOps3.exe is missing."
            }
        case .cod4x:
            guard has("iw3mp.exe"), has("main"), has("zone") else {
                return "That is not a Windows Call of Duty 4 folder: choose the one with iw3mp.exe, main/ and zone/."
            }
        case .plutonium, .iw7mod, .ownFiles, .bo3, .steam, .battlenet, .alterware:
            return nil
        }
        return nil
    }

    func gameFolderProblem(_ game: Game, _ url: URL) -> String? {
        Self.checkGameFolderProblem(game, url)
    }

    nonisolated static func checkIW5Problem(_ f: URL) -> String? {
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

    var iw5Problem: String? { folderProblem(for: .iw5) }
    var iw5Usable: Bool { folderUsable(for: .iw5) }
    func folderUsable(for game: Game) -> Bool {
        snapshot.folders[game] != nil && snapshot.folderProblems[game] == nil
    }
    func folderProblem(for game: Game) -> String? {
        snapshot.folderProblems[game]
    }
    func folderDetail(for game: Game) -> String {
        snapshot.folderProblems[game] ?? expectedFolderDetail(game)
    }
    func expectedFolderDetail(_ game: Game) -> String {
        switch game {
        case .waw: "The World at War folder: zone/ with the Zombies maps (nazi_zombie_*.ff) and binkw32.dll."
        case .bo1: "The Black Ops folder: zone/ with the Zombies maps (zombie_*.ff) and binkw32.dll."
        case .bo2: "The Black Ops II folder: zone/ with the Black Ops II maps (mp_hijacked.ff or zm_*.ff) and binkw32.dll."
        case .iw5: "The 32-bit folder with main/, zone/ and mss32.dll inside."
        case .iw4: "Choose the Modern Warfare 2 folder (Windows game files, with main/ and zone/). Siliconium downloads the IW4X launcher, which keeps IW4X up to date. The first launch downloads IW4X's client and DLC maps (~3 GB) and may take a few minutes."
        case .boiii: "The Windows game's folder, with BlackOps3.exe and zone/ inside."
        case .cod4x: "Choose the Call of Duty 4 folder (Windows game files, with iw3mp.exe, main/ and zone/). Siliconium installs CoD4X, which then keeps itself up to date. Steam's own download is never changed: CoD4X plays from its own copy of it."
        case .iw7mod: "Choose the Infinite Warfare folder (Windows game files, with iw7_ship.exe, common.ff and main/). Siliconium installs IW7-Mod, which then keeps itself up to date. A Steam download is found by itself and never changed: IW7-Mod plays from its own copy of it."
        default: ""
        }
    }
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
    var steamInstalled: Bool { snapshot.steamAppInstalled }
    var bo3GameState: String { bo3["state"] ?? "missing" }
    var bo3Installed: Bool { !(bo3["installed"] ?? "").isEmpty }
    var bo3Version: String? { bo3Installed ? bo3["installed"] : nil }
    var boiiiInstalled: Bool { snapshot.boiiiInstalled }

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

    /// steam.sh status: steam, signedin, running
    @Published var steamCampaign: [String: String] = [:]
    /// A game the sidebar should switch to.
    @Published var goTo: Game?

    func refreshSteamCampaign() {
        Task.detached {
            var d: [String: String] = [:]
            for line in Self.capture("steam.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                if p.count == 2 { d[String(p[0])] = String(p[1]) }
            }
            let result = d
            await MainActor.run { self.steamCampaign = result }
        }
    }

    // MARK: Steam Library (steam.sh)

    struct SteamEntry {
        var state = "missing"
        var folder = ""
        var parts: [(name: String, state: String)] = []
        var dlc = 0
        var tools: [String: String] = [:]
    }
    @Published var steamLibrary: [String: SteamEntry] = [:]
    func refreshSteamLibrary() {
        refreshSteamCampaign()
        Task.detached {
            var d: [String: SteamEntry] = [:]
            func pairs(_ field: String) -> [(name: String, state: String)] {
                field.split(separator: ",").compactMap { part -> (name: String, state: String)? in
                    let kv = part.split(separator: ":", maxSplits: 1).map(String.init)
                    return kv.count == 2 ? (kv[0], kv[1]) : nil
                }
            }
            for line in Self.capture("steam.sh", ["library"]).split(separator: "\n") {
                let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard p.count >= 5 else { continue }
                var tools: [String: String] = [:]
                if p.count >= 6 { for t in pairs(p[5]) { tools[t.name] = t.state } }
                d[p[0]] = SteamEntry(state: p[1], folder: p[2], parts: pairs(p[3]), dlc: Int(p[4]) ?? 0, tools: tools)
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
    func playSteam(_ title: SteamTitle, _ mode: SteamTitle.Mode) {
        guard progress == nil, running == nil else { return }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.playSteam(title, mode) }
            }
            return
        }
        running = .steam
        let modId = steamMod(title)?.id
        let exe: String
        switch (title.id, mode.id, modId) {
        case ("iw", _, "iw7mod"): exe = "iw7-mod.exe"
        case ("cod4", "sp", "iw3spmod"): exe = "iw3sp_mod.exe"
        case ("bo2", "sp", "t6spmod"): exe = "T6SP-Mod.exe"
        default: exe = mode.exe
        }
        runScript("launch.sh", ["steam", "\(title.id)-\(mode.id)"], title: "Loading…",
                  gameWindow: .init(executable: exe, acceptsFullscreenWindows: title.id == "ghosts" || title.id == "aw" || title.id == "iw",
                                    acceptsRaisedWindows: title.id == "cod1" || title.id == "uo" || title.id == "cod2" || title.id == "wwii")) { [weak self] in
            self?.running = nil
        }
    }
    func downloadAllSteamGames() {
        runScript("steam.sh", ["download-all"], title: "Asking Steam to download every game") { [weak self] in
            self?.refreshSteamLibrary()
        }
    }
    func openSteamStore(_ id: String) { runScript("steam.sh", ["store", id], title: nil) }
    func downloadSteamTool(_ id: String) {
        runScript("steam.sh", ["download-tool", id], title: nil) { [weak self] in self?.refreshSteamLibrary() }
    }
    func openBO3ModTools() {
        guard progress == nil, running == nil else { return }
        running = .steam
        runScript("bo3-modtools.sh", ["start"], title: "Opening Mod Tools…",
                  gameWindow: .init(executable: "modlauncher.exe")) { [weak self] in
            self?.running = nil
        }
    }
    func showBO3ModToolsWork() {
        runScript("bo3-modtools.sh", ["work", "--reveal"], title: nil)
    }
    func openSteamWorkshop(_ id: String) { runScript("steam.sh", ["workshop", id], title: nil) }
    func openInLinkedGame(_ game: Game, _ steamFolder: String) {
        if let key = game.folderKey, let current = settings[key], !current.isEmpty,
           gameFolderProblem(game, URL(fileURLWithPath: current)) == nil {
            goTo = game.usesPlutonium ? .plutonium : game
            return
        }
        useSteamFolder(game, steamFolder)
    }
    /// Games downloaded in the Steam Library or chosen in Your Own Game Files
    /// that a client tab plays are linked automatically when that client has no
    /// usable folder of its own; an explicitly chosen folder stays.
    func detectSteamDownloads() {
        detectOwnFoldersForClients()
        detectSteamFolder("311210", for: .boiii)
        detectSteamFolder("10190", for: .iw4)
        detectSteamFolder("7940", for: .cod4x)
        detectSteamFolder("292730", for: .iw7mod)
    }
    /// Automatically links Your Own Game Files folders to IW4X (MW2), CoD4X
    /// (CoD 4), and Plutonium (BO2 & 32-bit MW3) when those clients do not
    /// already have a usable folder set.
    func detectOwnFoldersForClients() {
        let currentSettings = settings
        Task.detached(priority: .utility) {
            let pairs: [(String, Game)] = [("mw2", .iw4), ("cod4", .cod4x), ("bo2", .bo2), ("mw3", .iw5)]
            var updates: [(String, String)] = []
            for (ownId, client) in pairs {
                guard let title = OwnGameTitle.catalog.first(where: { $0.id == ownId }),
                      let key = client.folderKey else { continue }
                let ownPath = [title.folderKey, title.legacyFolderKey]
                    .compactMap { $0 }.compactMap { currentSettings[$0] }.first { !$0.isEmpty }
                guard let ownPath else { continue }
                let ownDir = URL(fileURLWithPath: ownPath)
                guard Self.checkOwnFolderProblem(title, ownDir) == nil else { continue }
                if let current = currentSettings[key], !current.isEmpty,
                   Self.checkGameFolderProblem(client, URL(fileURLWithPath: current)) == nil { continue }
                guard Self.checkGameFolderProblem(client, ownDir) == nil else { continue }
                updates.append((key, ownDir.path))
            }
            guard !updates.isEmpty else { return }
            let finalUpdates = updates
            await MainActor.run {
                var changed = false
                for (k, v) in finalUpdates {
                    if self.settings[k] == nil || self.settings[k]?.isEmpty == true {
                        self.settings[k] = v
                        changed = true
                    }
                }
                if changed {
                    self.settings.save()
                    self.refreshStatusSnapshot()
                    self.refreshToken += 1
                }
            }
        }
    }
    func detectSteamFolder(_ app: String, for game: Game) {
        guard let key = game.folderKey else { return }
        Task.detached {
            let state = Self.capture("steam.sh", ["state", app]).trimmingCharacters(in: .whitespacesAndNewlines)
            let dir = Self.capture("steam.sh", ["gamedir", app]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard state == "installed", !dir.isEmpty else { return }
            let url = URL(fileURLWithPath: dir)
            guard Self.checkGameFolderProblem(game, url) == nil else { return }
            await MainActor.run {
                if let current = self.settings[key], !current.isEmpty,
                   self.folderUsable(for: game) { return }
                self.settings[key] = dir
                self.settings.save()
                self.snapshot.folders[game] = url
                self.snapshot.folderProblems[game] = nil
                self.refreshStatusSnapshot()
                self.refreshToken += 1
            }
        }
    }
    func folderIsSteamLibrary(_ game: Game) -> Bool {
        folder(for: game)?.path.contains("/prefix-steam/drive_c/Program Files (x86)/Steam/steamapps/common/") == true
    }
    func useSteamFolder(_ game: Game, _ path: String) {
        guard let key = game.folderKey, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        if let problem = gameFolderProblem(game, url) { error = problem; return }
        settings[key] = url.path
        settings.save()
        snapshot.folders[game] = url
        snapshot.folderProblems[game] = nil
        refreshStatusSnapshot()
        refreshToken += 1
        goTo = game.usesPlutonium ? .plutonium : game
    }

    // MARK: Battle.net (battlenet.sh)

    @Published var battlenet: [String: String] = [:]
    @Published var battlenetLibrary: [String: (state: String, folder: String)] = [:]
    func refreshBattleNet() {
        Task.detached {
            var status: [String: String] = [:]
            for line in Self.capture("battlenet.sh", ["status"]).split(separator: "\n") {
                let p = line.split(separator: "=", maxSplits: 1)
                if p.count == 2 { status[String(p[0])] = String(p[1]) }
            }
            var library: [String: (state: String, folder: String)] = [:]
            for line in Self.capture("battlenet.sh", ["library"]).split(separator: "\n") {
                let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if p.count >= 3 { library[p[0]] = (p[1], p[2]) }
            }
            let s = status, l = library
            await MainActor.run { self.battlenet = s; self.battlenetLibrary = l }
        }
    }
    func setupBattleNet() {
        runScript("battlenet.sh", ["setup"], title: "Installing Battle.net") { [weak self] in self?.refreshBattleNet() }
    }
    func openBattleNet() { runScript("battlenet.sh", ["open"], title: nil) { [weak self] in self?.refreshBattleNet() } }
    func downloadBattleNetGame(_ id: String) {
        runScript("battlenet.sh", ["download", id], title: nil) { [weak self] in self?.refreshBattleNet() }
    }
    func playBattleNet(_ title: BattleNetTitle) {
        guard progress == nil, running == nil else { return }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.playBattleNet(title) }
            }
            return
        }
        running = .battlenet
        runScript("launch.sh", ["battlenet", title.id], title: "Loading…",
                  gameWindow: .init(executable: title.exe, acceptsFullscreenWindows: true)) { [weak self] in
            self?.running = nil
        }
    }

    // MARK: Your Own Game Files (Offline)

    nonisolated private static func resolveEntryCaseInsensitive(_ name: String, in url: URL, directory: Bool = false) -> URL? {
        let fm = FileManager.default
        let direct = url.appendingPathComponent(name)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: direct.path, isDirectory: &isDir),
           (directory ? isDir.boolValue : !isDir.boolValue) {
            return direct
        }
        let target = name.lowercased()
        guard let entries = try? fm.contentsOfDirectory(atPath: url.path) else { return nil }
        for entry in entries where entry.lowercased() == target {
            let candidate = url.appendingPathComponent(entry)
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir),
               (directory ? isDir.boolValue : !isDir.boolValue) {
                return candidate
            }
        }
        return nil
    }

    nonisolated static func checkOwnFolderProblem(_ title: OwnGameTitle, _ url: URL) -> String? {
        for req in title.requiredDirs {
            guard resolveEntryCaseInsensitive(req, in: url, directory: true) != nil else {
                let reqList = title.requiredDirs.map { "\($0)/" }.joined(separator: " and ")
                return "That is not a Windows \(title.title) folder: \(req)/ is missing (choose the folder with \(reqList))."
            }
        }
        guard resolveEntryCaseInsensitive(title.mode.exe, in: url) != nil else {
            return "That is not a Windows \(title.title) campaign folder: \(title.mode.exe) is missing."
        }
        return nil
    }

    func ownFolderProblem(_ title: OwnGameTitle, _ url: URL) -> String? {
        Self.checkOwnFolderProblem(title, url)
    }

    func ownFolder(for title: OwnGameTitle) -> URL? {
        snapshot.ownFolders[title.id]
    }

    func ownApplicableMods(_ title: OwnGameTitle) -> [SteamTitle.Mod] {
        title.mods
    }

    func ownMod(_ title: OwnGameTitle) -> SteamTitle.Mod? {
        let mods = ownApplicableMods(title)
        let key = "OWN_MOD_\(title.id.uppercased())"
        let raw = settings[key]
        if raw == "none" { return nil }
        let chosenId = raw ?? title.defaultModId
        guard let chosenId else { return nil }
        return mods.first { $0.id == chosenId }
    }

    func setOwnMod(_ title: OwnGameTitle, _ mod: SteamTitle.Mod?) {
        let key = "OWN_MOD_\(title.id.uppercased())"
        settings[key] = mod?.id ?? (title.defaultModId != nil ? "none" : nil)
        settings.save()
        refreshToken += 1
    }

    func chooseOwnFolder(for title: OwnGameTitle) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        let reqList = title.requiredDirs.map { "\($0)/" }.joined(separator: ", ")
        panel.message = "Choose your \(title.title) Windows folder with \(reqList) and \(title.mode.exe)."
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.directoryURL = ownFolder(for: title) ?? downloads
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let problem = ownFolderProblem(title, url) {
            error = problem
            return
        }
        settings[title.folderKey] = url.path
        settings.save()
        snapshot.ownFolders[title.id] = url
        refreshStatusSnapshot()
        refreshToken += 1
        detectOwnFoldersForClients()
    }

    func forgetOwnFolder(for title: OwnGameTitle) {
        settings[title.folderKey] = nil
        if let legacy = title.legacyFolderKey { settings[legacy] = nil }
        settings.save()
        snapshot.ownFolders[title.id] = nil
        refreshStatusSnapshot()
        refreshToken += 1
    }

    func playOwn(_ title: OwnGameTitle) {
        guard progress == nil, running == nil else { return }
        if title.id != "ghosts" && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.playOwn(title) }
            }
            return
        }
        running = .ownFiles
        settings["LAST_GAME"] = Game.ownFiles.rawValue
        settings.save()
        let modId = ownMod(title)?.id
        let exe: String
        switch modId {
        case "iw3spmod": exe = "iw3sp_mod.exe"
        case "t6spmod": exe = "T6SP-Mod.exe"
        default: exe = title.mode.exe
        }
        runScript("launch.sh", ["own", "\(title.id)-\(title.mode.id)"], title: "Loading…",
                  gameWindow: .init(executable: exe, acceptsFullscreenWindows: title.id == "ghosts")) { [weak self] in
            self?.running = nil
            self?.prewarmWine(delay: .seconds(2))
        }
    }

    func createEmptyPrefix() { runScript("setup-prefix.sh", ["init"], title: "Creating the Wine prefix") }

    func isReady(_ game: Game) -> Bool {
        switch game {
        case .plutonium:
            engineInstalled && prefixReady && plutoniumInstalled
                && Game.plutoniumGames.contains { folderUsable(for: $0) }
        case .waw, .bo1, .bo2, .iw5:
            engineInstalled && prefixReady && folderUsable(for: game) && plutoniumInstalled
        case .iw4: engineInstalled && prefixReady && folderUsable(for: .iw4)
        case .boiii: engineInstalled && prefixReady && folderUsable(for: .boiii)
        case .cod4x: engineInstalled && folderUsable(for: .cod4x)
        case .iw7mod: engineInstalled && folderUsable(for: .iw7mod)
        case .alterware: false
        case .bo3: bo3Installed
        case .steam: engineInstalled && steamCampaign["steam"] == "installed"
        case .battlenet: engineInstalled && battlenet["battlenet"] == "installed"
        case .ownFiles: engineInstalled && !snapshot.ownFolders.isEmpty
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
        case .boiii: panel.message = "Choose the Windows Black Ops III folder: BlackOps3.exe and zone/."
        case .cod4x: panel.message = "Choose the Call of Duty 4 folder with iw3mp.exe, main/ and zone/ (Siliconium installs CoD4X)."
        case .iw7mod: panel.message = "Choose the Infinite Warfare folder with iw7_ship.exe, common.ff and main/ (Siliconium installs IW7-Mod; a Steam download is never changed)."
        default: panel.message = "Choose the \(game.title) game folder."
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let problem = gameFolderProblem(game, url) {
            error = problem
            return
        }
        settings[key] = url.path
        settings.save()
        snapshot.folders[game] = url
        snapshot.folderProblems[game] = nil
        refreshStatusSnapshot()
        refreshToken += 1
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

    /// Installs Plutonium and signs in (works even before any game folder is chosen).
    func setupPlutonium(_ game: Game? = nil) {
        let chosenGame = game ?? Game.plutoniumGames.first { folderUsable(for: $0) }
        if let g = chosenGame, let id = g.plutoniumID, let folder = folder(for: g), folderUsable(for: g) {
            let needsSignIn = !plutoniumInstalled
            runScript("setup-prefix.sh", ["setup", id, folder.path, folder.path],
                      title: needsSignIn ? "Setting up Plutonium" : "Linking the game folder", stepAside: needsSignIn)
        } else {
            runScript("setup-prefix.sh", ["plutonium"], title: "Setting up Plutonium", stepAside: true)
        }
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

    func updateIW4() { runScript("iw4-update.sh", [], title: "Updating IW4X") }

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
                      "cod4x": "Removing the CoD4X setup", "iw7mod": "Removing the IW7-Mod setup",
                      "all": "Removing the engine and Plutonium", "bo3": "Removing BO3 Mac Client"]
        running = nil
        runScript("uninstall.sh", [what], title: titles[what] ?? "Removing") { [weak self] in
            guard let self else { return }
            self.settings = Settings.load()
            self.refreshStatusSnapshot()
            self.refreshBO3()
            self.refreshSteamCampaign()
        }
    }

    func steamMod(_ title: SteamTitle) -> SteamTitle.Mod? {
        let id = settings["STEAM_MOD_\(title.id.uppercased())"]
        return title.mods.first { $0.id == id && !$0.opensLinked }
    }
    func setSteamMod(_ title: SteamTitle, _ mod: SteamTitle.Mod?) {
        settings["STEAM_MOD_\(title.id.uppercased())"] = mod?.id
        settings.save()
    }

    func bnetMod(_ title: BattleNetTitle) -> SteamTitle.Mod? {
        let id = settings["STEAM_MOD_\(title.id.uppercased())"]
        return title.mods.first { $0.id == id }
    }
    func setBnetMod(_ title: BattleNetTitle, _ mod: SteamTitle.Mod?) {
        settings["STEAM_MOD_\(title.id.uppercased())"] = mod?.id
        settings.save()
    }

    var bo3SpoofRanked: Bool { settings["BO3_SPOOF_RANKED"] == "1" }
    func setBO3SpoofRanked(_ on: Bool) {
        settings["BO3_SPOOF_RANKED"] = on ? "1" : "0"
        settings.save()
        runScript("bo3.sh", ["spoof", on ? "on" : "off"], title: nil) { [weak self] in self?.refreshBO3() }
    }

    func refreshBO3() {
        detectSteamDownloads()
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
    func openPlutonium(_ game: Game? = nil) {
        let target = game ?? Game.plutoniumGames.first { folderUsable(for: $0) }
        let arg = target?.rawValue ?? "plutonium"
        runScript("launch.sh", [arg, "online"], title: nil, stepAside: true,
                  noteHint: "Manage your Plutonium session here. Siliconium brings its window back when you close Plutonium.")
    }

    func openDiscord() {
        guard let url = URL(string: "https://discord.gg/4hpEXFqvNR") else { return }
        NSWorkspace.shared.open(url)
    }

    func askMicrophoneOnce() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    func play(_ game: Game, mode: PlayMode, lan: Bool = false) {
        guard progress == nil, running == nil else { return }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
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
            self?.watchUntilStopped()
        }
    }

    func stop() {
        gameWindowTask?.cancel()
        if gameWindowTask != nil { progress = nil }
        task?.terminate()
        runScript("launch.sh", ["stop"], title: nil)
        running = nil
    }

    nonisolated static var engineRunning: Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-if", #"t4mp\.exe|t4sp\.exe|t5mp\.exe|t5sp\.exe|t6mp\.exe|t6zm\.exe|t6sp\.exe|t6sp-mod\.exe|iw3sp\.exe|iw3sp_mod\.exe|iw3mp\.exe|iw4sp\.exe|iw4mp\.exe|iw5mp\.exe|iw5sp\.exe|boiii(-[[:alnum:]._-]+)?\.exe|blackops3\.exe|blackops4\.exe|iw4x(-launcher)?\.exe|iw6sp64_ship\.exe([[:space:]]|$)"#]
        p.standardOutput = Pipe()
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func watchUntilStopped() {
        Task.detached {
            while Self.engineRunning { try? await Task.sleep(for: .seconds(2)) }
            await MainActor.run {
                self.running = nil
                self.prewarmWine(delay: .seconds(2))
            }
        }
    }

    // MARK: App updates (GitHub releases of the repository)

    nonisolated static let repository = "sirdankdabs/siliconium"
    var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func showWhatsNewAfterUpdate() {
        if Paths.isCustomHome { return }
        let key = "lastRunVersion", defaults = UserDefaults.standard
        let last = defaults.string(forKey: key)
        defaults.set(appVersion, forKey: key)
        let updated = last.map { Self.isNewer(appVersion, than: $0) }
            ?? FileManager.default.fileExists(atPath: Paths.settings.path)
        if updated, let notes = Self.releaseNotes(for: appVersion) { whatsNew = notes }
    }

    nonisolated static func releaseNotes(for version: String) -> String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var lines: [String] = [], inside = false
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                if inside { break }
                let heading = String(line.dropFirst(3))
                inside = heading == version || heading.hasPrefix(version + " ")
                continue
            }
            if inside {
                if line.hasPrefix("**Details**") { break }
                lines.append(line)
            }
        }
        let notes = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? nil : notes
    }
    var kitVersion: String? { snapshot.kitVersion }

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

    func refreshInstalledFiles() {
        guard running == nil, progress == nil else { return }
        if engineInstalled, let kit = kitVersion, engineInfo["kit"] != kit {
            runScript("install-engine.sh", [], title: "Updating the game files") { [weak self] in self?.refreshBO3Files() }
        } else {
            refreshBO3Files()
        }
    }

    func tidyCopies() {
        Task.detached(priority: .utility) { _ = Self.capture("tools/steam-copy.sh", ["tidy"]) }
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
        p.environment = Paths.processEnvironment()
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private func showSetupNote(hint: String? = nil) {
        dismissSetupNote()
        let model = SetupNoteModel()
        if let hint { model.hint = hint }
        setupNoteModel = model
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 112),
                            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: SetupNoteView(model: model) { [weak self] in
            self?.showMainWindow()
        })
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - 360 - 20, y: f.maxY - 112 - 20))
        }
        panel.orderFrontRegardless()
        setupNote = panel
    }

    private func dismissSetupNote() {
        setupNote?.orderOut(nil)
        setupNote = nil
        setupNoteModel = nil
    }

    private func mainWindow() -> NSWindow? { NSApp.windows.first { !($0 is NSPanel) } }

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
                    if target.acceptsRaisedWindows, let game = NSRunningApplication(processIdentifier: pid) {
                        NSApp.yieldActivation(to: game)
                        game.activate(from: NSRunningApplication.current, options: [])
                    }
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

    /// Run a kit script, streaming its output to LogStore (no main-window
    /// redraws per log line); "==> " lines update progress, "ERROR: " lines alert.
    func runScript(_ script: String, _ args: [String], title: String?, env: [String: String] = [:],
                   stepAside: Bool = false, noteHint: String? = nil,
                   gameWindow: GameWindowTarget? = nil, done: (() -> Void)? = nil) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [Paths.kit.appendingPathComponent(script).path] + args
        p.environment = Paths.processEnvironment(merging: env)
        let launchesGame = gameWindow != nil || script == "launch.sh"
        p.qualityOfService = launchesGame ? .userInteractive : .userInitiated
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        if let title { progress = title; logStore.append("— \(title)") }
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            if data.isEmpty {
                if gameWindow != nil { h.readabilityHandler = nil }
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            let batch = text.split(separator: "\n").map(String.init)
            guard !batch.isEmpty else { return }
            var lastStep: String? = nil
            var lastErr: String? = nil
            for l in batch {
                if l.hasPrefix("==> ") { lastStep = String(l.dropFirst(4)) }
                if l.hasPrefix("ERROR: ") { lastErr = String(l.dropFirst(7)) }
            }
            Task { @MainActor in
                guard let self else { return }
                self.logStore.append(contentsOf: batch)
                if let step = lastStep {
                    if self.progress != step { self.progress = step }
                    if self.setupNoteModel?.step != step { self.setupNoteModel?.step = step }
                }
                if let err = lastErr { self.error = err }
            }
        }
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
                self?.refreshStatusSnapshot()
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
