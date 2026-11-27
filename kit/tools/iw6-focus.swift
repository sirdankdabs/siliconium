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
    var minimizedPID: Int32 = 0
    var minimizedHits = 0
    while Date() < deadline {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        var smallPID: Int32 = 0
        for info in list {
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
                  let name = windowsProgram(pid)?.lowercased(), wanted.contains(name) else { continue }
            if width >= 640 && height >= 480 { return pid }
            // Wine's iconic (minimized) titlebar window is 160x31 — avoid matching
            // transient pre-game splash/console windows like Plutonium's console.
            if smallPID == 0 && width >= 140 && width <= 220 && height >= 24 && height <= 48 { smallPID = pid }
        }
        // Exclusive-fullscreen games (e.g. WaW) can minimize themselves to Wine's
        // iconic 160x31 window immediately when started behind another app.
        if smallPID != 0 {
            if smallPID == minimizedPID { minimizedHits += 1 } else { minimizedPID = smallPID; minimizedHits = 1 }
            if minimizedHits >= 10 { return smallPID }
        } else {
            minimizedPID = 0; minimizedHits = 0
        }
        usleep(150_000)
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

// macOS screenshot/screen-recording UI (Cmd+Shift+3/4/5) and transient system
// overlays (Spotlight, Control Center, Notification Center): never hide the
// fullscreen game when these appear on top, so players can capture or record
// without the game minimizing.
@Sendable func isSystemOverlay(_ app: NSRunningApplication?) -> Bool {
    guard let app else { return true }
    if app.activationPolicy != .regular { return true }
    guard let bid = app.bundleIdentifier?.lowercased() else { return false }
    return bid == "com.apple.screencaptureui"
        || bid == "com.apple.screenshot.launcher"
        || bid == "com.apple.screenshot"
        || bid == "com.apple.screencontinuity"
        || bid == "com.apple.controlcenter"
        || bid == "com.apple.notificationcenterui"
        || bid == "com.apple.spotlight"
}

@Sendable func isScreenCaptureActive() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.screencaptureui").isEmpty
}

// The game has been the active app at least once (its first frames drawn)
var wasFront = false
let updateVisibility: @MainActor @Sendable () -> Void = {
    let front = workspace.frontmostApplication
    if front?.processIdentifier == gamePID {
        wasFront = true
        restoreOnActivation()
    } else if isSystemOverlay(front) || isScreenCaptureActive() {
        // Keep the fullscreen game visible and un-minimized while the user
        // takes a screenshot or uses the screen recording overlay.
        pending?.cancel()
    } else {
        pending?.cancel()
        // As Windows does with a fullscreen game on Alt-Tab: the game goes
        // out of the way when the player switches to another app. Left on
        // screen, its fullscreen window stayed above the desktop, black,
        // behind the other app (Ghosts; and every game once the display was
        // no longer captured, 2026-11-24). Cmd-Tab back shows it again (macOS
        // unhides an app it activates) and the window is restored above.
        // Ghosts at any time; the others only once they have been in front:
        // hiding Call of Duty 2 while it started (Siliconium still in front)
        // froze it before its first frame.
        // (A fallback since 2026-11-24: winemac hides the game itself,
        // SIL_HIDE_ON_DEACTIVATE in launch.sh. This hide is asynchronous and
        // came too late or not at all in a BO2 run: this helper sits at
        // priority 4 while Game Mode is on.)
        if isGhosts || wasFront, let game = NSRunningApplication(processIdentifier: gamePID), !game.isActive, !game.isHidden {
            _ = game.hide()
        }
    }
}

