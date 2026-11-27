import Foundation
import SwiftUI

// MARK: - Games

/// The sidebar's tabs and the games in each, in order.
enum GameTab: String, CaseIterable, Identifiable {
    // (the sidebar's order: Steam, Battle.net, Plutonium, CoD4X, IW4X, BOIII/EZZ, IW7-Mod, AlterWare, Offline)
    case steam, battlenet, plutonium, cod4x, iw4x, bo3, iw7mod, alterware, others
    var id: String { rawValue }
    var title: String {
        switch self {
        case .plutonium: "Plutonium"
        case .bo3: "BOIII/EZZ"
        case .cod4x: "CoD4X"
        case .iw4x: "IW4X"
        // (CBServers' fork of AuroraMod's IW7-Mod)
        case .iw7mod: "IW7-Mod (CBServers)"
        case .alterware: "AlterWare"
        case .others: "Offline"
        case .steam: "Steam"
        case .battlenet: "Battle.net"
        }
    }
    var games: [Game] {
        switch self {
        case .plutonium: [.plutonium]
        case .bo3: [.boiii, .bo3]
        case .cod4x: [.cod4x]
        case .iw4x: [.iw4]
        case .iw7mod: [.iw7mod]
        // only an explanation: AlterWare's Ghosts client cannot sign in online
        // under Rosetta 2 and its Advanced Warfare client was discontinued
        case .alterware: [.alterware]
        // Offline games live inside "Your Own Game Files" (Campaign for CoD 4,
        // MW2, MW3, Black Ops II and Ghosts from user-chosen Windows folders,
        // without Steam or a separate manual prefix).
        case .others: [.ownFiles]
        case .steam: [.steam]
        case .battlenet: [.battlenet]
        }
    }
    static func of(_ game: Game) -> GameTab {
        if game.usesPlutonium { return .plutonium }
        return allCases.first { $0.games.contains(game) } ?? .plutonium
    }
}

enum Game: String, CaseIterable, Identifiable {
    case plutonium, waw, bo1, bo2, iw5, iw4, ownFiles, bo3, boiii, steam, battlenet, cod4x, iw7mod, alterware
    var id: String { rawValue }

    /// The four games managed inside the unified Plutonium Launcher section.
    static let plutoniumGames: [Game] = [.waw, .bo1, .bo2, .iw5]

    /// Maps saved/legacy identifiers (e.g. from earlier versions) to their current sidebar tab.
    static func sidebarTarget(for raw: String) -> Game? {
        switch raw {
        case "iw6", "bo2c": return .ownFiles
        case "bo2s": return .steam
        case "waw", "bo1", "bo2", "iw5": return .plutonium
        default:
            guard let g = Game(rawValue: raw) else { return nil }
            return g.usesPlutonium ? .plutonium : g
        }
    }

