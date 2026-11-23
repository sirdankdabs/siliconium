import AppKit
import SwiftUI

@main
struct SiliconiumApp: App {
    init() {
        // The window is designed dark (white labels on a dark sidebar and a
        // dark blue detail gradient). In light mode the sidebar's vibrancy
        // material became light while the labels stayed white, which made
        // them almost invisible. Pin the whole app to the dark appearance:
        // it is the look the screenshots and the design use, and it keeps
        // every window, sheet, alert and the sidebar material consistent.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        // one window, no window tabs (and no "Show Tab Bar" in the View menu)
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// Black Ops III for Mac (Steam's Mac version with BO3 Mac Client) is
    /// optional: the Windows game through Ezz is the recommended way to play.
    @AppStorage("showBO3ForMac") private var showBO3ForMac = false

    // The app itself doesn't observe the state: if it did, every change (a log
    // line, a status refresh) would rebuild the whole scene and the menu bar,
    // which made the menus stutter. The window's view observes it instead.
    var body: some Scene {
        WindowGroup("Siliconium") {
            RootView()
                .frame(minWidth: 1080, minHeight: 640)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { AppState.shared.checkForAppUpdate(manual: true) }
            }
            CommandGroup(before: .toolbar) {
                Toggle("Show Black Ops III for Mac (Steam)", isOn: $showBO3ForMac)
                Divider()
            }
        }
    }
}

struct RootView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        ContentView()
            .environmentObject(state)
            // `NSApplication.appearance` covers alerts, menus and panels, but
            // a SwiftUI window keeps the system appearance for its AppKit
            // chrome: in Light Mode the sidebar's vibrancy material turned
            // white under the white labels. Set the window itself dark too.
            .background(DarkWindowAppearance())
            .sheet(isPresented: Binding(get: { state.whatsNew != nil }, set: { if !$0 { state.whatsNew = nil } })) {
                WhatsNewView(version: state.appVersion, notes: state.whatsNew ?? "") { state.whatsNew = nil }
            }
            .onAppear {
                state.showWhatsNewAfterUpdate()
                state.warnOldMacOS()
                state.checkUpdates()
                state.refreshInstalledFiles()
                state.tidyCopies()
                state.checkForAppUpdate(manual: false)
                state.checkBluetoothController()
                state.confirmBluetoothPermissionAfterRelaunch()
                // The window is created around the first layout pass: set its
                // appearance once it exists (see DarkWindowAppearance).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                    for window in NSApp.windows where !(window is NSPanel) {
                        window.appearance = NSAppearance(named: .darkAqua)
                    }
                }
            }
            // A controller connected while the app is open: check again (the
            // prompt is shown once per run) without polling the HID stack.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                state.checkBluetoothController()
            }
            .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
                // Not while a game is playing: nothing to ask then, and the
                // HID enumeration would only compete with the game.
                guard state.running == nil else { return }
                state.checkBluetoothController()
            }
    }
}

/// A zero-size AppKit view that gives the hosting window the dark appearance.
/// Doing it from the window itself (not only from the SwiftUI environment)
/// is what changes the sidebar's `NSVisualEffectView` material.
private struct DarkWindowAppearance: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { apply(to: view) }

    private func apply(to view: NSView) {
        DispatchQueue.main.async {
            view.window?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    // `-openSettings bo1` on the command line opens that game's settings;
    // otherwise the app opens on the row the player had selected last time
    @State private var selection: Game = (UserDefaults.standard.string(forKey: "openSettings")
        ?? UserDefaults.standard.string(forKey: "lastSelectedGame"))
        .flatMap(Game.init(rawValue:))
        .flatMap { game in GameTab.allCases.contains { $0.games.contains(game) } ? game : nil } ?? .waw
    @State private var showLog = false
    @AppStorage("showBO3ForMac") private var showBO3ForMac = false

    var body: some View {
        NavigationSplitView {
            // every game at once, grouped by what runs it
            List(selection: $selection) {
                ForEach(GameTab.allCases) { section in
                    Section {
                        ForEach(section.games.filter { $0 != .bo3 || showBO3ForMac }) { game in
                            GameRow(game: game).tag(game)
                        }
                    } header: {
                        Text(section.title.uppercased())
                            .font(.system(size: 10, weight: .semibold)).kerning(0.8)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .listStyle(.sidebar)
            .environment(\.colorScheme, .dark)
            .safeAreaInset(edge: .top) { BrandHeader() }
            .onChange(of: showBO3ForMac) {
                if !showBO3ForMac && selection == .bo3 { selection = .boiii }
            }
            .onAppear {
                if !showBO3ForMac && selection == .bo3 { selection = .boiii }
                // the restored row gets the same refresh as when it is clicked
                if selection == .bo2c { state.refreshCampaign() }
                if selection == .bo2s { state.refreshSteamCampaign() }
                // the sidebar's Battle.net row says Ready / Set up from the start
                state.refreshBattleNet()
            }
            .onChange(of: state.goTo) {
                guard let g = state.goTo else { return }
                selection = g; state.goTo = nil
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 250, max: 320)
            .safeAreaInset(edge: .bottom) { EngineFooter(showLog: $showLog) }
        } detail: {
            GameDetail(game: selection)
                .id("\(selection.rawValue)-\(state.refreshToken)")
        }
        .sheet(isPresented: $showLog) { LogView() }
        .overlay {
            if let g = state.settingsGame {
                ZStack {
                    // clicking outside the panel closes it without saving
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { state.settingsGame = nil }
                    SettingsView(game: g) { state.settingsGame = nil }
                        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 30)
                        .onExitCommand { state.settingsGame = nil }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.settingsGame)
        .onChange(of: selection) {
            UserDefaults.standard.set(selection.rawValue, forKey: "lastSelectedGame")
            state.settingsGame = nil
            if selection == .bo2c { state.refreshCampaign() }
            if selection == .bo2s { state.refreshSteamCampaign() }
            if selection == .steam { state.refreshSteamLibrary() }
            if selection == .battlenet { state.refreshBattleNet() }
        }
        .alert("Something went wrong", isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) {
            Button("OK") { state.error = nil }
            // the alert has to finish closing before the sheet can open
            Button("Show log") {
                state.error = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showLog = true }
            }
        } message: {
            Text(state.error ?? "")
        }
    }
}

/// A game as a periodic-table tile, like the app's own "Si 14": the engine
/// code large, the release year as its atomic number, the client underneath.
struct ElementTile: View {
    let game: Game
    var size: CGFloat

    var body: some View {
        let radius = size * 0.22
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [game.colors[0].opacity(0.92), game.colors[1]],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            shape.strokeBorder(.white.opacity(0.2), lineWidth: max(1, size / 90))
            Text(game.badge)
                .font(.system(size: size * (game.badge.count > 2 ? 0.33 : 0.40), weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: size / 60, y: size / 80)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.08)
            if size >= 64 {
                VStack(spacing: 0) {
                    HStack {
                        Text(game.year).font(.system(size: size * 0.11, weight: .medium).monospacedDigit())
                        Spacer()
                    }
                    Spacer()
                    Text(game.tileClient.uppercased())
                        .font(.system(size: size * 0.085, weight: .semibold)).kerning(size * 0.01)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .foregroundStyle(.white.opacity(0.72))
                .padding(size * 0.11)
            }
        }
        .frame(width: size, height: size)
    }
}

/// The sidebar's top: the app's mark and name.
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.17, blue: 0.20), Color(red: 0.06, green: 0.06, blue: 0.08)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.14)))
                Text("Si")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 0.62, green: 0.86, blue: 1), Color(red: 0.76, green: 0.70, blue: 1)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("Siliconium").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("Call of Duty on Apple silicon")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 10)
    }
}

