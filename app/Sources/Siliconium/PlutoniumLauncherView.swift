import AppKit
import SwiftUI

/// Unified Plutonium Launcher section: shared setup/sign-in at the top, followed
/// by all four Plutonium games (World at War, Black Ops, Black Ops II, Modern
/// Warfare 3) in the same card-list design as Steam Library, Battle.net and
/// Your Own Game Files.
struct PlutoniumLauncherView: View {
    @EnvironmentObject var state: AppState
    @State private var confirmRemoveAll = false

    private var plutoniumReady: Bool {
        state.engineInstalled && state.prefixReady && state.plutoniumInstalled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !plutoniumReady {
                VStack(alignment: .leading, spacing: 14) {
                    Check(done: state.rosettaInstalled, title: "Rosetta 2",
                          detail: "Run in Terminal: softwareupdate --install-rosetta --agree-to-license")
                    Check(done: state.engineInstalled, title: "Siliconium engine",
                          detail: "Downloads our engine, built from open source, and adds our patches. About 330 MB.") {
                        Button("Install") { state.installEngine() }.disabled(state.progress != nil)
                    }
                    Check(done: state.plutoniumInstalled && state.prefixReady,
                          title: "Plutonium setup",
                          detail: state.plutoniumInstalled
                              ? "Signed in. Every Plutonium game uses this session."
                              : "Downloads Plutonium and opens its window to sign in once. Siliconium closes it automatically when you are in.") {
                        HStack {
                            if !state.prefixReady {
                                Button("Import…") { state.choosePrefixToImport() }
                                    .disabled(!state.engineInstalled || state.progress != nil || state.running != nil)
                            }
                            Button("Install") { state.setupPlutonium() }
                                .disabled(!state.engineInstalled || state.progress != nil || state.running != nil)
                        }
                    }
                }
                .padding(18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Button { state.openPlutonium() } label: {
                        Label("Open Plutonium", systemImage: "person.crop.circle")
                    }
                    .disabled(state.progress != nil || state.running != nil)
                    .help("Open Plutonium to manage your account sign-in.")
                    if state.running?.usesPlutonium == true {
                        Button { state.stop() } label: { Label("Stop the game", systemImage: "stop.fill") }
                            .buttonStyle(.bordered).tint(.white)
                    }
                    Spacer()
                    Button { confirmRemoveAll = true } label: {
                        Label("Remove setup…", systemImage: "trash").font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                    .disabled(state.progress != nil || state.running != nil)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Game.plutoniumGames) { game in
                        PlutoniumGameRow(game: game, plutoniumReady: plutoniumReady)
                        if game == .bo2 && state.isReady(.bo2) {
                            DeclassifiedCard(fullWidth: true)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .confirmationDialog("Remove Plutonium setup?", isPresented: $confirmRemoveAll) {
            Button("Remove everything (engine and Plutonium)", role: .destructive) { state.removeSetup("all") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moves the Siliconium engine and the shared Wine prefix (Plutonium, its login and game settings) to the Trash. Your game folders are not touched.")
        }
    }
}

struct PlutoniumGameRow: View {
    @EnvironmentObject var state: AppState
    let game: Game
    let plutoniumReady: Bool
    @State private var confirmRemove = false

    private var folder: URL? { state.folder(for: game) }
    private var problem: String? { state.folderProblem(for: game) }
    private var folderUsable: Bool { folder != nil && problem == nil }
    private var isPlaying: Bool { state.running == game }
    private var canPlay: Bool { plutoniumReady && folderUsable && state.running == nil && state.progress == nil }

    var body: some View {
        SteamRowLayout(spacing: 14) {
            ElementTile(game: game, size: 44)
            details
            HStack(spacing: 10) { actions }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("Remove the \(game.title) setup?", isPresented: $confirmRemove) {
            Button("Forget \(game.title) folder", role: .destructive) { state.removeSetup(game.rawValue) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(game == .bo1
                 ? "Forgets the Black Ops folder and moves its shader caches to the Trash. Your game files are not touched."
                 : "Forgets the \(game.title) game folder in Siliconium. Your game files are not touched.")
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(game.title).font(.system(size: 14, weight: .semibold))
                Text(game.year).font(.system(size: 11).monospacedDigit()).opacity(0.5)
            }
            HStack(spacing: 5) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                Text(statusText).font(.system(size: 11)).opacity(0.65)
                if let folder {
                    Text("· \(folder.lastPathComponent)")
                        .font(.system(size: 10)).opacity(0.45)
                        .lineLimit(1).truncationMode(.middle)
                        .help(folder.path)
                }
            }
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if folderUsable, let avoid = game.avoid {
                Label(avoid, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if folderUsable && game == .iw5 {
                Label("Survival is played on community servers that recreate it.", systemImage: "info.circle")
                    .font(.system(size: 10))
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var actions: some View {
        if folderUsable {
            ForEach(game.modes) { mode in
                if mode.id == game.modes.first?.id {
                    Button { state.play(game, mode: mode) } label: {
                        Label(mode.title, systemImage: mode.symbol)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canPlay)
                } else {
                    Button { state.play(game, mode: mode) } label: {
                        Label(mode.title, systemImage: mode.symbol)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canPlay)
                }
            }
            Button { state.settingsGame = game } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .help("\(game.title) settings and patches")
            Menu {
                Button("Change folder…") { state.chooseFolder(for: game) }
                    .disabled(state.running != nil || state.progress != nil)
                if let folder {
                    Button("Show the game's folder") { NSWorkspace.shared.open(folder) }
                }
                if plutoniumReady {
                    Menu("Play on LAN") {
                        ForEach(game.modes) { mode in
                            Button(mode.title) { state.play(game, mode: mode, lan: true) }
                        }
                    }
                    .disabled(!canPlay)
                }
                if game == .waw || game == .bo1 {
                    Button("Prepare all maps (shaders)") { state.prepareShaders(game) }
                        .disabled(!canPlay)
                }
                Divider()
                Button("Remove setup…", role: .destructive) { confirmRemove = true }
                    .disabled(state.running != nil || state.progress != nil)
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        } else {
            if game == .iw5 {
                Button("32-bit info") { state.showIW5FilesHelp() }
                    .buttonStyle(.bordered)
                    .help("Modern Warfare 3 on Plutonium requires 32-bit game files")
            }
            Button { state.chooseFolder(for: game) } label: {
                Label("Choose Folder…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.running != nil || state.progress != nil)
            .help(state.expectedFolderDetail(game))
        }
    }

    private var statusText: String {
        if isPlaying { return "Playing" }
        if problem != nil { return "Folder issue" }
        if folderUsable { return plutoniumReady ? "Ready" : "Plutonium setup required" }
        return "Folder not set"
    }

    private var dotColor: Color {
        if isPlaying { return Color(red: 0.35, green: 0.75, blue: 1) }
        if problem != nil { return .orange }
        if folderUsable { return plutoniumReady ? Color(red: 0.30, green: 0.82, blue: 0.48) : .orange }
        return .white.opacity(0.35)
    }
}
