import AppKit

// AppKit can bring Ghosts forward while its Win32 window is still iconic.
// Ask Wine to restore that window only after the Ghosts process gains focus.
let args = CommandLine.arguments
// iw6-focus <game pid> <wine> <iw6-restore.exe> [executable name]: the name
// (default iw6sp64_ship.exe) is passed on to iw6-restore.exe (Call of Duty 2
// minimizes its fullscreen window the same way when it loses focus).
// A game pid of 0: the game is found by that executable name (or one of a ':'
// list: a fix's own executable, the game's) (a launcher or
// another Windows program starts it: Plutonium, IW4X): the process running it
// that shows a window of at least 640x480; this waits up to 15 minutes.
guard args.count == 4 || args.count == 5, let pidArgument = Int32(args[1]), pidArgument >= 0 else { exit(2) }
func windowsProgram(_ pid: pid_t) -> String? {
    var mib = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
    // argc, the executable's path, padding, then argv[0] (Wine's: the Windows program)
    var start = MemoryLayout<Int32>.size
    while start < size && buffer[start] != 0 { start += 1 }
    while start < size && buffer[start] == 0 { start += 1 }
    var end = start
    while end < size && buffer[end] != 0 { end += 1 }
    guard end > start, let argv0 = String(bytes: buffer[start..<end], encoding: .utf8) else { return nil }
    return argv0.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init)
}
let gamePID: Int32 = {
    if pidArgument > 0 { return pidArgument }
    guard args.count == 5 else { exit(2) }
    let wanted = Set(args[4].lowercased().split(separator: ":").map(String.init))
    let deadline = Date().addingTimeInterval(900)
    while Date() < deadline {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in list {
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
                  width >= 640, height >= 480, let name = windowsProgram(pid)?.lowercased(), wanted.contains(name) else { continue }
            return pid
        }
        usleep(500_000)
    }
    exit(0)
}()
// Ghosts: no executable name, or one of Ghosts' (its multiplayer passes iw6mp64_ship.exe)
let isGhosts = args.count == 4 || args[4].lowercased().hasPrefix("iw6")
// iw6-restore.exe's target: the program the game's process runs (names may be
// a ':' list: a fix's executable or the game's own)
let restoreTarget: String? = args.count == 5 ? (args[4].contains(":") ? (windowsProgram(gamePID) ?? String(args[4].split(separator: ":").last!)) : args[4]) : nil
let workspace = NSWorkspace.shared
var pending: DispatchWorkItem?
// The restore helper runs on Wine's own loader, not on the copy inside the
// Game Mode bundle (tools/game-bundle.sh) that the caller passes: a program
// started from an app bundle's executable took 3.9 s to start instead of 1.2 s
// (Black Ops 4, 2026-11-23), all of it black screen after Cmd-Tab back.
let (restoreLoader, restoreEnvironment): (String, [String: String]) = {
    var environment = ProcessInfo.processInfo.environment
    let macOS = URL(fileURLWithPath: args[2]).deletingLastPathComponent()
    let contents = macOS.deletingLastPathComponent()
    let bundle = contents.deletingLastPathComponent()
    if macOS.lastPathComponent == "MacOS", contents.lastPathComponent == "Contents", bundle.pathExtension == "app" {
        let plain = bundle.deletingLastPathComponent().appendingPathComponent("wine").path
        if FileManager.default.isExecutableFile(atPath: plain) {
            environment.removeValue(forKey: "WINELOADER")
            return (plain, environment)
        }
    }
    return (args[2], environment)
}()

// The restore helper stays running from the game's start (iw6-restore.exe
// --wait): a Cmd-Tab back then only writes a line to it, instead of starting
// a Wine program (2.6-5 s while the game runs; the screen stayed black that
// long). A one-shot helper is the fallback if it is not running.
signal(SIGPIPE, SIG_IGN)
let residentInput = Pipe(), residentOutput = Pipe()
let resident: Process? = {
    let helper = Process()
    helper.executableURL = URL(fileURLWithPath: restoreLoader)
    helper.environment = restoreEnvironment
    helper.arguments = [args[3], "--wait"] + (restoreTarget.map { [$0] } ?? [])
    helper.standardInput = residentInput
    helper.standardOutput = residentOutput
    helper.standardError = FileHandle.nullDevice
    residentOutput.fileHandleForReading.readabilityHandler = { handle in
        let answer = String(decoding: handle.availableData, as: UTF8.self)
        if answer.contains("1") {
            FileHandle.standardOutput.write(Data("Siliconium: restored the game window in Wine\n".utf8))
        }
    }
    return (try? helper.run()) != nil ? helper : nil
}()