struct GameRow: View {
    @EnvironmentObject var state: AppState
    let game: Game

    var body: some View {
        HStack(spacing: 11) {
            ElementTile(game: game, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(game.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(statusText).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var statusText: String {
        if game == .alterware { return "Not available" }   // (an explanation page)
        if state.running == game { return "Playing" }
        return state.isReady(game) ? "Ready" : "Set up"
    }
    private var statusColor: Color {
        if state.running == game { return Color(red: 0.35, green: 0.75, blue: 1) }
        return state.isReady(game) ? Color(red: 0.30, green: 0.82, blue: 0.48) : Color.white.opacity(0.35)
    }
}

/// The AlterWare section (owner 2026-11-21): AlterWare's clients cannot be played
/// on Apple silicon, so Siliconium has none of them, only this explanation.
/// Evidence: session 23 (Siliconium's notes). Ghosts (iw6-mod) starts but never
/// finishes the online sign-in it emulates: Arxan sets x86 hardware breakpoints
/// (Dr0-Dr3, Dr7 0x155) on the game's Demonware code, and under Rosetta 2 Wine
/// accepts them but they never fire. Advanced Warfare (s1-mod): discontinued
/// (archived 2026-08-28), refuses Steam's August 2026 build.
struct AlterWareInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Why AlterWare's Ghosts and Advanced Warfare are not in Siliconium")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            note("info.circle", "AlterWare (alterware.dev) made community clients for Call of Duty: Ghosts (iw6-mod) and Advanced Warfare (s1-mod), with their own dedicated servers. Neither can be played on a Mac with Apple silicon, so Siliconium does not include them.")
            note("exclamationmark.triangle.fill", "Ghosts: the client starts and its menus work, but Online Play never gets past \"Connecting to Online Services\", and the client lets you join a server only after that sign-in. The game's copy protection (Arxan) relies on the processor's hardware breakpoints around its online code. Rosetta 2, which runs Windows games on Apple silicon, does not provide them: they are accepted but never trigger, so the sign-in never completes. Private matches and Extinction most likely need the same sign-in.", orange: true)
            note("exclamationmark.triangle.fill", "Advanced Warfare: AlterWare discontinued its client (s1-mod) in 2026. It refuses Steam's current (2026) version of the game, and AlterWare offers no older one. Advanced Warfare uses the same kind of protection: Steam's own Advanced Warfare Multiplayer also stops at \"Connecting to Online Services\" on a Mac.", orange: true)
            note("checkmark.seal.fill", "Both campaigns play from the Steam Library, and Ghosts' campaign from the Offline tab. AlterWare stopped development in September 2026.")
        }
        .frame(maxWidth: 600, alignment: .leading)
    }

    private func note(_ symbol: String, _ text: String, orange: Bool = false) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12))
            .foregroundStyle(orange ? Color.orange : Color.white.opacity(0.85))
        // (no .fixedSize(horizontal: false, vertical: true) here: with it, opening
        // this page left the whole window blank, sidebar included; the views
        // existed but nothing was drawn. The text wraps without it)
    }
}

// MARK: - Detail

struct GameDetail: View {
    @EnvironmentObject var state: AppState
    let game: Game