    var title: String {
        switch self {
        case .plutonium: "Plutonium Launcher"
        case .waw: "World at War"
        case .bo1: "Black Ops"
        case .bo2: "Black Ops II"
        case .iw5: "Modern Warfare 3"
        case .iw4: "Modern Warfare 2"
        case .ownFiles: "Your Own Game Files"
        case .bo3: "Black Ops III for Mac"
        case .boiii: "Black Ops III"
        case .steam: "Steam Library"
        case .battlenet: "Battle.net"
        case .cod4x: "Call of Duty 4"
        case .iw7mod: "Infinite Warfare"
        case .alterware: "Ghosts, Advanced Warfare"
        }
    }
    /// A game option that hurts the game on a Mac (shown on its page or row)
    var avoid: String? {
        switch self {
        case .bo2: "Keep Depth of Field off in the game's options: on a Mac it makes the game lag badly."
        default: nil
        }
    }
    /// Release year (or game count on collection tiles), shown like an atomic number on the tile.
    var year: String {
        switch self {
        case .plutonium: "4"
        case .waw: "2008"
        case .bo1: "2010"
        case .bo2: "2012"
        case .iw5: "2011"
        case .iw4: "2009"
        case .ownFiles: "5"
        case .alterware: "–"
        case .bo3, .boiii: "2015"
        case .steam: "10"
        case .battlenet: "1"
        case .cod4x: "2007"
        case .iw7mod: "2016"
        }
    }
    /// Who runs it, under the code on the game's tile.
    var client: String {
        switch self {
        case .plutonium, .waw, .bo1, .bo2, .iw5: "Plutonium"
        case .iw4: "IW4X"
        case .ownFiles: "Offline"
        case .bo3: "Steam"
        case .boiii: "Ezz"
        case .steam: "Steam"
        case .battlenet: "Battle.net"
        case .cod4x: "CoD4X"
        case .iw7mod: "IW7-Mod (CBServers)"
        case .alterware: "AlterWare"
        }
    }
    /// The client's name on the game's tile (it has room for one short word:
    /// "IW7-MOD (CBSERVERS)" was cut off)
    var tileClient: String { self == .iw7mod ? "CBServers" : client }
    var subtitle: String {
        switch self {
        case .plutonium: "Plutonium · World at War, Black Ops, Black Ops II and Modern Warfare 3"
        case .bo1: "Plutonium · Zombies, Campaign, Multiplayer"
        case .bo2: "Plutonium · Zombies, Multiplayer"
        case .iw5: "Plutonium · Multiplayer"
        case .iw4: "IW4X · Multiplayer"
        case .ownFiles: "Offline · Campaign · your own Windows game folders, no Steam"
        case .bo3: "Native Mac game · community servers"
        case .boiii: "BOIII · Ezz community servers"
        case .waw: "Plutonium · Zombies, Campaign, Multiplayer"
        case .steam: "Steam for Windows · download your Call of Duty games"
        case .battlenet: "Battle.net for Windows · Black Ops 4"
        case .cod4x: "CoD4X · Multiplayer"
        case .iw7mod: "IW7-Mod (CBServers) · Campaign, Multiplayer, Zombies, custom maps"
        case .alterware: "AlterWare · not available on Apple silicon"
        }
    }
    var symbol: String {
        switch self {
        case .plutonium: "atom"
        case .bo1: "1.circle.fill"
        case .bo2: "2.circle.fill"
        case .iw5: "5.circle.fill"
        case .iw4: "flame.fill"
        case .ownFiles: "folder.fill"
        case .bo3: "3.circle.fill"
        case .boiii: "3.square.fill"
        case .waw: "4.circle.fill"
        case .steam: "cart.fill"
        case .battlenet: "bolt.horizontal.fill"
        case .cod4x: "scope"
        case .iw7mod: "sparkles"
        case .alterware: "info.circle"
        }
    }
    /// The short engine/element code shown in the sidebar's game badge.
    var badge: String {
        switch self {
        case .plutonium: "Pu"
        case .waw: "T4"
        case .bo1: "T5"
        case .bo2: "T6"
        case .iw5: "IW5"
        case .iw4: "IW4"
        case .ownFiles: "Own"
        case .alterware: "AW"
        case .bo3, .boiii: "T7"
        case .steam: "St"
        case .battlenet: "Bn"
        case .cod4x: "IW3"
        case .iw7mod: "IW7"
        }
    }
    var colors: [Color] {
        switch self {
        case .plutonium: [Color(red: 0.48, green: 0.28, blue: 0.88), Color(red: 0.14, green: 0.06, blue: 0.30)]
        case .bo1: [Color(red: 0.20, green: 0.55, blue: 0.95), Color(red: 0.04, green: 0.12, blue: 0.35)]
        case .bo2: [Color(red: 0.92, green: 0.18, blue: 0.20), Color(red: 0.30, green: 0.04, blue: 0.06)]
        case .iw5: [Color(red: 0.42, green: 0.58, blue: 0.32), Color(red: 0.10, green: 0.16, blue: 0.08)]
        case .iw4: [Color(red: 0.96, green: 0.40, blue: 0.06), Color(red: 0.28, green: 0.05, blue: 0.01)]
        case .ownFiles: [Color(red: 0.30, green: 0.54, blue: 0.64), Color(red: 0.07, green: 0.13, blue: 0.18)]
        case .bo3, .boiii: [Color(red: 0.98, green: 0.52, blue: 0.10), Color(red: 0.35, green: 0.12, blue: 0.03)]
        case .waw: [Color(red: 0.62, green: 0.58, blue: 0.36), Color(red: 0.16, green: 0.15, blue: 0.08)]
        case .steam: [Color(red: 0.16, green: 0.47, blue: 0.80), Color(red: 0.05, green: 0.10, blue: 0.20)]
        case .battlenet: [Color(red: 0.00, green: 0.56, blue: 0.94), Color(red: 0.02, green: 0.09, blue: 0.22)]
        case .cod4x: [Color(red: 0.36, green: 0.50, blue: 0.30), Color(red: 0.08, green: 0.13, blue: 0.07)]
        case .iw7mod: [Color(red: 0.32, green: 0.46, blue: 0.62), Color(red: 0.06, green: 0.09, blue: 0.15)]
        case .alterware: [Color(white: 0.36), Color(white: 0.12)]
        }
    }
    /// Settings key of the game folder.
    var folderKey: String? {
        switch self {
        case .waw: "WAW_DIR"
        case .bo1: "BO1_DIR"
        case .bo2: "BO2_DIR"
        case .iw5: "IW5_DIR"
        case .iw4: "IW4_DIR"
        case .boiii: "BOIII_DIR"
        case .cod4x: "COD4X_DIR"
        case .iw7mod: "IW7MOD_DIR"
        default: nil
        }
    }
    var usesEngine: Bool { self != .bo3 && self != .alterware }
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
        case .cod4x: [PlayMode(id: "play", title: "Play CoD4X", symbol: "play.fill")]
        case .iw7mod: [PlayMode(id: "play", title: "Play IW7-Mod", symbol: "play.fill")]
        case .boiii: [PlayMode(id: "launcher", title: "Open BOIII", symbol: "play.fill")]
        default: []
        }
    }
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
    /// A visible button that plays this download with the linked game's client
    /// (its label), besides the ⋯ menu's "Use this download in…"
    var linkedButton: String? = nil
    /// The game has a Steam Workshop (mods and maps)
    var workshop = false
    /// The game's Steam tools for making maps and mods (steam.sh tools: their
    /// name there, e.g. ModTools), downloaded only from their own button
    var tools: String? = nil
    /// Game options that break the game on a Mac (Siliconium turns them off at every start)
    var avoid: String? = nil
    /// A known problem on a Mac that Siliconium cannot fix yet (shown under Play)
    var known: String? = nil
    /// What Play starts (launch.sh steam <id>-<mode>): the part and its executable
    var modes: [Mode] = []
    struct Mode: Identifiable {
        let id: String       // sp | mp | zm
        let title: String
        let exe: String
        var symbol: String { id == "mp" ? "person.3.fill" : id == "zm" ? "hand.raised.fill" : "figure.walk" }
    }
    /// Community fixes the player can choose for this game (kit/tools/steam-mods.sh, same ids)
    var mods: [Mod] = []
    struct Mod: Identifiable {
        let id: String       // settings.conf STEAM_MOD_<GAME>=<id>
        let title: String
        let parts: String    // what it applies to, as the player sees it
        let about: String    // the ⓘ text
        let source: String   // its author's page
        let license: String
        var warning: String? = nil
        /// Not a fix: choosing it opens the linked game's tab (its own client)
        var opensLinked = false
    }

    static let ghostsColors: [Color] = [Color(white: 0.47), Color(white: 0.15)]

    /// Call of Duty 4 campaign fix (used in Steam Library and Your Own Game Files)
    static let iw3spmod = Mod(id: "iw3spmod", title: "IW3SP-MOD", parts: "Campaign",
        about: "The campaign with real controller support (analog sticks, console aim assist, controller button prompts and menus), no frame-rate cap, raw mouse input and many fixes. Siliconium downloads it from its author the first time (about 14 MB), keeps its updater off, and takes its files out of the game's folder when the game quits: the game's own files are never changed.",
        source: "https://gitea.com/JerryALT/iw3sp_mod", license: "GPL-3.0 (by JerryALT)")
    /// Black Ops II campaign client (used in Steam Library and Your Own Game Files)
    static let t6spmod = Mod(id: "t6spmod", title: "T6SP-Mod", parts: "Campaign",
        about: "Rattpak's campaign client: a developer console, unlocked settings (a field of view above 90), gamepad aim assist (pc_aim_assist 1) and its own autoexec config. On offline copies it also avoids Rosetta 2 data-breakpoint crashes in modified executables. Siliconium downloads it from its author the first time and takes its files out of the game's folder when the game quits: the game's own files are never changed.",
        source: "https://github.com/Rattpak/T6SP-Mod-Release", license: "Closed source: downloaded from its author, never shipped",
        warning: "Antivirus tools flag it because it injects a DLL into the game (that is how it works).")

    /// Modern Warfare 2 and 3 (64-bit and 32-bit campaigns): one fix for both
    static let iwPad = Mod(id: "iwpad", title: "IW-Pad", parts: "Campaign",
        about: "Real controller support for the campaign (analog sticks, console aim assist, controller button prompts and menu navigation) in place of Siliconium's keyboard-and-mouse controller mapping; the mouse keeps working. Supports both 64-bit Steam copies and standard 32-bit retail/offline builds (it checks the build automatically). Siliconium downloads it from its GitHub release the first time and takes its files out of the game's folder when the game quits.",
        source: "https://github.com/GalvarinoDev/IW-Pad", license: "GPL-3.0 (by GalvarinoDev)")

    /// The multiplayer community clients, each in its own tab (as Ezz's BOIII for
    /// Black Ops III): choosing one opens that tab, which plays this same Steam
    /// download when it has no game folder of its own
    static let iw4x = Mod(id: "iw4x", title: "IW4X", parts: "Multiplayer",
        about: "Not a fix: opens the IW4X tab, the community multiplayer client (dedicated servers, mods, its own server list) that plays this same Steam download when that tab has no game folder of its own. IW4X's launcher adds its own files next to the game's and keeps them up to date: its client, its maps and DLC (about 3 GB), and on the first start a copy of the game's maps converted for its client (about 4 GB, takes a while). Steam's own files are not changed.",
        source: "https://github.com/iw4x/launcher", license: "GPL-3.0", opensLinked: true)
    static let cod4x = Mod(id: "cod4x", title: "CoD4X", parts: "Multiplayer",
        about: "Not a fix: opens the CoD4X tab, the community multiplayer client (its own servers and server list, security and bug fixes, no PunkBuster) that plays this same Steam download when that tab has no game folder of its own. CoD4X needs its own copy of the 1.7 executable and its loader in place of two of the game's files, so it plays from a copy of this download in Siliconium's folder (made with APFS clones: it takes no extra disk space) and Steam's own files are never changed. Siliconium installs it from CoD4X's official releases; it keeps itself up to date.",
        source: "https://cod4x.ovh", license: "Free (CoD4X team; launcher and loader MIT)", opensLinked: true)
    /// Infinite Warfare: Play starts CBServers' IW7-Mod instead of the game as
    /// it is (launch.sh steam iw-sp with STEAM_MOD_IW=iw7mod = the IW7-Mod tab's
    /// Play on this download); None: Steam's game exactly as before
    static let iw7mod = Mod(id: "iw7mod", title: "IW7-Mod (CBServers)", parts: "Every mode",
        about: "CBServers' fork of AuroraMod's IW7-Mod community client: Play starts it instead of the game as it is (CBServers' servers and server browser, bots, Zombies and the campaign, custom maps from the game folder's usermaps; no Steam needed), with the same Siliconium setup and the same shader caches. Steam's own files are never changed: IW7-Mod plays from its own copy of this download in Siliconium's folder (APFS clones: no extra disk space) and keeps its own profile and saves there. Choose None to play the normal game again. Siliconium downloads it from CBServers the first time; it then keeps itself up to date (the first start also downloads its data, about 400 MB). The IW7-Mod (CBServers) tab plays the same copy.",
        source: "https://github.com/CBServers/iw7-mod", license: "GPL-3.0 (CBServers' fork of AuroraMod's IW7-Mod)")
    static let catalog: [SteamTitle] = [
        .init(id: "cod1", title: "Call of Duty", year: "2003", badge: "CoD",
              colors: [Color(red: 0.55, green: 0.47, blue: 0.33), Color(red: 0.14, green: 0.11, blue: 0.07)],
              modes: [.init(id: "sp", title: "Campaign", exe: "CoDSP.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoDMP.exe")]),
        .init(id: "uo", title: "Call of Duty: United Offensive", year: "2004", badge: "UO",
              colors: [Color(red: 0.58, green: 0.36, blue: 0.24), Color(red: 0.15, green: 0.08, blue: 0.05)],
              modes: [.init(id: "sp", title: "Campaign", exe: "CoDUOSP.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoDUOMP.exe")]),
        .init(id: "cod2", title: "Call of Duty 2", year: "2005", badge: "CoD2",
              colors: [Color(red: 0.50, green: 0.52, blue: 0.48), Color(red: 0.12, green: 0.13, blue: 0.12)],
              modes: [.init(id: "sp", title: "Campaign", exe: "CoD2SP_s.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoD2MP_s.exe")]),
        .init(id: "cod4", title: "Call of Duty 4: Modern Warfare", year: "2007", badge: "IW3",
              colors: [Color(red: 0.36, green: 0.50, blue: 0.30), Color(red: 0.08, green: 0.13, blue: 0.07)],
              linked: .cod4x,
              modes: [.init(id: "sp", title: "Campaign", exe: "iw3sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw3mp.exe")],
              mods: [iw3spmod, cod4x]),
        .init(id: "waw", title: "World at War", year: "2008", badge: "T4",
              colors: Game.waw.colors, linked: .waw,
              modes: [.init(id: "sp", title: "Campaign & Zombies", exe: "CoDWaW.exe"), .init(id: "mp", title: "Multiplayer", exe: "CoDWaWmp.exe")],
              mods: [.init(id: "t4me", title: "T4Me", parts: "Campaign & Zombies",
                           about: "T4M Enhanced: higher engine limits (fewer missing textures and crashes with big maps and mods), an unlocked field of view, controller navigation in menus and gamepad auto-aim, and a HUD-scale fix. Drawing stays on Siliconium's own DXVK and audio on the game's own; it never patches the game's executable. Siliconium downloads it from its GitHub release the first time and takes its files out of the game's folder when the game quits.",
                           source: "https://github.com/JBShady/T4M-Enhanced", license: "No licence: downloaded from its author, never shipped")]),
        .init(id: "mw2", title: "Modern Warfare 2", year: "2009", badge: "IW4",
              colors: Game.iw4.colors, linked: .iw4,
              known: "Known issue: the cutscene videos sometimes show colored blocks for a moment. Gameplay is not affected.",
              modes: [.init(id: "sp", title: "Campaign", exe: "iw4sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw4mp.exe")],
              mods: [iwPad, iw4x]),
        .init(id: "bo1", title: "Black Ops", year: "2010", badge: "T5",
              colors: Game.bo1.colors, linked: .bo1,
              modes: [.init(id: "sp", title: "Campaign & Zombies", exe: "BlackOps.exe"), .init(id: "mp", title: "Multiplayer", exe: "BlackOpsMP.exe")]),
        .init(id: "mw3", title: "Modern Warfare 3", year: "2011", badge: "IW5",
              colors: Game.iw5.colors,
              note: "Steam's Modern Warfare 3 is the 64-bit update; Plutonium needs the 32-bit game.",
              known: "Known issue: the cutscene videos sometimes show colored blocks for a moment. Gameplay is not affected.",
              modes: [.init(id: "sp", title: "Campaign", exe: "iw5sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw5mp.exe")],
              mods: [iwPad]),
        .init(id: "bo2", title: "Black Ops II", year: "2012", badge: "T6",
              colors: Game.bo2.colors, linked: .bo2,
              avoid: "Keep Depth of Field off in the game's options: on a Mac it makes the game lag badly.",
              modes: [.init(id: "sp", title: "Campaign", exe: "t6sp.exe"), .init(id: "mp", title: "Multiplayer", exe: "t6mp.exe"), .init(id: "zm", title: "Zombies", exe: "t6zm.exe")],
              mods: [t6spmod]),
        .init(id: "ghosts", title: "Ghosts", year: "2013", badge: "IW6",
              colors: ghostsColors,
              avoid: "Keep Ambient Occlusion (SSAO) and Tessellation off in the game's options: on a Mac they freeze the GPU within minutes. Siliconium turns them off at every start.",
              modes: [.init(id: "sp", title: "Campaign", exe: "iw6sp64_ship.exe"), .init(id: "mp", title: "Multiplayer", exe: "iw6mp64_ship.exe")]),
        .init(id: "aw", title: "Advanced Warfare", year: "2014", badge: "S1",
              colors: [Color(red: 0.85, green: 0.70, blue: 0.25), Color(red: 0.22, green: 0.16, blue: 0.04)],
              note: "Multiplayer and Exo Zombies do not work: they stay at \"Connecting to online services\", and AlterWare's s1-mod, the community client that played them, was discontinued and does not accept Steam's current version of the game.",
              known: "Entering a mission takes a while: after its intro video the game preloads its shaders (about 1-2 minutes). The first time is longer while Siliconium builds its shader cache; later loads are faster.",
              modes: [.init(id: "sp", title: "Campaign", exe: "s1_sp64_ship.exe"), .init(id: "mp", title: "Multiplayer", exe: "s1_mp64_ship.exe")]),
        .init(id: "bo3", title: "Black Ops III", year: "2015", badge: "T7",
              colors: Game.boiii.colors, linked: .boiii, linkedButton: "Play with BOIII", workshop: true, tools: "ModTools",
              modes: [.init(id: "sp", title: "Play", exe: "BlackOps3.exe")],
              mods: [.init(id: "cleanops", title: "Clean Ops", parts: "Every mode",
                           about: "The community patch for Black Ops III's Multiplayer: protection against exploits, crashes and remote attacks, its own cheater blacklist (listed players are kicked from lobbies with a Clean Ops player), peer-to-peer hosting with its own server browser and lobby tools, and an in-game menu that opens by itself when the game starts. That menu's key is Insert, which Mac keyboards lack: choose End (fn+→ on a Mac keyboard) as its Menu Hotkey there, once. It loads in every mode, and in the map tests the Mod Tools start. It updates itself from its author's GitHub when the game starts; Siliconium keeps its newest copy and its settings for the next game. Siliconium downloads it from its author the first time and takes it out of the game's folder when the game quits: the game's own files are never changed.",
                           source: "https://cleanops.dev", license: "Closed source: downloaded from its author, never shipped",
                           warning: "Closed source and packed, so antivirus tools may flag it. At every start it sends your Steam ID and IP address to its own server, and shares your IP with other Clean Ops players when you host."),
                     .init(id: "boiii", title: "Ezz (BOIII)", parts: "Its own tab",
                           about: "Not a fix: opens the Black Ops III tab, where Ezz's BOIII client plays this same Steam download.",
                           source: "https://github.com/Ezz-lol/boiii-free", license: "GPL-3.0", opensLinked: true)]),
        .init(id: "iw", title: "Infinite Warfare", year: "2016", badge: "IW7",
              colors: Game.iw7mod.colors, linked: .iw7mod,
              known: "The first start prepares the game's shaders once (\"Preloading Shaders\", a few minutes). Later starts reach the menu in seconds.",
              modes: [.init(id: "sp", title: "Play", exe: "iw7_ship.exe")],
              mods: [iw7mod]),
        .init(id: "wwii", title: "WWII", year: "2017", badge: "S2",
              colors: [Color(red: 0.62, green: 0.55, blue: 0.36), Color(red: 0.16, green: 0.14, blue: 0.08)],
              known: "Loading a campaign mission takes about 2-3 minutes. The first time Multiplayer or Nazi Zombies opens, Activision's license appears in the game.",
              modes: [.init(id: "sp", title: "Campaign", exe: "s2_sp64_ship.exe"), .init(id: "mp", title: "Multiplayer", exe: "s2_mp64_ship.exe"), .init(id: "zm", title: "Nazi Zombies", exe: "s2_mp64_ship.exe")]),
    ]
}

