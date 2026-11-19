import AppKit

// AppKit can bring Ghosts forward while its Win32 window is still iconic.
// Ask Wine to restore that window only after the Ghosts process gains focus.
let args = CommandLine.arguments
guard args.count == 4, let gamePID = Int32(args[1]), gamePID > 0 else { exit(2) }
let workspace = NSWorkspace.shared
var pending: DispatchWorkItem?

@MainActor func restoreOnActivation() {
    pending?.cancel()
    let work = DispatchWorkItem {
        guard workspace.frontmostApplication?.processIdentifier == gamePID else { return }
        let restore = Process()
        restore.executableURL = URL(fileURLWithPath: args[2])
        restore.arguments = [args[3]]
        restore.standardInput = FileHandle.nullDevice
        restore.standardOutput = FileHandle.nullDevice
        restore.standardError = FileHandle.nullDevice
        restore.terminationHandler = { process in
            if process.terminationStatus == 0 {
                FileHandle.standardOutput.write(Data("Siliconium: restored the Ghosts window in Wine\n".utf8))
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
        if let game = NSRunningApplication(processIdentifier: gamePID), !game.isActive, !game.isHidden {
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