    var body: some View {
        ZStack(alignment: .topLeading) {
            // graphite, lit by the game's colour from the top corner
            Color(red: 0.055, green: 0.06, blue: 0.075).ignoresSafeArea()
            RadialGradient(colors: [game.colors[0].opacity(0.42), game.colors[1].opacity(0.18), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 760)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 26) {
                Spacer().frame(height: 14)
                HStack(alignment: .center, spacing: 22) {
                    ElementTile(game: game, size: 104)
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.title)
                            .font(.system(size: 34, weight: .bold))
                        Text(game.subtitle).font(.system(size: 14, weight: .medium)).opacity(0.7)
                    }
                    .foregroundStyle(.white)
                }

                if let avoid = game.avoid {
                    Label(avoid, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .frame(maxWidth: 640, alignment: .leading)
                }
                switch game {
                case .waw, .bo1, .bo2, .iw5, .iw4, .iw6, .bo2c, .bo2s, .boiii, .cod4x, .iw7mod: PlutoniumGameView(game: game)
                case .alterware: AlterWareInfoView()
                case .bo3: BO3View()
                case .steam: SteamLibraryView()
                case .battlenet: BattleNetView()
                }
                // the Steam Library and Battle.net scroll: their lists run to the
                // window's edge (with the page margin and this spacer it stopped
                // ~60 pt short, rows cut off above an empty band)
                if game != .steam && game != .battlenet { Spacer() }
                if let p = state.progress {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text(p).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding([.top, .horizontal], 32)
            .padding(.bottom, game == .steam || game == .battlenet ? 0 : 32)
        }
    }
}

struct PlutoniumGameView: View {
    @EnvironmentObject var state: AppState
    let game: Game
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
            if game == .bo2 && state.isReady(game) { DeclassifiedCard() }
            if game == .iw6
                ? state.settings["IW6_DIR"] != nil || state.iw6PrefixReady
                : state.folder(for: game) != nil || state.engineInstalled || (game == .bo2s && state.steamCampaign["steam"] == "installed") {
                Button { confirmRemove = true } label: {
                    Label("Remove setup…", systemImage: "trash").font(.system(size: 11, weight: .medium))
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.75))
                    .disabled(state.progress != nil || (game == .iw6 && state.running != nil))
            }
            if game == .bo2c {
                Label("Only works with the Steam version of Black Ops II and an additional required file that cannot be shared here. Contact the developer to obtain it.",
                      systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: 620, alignment: .leading)
            }
        }
        .confirmationDialog("Remove the \(game.title) setup?", isPresented: $confirmRemove) {
            Button("Remove the \(game.title) setup", role: .destructive) { state.removeSetup(game.rawValue) }
            if game != .iw6 {
                Button("Remove everything (engine and Plutonium)", role: .destructive) { state.removeSetup("all") }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(game == .bo2s
                 ? "Steam campaign: closes Steam and moves its Wine prefix to the Trash, with Steam, its sign-in and the Black Ops II it downloaded (to play again, set it up and download the game again).\n\nEverything: also moves the engine and the Plutonium prefix to the Trash."
                 : game == .bo2c
                 ? "Campaign setup: puts the original t6sp.exe back (from t6sp.exe.steam) and moves the campaign's Wine prefix to the Trash. Your game files stay.\n\nEverything: also moves the engine and the Plutonium prefix to the Trash."
                 : game == .iw6
                 ? "This forgets the chosen Ghosts folder and moves its Wine prefix to the Trash."
                 : game == .boiii
                 ? "Black Ops III (Windows) setup: forgets the game folder. The game, boiii.exe and your stats in it are not touched.\n\nEverything: also moves the engine and the Wine prefix (Plutonium, its login and BOIII's identity keys: back up your stats first) to the Trash."
                 : game == .iw5
                 ? "Modern Warfare 3 setup: forgets the 32-bit game folder. Your game files are not touched.\n\nEverything: also moves the engine and the Wine prefix (Plutonium and its login) to the Trash, so every Plutonium game is set up again from the start."
                 : game == .iw7mod
                 ? "Infinite Warfare (IW7-Mod) setup: forgets the game folder and its IW7-Mod switches, and moves IW7-Mod's download and its copy of a Steam download to the Trash (Play makes it again). Steam's Infinite Warfare and IW7-Mod's profile and saves are kept; a Steam download is found again by itself.\n\nEverything: also moves the engine and the Plutonium prefix to the Trash."
                 : game == .cod4x
                 ? "Call of Duty 4 (CoD4X) setup: forgets the game folder and moves CoD4X's copy of a Steam download to the Trash (Play makes it again). Steam's Call of Duty 4 and your CoD4X profile are not touched.\n\nEverything: also moves the engine and the shared Wine prefix (Plutonium, its login and any other game settings) to the Trash."
                 : game == .iw4
                 ? "Modern Warfare 2 (IW4X) setup: forgets the game folder. Your game files are not touched.\n\nEverything: also moves the engine and the shared Wine prefix (Plutonium, its login and any other game settings) to the Trash."
                 : game == .waw
                 ? "World at War setup: forgets the game folder.\n\nEverything: also moves the engine and the Wine prefix with Plutonium (and its login) to the Trash, so every Plutonium game is set up again from the start.\n\nYour game folders are not touched."
                 : game == .bo1
                 ? "Black Ops setup: forgets the game folder and moves its shader caches to the Trash (the next visit to each map compiles again).\n\nEverything: also moves the engine and the Wine prefix with Plutonium (and its login) to the Trash, so Black Ops and Black Ops II are both set up again from the start.\n\nYour game folders are not touched."
                 : "Black Ops II setup: forgets the game folder and its mod arguments.\n\nEverything: also moves the engine and the Wine prefix with Plutonium (and its login) to the Trash, so Black Ops and Black Ops II are both set up again from the start.\n\nYour game folders are not touched.")
        }
    }

    private var modes: [PlayMode] {
        game.modes
    }

    @ViewBuilder private var content: some View {
        if state.isReady(game) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ForEach(modes) { mode in
                        BigButton(title: mode.title, symbol: mode.symbol, primary: mode.id == modes.first?.id) {
                            if mode.id == "campaign-options" { state.showCampaignOptions() } else { state.play(game, mode: mode) }
                        }
                        .disabled(mode.id != "campaign-options" &&
                                  (state.running != nil || state.progress != nil))
                    }
                    BigButton(title: "Settings", symbol: "slider.horizontal.3", outlined: true) { state.settingsGame = game }
                        .help("Settings and patches")
                    if game.usesPlutonium {
                        BigButton(title: "Plutonium", symbol: "person.crop.circle", outlined: true) { state.openPlutonium(game) }
                            .help("Open Plutonium to manage your sign-in.")
                            .disabled(state.progress != nil || state.running != nil)
                    }
                }
                if state.running == game {
                    Button { state.stop() } label: { Label("Stop the game", systemImage: "stop.fill") }
                        .buttonStyle(.bordered).tint(.white)
                }
                if game == .bo2s {
                    HStack(spacing: 10) {
                        Button { state.openSteam() } label: { Label("Open Steam", systemImage: "macwindow") }
                        InfoButton(text: "Play Campaign opens Steam in the background (signed in), applies Siliconium's patches (x87 accelerator, DXMT, direct fullscreen at 1x, console controller aim, 4x anti-aliasing at most) and asks Steam to start the game, which checks your license. Open Steam for downloads, updates or to sign in again.")
                    }
                    .buttonStyle(.bordered).tint(.white)
                    .disabled(state.progress != nil)
                }
                if game == .bo2c {
                    Label("No Steam: Play Campaign starts t6sp.exe directly.", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: 560, alignment: .leading)
                }
                if game == .boiii {
                    // the folder is Steam's own download (found on its own when Black
                    // Ops III was installed in the Steam Library, or chosen there)
                    if let folder = state.folder(for: .boiii),
                       folder.path.contains("/prefix-steam/drive_c/Program Files (x86)/Steam/steamapps/common/") {
                        Label("Detected automatically from the Steam Library: BOIII plays the Black Ops III you downloaded there.",
                              systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: 560, alignment: .leading)
                    }
                    HStack(spacing: 10) {
                        Button { state.backupBoiii() } label: { Label("Back Up Stats…", systemImage: "externaldrive.badge.plus") }
                        Button { state.restoreBoiii() } label: { Label("Restore Stats…", systemImage: "arrow.counterclockwise") }
                        InfoButton(text: "BOIII keeps your stats, loadouts and save games in the game folder (boiii_players) and the identity the servers know you by in Wine's AppData. Back Up saves both in one zip you can keep, take to another Mac (Restore) or to Windows (boiii_players goes next to boiii.exe, the key files in %LOCALAPPDATA%\\boiii\\user). Keep the zip private: anyone with it can play as you.")
                    }
                    .buttonStyle(.bordered).tint(.white)
                    .disabled(state.running != nil || state.progress != nil)
                }
                if game == .iw5 {
                    Label("Survival is played on community servers that recreate it.",
                          systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: 620, alignment: .leading)
                }
                if game == .iw4 && state.folderIsSteamLibrary(.iw4) {
                    Label("Detected automatically from the Steam Library: IW4X plays the Modern Warfare 2 you downloaded there. IW4X adds its own files next to the game's (the first start converts the maps for its client, which takes a while); Steam's own files are not changed.",
                          systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: 560, alignment: .leading)
                }
                if game == .cod4x && state.folderIsSteamLibrary(.cod4x) {
                    Label("Detected automatically from the Steam Library: CoD4X plays the Call of Duty 4 you downloaded there, from its own copy of it in Siliconium's folder (it takes no extra disk space). Steam's own files are never changed.",
                          systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: 560, alignment: .leading)
                }
                if game == .iw7mod && state.folderIsSteamLibrary(.iw7mod) {
                    Label("Detected automatically from the Steam Library: IW7-Mod (CBServers) plays the Infinite Warfare you downloaded there, from its own copy of it in Siliconium's folder (APFS clones: no extra disk space). Steam's own files are never changed, Play in the Steam Library keeps playing the normal game, and both share the same shader caches. Custom maps go in the game folder's usermaps folder (usermaps/<map>/): they reach IW7-Mod's copy at every start.",
                          systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: 560, alignment: .leading)
                }
                if game == .iw7mod {
                    // updater.cpp (CBServers): files.json + data/ from github.com/CBServers/updater (~400 MB, 88 files, 2026-11-21);
                    // filesystem.cpp: players2 -> iw7-mod/players2
                    Label("The first start downloads IW7-Mod's own data (about 400 MB) before the game opens, and the game prepares its shaders once if Steam's Infinite Warfare has not done it yet. IW7-Mod keeps its own profile and campaign saves (iw7-mod/players2), starting from the game's video settings.",
                          systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: 560, alignment: .leading)
                }
                if game == .cod4x {
                    // the original 1.7 executable CoD4X needs asks for the game's key
                    // (Steam's own executable does not, so Steam never stores it)
                    Label("The first time you join a server, CoD4X asks for your Call of Duty 4 key code (only once). A Steam copy's key is in Steam: Library → right-click Call of Duty 4 → Manage → CD Keys.",
                          systemImage: "key.fill")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: 560, alignment: .leading)
                    // the server's own rule (sv_steamforce in CoD4X's server auth module):
                    // launch.sh starts Steam for Windows for CoD4X when it is set up (COD4X_STEAM)
                    Label("Some servers only let you in while Steam is running (\"Steam is not installed\" / \"Steam is not running\": the server's own setting). Set up Steam in the Steam section and sign in: Play CoD4X then starts it in the background for them. Every other server plays without Steam.",
                          systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: 560, alignment: .leading)
                }
                if game == .iw4 {
                    HStack(spacing: 10) {
                        Button { state.backupIW4Stats() } label: { Label("Back Up Stats…", systemImage: "externaldrive.badge.plus") }
                        Button { state.restoreIW4Stats() } label: { Label("Restore Stats…", systemImage: "arrow.counterclockwise") }
                        InfoButton(text: "IW4X keeps your stats (XP, level, unlocks and challenges) in players/iw4x.stat inside the game folder. Back Up saves them in a zip you can keep or take to another Mac; Restore puts them back (close IW4X first: the stats it replaces go to the Trash). Your settings (iw4x_config.cfg) are not touched. Keep the zip private: it is your progress.")
                    }
                    .buttonStyle(.bordered).tint(.white)
                    .disabled(state.running != nil || state.progress != nil)
                }
            }
        } else {
            SetupChecklist(game: game)
        }
    }
}

