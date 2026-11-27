import AppKit
import SwiftUI

/// The "Your Own Game Files" section under Offline: play the campaigns of
/// Call of Duty 4, Modern Warfare 2, Modern Warfare 3, Black Ops II and Ghosts
/// from your own Windows game folders (disc / retail / offline copies) without
/// Steam, with Siliconium's patches and the Steam Library's community fixes.
struct OwnFilesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !state.engineInstalled {
                VStack(alignment: .leading, spacing: 14) {
                    Check(done: state.rosettaInstalled, title: "Rosetta 2",
                          detail: "Run in Terminal: softwareupdate --install-rosetta --agree-to-license")
                    Check(done: state.engineInstalled, title: "Siliconium engine",
                          detail: "Downloads our engine, built from open source, and adds our patches. About 330 MB.") {
                        Button("Install") { state.installEngine() }.disabled(state.progress != nil)
                    }
                }
                .padding(18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Button { state.settingsGame = .ownFiles } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .help("Frame-rate cap and patches for offline campaigns")
                    if state.running == .ownFiles {
                        Button { state.stop() } label: { Label("Stop the game", systemImage: "stop.fill") }
                            .buttonStyle(.bordered).tint(.white)
                    }
                    Text("Choose each game's Windows folder (disc or offline copy). Plays Campaign without Steam, with Siliconium's patches and fixes.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(OwnGameTitle.catalog) { title in
                        OwnGameRow(title: title)
                    }
                }
                .padding(.bottom, 32)   // the last row can scroll clear of the edge
            }
        }
    }
}

struct OwnGameRow: View {
    @EnvironmentObject var state: AppState
    let title: OwnGameTitle
    @State private var showModInfo = false

    private var folder: URL? { state.ownFolder(for: title) }
    private var isReady: Bool { state.engineInstalled && folder != nil }
    private var applicableMods: [SteamTitle.Mod] { state.ownApplicableMods(title) }
    private var linkedClient: Game? {
        switch title.id {
        case "mw2": .iw4
        case "cod4": .cod4x
        case "bo2": .bo2
        case "mw3": .iw5
        default: nil
        }
    }

    private var steamTileProxy: SteamTitle {
        SteamTitle(id: title.id, title: title.title, year: title.year,
                   badge: title.badge, colors: title.colors, mods: applicableMods)
    }

    var body: some View {
        SteamRowLayout(spacing: 14) {
            SteamTile(title: steamTileProxy, size: 44)
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
                if let folder {
                    Text("· \(folder.lastPathComponent)")
                        .font(.system(size: 10)).opacity(0.45)
                        .lineLimit(1).truncationMode(.middle)
                        .help(folder.path)
                }
            }
            if folder != nil, let avoid = title.avoid {
                Label(avoid, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if folder != nil, let known = title.known {
                Label(known, systemImage: "info.circle")
                    .font(.system(size: 10))
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var actions: some View {
        if let folder {
            if !applicableMods.isEmpty { modPicker }
            Button { state.playOwn(title) } label: { Label(title.mode.title, systemImage: title.mode.symbol) }
                .buttonStyle(.borderedProminent)
                .disabled(!isReady || state.running != nil || state.progress != nil)
            Menu {
                Button("Change folder…") { state.chooseOwnFolder(for: title) }
                    .disabled(state.running != nil || state.progress != nil)
                Button("Show the game's folder") { NSWorkspace.shared.open(folder) }
                if let linked = linkedClient, state.gameFolderProblem(linked, folder) == nil {
                    Button("Use this folder in \(linked.client)") { state.useSteamFolder(linked, folder.path) }
                }
                Divider()
                Button("Forget folder", role: .destructive) { state.forgetOwnFolder(for: title) }
                    .disabled(state.running != nil || state.progress != nil)
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        } else {
            Button { state.chooseOwnFolder(for: title) } label: {
                Label("Choose Folder…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.running != nil || state.progress != nil)
            .help("Choose your \(title.title) Windows game folder")
        }
    }

    @ViewBuilder private var modPicker: some View {
        let chosen = state.ownMod(title)
        HStack(spacing: 4) {
            Menu {
                Button { state.setOwnMod(title, nil) } label: {
                    if chosen == nil { Label("None", systemImage: "checkmark") } else { Text("None") }
                }
                ForEach(applicableMods) { mod in
                    Button { state.setOwnMod(title, mod) } label: {
                        if chosen?.id == mod.id { Label("\(mod.title) (\(mod.parts))", systemImage: "checkmark") }
                        else { Text("\(mod.title) (\(mod.parts))") }
                    }
                }
            } label: {
                Label(chosen?.title ?? "No fix", systemImage: "wrench.and.screwdriver")
            }
            .fixedSize()
            .disabled(state.running != nil || state.progress != nil)
            .help("A community fix used when this campaign starts. None: the game exactly as Siliconium plays it.")
            Button { showModInfo.toggle() } label: { Image(systemName: "info.circle") }
                .buttonStyle(.borderless)
                .help("What each fix does")
                .popover(isPresented: $showModInfo, arrowEdge: .bottom) { SteamModInfo(title: steamTileProxy) }
        }
    }

    private var statusText: String {
        if folder != nil { return state.engineInstalled ? "Ready" : "Engine required" }
        return "Folder not set"
    }

    private var dotColor: Color {
        if isReady { return Color(red: 0.30, green: 0.82, blue: 0.48) }
        if folder != nil { return Color.orange }
        return .white.opacity(0.35)
    }
}