@MainActor func restoreOnActivation() {
    pending?.cancel()
    let work = DispatchWorkItem {
        guard workspace.frontmostApplication?.processIdentifier == gamePID else { return }
        if let resident, resident.isRunning,
           (try? residentInput.fileHandleForWriting.write(contentsOf: Data("\n".utf8))) != nil {
            return
        }
        let restore = Process()
        restore.executableURL = URL(fileURLWithPath: restoreLoader)
        restore.environment = restoreEnvironment
        restore.arguments = [args[3]] + (restoreTarget.map { [$0] } ?? [])
        restore.standardInput = FileHandle.nullDevice
        restore.standardOutput = FileHandle.nullDevice
        restore.standardError = FileHandle.nullDevice
        restore.terminationHandler = { process in
            if process.terminationStatus == 0 {
                FileHandle.standardOutput.write(Data("Siliconium: restored the game window in Wine\n".utf8))
            }
        }
        try? restore.run()
    }
    pending = work
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250), execute: work)
}

let updateVisibility: @MainActor @Sendable () -> Void = {
    if workspace.frontmostApplication?.processIdentifier == gamePID {
        restoreOnActivation()
    } else {
        pending?.cancel()
        // Ghosts can leave its black fullscreen window above the desktop
        // while another app is active. Hide just the game in that case.
        // Ghosts only: hiding Call of Duty 2 while it started (Siliconium
        // still in front) froze it before its first frame.
        if isGhosts, let game = NSRunningApplication(processIdentifier: gamePID), !game.isActive, !game.isHidden {
            _ = game.hide()
        }
    }
}

// SIL_FOCUS_FROM=<name>[:<name>…] (Battle.net's games): a game that another
// program starts (Battle.net) is not brought forward by macOS, so the keys went
// to the app that was in front and macOS Game Mode stayed off until a click.
// Once the game's window is on screen it is made the active app, but only if
// the app in front then is one of these (a bundle identifier, or the Windows
// program a Wine process runs): Siliconium after Play, or Battle.net. Another
// app in front (the player went elsewhere) is never interrupted. Once only.
func gameWindowOnScreen() -> Bool {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
    return list.contains { info in
        guard (info[kCGWindowOwnerPID as String] as? Int32) == gamePID,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double else { return false }
        return width >= 640 && height >= 480   // the game's screen, not one of its message boxes
    }
}
func say(_ text: String) { FileHandle.standardOutput.write(Data("Siliconium: \(text)\n".utf8)) }
let frontFrom = (ProcessInfo.processInfo.environment["SIL_FOCUS_FROM"] ?? "").split(separator: ":").map { $0.lowercased() }
var frontTries = 0
let frontSince = Date()
let bringFront: Timer? = frontFrom.isEmpty ? nil : Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
    MainActor.assumeIsolated {
        if Date().timeIntervalSince(frontSince) > 300 { timer.invalidate(); return }
        guard gameWindowOnScreen(), let game = NSRunningApplication(processIdentifier: gamePID),
              let front = workspace.frontmostApplication else { return }
        if front.processIdentifier == gamePID {
            if frontTries > 0 { say("the game is in front") }
            timer.invalidate(); return
        }
        let names = [front.bundleIdentifier, windowsProgram(front.processIdentifier)].compactMap { $0?.lowercased() }
        guard names.contains(where: frontFrom.contains) else {
            say("game left behind \(names.last ?? "another app") (not Siliconium or the launcher)")
            timer.invalidate(); return
        }
        // as if the app in front handed over (macOS's cooperative activation)
        let asked = game.activate(from: front, options: [.activateAllWindows]) || game.activate(options: [.activateAllWindows])
        frontTries += 1
        if frontTries == 1 { say("bringing the game to the front from \(names.last ?? "?") (\(asked ? "asked" : "refused"))") }
        if frontTries >= 10 { say("the game did not come to the front"); timer.invalidate() }
    }
}

let observer = workspace.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { _ in
    MainActor.assumeIsolated { updateVisibility() }
}
let checkGame = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    if kill(gamePID, 0) != 0 { CFRunLoopStop(CFRunLoopGetMain()) }
}
MainActor.assumeIsolated { updateVisibility() }
CFRunLoopRun()
pending?.cancel()
try? residentInput.fileHandleForWriting.close()
bringFront?.invalidate()
checkGame.invalidate()
workspace.notificationCenter.removeObserver(observer)