struct DeclassifiedCard: View {
    @EnvironmentObject var state: AppState
    @State private var confirmInstall = false
    @State private var confirmRemove = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "moon.stars.fill").font(.system(size: 22)).foregroundStyle(.white).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Zombies Declassified").font(.system(size: 14, weight: .bold))
                    InfoButton(text: "Zombies Declassified by Logo-2K (github.com/Logo-2K/zombies-declassified) is Black Ops II's unreleased \"DLC 5\": Nacht der Untoten, Verrückt, Shi No Numa, Der Riese, Kino der Toten, \"Five\", Ascension, Shangri-La and Moon, ported to Black Ops II as a Plutonium mod. It needs the full game with all DLC.\n\nInstalled with the mod's own installer: every file is checked against the release's SHA-256, and any game file it replaces is backed up.\n\nTo play it: in the game, Mods → dlc5.")
                }
                Text(statusText).font(.system(size: 11)).opacity(0.75)
            }
            .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 8) {
                if state.zdInstalled == nil {
                    Button("Install…") { confirmInstall = true }
                } else {
                    if let l = state.zdLatest, l != state.zdInstalled { Button("Update to \(l)…") { confirmInstall = true } }
                    Button("Check files") { state.zombiesDeclassified("verify") }
                    Button("Remove…") { confirmRemove = true }
                }
            }
            .disabled(state.progress != nil || state.running != nil)
        }
        .padding(14)
        .frame(maxWidth: 620, alignment: .leading)
        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog("Install Zombies Declassified?", isPresented: $confirmInstall) {
            Button("Install") { state.zombiesDeclassified("install") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Downloads about 9 GB from the mod's GitHub release (stopped downloads resume where they left off) into Black Ops II's sound folder and Plutonium's mods folder.")
        }
        .confirmationDialog("Remove Zombies Declassified?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { state.zombiesDeclassified("remove") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moves the mod's files to the Trash and puts back any game file it had replaced.")
        }
        .task { state.refreshZD() }
    }

    private var statusText: String {
        if let v = state.zdInstalled { return "Installed (\(v)): BO1 and World at War zombies maps in Black Ops II" }
        return "BO1 and World at War zombies maps in Black Ops II · about 9 GB"
    }
}

struct SetupChecklist: View {
    @EnvironmentObject var state: AppState
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Check(done: state.rosettaInstalled, title: "Rosetta 2",
                  detail: "Run in Terminal: softwareupdate --install-rosetta --agree-to-license")
            Check(done: state.engineInstalled, title: "Siliconium engine",
                  detail: "Downloads our engine, built from open source, and adds our patches. About 330 MB.") {
                Button("Install") { state.installEngine() }.disabled(state.progress != nil)
            }
            if game == .bo2s {
                Check(done: state.steamCampaign["steam"] == "installed", title: "Steam for Windows",
                      detail: "Downloads Valve's Steam installer and installs it in its own Wine prefix, apart from the other games.") {
                    Button("Install") { state.setupSteamCampaign() }
                        .disabled(!state.engineInstalled || state.progress != nil)
                }
                Check(done: state.steamCampaign["signedin"] == "yes", title: "Signed in to Steam",
                      detail: "Sign in with the account that owns Black Ops II, and tick Remember me so Siliconium can open Steam in the background.") {
                    Button("Open Steam") { state.openSteam() }
                        .disabled(state.steamCampaign["steam"] != "installed" || state.progress != nil)
                }
                Check(done: state.steamCampaign["game"] == "installed", title: "Black Ops II downloaded in Steam",
                      detail: state.steamCampaign["game"] == "downloading"
                          ? "Steam is downloading or updating the game: wait until it finishes (Open Steam shows the progress)."
                          : "Opens Steam's install dialog for Call of Duty: Black Ops II (about 13 GB). Siliconium applies its patches when you play.") {
                    HStack {
                        Button("Download") { state.downloadInSteam() }
                        Button("Refresh") { state.refreshSteamCampaign() }
                    }
                    .disabled(state.steamCampaign["steam"] != "installed" || state.progress != nil)
                }
            } else {
                if game == .iw5 {
                    Check(done: state.iw5Usable, title: "IW5 - MW3 game folder",
                          detail: state.folderDetail(for: .iw5)) {
                        HStack {
                            Button("Choose…") { state.chooseFolder(for: .iw5) }
                            Button("Requires 32-bit game files") { state.showIW5FilesHelp() }
                        }
                        .disabled(state.progress != nil)
                    }
                } else if game == .waw || game == .bo1 || game == .bo2 || game == .bo2c || game == .iw6 {
                    Check(done: state.folderUsable(for: game), title: "\(game.title) game folder",
                          detail: state.folderDetail(for: game)) {
                        Button("Choose…") { state.chooseFolder(for: game) }
                            .disabled(state.progress != nil || state.running != nil)
                    }
                }
            if game == .bo2c {
                Check(done: state.campaign["ready"] == "yes", title: "Steam-free campaign",
                      detail: "Runs directly from t6sp.exe.") {
                    Button("Prepare") { state.prepareCampaign() }
                        .disabled(!state.engineInstalled || !state.folderUsable(for: game) || state.progress != nil)
                }
            } else if game == .iw6 {
                Check(done: state.iw6PrefixReady, title: "Wine prefix",
                      detail: "Creates a separate Windows environment for Ghosts.") {
                    Button("Create") { state.createIW6Prefix() }
                        .disabled(!state.engineInstalled || !state.folderUsable(for: game)
                                  || state.progress != nil || state.running != nil)
                }
            } else if game == .boiii {
                Check(done: state.folderUsable(for: .boiii), title: "Black Ops III game folder",
                      detail: state.folderDetail(for: .boiii)) {
                    Button("Choose…") { state.chooseFolder(for: .boiii) }
                }
                Check(done: state.prefixReady, title: "Wine prefix",
                      detail: "Where Windows programs keep their settings (shared with Black Ops and Black Ops II).") {
                    Button("Create") { state.createEmptyPrefix() }
                        .disabled(!state.engineInstalled || state.progress != nil)
                }
            } else if game == .cod4x || game == .iw7mod {
                // Steam's prefix is made by Play when missing (launch.sh), without Steam
                Check(done: state.folderUsable(for: game), title: "\(game.title) game folder",
                      detail: state.folderDetail(for: game)) {
                    Button("Choose…") { state.chooseFolder(for: game) }
                }
            } else if game == .iw4 {
                Check(done: state.folderUsable(for: .iw4), title: "\(game.title) game folder",
                      detail: state.folderDetail(for: .iw4)) {
                    Button("Choose…") { state.chooseFolder(for: .iw4) }
                }
                Check(done: state.prefixReady, title: "Wine prefix",
                      detail: "Where Windows programs keep their settings (shared with the other games).") {
                    Button("Create") { state.createEmptyPrefix() }
                        .disabled(!state.engineInstalled || state.progress != nil)
                }
            } else {
            Check(done: state.plutoniumInstalled,
                  title: "Plutonium setup",
                  detail: state.plutoniumInstalled
                      ? "Signed in. Every Plutonium game uses this session."
                      : "Sign in once in Plutonium. Siliconium closes it after sign-in and links this game folder.") {
                HStack {
                    if !state.prefixReady {
                        Button("Import…") { state.choosePrefixToImport() }
                            .disabled(!state.engineInstalled || state.progress != nil || state.running != nil)
                    }
                    Button("Install") { state.setupPlutonium(game) }
                        .disabled(!state.engineInstalled || !state.folderUsable(for: game) ||
                                  state.progress != nil || state.running != nil)
                }
            }
            }
            }
        }
        .padding(20)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct Check<Accessory: View>: View {
    let done: Bool
    let title: String
    let detail: String
    @ViewBuilder var accessory: () -> Accessory

    init(done: Bool, title: String, detail: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.done = done; self.title = title; self.detail = detail; self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .white.opacity(0.6))
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if !done { Text(detail).font(.system(size: 11)).opacity(0.7) }
            }
            .foregroundStyle(.white)
            Spacer()
            if !done { accessory() }
        }
    }
}