/// A game of the Battle.net section (kit/tools/battlenet-games.sh's catalog, same ids).
struct BattleNetTitle: Identifiable {
    let id: String
    let title: String
    let year: String
    let badge: String
    let colors: [Color]
    /// Its executable (the window Siliconium waits for)
    let exe: String
    /// What Play starts, as the player sees it
    let modes: String
    /// A known problem on a Mac that Siliconium cannot fix yet (shown under Play)
    var known: String? = nil
    /// Community fixes the player can choose (kit/tools/steam-mods.sh, same ids;
    /// settings.conf STEAM_MOD_<GAME>=<id>, as the Steam Library's)
    var mods: [SteamTitle.Mod] = []

    /// Black Ops 4: Project-BO4's Shield (offline client)
    static let shield = SteamTitle.Mod(id: "shield", title: "Shield (Project-BO4)", parts: "Every mode",
        about: "Project-BO4's Shield, the community client for Black Ops 4: its built-in Demonware server emulator plays the game without Battle.net's online services (Zombies, Multiplayer and Blackout, offline), with an in-game console and GSC and Lua mods (in the game folder's project-bo4/mods). With it, Play starts the game directly, not through Battle.net; Battle.net must have started the game once before (it downloads the files Shield needs). Siliconium uses Build R2, the community's update for the game's current version (project-bo4's own release closes the current game), downloads it from GitHub the first time and takes it out of the game's folder when the game quits, with Shield's own settings and log: the game's own files are never changed. Your progress with Shield is a separate offline profile.",
        source: "https://github.com/project-bo4/shield-development", license: "GPL-3.0 (project-bo4; Build R2 by Scroptss)",
        warning: "Unofficial: a community client, not Activision's or Blizzard's. Build R2 comes from a fork whose update project-bo4 has not merged yet.")

