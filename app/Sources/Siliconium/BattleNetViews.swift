import AppKit
import SwiftUI

/// The Battle.net section (owner 2026-11-22: right below the Steam Library):
/// Battle.net for Windows in its own Wine prefix (kit/battlenet.sh), for the
/// Call of Duty games sold only there, starting with Black Ops 4. The player
/// signs in and installs the game in Battle.net's own window; Play starts it
/// through Battle.net with Siliconium's settings (launch.sh battlenet <id>).
struct BattleNetView: View {
    @EnvironmentObject var state: AppState

    private var installed: Bool { state.battlenet["battlenet"] == "installed" }
    private var signedIn: Bool { state.battlenet["signedin"] == "yes" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !(state.engineInstalled && installed && signedIn) {
                VStack(alignment: .leading, spacing: 14) {
                    Check(done: state.engineInstalled, title: "Siliconium engine",
                          detail: "Downloads our engine, built from open source, and adds our patches. About 330 MB.") {
                        Button("Install") { state.installEngine() }.disabled(state.progress != nil)
                    }
                    Check(done: installed, title: "Battle.net for Windows",
                          detail: "Downloads Blizzard's Battle.net installer and installs it in its own Wine prefix, apart from Steam and the other games. Confirm in the installer's window.") {
                        Button("Install Battle.net") { state.setupBattleNet() }
                            .disabled(!state.engineInstalled || state.progress != nil)
                    }
                    Check(done: signedIn, title: "Signed in to Battle.net",
                          detail: "Sign in with your Battle.net account and tick Keep me logged in, so Siliconium can start Battle.net in the background.") {
                        Button("Open Battle.net") { state.openBattleNet() }.disabled(!installed)
                    }
                }
                .padding(18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Button { state.openBattleNet() } label: {
                        Label("Open Battle.net", systemImage: "arrow.up.forward.app")
                    }
                    Text("Installs keep going while Battle.net is open in the background.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
            }

            // In a ScrollView, like the Steam Library's rows. Outside one, the
            // window measured a row at zero width (SteamRowLayout then wraps the
            // details a letter per line, ~950 pt tall): the window's content
            // grew taller than the window and was cut off at the top and bottom,
            // the sidebar sliding under the window buttons.
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(BattleNetTitle.catalog) { title in
                        BattleNetTitleRow(title: title, ready: installed)
                    }
                }
                .padding(.bottom, 32)   // the last row can scroll clear of the edge
            }
        }
        .task {
            // Battle.net's installs move on their own: keep the states current
            while !Task.isCancelled {
                state.refreshBattleNet()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

struct BattleNetTitleRow: View {
    @EnvironmentObject var state: AppState
    let title: BattleNetTitle
    let ready: Bool

    private var gameState: String { state.battlenetLibrary[title.id]?.state ?? "missing" }
    private var folder: String { state.battlenetLibrary[title.id]?.folder ?? "" }

    var body: some View {
        SteamRowLayout(spacing: 14) {
            SteamTile(title: SteamTitle(id: title.id, title: title.title, year: title.year,
                                        badge: title.badge, colors: title.colors), size: 44)
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
            Text(title.modes).font(.system(size: 10)).opacity(0.5)
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
            Button { state.playBattleNet(title) } label: { Label("Play", systemImage: "play.fill") }
                .buttonStyle(.borderedProminent)
                .disabled(state.running != nil || state.progress != nil)
                .help("Starts \(title.title) through Battle.net, with Siliconium's settings. Choose Zombies, Multiplayer or Blackout in the game's menu.")
            Menu {
                if !folder.isEmpty {
                    Button("Show the game's folder") { NSWorkspace.shared.open(URL(fileURLWithPath: folder)) }
                }
                Button("Open Battle.net") { state.openBattleNet() }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        case "downloading":
            Button("Open Battle.net") { state.openBattleNet() }
                .help("Battle.net is installing or updating \(title.title): this opens Battle.net to see its progress.")
        default:
            Button("Install") { state.downloadBattleNetGame(title.id) }
                .buttonStyle(.borderedProminent)
                .disabled(!ready || state.progress != nil)
                .help("Opens \(title.title) in Battle.net: press Install there (your account must own it). It needs a lot of disk space: Black Ops 4 with every mode is about 152 GB (November 2026).")
        }
    }

    private var statusText: String {
        switch gameState {
        case "installed": "Installed"
        case "downloading": "Installing in Battle.net"
        default: "Not installed"
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