struct BO3View: View {
    @EnvironmentObject var state: AppState
    @State private var confirmInstall = false
    @State private var confirmSpoof = false
    @State private var confirmRemove = false

    static let spoofRisks = "Ranked spoofing (T7Patch's SPOOF_RANKED, part of BO3MacFix) makes the game treat community and modded matches as ranked, so the XP and rank you earn there count.\n\nRisks:\n• It modifies your original Steam stats for Black Ops III: your real rank, XP and stats change, also for Steam's official matchmaking, and the changes can't be undone.\n• Community servers that hand out ranks (some set you to max prestige or level 1000) then write them to your real profile too. With spoofing off, modded matches keep their stats in a separate profile that the game resets.\n• The BO3MacFix authors warn that it can get your account banned.\n\nUse it at your own risk. It is off unless you turn it on."

    private var spoofToggle: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(get: { state.bo3SpoofRanked },
                                 set: { on in if on { confirmSpoof = true } else { state.setBO3SpoofRanked(false) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ranked spoofing (optional)").font(.system(size: 13, weight: .semibold))
                    Text("XP counts on community servers. Modifies your Steam stats; ban risk.")
                        .font(.system(size: 11)).opacity(0.75)
                }
            }
            .toggleStyle(.switch)
            InfoButton(text: Self.spoofRisks)
        }
        .foregroundStyle(.white)
        .alert("Turn on ranked spoofing?", isPresented: $confirmSpoof) {
            Button("Turn on", role: .destructive) { state.setBO3SpoofRanked(true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Self.spoofRisks)
        }
    }

    var body: some View {
        Group {
            if state.bo3Installed { installed } else { setup }
        }
        .confirmationDialog(state.bo3Installed ? "Update BO3 Mac Client?" : "Install BO3 Mac Client?",
                            isPresented: $confirmInstall) {
            Button(state.bo3Installed ? "Update" : "Install") { state.installBO3() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Installs BO3 Mac Client, which comes with Siliconium: BO3MacFix goes into your Black Ops III from Steam (Steam's launcher is kept as a backup), and its server browser opens when it is done.")
        }
        .task { state.refreshBO3() }
    }

    // Ready to play
    private var installed: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                BigButton(title: "Community Servers", symbol: "server.rack", primary: true) { state.openBO3() }
                    .disabled(state.progress != nil)
                BigButton(title: "Play on Steam", symbol: "gamecontroller.fill") { state.playBO3OnSteam() }
                    .disabled(state.progress != nil)
                BigButton(title: updateAvailable ? "Update" : "Reinstall", symbol: "arrow.down.circle") { confirmInstall = true }
                    .disabled(state.progress != nil || state.bo3GameState != "ready")
            }
            Text(versionText).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            spoofToggle
                .padding(12)
                .frame(maxWidth: 560, alignment: .leading)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                Label("Community Servers opens the server list: type your player name, pick a server and press Join. It starts the game through Steam and connects you.", systemImage: "1.circle")
                Label("Play on Steam starts Black Ops III normally, for Steam's own matchmaking. BO3MacFix's fixes apply there too.", systemImage: "2.circle")
            }
            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: 560, alignment: .leading)
            Button { confirmRemove = true } label: {
                Label("Remove BO3 Mac Client…", systemImage: "trash").font(.system(size: 11, weight: .medium))
            }
                .buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                .disabled(state.progress != nil)
                .confirmationDialog("Remove BO3 Mac Client?", isPresented: $confirmRemove) {
                    Button("Remove", role: .destructive) { state.removeSetup("bo3") }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Puts Steam's own launcher back into Black Ops III and moves BO3MacFix and the server browser to the Trash. Your identity key (rank and VIP on community servers) is kept and comes back with the next install. The game itself is not touched.")
                }
        }
    }

    // Not installed yet
    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Check(done: state.steamInstalled, title: "Steam",
                  detail: "Install Steam from store.steampowered.com and sign in.")
            Check(done: state.bo3GameState == "ready", title: "Black Ops III (Steam version)",
                  detail: state.bo3GameState == "downloading"
                      ? "Black Ops III is still downloading in Steam. Come back when it has finished, open it once and close it."
                      : "Install Call of Duty: Black Ops III in Steam, open it once and close it.") {
                Button("Open Steam") { NSWorkspace.shared.open(URL(string: "steam://nav/games/details/311210")!) }
            }
            Check(done: false, title: "BO3 Mac Client",
                  detail: "BO3MacFix (T7Patch fixes, audio and stutter fixes, community servers) goes into the game, and the server browser opens.") {
                Button("Install") { confirmInstall = true }
                    .disabled(state.bo3GameState != "ready" || state.progress != nil)
            }
            Divider().overlay(.white.opacity(0.2))
            spoofToggle
            if let g = state.bo3["game"], !g.isEmpty {
                Text(g).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(20)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }

    private var updateAvailable: Bool {
        guard let l = state.bo3Latest, let v = state.bo3Version else { return false }
        return l != v
    }
    private var versionText: String {
        let installed = state.bo3Version ?? "not installed"
        if let l = state.bo3Latest, l != installed { return "BO3 Mac Client \(installed) · update available: \(l)" }
        return "BO3 Mac Client \(installed) · up to date"
    }
}