    static let catalog: [BattleNetTitle] = [
        .init(id: "bo4", title: "Black Ops 4", year: "2018", badge: "T8",
              colors: [Color(red: 0.95, green: 0.42, blue: 0.12), Color(red: 0.26, green: 0.08, blue: 0.03)],
              exe: "BlackOps4.exe", modes: "Zombies, Multiplayer, Blackout", mods: [shield]),
    ]
}

/// A game under Offline -> "Your Own Game Files" (disc / retail / offline
/// Windows folders chosen by the player; Campaign only, same catalog names,
/// row design and community fixes as the Steam Library, launched directly
/// without Steam via `launch.sh own`).
struct OwnGameTitle: Identifiable {
    let id: String              // cod4 | mw2 | mw3 | bo2 | ghosts
    let title: String
    let year: String
    let badge: String
    let colors: [Color]
    let folderKey: String       // settings.conf OWN_<ID>_DIR
    var legacyFolderKey: String? = nil
    let requiredDirs: [String]  // e.g. ["main", "zone"] or ["zone"]
    var avoid: String? = nil
    var known: String? = nil
    let mode: SteamTitle.Mode   // Campaign only
    var mods: [SteamTitle.Mod] = []
    /// Default fix when the player has not explicitly chosen one (nil = None)
    var defaultModId: String? = nil

