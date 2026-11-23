// displaymode <width> <height> <pid>: while <pid> runs, keep the main display
// in a 1x mode of <width>x<height> (pixels = points) at its highest refresh
// rate; when <pid> ends, put back the mode the desktop had at the start.
// The 1x mode is the login session's mode while the game runs, not only this
// process's: Wine releases the display it captured for a fullscreen game when
// the player presses Cmd+Tab, and macOS then put the display back in the
// session's mode (the HiDPI desktop); Wine captured that mode again when the
// game came back, and every frame was composed at 5K from then on (Black Ops
// 4: 115 -> 52 FPS, 2026-11-23). The desktop's mode is written to
// <Siliconium>/cache/displaymode-desktop while the hold is on, so a hold that
// was killed before it could put it back is undone by the next one.
// displaymode current: print the desktop's size in points and its refresh
// rate, e.g. "2560 1440 160".
// displaymode best <width> <height>: see below.
// displaymode set <width> <height> <hz>: switch to that 1x mode for the
// login session.
//
// Why: on a HiDPI-scaled desktop (e.g. "looks like 2560x1440" on a 4K panel,
// drawn at 5120x2880), a fullscreen game at that same size leaves the display
// in the scaled mode, and macOS composes every frame at 5K: BO1 waited ~10 ms
// per frame for a drawable and ran at ~75 FPS. In the 1x mode, 153-166 FPS.
// Wine also changes the display's mode for fullscreen games and does not put
// it back when its processes are killed (a crash, "Close BO1"), which left a
// 320 Hz monitor at 60 Hz: the restore at the end covers that.
import CoreGraphics
import Foundation

let args = CommandLine.arguments
let display = CGMainDisplayID()
guard let original = CGDisplayCopyDisplayMode(display) else { exit(1) }
let allOpts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
let allModes = CGDisplayCopyAllDisplayModes(display, allOpts) as? [CGDisplayMode] ?? []

func say(_ s: String) { print("displaymode: \(s)"); fflush(stdout) }
func apply(_ mode: CGDisplayMode, _ option: CGConfigureOption) -> Bool {
  var config: CGDisplayConfigRef?
  guard CGBeginDisplayConfiguration(&config) == .success else { return false }
  CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
  return CGCompleteDisplayConfiguration(config, option) == .success
}
func oneX(_ w: Int, _ h: Int) -> [CGDisplayMode] {
  allModes.filter { $0.width == w && $0.height == h && $0.pixelWidth == w && $0.pixelHeight == h }
}

if args.count == 2 && args[1] == "current" {
  print("\(original.width) \(original.height) \(Int(original.refreshRate.rounded()))")
  exit(0)
}
// displaymode best <width> <height>: the highest refresh rate of a 1x mode of
// that size (what the game gets once the 1x mode is held), e.g. 160 on a panel
// whose HiDPI desktop mode stops at 154 Hz; nothing if there is no such mode.
if args.count == 4 && args[1] == "best", let w = Int(args[2]), let h = Int(args[3]) {
  if let mode = oneX(w, h).filter({ $0.isUsableForDesktopGUI() }).max(by: { $0.refreshRate < $1.refreshRate }) {
    print(Int(mode.refreshRate.rounded()))
  }
  exit(0)
}
if args.count == 5 && args[1] == "set", let w = Int(args[2]), let h = Int(args[3]), let hz = Double(args[4]) {
  guard let mode = oneX(w, h).min(by: { abs($0.refreshRate - hz) < abs($1.refreshRate - hz) }) else {
    say("no 1x \(w)x\(h) mode"); exit(1)
  }
  guard apply(mode, .forSession) else { say("could not switch mode"); exit(1) }
  say("set \(w)x\(h) at 1x, \(Int(mode.refreshRate)) Hz"); exit(0)
}
guard args.count == 4, let w = Int(args[1]), let h = Int(args[2]), let pid = Int32(args[3]) else {
  FileHandle.standardError.write(
    "usage: displaymode <width> <height> <pid> | current | set <width> <height> <hz>\n".data(using: .utf8)!)
  exit(2)
}

let home = ProcessInfo.processInfo.environment["SIL_HOME"] ??
  (NSHomeDirectory() + "/Library/Application Support/Siliconium")
let stateFile = home + "/cache/displaymode-desktop"
// The desktop's mode: the one at the start, or, when the display is already in
// the 1x mode and a hold left its record behind, the mode that hold recorded.
var desktop = original
if original.pixelWidth == w && original.pixelHeight == h && original.width == w && original.height == h,
   let text = try? String(contentsOfFile: stateFile, encoding: .utf8),
   let id = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
   let saved = allModes.first(where: { $0.ioDisplayModeID == id }) {
  desktop = saved
}

// Put the desktop's mode back if the game (Wine) left another one.
func restore() {
  guard let now = CGDisplayCopyDisplayMode(display) else { return }
  if now.ioDisplayModeID != desktop.ioDisplayModeID || now.refreshRate != desktop.refreshRate {
    let ok = apply(desktop, .forSession)
    say("restored \(desktop.width)x\(desktop.height) \(Int(desktop.refreshRate)) Hz" + (ok ? "" : " FAILED"))
  }
  try? FileManager.default.removeItem(atPath: stateFile)
}
var sources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
  signal(sig, SIG_IGN)
  let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
  s.setEventHandler { restore(); exit(0) }
  s.resume()
  sources.append(s)
}

if original.pixelWidth == w && original.pixelHeight == h {
  say("already \(w)x\(h) at 1x (\(Int(original.refreshRate)) Hz); watching pid \(pid)")
} else if let mode = oneX(w, h).max(by: { $0.refreshRate < $1.refreshRate }) {
  try? FileManager.default.createDirectory(atPath: home + "/cache", withIntermediateDirectories: true)
  try? "\(desktop.ioDisplayModeID)\n".write(toFile: stateFile, atomically: true, encoding: .utf8)
  if apply(mode, .forSession) {
    say("\(w)x\(h) at 1x, \(Int(mode.refreshRate)) Hz, until pid \(pid) ends")
  } else {
    say("could not switch mode")
  }
} else {
  say("no 1x \(w)x\(h) mode; watching pid \(pid)")
}
// Watch on a timer so the signal sources on the main queue still run.
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + 1, repeating: 1)
timer.setEventHandler {
  if kill(pid, 0) != 0 {
    // Give Wine a moment to put things back itself before checking.
    sleep(2)
    restore()
    exit(0)
  }
}
timer.resume()
dispatchMain()