// MARK: - Steam Library

/// Steam for Windows in its own prefix: sign in once, download the games
/// there. Steam runs them from its own (original) files.
struct SteamLibraryView: View {
    @EnvironmentObject var state: AppState

    private var steamInstalled: Bool { state.steamCampaign["steam"] == "installed" }
    private var signedIn: Bool { state.steamCampaign["signedin"] == "yes" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !(state.engineInstalled && steamInstalled && signedIn) {
                VStack(alignment: .leading, spacing: 14) {
                    Check(done: state.engineInstalled, title: "Siliconium engine",
                          detail: "Downloads our engine, built from open source, and adds our patches. About 330 MB.") {
                        Button("Install") { state.installEngine() }.disabled(state.progress != nil)
                    }
                    Check(done: steamInstalled, title: "Steam for Windows",
                          detail: "Downloads Valve's Steam installer and installs it in its own Wine prefix, apart from the other games.") {
                        Button("Install Steam") { state.setupSteam() }
                            .disabled(!state.engineInstalled || state.progress != nil)
                    }
                    Check(done: signedIn, title: "Signed in to Steam",
                          detail: "Sign in with your Steam account and tick Remember me, so Siliconium can open Steam in the background.") {
                        Button("Open Steam") { state.openSteamLibrary() }.disabled(!steamInstalled)
                    }
                }
                .padding(18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Button { state.openSteamLibrary() } label: {
                        Label("Open Steam", systemImage: "arrow.up.forward.app")
                    }
                    if SteamTitle.catalog.contains(where: { (state.steamLibrary[$0.id]?.state ?? "missing") == "missing" }) {
                        Button { state.downloadAllSteamGames() } label: {
                            Label("Download all", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.progress != nil)
                        .help("Asks Steam to download every game here, with its multiplayer, zombies and the DLC you own")
                    }
                    Text("Downloads keep going while Steam is open in the background.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(SteamTitle.catalog) { title in
                        SteamTitleRow(title: title, steamReady: steamInstalled)
                    }
                }
                .padding(.bottom, 32)   // the last row can scroll clear of the edge
            }
        }
        .task {
            // Steam's downloads move on their own: keep the states current
            while !Task.isCancelled {
                state.refreshSteamLibrary()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

struct SteamTitleRow: View {
    @EnvironmentObject var state: AppState
    let title: SteamTitle
    let steamReady: Bool
    @State private var showModInfo = false

    private var entry: AppState.SteamEntry? { state.steamLibrary[title.id] }
    private var gameState: String { entry?.state ?? "missing" }

    var body: some View {
        // The details and the buttons side by side, or the buttons under the
        // details when the window is too narrow for both (SteamRowLayout)
        SteamRowLayout(spacing: 14) {
            SteamTile(title: title, size: 44)
            details
            HStack(spacing: 14) { actions }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var details: some View {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title.title).font(.system(size: 14, weight: .semibold))
                    Text(title.year).font(.system(size: 11).monospacedDigit()).opacity(0.5)
                }
                HStack(spacing: 5) {
                    Circle().fill(dotColor).frame(width: 6, height: 6)
                    Text(statusText).font(.system(size: 11)).opacity(0.65)
                }
                if let parts = entry?.parts, parts.count > 1 || (entry?.dlc ?? 0) > 0 {
                    HStack(spacing: 5) {
                        if parts.count > 1 {
                            ForEach(parts, id: \.name) { part in PartChip(name: part.name, state: part.state) }
                        }
                        if let dlc = entry?.dlc, dlc > 0 {
                            Text("+\(dlc) DLC")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1).fixedSize()
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color(red: 0.76, green: 0.70, blue: 1).opacity(0.25), in: Capsule())
                                .help("DLC you own (map packs and more), downloaded by Steam with the game")
                        }
                    }
                    .padding(.top, 2)
                }
                if gameState == "installed", let note = title.note {
                    Text(note).font(.system(size: 10)).opacity(0.5)
                }
                if gameState == "installed", let avoid = title.avoid {
                    Label(avoid, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if gameState == "installed", let known = title.known {
                    Label(known, systemImage: "info.circle")
                        .font(.system(size: 10))
                        .opacity(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(.white)
    }

    @ViewBuilder private var actions: some View {
            switch gameState {
            case "installed":
                if entry?.parts.contains(where: { $0.state == "missing" }) == true {
                    Button("Download the rest") { state.downloadSteamGame(title.id) }
                        .help("Downloads the parts not in Steam yet (if your account owns them)")
                }
                if !title.mods.isEmpty { modPicker }
                ForEach(Array(title.modes.enumerated()), id: \.element.id) { index, mode in
                    if index == 0 {
                        Button { state.playSteam(title, mode) } label: { Label(mode.title, systemImage: mode.symbol) }
                            .buttonStyle(.borderedProminent)
                            .disabled(state.running != nil || state.progress != nil)
                    } else {
                        Button { state.playSteam(title, mode) } label: { Label(mode.title, systemImage: mode.symbol) }
                            .disabled(state.running != nil || state.progress != nil)
                    }
                }
                if title.workshop {
                    Button { state.openSteamWorkshop(title.id) } label: { Label("Workshop", systemImage: "puzzlepiece.extension") }
                        .help("The game's Steam Workshop: mods and maps. Steam downloads what you subscribe to; the game lists it in its Mods menu.")
                }
                if title.tools != nil { toolsButton }
                if let label = title.linkedButton, let game = title.linked, let folder = entry?.folder, !folder.isEmpty {
                    Button { state.openInLinkedGame(game, folder) } label: { Label(label, systemImage: game.symbol) }
                        .help("Opens the \(game.title) tab (\(game.client)'s client). With no game folder of its own it uses this Steam download.")
                        .disabled(state.running != nil || state.progress != nil)
                }
                Menu {
                    if let f = entry?.folder, !f.isEmpty {
                        Button("Show the game's folder") { NSWorkspace.shared.open(URL(fileURLWithPath: f)) }
                    }
                    if let game = title.linked, let folder = entry?.folder, !folder.isEmpty {
                        Button("Use this download in \(game.client) (\(game.title) tab)") { state.useSteamFolder(game, folder) }
                    }
                    if toolsState == "installed" {
                        Button("Show my Mod Tools work (maps and mods)") { state.showBO3ModToolsWork() }
                    }
                    Button("Store page") { state.openSteamStore(title.id) }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            case "downloading":
                Button("Open Steam") { state.openSteamLibrary() }
            default:
                Button("Store") { state.openSteamStore(title.id) }.disabled(!steamReady)
                Button("Download") { state.downloadSteamGame(title.id) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!steamReady)
            }
    }

    /// The game's Steam tools (Black Ops III: Mod Tools): Download (Steam's
    /// install dialog), then the download's progress in Steam, then Open
    private var toolsState: String { title.tools.flatMap { entry?.tools[$0] } ?? "missing" }
    @ViewBuilder private var toolsButton: some View {
        switch toolsState {
        case "installed":
            Button { state.openBO3ModTools() } label: { Label("Mod Tools", systemImage: "hammer.fill") }
                .help("Opens the Black Ops III Mod Tools launcher (Radiant, the Asset Editor, compile, light, link and run your map). Your maps and mods stay in Siliconium's Mod Tools workspace, never in Steam's folders, and show in Documents › Black Ops III Mod Tools on your Mac (⋯ › Show my Mod Tools work).")
                .disabled(state.running != nil || state.progress != nil)
        case "downloading":
            Button { state.openSteamLibrary() } label: { Label("Mod Tools…", systemImage: "arrow.down.circle") }
                .help("Steam is downloading the Black Ops III Mod Tools: this opens Steam to see its progress.")
        default:
            Button { state.downloadSteamTool(title.id) } label: { Label("Mod Tools", systemImage: "hammer") }
                .help("Downloads Call of Duty: Black Ops III - Mod Tools (Steam app 455130, free with the game) to make your own maps and mods: about 25 GB (28 GB on disk). Steam asks to confirm. Their optional \"Additional Assets\" (about 100 GB) are not downloaded.")
                .disabled(!steamReady || state.progress != nil)
        }
    }

    /// The community fix used when this game starts (None: the game as it is),
    /// and what each one does
    @ViewBuilder private var modPicker: some View {
        let chosen = state.steamMod(title)
        HStack(spacing: 4) {
            Menu {
                Button { state.setSteamMod(title, nil) } label: {
                    if chosen == nil { Label("None", systemImage: "checkmark") } else { Text("None") }
                }
                ForEach(title.mods.filter { !$0.opensLinked }) { mod in
                    Button { state.setSteamMod(title, mod) } label: {
                        if chosen?.id == mod.id { Label("\(mod.title) (\(mod.parts))", systemImage: "checkmark") }
                        else { Text("\(mod.title) (\(mod.parts))") }
                    }
                }
                let linked = title.mods.filter(\.opensLinked)
                if !linked.isEmpty, let game = title.linked, let folder = entry?.folder, !folder.isEmpty {
                    Divider()
                    ForEach(linked) { mod in
                        Button { state.openInLinkedGame(game, folder) } label: { Label(mod.title, systemImage: game.symbol) }
                    }
                }
            } label: {
                Label(chosen?.title ?? "No fix", systemImage: "wrench.and.screwdriver")
            }
            .fixedSize()
            .disabled(state.running != nil || state.progress != nil)
            .help("A community fix used when this game starts. None: the game exactly as Siliconium plays it.")
            Button { showModInfo.toggle() } label: { Image(systemName: "info.circle") }
                .buttonStyle(.borderless)
                .help("What each fix does")
                .popover(isPresented: $showModInfo, arrowEdge: .bottom) { SteamModInfo(title: title) }
        }
    }

    private var statusText: String {
        switch gameState {
        case "installed": "Downloaded"
        case "downloading": "Downloading in Steam"
        default: "Not downloaded"
        }
    }
    private var dotColor: Color {
        switch gameState {
        case "installed": Color(red: 0.30, green: 0.82, blue: 0.48)
        case "downloading": Color(red: 0.35, green: 0.75, blue: 1)
        default: .white.opacity(0.35)
        }
    }
}

/// The ⓘ of a Steam game's fixes: what each does, its author's page and licence.
struct SteamModInfo: View {
    let title: SteamTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community fixes for \(title.title)").font(.headline)
            entry("None", "The game exactly as Siliconium plays it, with nothing added.", nil, nil, nil)
            ForEach(title.mods) { mod in
                entry("\(mod.title) · \(mod.parts)", mod.about, mod.warning, mod.source, mod.license)
            }
            Text("Fixes are made by their authors, not by Siliconium. They are added only while the game runs; the game's own files are never changed.")
                .font(.system(size: 10)).opacity(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 380)
    }

    @ViewBuilder private func entry(_ name: String, _ about: String, _ warning: String?, _ source: String?, _ license: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.system(size: 12, weight: .semibold))
            Text(about).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let source, let url = URL(string: source) {
                HStack(spacing: 6) {
                    Link(url.host.map { "\($0)\(url.path)" } ?? source, destination: url).font(.system(size: 10))
                    if let license { Text("· \(license)").font(.system(size: 10)).opacity(0.6) }
                }
            }
        }
    }
}

/// A part of a Steam game (Campaign, Multiplayer, Zombies), each its own Steam app.
/// "What's new in Siliconium <version>": the release notes (CHANGELOG lines:
/// "**Heading**", "- item" with inline Markdown), once after an update
struct WhatsNewView: View {
    let version: String
    let notes: String
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What's new in Siliconium \(version)").font(.system(size: 20, weight: .bold))
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(notes.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        noteLine(line)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            HStack {
                Spacer()
                Button("Continue") { close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640, height: 560)
    }

    @ViewBuilder private func noteLine(_ line: String) -> some View {
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            Color.clear.frame(height: 4)
        } else if text.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                Text(inline(String(text.dropFirst(2)))).fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 13))
        } else {
            Text(inline(text)).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
        }
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

/// A Steam Library row: tile, details and buttons on one line when the details
/// keep at least their chips' width (and `minDetails`); otherwise the buttons
/// move under the details (a narrow window squeezed the chips letter by letter).
/// Subviews: tile, details, buttons.
struct SteamRowLayout: Layout {
    var spacing: CGFloat = 14
    var rowSpacing: CGFloat = 10
    var minDetails: CGFloat = 260

    private func oneLine(_ s: Subviews, width: CGFloat) -> Bool {
        guard s.count == 3, width.isFinite else { return true }
        let tile = s[0].sizeThatFits(.unspecified).width
        // narrowest width of the details: their fixed parts (chips, DLC) stay whole
        let details = max(minDetails, s[1].sizeThatFits(.init(width: 1, height: nil)).width)
        let buttons = s[2].sizeThatFits(.unspecified).width
        return tile + spacing + details + spacing + buttons <= width
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews s: Subviews, cache: inout ()) -> CGSize {
        guard s.count == 3 else { return .zero }
        let width = proposal.width ?? .infinity
        let tile = s[0].sizeThatFits(.unspecified), buttons = s[2].sizeThatFits(.unspecified)
        if oneLine(s, width: width) {
            let detailsWidth: CGFloat? = width.isFinite ? max(0, width - tile.width - buttons.width - 2 * spacing) : nil
            let details = s[1].sizeThatFits(.init(width: detailsWidth, height: nil))
            return CGSize(width: width.isFinite ? width : tile.width + details.width + buttons.width + 2 * spacing,
                          height: max(tile.height, details.height, buttons.height))
        }
        let detailsWidth = max(0, width - tile.width - spacing)
        let details = s[1].sizeThatFits(.init(width: detailsWidth, height: nil))
        let below = s[2].sizeThatFits(.init(width: detailsWidth, height: nil))
        return CGSize(width: width, height: max(tile.height, details.height) + rowSpacing + below.height)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews s: Subviews, cache: inout ()) {
        guard s.count == 3 else { return }
        let tile = s[0].sizeThatFits(.unspecified), buttons = s[2].sizeThatFits(.unspecified)
        if oneLine(s, width: b.width) {
            let detailsWidth = max(0, b.width - tile.width - buttons.width - 2 * spacing)
            let details = s[1].sizeThatFits(.init(width: detailsWidth, height: nil))
            s[0].place(at: CGPoint(x: b.minX, y: b.midY), anchor: .leading, proposal: .unspecified)
            s[1].place(at: CGPoint(x: b.minX + tile.width + spacing, y: b.midY), anchor: .leading,
                       proposal: .init(width: detailsWidth, height: details.height))
            s[2].place(at: CGPoint(x: b.maxX, y: b.midY), anchor: .trailing, proposal: .unspecified)
        } else {
            let detailsWidth = max(0, b.width - tile.width - spacing)
            let details = s[1].sizeThatFits(.init(width: detailsWidth, height: nil))
            let top = max(tile.height, details.height)
            s[0].place(at: CGPoint(x: b.minX, y: b.minY + top / 2), anchor: .leading, proposal: .unspecified)
            s[1].place(at: CGPoint(x: b.minX + tile.width + spacing, y: b.minY + top / 2), anchor: .leading,
                       proposal: .init(width: detailsWidth, height: details.height))
            s[2].place(at: CGPoint(x: b.minX + tile.width + spacing, y: b.minY + top + rowSpacing), anchor: .topLeading,
                       proposal: .init(width: detailsWidth, height: nil))
        }
    }
}

struct PartChip: View {
    let name: String
    let state: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state == "installed" ? "checkmark" : state == "downloading" ? "arrow.down" : "minus")
                .font(.system(size: 8, weight: .bold))
            Text(name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 7).padding(.vertical, 2)
        .foregroundStyle(.white.opacity(state == "missing" ? 0.5 : 0.95))
        .background(color.opacity(0.25), in: Capsule())
    }
    private var color: Color {
        switch state {
        case "installed": Color(red: 0.30, green: 0.82, blue: 0.48)
        case "downloading": Color(red: 0.35, green: 0.75, blue: 1)
        default: .white.opacity(0.4)
        }
    }
}

/// The catalog game's tile, in the style of ElementTile.
struct SteamTile: View {
    let title: SteamTitle
    var size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [title.colors[0].opacity(0.92), title.colors[1]],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            shape.strokeBorder(.white.opacity(0.2), lineWidth: 1)
            Text(title.badge)
                .font(.system(size: size * (title.badge.count > 2 ? 0.30 : 0.38), weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

struct BigButton: View {
    let title: String
    let symbol: String
    var primary = false
    var outlined = false
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .bold))
            }
            .frame(width: 128, height: 84)
            .foregroundStyle(primary ? .black : .white)
            .background(primary ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.14)),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(primary ? 0 : outlined ? 0.95 : 0.25), lineWidth: outlined ? 2 : 1))
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Footer, settings, log