    static let catalog: [OwnGameTitle] = [
        .init(id: "cod4", title: "Call of Duty 4: Modern Warfare", year: "2007", badge: "IW3",
              colors: [Color(red: 0.36, green: 0.50, blue: 0.30), Color(red: 0.08, green: 0.13, blue: 0.07)],
              folderKey: "OWN_COD4_DIR", requiredDirs: ["main", "zone"],
              mode: .init(id: "sp", title: "Campaign", exe: "iw3sp.exe"),
              mods: [SteamTitle.iw3spmod]),
        .init(id: "mw2", title: "Modern Warfare 2", year: "2009", badge: "IW4",
              colors: Game.iw4.colors,
              folderKey: "OWN_MW2_DIR", requiredDirs: ["main", "zone"],
              known: "Known issue: the cutscene videos sometimes show colored blocks for a moment. Gameplay is not affected.",
              mode: .init(id: "sp", title: "Campaign", exe: "iw4sp.exe"),
              mods: [SteamTitle.iwPad]),
        .init(id: "mw3", title: "Modern Warfare 3", year: "2011", badge: "IW5",
              colors: Game.iw5.colors,
              folderKey: "OWN_MW3_DIR", requiredDirs: ["main", "zone"],
              known: "Known issue: the cutscene videos sometimes show colored blocks for a moment. Gameplay is not affected.",
              mode: .init(id: "sp", title: "Campaign", exe: "iw5sp.exe"),
              mods: [SteamTitle.iwPad]),
        .init(id: "bo2", title: "Black Ops II", year: "2012", badge: "T6",
              colors: Game.bo2.colors,
              folderKey: "OWN_BO2_DIR", requiredDirs: ["zone"],
              avoid: "Keep Depth of Field off in the game's options: on a Mac it makes the game lag badly.",
              mode: .init(id: "sp", title: "Campaign", exe: "t6sp.exe"),
              mods: [SteamTitle.t6spmod], defaultModId: "t6spmod"),
        .init(id: "ghosts", title: "Ghosts", year: "2013", badge: "IW6",
              colors: SteamTitle.ghostsColors,
              folderKey: "OWN_GHOSTS_DIR", legacyFolderKey: "IW6_DIR", requiredDirs: ["zone"],
              avoid: "Keep Ambient Occlusion (SSAO) and Tessellation off in the game's options: on a Mac they freeze the GPU within minutes. Siliconium turns them off at every start.",
              mode: .init(id: "sp", title: "Campaign", exe: "iw6sp64_ship.exe")),
    ]
}

