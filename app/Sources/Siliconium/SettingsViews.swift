import AppKit
import SwiftUI

// MARK: - Settings, Info, Log & Setup Note

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    let game: Game
    var close: () -> Void
    @State private var fps = "monitor"
    @State private var patches: [String: Bool] = [:]
    @State private var deadzone = 0.08
    @State private var name = "Player"
    @State private var mods = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(game.title) settings").font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close without saving")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
            form
        }
        .frame(width: 540, height: 560)
        .onAppear(perform: load)
    }

    private var form: some View {
        Form {
            if let folder = state.folder(for: game) {
                Section("Game folder") {
                    HStack {
                        Text(folder.path).font(.system(size: 11)).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        Spacer()
                        if game.usesPlutonium || game == .iw4 || game == .cod4x || game == .iw7mod || game == .boiii {
                            Button("Change…") {
                                state.chooseFolder(for: game)
                                close()
                            }
                            .disabled(state.running != nil || state.progress != nil)
                        }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    }
                }
            }
            Section("Play") {
                if !game.usesPlutonium && game != .cod4x && game != .iw7mod && game != .ownFiles {
                    TextField("Player name (offline)", text: $name)
                }
                Picker("Frame-rate cap", selection: $fps) {
                    Text("Monitor's refresh rate").tag("monitor")
                    Text("240").tag("240"); Text("160").tag("160"); Text("120").tag("120")
                    Text("80").tag("80"); Text("60").tag("60"); Text("No cap").tag("0")
                }
            }
            if game == .iw5 {
                Section("Display") {
                    Text("Resolution and anti-aliasing are in the game's Video options. Siliconium starts Modern Warfare 3 at your display's size with 2x anti-aliasing for smooth frame rates; raise them there if you want more detail.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(Patch.for(game)) { patch in
                    HStack(spacing: 6) {
                        Toggle(patch.title, isOn: Binding(get: { patches[patch.key] ?? true },
                                                         set: { patches[patch.key] = $0 }))
                        InfoButton(text: patch.info)
                    }
                }
            } header: {
                HStack {
                    Text("Patches")
                    Spacer()
                    Button("Turn all on") { for p in Patch.for(game) { patches[p.key] = true } }
                        .buttonStyle(.link).font(.system(size: 11))
                }
            } footer: {
                Text("All patches are on by default. Changes apply the next time the game starts.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if game == .waw || game == .bo1 || game == .iw4 {
                Section("Shaders") {
                    HStack {
                        Text("Loads every map once, offline, so its shaders are ready: the first time you play a map, the map and the weapons appear complete. About 1–2 minutes per map; the game opens and closes by itself.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Prepare all maps") {
                            save()
                            close()
                            state.prepareShaders(game)
                        }
                        .disabled(state.running != nil || state.progress != nil || state.folder(for: game) == nil)
                    }
                }
            }
            Section("Controller") {
                if game == .iw5 {
                    Text("Plutonium supports Xbox controllers. Modern Warfare 3 keeps its stick settings in the game (Options → Controls → Gamepad).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if game == .iw4 {
                    Text("Modern Warfare 2 keeps its controller settings in the game (Options → Controls).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if game == .iw7mod {
                    Text("Infinite Warfare has its own controller support: it asks to switch to the gamepad when one is connected, and keeps its controller settings in the game (Options → Controls).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if game == .cod4x {
                    Text("Call of Duty 4 has no controller support on PC: Siliconium plays your controller as keyboard and mouse, as for Steam's Call of Duty 4 (the keyboard keeps your own bindings).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if game == .ownFiles {
                    Text("Call of Duty 4, Modern Warfare 2 and Modern Warfare 3 use Siliconium's controller mapping automatically (or native controller support with IW3SP-MOD / IW-Pad). Black Ops II and Ghosts use native controller support with console aim.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    HStack {
                        Text("Stick deadzone (Black Ops II)")
                        Slider(value: $deadzone, in: 0.02...0.25, step: 0.01)
                        Text(String(format: "%.2f", deadzone)).monospacedDigit().frame(width: 36)
                    }
                } else {
                    HStack {
                        Text("Stick deadzone")
                        Slider(value: $deadzone, in: 0.02...0.25, step: 0.01)
                        Text(String(format: "%.2f", deadzone)).monospacedDigit().frame(width: 36)
                    }
                }
                Button("Bluetooth controller help…") { state.checkBluetoothController(force: true) }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
            if game.usesPlutonium {
                Section("LAN") {
                    TextField("LAN player name", text: $name)
                    if game == .bo2 {
                        TextField("Extra arguments, e.g. +set fs_game mods/dlc5", text: $mods)
                    }
                    Menu("Play on LAN") {
                        ForEach(game.modes) { mode in
                            Button(mode.title) {
                                save()
                                close()
                                state.play(game, mode: mode, lan: true)
                            }
                        }
                    }
                    .disabled(state.running != nil || state.progress != nil)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: close)
                Button("Save") { save(); close() }.keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func load() {
        let s = state.settings
        fps = s["MAXFPS"] ?? "monitor"
        for p in Patch.for(game) { patches[p.key] = s[p.key] != p.offValue }
        deadzone = Double(s["STICK_DEADZONE"] ?? "") ?? 0.08
        name = s["PLAYER_NAME"] ?? "Player"
        mods = s["BO2_MODS"] ?? ""
    }

    private func save() {
        state.settings["MAXFPS"] = fps == "monitor" ? nil : fps
        for p in Patch.for(game) { state.settings[p.key] = (patches[p.key] ?? true) ? nil : p.offValue }
        state.settings["STICK_DEADZONE"] = String(format: "%.2f", deadzone)
        state.settings["PLAYER_NAME"] = name
        state.settings["BO2_MODS"] = mods
        state.settings.save()
        state.refreshStatusSnapshot()
    }
}

struct InfoButton: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(text)
        .popover(isPresented: $shown, arrowEdge: .trailing) {
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 280, alignment: .leading)
                .padding(12)
        }
    }
}

struct LogView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var logStore: LogStore
    @Environment(\.dismiss) private var dismiss

    /// Privacy-safe system summary so bug reports immediately show OS, chip,
    /// RAM, Rosetta, engine/x87 versions, prefixes, and free disk space.
    private var diagnosticHeader: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let chip = Paths.cpuBrand()
        let ramGB = Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0).rounded())
        let rosetta = state.rosettaInstalled ? "yes" : "no"
        let info = state.engineInfo
        let eng = state.engineInstalled ? (info["base"] ?? info["crossover"].map { "CrossOver \($0)" } ?? "installed") : "not installed"
        let kitV = info["kit"] ?? state.kitVersion ?? "?"
        let x87 = info["x87sidecar"] ?? "none"
        let disp: String = {
            guard let d = state.display else { return "unknown" }
            let mode = d.plan == "kept" ? (d.keepMode == "1" ? "Smart HiDPI" : "HiDPI") : d.plan
            return "\(d.gameWidth)x\(d.gameHeight) @ \(d.gameHz) Hz (\(mode))"
        }()
        let fm = FileManager.default
        let pMain = state.prefixReady ? "ready" : "none"
        let pSteam = fm.fileExists(atPath: Paths.steamPrefix.appendingPathComponent("system.reg").path) ? "ready" : "none"
        let pBnet = fm.fileExists(atPath: Paths.home.appendingPathComponent("prefix-battlenet/system.reg").path) ? "ready" : "none"
        let disk = Paths.freeDiskGB().map { "\($0) GB free" } ?? "unknown"
        var line3 = "Prefixes: main=\(pMain), steam=\(pSteam), battlenet=\(pBnet) · Disk: \(disk)"
        if Paths.usesIsolatedHome { line3 += " · Storage: isolated (special char in home path)" }
        return """
        Siliconium \(state.appVersion) · macOS \(os) · \(chip) · \(ramGB) GB RAM · Rosetta 2: \(rosetta)
        Engine: \(eng) (kit \(kitV)) · x87sidecar: \(x87) · Display: \(disp)
        \(line3)
        """
    }

    /// Most recent setup/error log modified in the last 10 minutes if an error
    /// message did not explicitly name a `logs/*.log` file (e.g. Steam setup).
    private var recentErrorLogName: String? {
        guard state.errorLog == nil, state.error != nil else { return nil }
        let logsDir = Paths.home.appendingPathComponent("logs")
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: logsDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { return nil }
        let cutoff = Date().addingTimeInterval(-600)
        let newest = urls
            .filter { ($0.pathExtension == "log" || $0.pathExtension == "txt") && $0.lastPathComponent != "displaymode.log" }
            .compactMap { url -> (URL, Date)? in
                guard let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      d >= cutoff else { return nil }
                return (url, d)
            }
            .max { $0.1 < $1.1 }
        return newest.map { "logs/\($0.0.lastPathComponent)" }
    }

    /// System summary, the app's own output, and the end of the relevant log
    /// file — automatically scrubbed of the user's home directory and username.
    private var text: String {
        var parts: [String] = [diagnosticHeader]
        if !logStore.lines.isEmpty { parts.append(logStore.lines.joined(separator: "\n")) }
        if let name = state.errorLog ?? recentErrorLogName {
            let url = Paths.home.appendingPathComponent(name)
            if let data = try? Data(contentsOf: url) {
                let t = String(decoding: data, as: UTF8.self)
                let lines = t.split(separator: "\n", omittingEmptySubsequences: false).suffix(300)
                parts.append("— \(name)\n" + (t.isEmpty ? "(empty)" : lines.joined(separator: "\n")))
            } else {
                parts.append("— \(name)\n(not found)")
            }
        }
        return Paths.redact(parts.joined(separator: "\n\n"))
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("end")
                }
                .onAppear { proxy.scrollTo("end", anchor: .bottom) }
            }
            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("Open Logs Folder") {
                    let logs = Paths.home.appendingPathComponent("logs")
                    try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(logs)
                }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 700, height: 440)
    }
}

// MARK: - Setup note

struct SetupNoteView: View {
    @ObservedObject var model: SetupNoteModel
    var showApp: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProgressView().controlSize(.small).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Plutonium").font(.system(size: 12.5, weight: .semibold))
                Text(model.step)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.hint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Show Siliconium", action: showApp)
                    .buttonStyle(.link)
                    .font(.system(size: 10.5))
            }
        }
        .padding(14)
        .frame(width: 360, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