struct EngineFooter: View {
    @EnvironmentObject var state: AppState
    @Binding var showLog: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Siliconium \(state.appVersion)")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            if state.engineInstalled {
                let info = state.engineInfo
                let engine = (info["base"] ?? info["crossover"].map { "CrossOver \($0)" } ?? "?")
                    .replacingOccurrences(of: "own ", with: "")
                Text("Engine \(engine)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("x87 \(info["x87sidecar"] ?? "?")").font(.system(size: 10)).foregroundStyle(.secondary)
                    if let latest = state.x87Latest, latest != info["x87sidecar"] {
                        Button("Update to \(latest)") { state.updateX87() }
                            .font(.system(size: 10)).buttonStyle(.link)
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Show log") { showLog = true }
                Text("·").foregroundStyle(.tertiary)
                Button("Check for Updates") { state.checkForAppUpdate(manual: true) }
                Text("·").foregroundStyle(.tertiary)
                Button("Discord") { state.openDiscord() }
            }
            .font(.system(size: 10)).buttonStyle(.link)
        }
        .padding(.horizontal, 12).padding(.bottom, 10)
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    let game: Game
    var close: () -> Void
    @State private var fps = "monitor"
    @State private var patches: [String: Bool] = [:]
    @State private var deadzone = 0.08
    @State private var name = "Player"
    @State private var mods = ""
    private var fpsKey: String { game == .iw6 ? "IW6_MAXFPS" : "MAXFPS" }

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
                        if game.usesPlutonium || game == .iw6 || game == .iw4 || game == .cod4x || game == .iw7mod || game == .boiii {
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
                if !game.usesPlutonium && game != .iw6 && game != .cod4x && game != .iw7mod { TextField("Player name (offline)", text: $name) }
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
                } else if game == .iw6 {
                    Text("Ghosts keeps its controller settings in the game's Options menu.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if game == .iw7mod {
                    Text("Infinite Warfare has its own controller support: it asks to switch to the gamepad when one is connected, and keeps its controller settings in the game (Options → Controls).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if game == .cod4x {
                    Text("Call of Duty 4 has no controller support on PC: Siliconium plays your controller as keyboard and mouse, as for Steam's Call of Duty 4 (the keyboard keeps your own bindings).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Stick deadzone")
                        Slider(value: $deadzone, in: 0.02...0.25, step: 0.01)
                        Text(String(format: "%.2f", deadzone)).monospacedDigit().frame(width: 36)
                    }
                }
                // Bluetooth controllers need macOS's Input Monitoring
                // permission; wired and dongle ones don't. This is where a
                // player can read about it again or enable it later.
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
        fps = s[fpsKey] ?? "monitor"
        for p in Patch.for(game) { patches[p.key] = s[p.key] != p.offValue }
        deadzone = Double(s["STICK_DEADZONE"] ?? "") ?? 0.08
        name = s["PLAYER_NAME"] ?? "Player"
        mods = s["BO2_MODS"] ?? ""
    }