struct PlayMode: Identifiable {
    let id: String      // launch.sh mode
    let title: String
    let symbol: String
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
        Patch(key: "X87", title: "x87 acceleration",
              info: "Runs the games' old x87 floating-point maths as native ARM code with athei's x87sidecar (based on Lifeisawful's rosettax87), instead of Rosetta's slow emulation. The biggest frame-rate gain.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .ownFiles]),
        Patch(key: "EXEC_ON_DEMAND", title: "Fast code execution",
              info: "Plutonium turns off DEP, so Wine would make the game's whole memory executable at once, which makes Rosetta re-check it constantly (BO2 ran in slow motion). Our engine makes each page executable only when it is first run.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .ownFiles, .boiii]),
        Patch(key: "RUMBLE_FIX", title: "Controller vibration without input delay",
              info: "Every vibration command is a round trip to the controller, and Wine made the controller's input wait for it twice: in XInput (the game waited too) and in its HID bus driver (winebus), which held the device lock during the write and so held back every stick and button report. Aiming and shooting lagged whenever the controller rumbled. Ours sends vibration from its own thread and writes it without blocking input.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .ownFiles, .boiii]),
        Patch(key: "RAW_INPUT", title: "Raw mouse input",
              info: "Reads the mouse directly, without macOS pointer acceleration or smoothing, so aim follows your hand 1:1.",
              games: [.waw, .bo1, .bo2, .ownFiles]),
        Patch(key: "CONSOLE_AIM", title: "Console controller aim",
              info: "Makes the controller aim like on the consoles: turn acceleration, the console's turn speeds (slower up/down and while aiming down sights) and aim assist (slowdown and lock-on over targets). Applies to zombies, campaign and multiplayer; mouse aim is not affected.",
              games: [.waw, .bo1, .bo2, .ownFiles]),
        Patch(key: "DISPLAY_MODE", title: "Smart display mode in fullscreen",
              info: "D3D9 games on mtld3d and Black Ops II keep your sharp HiDPI desktop at full refresh rate with no mode switch. Heavy D3D11 games and DXVK fallback switch to a 1x mode on scaled displays so macOS does not draw every frame at 5K.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .cod4x, .ownFiles, .boiii]),
        Patch(key: "HIDE_ON_CMDTAB", title: "Hide fullscreen game on Cmd+Tab",
              info: "Automatically hides fullscreen games when you switch to another app so your desktop stays clean. Turn off if you want to capture or stream the game window directly in Discord's Applications tab or OBS.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .cod4x, .iw7mod, .ownFiles, .boiii]),
        Patch(key: "D3D9_MTLD3D", title: "Direct Metal renderer (mtld3d)",
              info: "Translates Direct3D 9 straight to Apple Metal instead of Vulkan/MoltenVK (patched mtld3d v0.15.5, macOS 15+). Uses up to 45% less memory, loads shader caches in under a second, keeps HiDPI sharp on scaled displays, and reduces GPU frame times. Turn off to fall back to DXVK + MoltenVK.",
              games: [.waw, .bo1, .iw5, .iw4, .cod4x, .ownFiles]),
        Patch(key: "MSAA_FIX", title: "Supported anti-aliasing",
              info: "Apple GPUs support up to 4x MSAA; higher settings in the games' configs are lowered to 4x so the game does not fall back or render wrongly.",
              games: [.waw, .bo1, .bo2, .iw5, .iw4, .ownFiles]),
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
              info: "Uses the XAudio2 from the game's own DirectX redistributable: with Wine's, Black Ops plays no gunfire sounds. Also used by Steam's Black Ops (campaign, Zombies and Multiplayer).",
              games: [.bo1]),
        // Black Ops II
        Patch(key: "BO2_MOUSE_LAG_FIX", title: "Fix mouse lag",
              info: "Enables Plutonium's fix for hitches when aiming with high-polling-rate mice in Black Ops II Zombies and Multiplayer.",
              games: [.bo2]),
        Patch(key: "BO2_ASYNC", title: "Background shader compilation",
              info: "DXMT compiles new Metal pipelines on separate threads instead of stopping the frame that needs them.",
              games: [.bo2, .ownFiles, .boiii]),
        Patch(key: "BO2_FRAME_PACING", title: "Frame pacing",
              info: "DXMT paces frames evenly at the frame-rate cap (the monitor's refresh rate by default) instead of letting them bunch up.",
              games: [.bo2, .ownFiles, .boiii]),
        Patch(key: "BO2_HW_PROFILE", title: "Safe hardware profile",
              info: "Starts Black Ops II with a blank hardware profile so it detects settings Apple GPUs support (otherwise it can pick 8x MSAA, which they do not have).",
              games: [.bo2, .ownFiles]),
        Patch(key: "BO2_XAUDIO", title: "Gunfire sound fix",
              info: "Uses the XAudio2 from the game's own DirectX redistributable: with Wine's, Black Ops II Zombies and Multiplayer play no gunfire and most weapon sounds on some Macs. Also used by Steam's Black Ops II Zombies and Multiplayer.",
              games: [.bo2]),
        // Modern Warfare 3 (Direct3D 9)
        Patch(key: "IW5_GRAPHICS", title: "Full-detail first start",
              info: "On its first start Modern Warfare 3 gets fullscreen at your display's size, VSync, 2x anti-aliasing, 16x anisotropic filtering and full-resolution textures. Only once: the game's options rule.",
              games: [.iw5]),
        Patch(key: "IW5_ASYNC", title: "Background shader compilation",
              info: "DXVK compiles Modern Warfare 3's new Direct3D 9 pipelines on separate threads instead of stopping the frame that needs them, so first-time effects, explosions and new areas do not stutter.",
              games: [.iw5]),
        Patch(key: "IW5_SHADER_CACHE", title: "Persistent shader caches",
              info: "Keeps compiled shaders between runs: DXVK's pipeline state cache and MoltenVK's translated Metal shaders. Maps you have played load and run without compiling every shader again.",
              games: [.iw5]),
        Patch(key: "IW5_METAL_PARALLEL", title: "Parallel Metal compilation",
              info: "Lets Metal compile shaders on every CPU core at once instead of a few at a time, so the first map load and new effects compile faster.",
              games: [.iw5]),
        // Modern Warfare 2 (IW4X)
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
        Patch(key: "BO1_SKIP_INTRO", offValue: "1", title: "Play the intro movie",
              info: "Plays Black Ops' startup intro movie when the game opens. Turn off to skip straight to the menu.",
              games: [.bo1]),
        Patch(key: "SKIP_INTRO", title: "Skip the intro movies",
              info: "Goes straight to the menu: the publisher and studio logo movies are not played when the game starts.",
              games: [.waw, .bo2, .iw5, .ownFiles]),
        Patch(key: "SETTINGS_GUARD", title: "Keep settings on \"Set Optimal Settings?\"",
              info: "When the game thinks the hardware changed (for example a profile copied from a Windows PC), it asks \"Set Optimal Settings?\". Answering Yes would replace Siliconium's settings with the game's guesses for an unknown GPU (lower resolution, no anti-aliasing, a 60 Hz mode). With this on, Yes keeps your settings exactly like No.",
              games: [.waw, .bo1, .iw5, .iw4]),
        Patch(key: "CURSOR_FIX", title: "Smooth frame rate with fast mice (macOS 26+)",
              info: "On macOS 26 and later, hiding the cursor makes every frame wait on mouse movement, so a 1000 Hz mouse lowered the frame rate. Black Ops II's invisible-cursor fix is applied to this game too. No effect on macOS 15.",
              games: [.waw, .bo1, .iw5, .iw4, .ownFiles, .boiii]),
        Patch(key: "IW6_TUNE", title: "Apple GPU tuning (Ghosts)",
              info: "Ghosts never loads NVIDIA's HBAO+, TXAA and APEX libraries (NVIDIA-only), and starts once with tessellation and motion blur off, the heaviest work for Apple GPUs. The game's options can turn them back on.",
              games: [.ownFiles]),
        // Black Ops III (Windows)
        Patch(key: "BOIII_GRAPHICS", title: "Full-detail first start",
              info: "On its first start Black Ops III's auto-detect does not know Apple GPUs and picks half resolution with no shadows. Instead it starts fullscreen at your display's native size and refresh rate with shadows, ambient occlusion, SMAA, and balanced render scale (80% on 1440p, 70% on 4K, keeping crisp native menus/HUD while volumetric lighting and subsurface scattering start off). Only once: the game's own options rule afterwards.",
              games: [.boiii]),
        Patch(key: "BOIII_SCREEN", title: "Fullscreen at your display's refresh rate",
              info: "Every start: fullscreen at your display's size and refresh rate, and the frame cap at that rate. Black Ops III's own default cap is 60 FPS (MaxFPS, and Ezz's com_maxfps), and a crash or the launcher could leave it in a window.",
              games: [.boiii]),
        // CoD4X
        Patch(key: "COD4X_STEAM", title: "Steam for servers that require it",
              info: "Some CoD4X servers only let you in while Steam is running (\"Steam is not installed\" or \"Steam is not running\"). When Steam for Windows is set up in the Steam section and signs in by itself, Play CoD4X starts it in the background first. Without it, CoD4X plays on every server that does not require Steam.",
              games: [.cod4x]),
        // IW7-Mod
        Patch(key: "IW7MOD_DXMT_FIX", title: "Infinite Warfare's DXMT fixes",
              info: "Infinite Warfare creates depth-only tessellation pipelines that aborted stock DXMT during shader preload. Siliconium's unified DXMT already carries the tessellation translator fix, and this switch adds the mesh-pipeline Direct3D 11 DLL fix for Infinite Warfare. Turn off only for testing.",
              games: [.iw7mod]),
        Patch(key: "IW7MOD_SCREEN", title: "Fit the display",
              info: "Every start: the game's resolution is your display's size and its refresh rate the one Siliconium holds, written into its profile (players2/config_mp.cfg). Off: the game keeps what it saved.",
              games: [.iw7mod]),
        Patch(key: "IW7MOD_DISPLAY_MODE", title: "Native display mode in fullscreen",
              info: "While the game runs, the display uses a 1x mode of your desktop's size at its best refresh rate (a scaled HiDPI desktop is otherwise slower and capped lower); your desktop's mode comes back when the game ends.",
              games: [.iw7mod]),
        Patch(key: "IW7MOD_ASYNC", title: "Background shader compilation",
              info: "New shaders are compiled in the background instead of stopping the frame (a short hitch the first time an effect appears).",
              games: [.iw7mod]),
        Patch(key: "IW7MOD_FRAME_PACING", title: "Frame pacing",
              info: "DXMT spaces frames evenly at the frame-rate cap (your display's refresh rate by default).",
              games: [.iw7mod]),
        Patch(key: "BOIII_SAFE_LUA", title: "Ask before unsafe Lua",
              info: "Some Workshop mods and modded servers use \"unsafe\" Lua functions: reading and writing files, running system commands, loading DLLs. boiii asks first (\"Unsafe Lua Function Called\"). If a mod needs them and the question gets in its way, turn this off: boiii then starts with -unsafe-lua and lets them run without asking. The risk: any mod from any server can then use them, and under Wine that reaches your whole Mac (drive Z:). Only turn it off if you trust the servers and mods you play.",
              games: [.boiii]),
    ]

    static func `for`(_ game: Game) -> [Patch] { all.filter { $0.games.contains(game) } }
}
