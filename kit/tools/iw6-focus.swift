import AppKit

// AppKit can bring Ghosts forward while its Win32 window is still iconic.
// Ask Wine to restore that window only after the Ghosts process gains focus.
let args = CommandLine.arguments
// iw6-focus <game pid> <wine> <iw6-restore.exe> [executable name]: the name
// (default iw6sp64_ship.exe) is passed on to iw6-restore.exe (Call of Duty 2
// minimizes its fullscreen window the same way when it loses focus)
guard args.count == 4 || args.count == 5, let gamePID = Int32(args[1]), gamePID > 0 else { exit(2) }
// Ghosts: no executable name, or one of Ghosts' (its multiplayer passes iw6mp64_ship.exe)
let isGhosts = args.count == 4 || args[4].lowercased().hasPrefix("iw6")
let workspace = NSWorkspace.shared
var pending: DispatchWorkItem?

@MainActor func restoreOnActivation() {
    pending?.cancel()
    let work = DispatchWorkItem {
        guard workspace.frontmostApplication?.processIdentifier == gamePID else { return }
        let restore = Process()
        restore.executableURL = URL(fileURLWithPath: args[2])
        restore.arguments = args.count == 5 ? [args[3], args[4]] : [args[3]]
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
checkGame.invalidate()
workspace.notificationCenter.removeObserver(observer)