    private func save() {
        state.settings[fpsKey] = fps == "monitor" ? nil : fps
        for p in Patch.for(game) { state.settings[p.key] = (patches[p.key] ?? true) ? nil : p.offValue }
        if game != .iw6 {
            state.settings["STICK_DEADZONE"] = String(format: "%.2f", deadzone)
            state.settings["PLAYER_NAME"] = name
            state.settings["BO2_MODS"] = mods
        }
        state.settings.save()
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
    @Environment(\.dismiss) private var dismiss

    /// The app's own output, then the end of the log file the last error named
    private var text: String {
        var parts: [String] = []
        if !state.log.isEmpty { parts.append(state.log.joined(separator: "\n")) }
        if let name = state.errorLog {
            let url = Paths.home.appendingPathComponent(name)
            if let data = try? Data(contentsOf: url) {
                let t = String(decoding: data, as: UTF8.self)
                let lines = t.split(separator: "\n", omittingEmptySubsequences: false).suffix(300)
                parts.append("— \(name)\n" + (t.isEmpty ? "(empty)" : lines.joined(separator: "\n")))
            } else {
                parts.append("— \(name)\n(not found)")
            }
        }
        return parts.isEmpty ? "Nothing logged yet in this session." : parts.joined(separator: "\n\n")
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