// SIL_FOCUS_FROM=<name>[:<name>…] (set by every Siliconium launcher): a game
// that another program starts (a launcher, Plutonium's bootstrapper, Steam,
// Battle.net) is not brought forward by macOS, so the keys went to the app that
// was in front and macOS Game Mode stayed off until a click. Once the game's
// window is on screen it is made the active app, ONCE per start (the first
// 5 minutes after its window was found), whichever app is in front then: the
// player started it from Siliconium (owner, 2026-11-24: "No pasaba en la
// 1.0.0"). Until then a player who went to another app while the game loaded
// got it left behind ("game left behind claude"): Black Ops' exclusive
// fullscreen draws nothing while it is not the active app, so the intro and
// menu stayed black until a click (1.0.0's captured display had kept the game
// above everything). The names only say, in the log, where it came from.
// Never again after that first time: Cmd-Tab away later is the player's.
//
// macOS 14+ activation is cooperative: a request from a helper may be
// ignored when the app in front has not yielded. So: the documented request
// first; if the game is still not in front half a second later, WindowServer
// is asked to make it the front process (SkyLight's
// _SLPSSetFrontProcessWithOptions, as macOS's own app switchers do; looked up
// at run time, skipped if missing); the log says which one worked.
/// The game's screen window (not one of its message boxes), if it is on screen.
/// Returns (windowID, isMinimizedFallback) so bringFront can also restore a
/// game that started minimized to Wine's iconic 160x31 window.
func gameWindowOnScreen() -> (CGWindowID, Bool)? {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
    var fallback: CGWindowID?
    for info in list {
        guard (info[kCGWindowOwnerPID as String] as? Int32) == gamePID,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double else { continue }
        let wid = (info[kCGWindowNumber as String] as? UInt32) ?? 0
        if width >= 640 && height >= 480 { return (wid, false) }
        if fallback == nil && width >= 140 && width <= 220 && height >= 24 && height <= 48 { fallback = wid }
    }
    return fallback.map { ($0, true) }
}
func say(_ text: String) { FileHandle.standardOutput.write(Data("Siliconium: \(text)\n".utf8)) }
/// WindowServer's own "make this the front process" (what a click on the
/// game's window does); answers nil when the private functions are not there.
let setFrontProcess: (pid_t, CGWindowID) -> Int32? = {
    typealias PSNForPID = @convention(c) (pid_t, UnsafeMutablePointer<UInt32>) -> Int32
    typealias SetFront = @convention(c) (UnsafeMutablePointer<UInt32>, UInt32, UInt32) -> Int32
    let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    guard let p = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "GetProcessForPID"),   // RTLD_DEFAULT
          let f = sky.flatMap({ dlsym($0, "_SLPSSetFrontProcessWithOptions") }) else { return { _, _ in nil } }
    let psnForPID = unsafeBitCast(p, to: PSNForPID.self), setFront = unsafeBitCast(f, to: SetFront.self)
    return { pid, window in
        var psn: [UInt32] = [0, 0]   // ProcessSerialNumber (high, low)
        guard psnForPID(pid, &psn) == 0 else { return nil }
        return setFront(&psn, window, 0x200)   // kCPSUserGenerated
    }
}()
let frontFrom = (ProcessInfo.processInfo.environment["SIL_FOCUS_FROM"] ?? "").split(separator: ":").map { $0.lowercased() }
var frontTries = 0
var frontFirstFrom = ""
let frontSince = Date()
let bringFront: Timer? = frontFrom.isEmpty ? nil : Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
    MainActor.assumeIsolated {
        if Date().timeIntervalSince(frontSince) > 300 { timer.invalidate(); return }
        guard let (window, isMinimized) = gameWindowOnScreen(), let game = NSRunningApplication(processIdentifier: gamePID),
              let front = workspace.frontmostApplication else { return }
        if front.processIdentifier == gamePID {
            if isMinimized {
                restoreOnActivation()
                frontTries += 1
                if frontTries >= 15 { timer.invalidate() }
                return
            }
            if frontTries > 0 {
                say("the game is in front (from \(frontFirstFrom), \(frontTries == 1 ? "macOS request" : "WindowServer"))")
            }
            timer.invalidate(); return
        }
        let names = [front.bundleIdentifier, windowsProgram(front.processIdentifier)].compactMap { $0?.lowercased() }
        let from = names.last ?? "another app"
        frontTries += 1
        if frontTries == 1 {
            frontFirstFrom = from
            // as if the app in front handed over (macOS's cooperative activation)
            let asked = game.activate(from: front, options: [.activateAllWindows]) || game.activate(options: [.activateAllWindows])
            say("bringing the game to the front from \(from)\(names.contains(where: frontFrom.contains) ? "" : " (another app)") (\(asked ? "asked" : "refused"))")
        } else if let result = setFrontProcess(gamePID, window) {
            if frontTries == 2 { say("macOS did not bring it; asking WindowServer (\(result == 0 ? "ok" : "error \(result)"))") }
        } else {
            _ = game.activate(options: [.activateAllWindows])
        }
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
