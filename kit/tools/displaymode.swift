// displaymode <width> <height> <pid>: while <pid> runs, keep the main display
// in a 1x mode of <width>x<height> (pixels = points) at its highest refresh
// rate; when <pid> ends, put back the mode the desktop had at the start.
// The 1x mode is the login session's mode while the game runs, not only this
// process's: Wine releases the display it captured for a fullscreen game when
// the player presses Cmd+Tab, and macOS then put the display back in the
// session's mode (the HiDPI desktop); Wine captured that mode again when the
// game came back, and every frame was composed at 5K from then on (Black Ops
// 4: 115 -> 52 FPS, 2026-11-23). While the hold is on, the desktop's mode and
// the held one are written to <Siliconium>/cache/displaymode-desktop and the
// hold keeps a lock on <Siliconium>/cache/displaymode.lock (macOS releases it
// however the hold ends).
// displaymode restore: a hold that ended without putting the desktop's mode
// back (killed: its record is there and nobody has the lock) is undone now,
// if the display is still in the mode that hold set; a mode the player chose
// since is left as it is. launch.sh runs it at every start and stop, and the
// app when it opens, so a killed hold never leaves the Mac in the game's mode
// until the next game.
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
import IOKit.graphics

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

let home = ProcessInfo.processInfo.environment["SIL_HOME"] ??
  (NSHomeDirectory() + "/Library/Application Support/Siliconium")
let stateFile = home + "/cache/displaymode-desktop"
let lockFile = home + "/cache/displaymode.lock"
// The record: the desktop's mode, then the held one, one mode ID per line
// (Siliconium 1.3.0 wrote the desktop's only).
func readRecord() -> [Int32] {
  guard let text = try? String(contentsOfFile: stateFile, encoding: .utf8) else { return [] }
  return text.split(whereSeparator: \.isNewline).compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
}
// The hold's lock, kept (open) until this process ends.
var lockFD: Int32 = -1
func takeLock(tries: Int) -> Bool {
  try? FileManager.default.createDirectory(atPath: home + "/cache", withIntermediateDirectories: true)
  let fd = open(lockFile, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
  guard fd >= 0 else { return false }
  for i in 0..<max(tries, 1) {
    if flock(fd, LOCK_EX | LOCK_NB) == 0 { lockFD = fd; return true }
    if i + 1 < tries { usleep(100_000) }
  }
  close(fd)
  return false
}

if args.count == 2 && args[1] == "current" {
  print("\(original.width) \(original.height) \(Int(original.refreshRate.rounded()))")
  exit(0)
}
if args.count == 2 && args[1] == "restore" {
  guard FileManager.default.fileExists(atPath: stateFile) else { exit(0) }
  // A hold that is still on has the lock and puts the mode back itself.
  guard takeLock(tries: 1) else { exit(0) }
  let record = readRecord()
  if let id = record.first, let saved = allModes.first(where: { $0.ioDisplayModeID == id }),
     original.ioDisplayModeID != saved.ioDisplayModeID {
    let held = record.count > 1 ? original.ioDisplayModeID == record[1]
                                : original.pixelWidth == original.width && original.pixelHeight == original.height
    if held {
      let ok = apply(saved, .forSession)
      say("restored \(saved.width)x\(saved.height) \(Int(saved.refreshRate)) Hz (left by a hold that did not end normally)"
          + (ok ? "" : " FAILED"))
      if !ok { exit(1) }   // (the record stays: the next restore tries again)
    } else {
      say("record of an earlier hold dropped: the display is in another mode now (\(original.width)x\(original.height))")
    }
  }
  try? FileManager.default.removeItem(atPath: stateFile)
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
    "usage: displaymode <width> <height> <pid> | current | restore | best <width> <height> | set <width> <height> <hz>\n"
      .data(using: .utf8)!)
  exit(2)
}

// The lock first, then the record: a restore never takes the record of a hold
// that is on for one left behind. (An earlier hold that is ending may have the
// lock for a moment: launch.sh stops it before it starts this one.)
_ = takeLock(tries: 30)
// The desktop's mode: the one at the start, or, when the display is already in
// the 1x mode and a hold left its record behind, the mode that hold recorded.
var desktop = original
if original.pixelWidth == w && original.pixelHeight == h && original.width == w && original.height == h,
   let id = readRecord().first,
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

// SIL_KEEP_UNSCALED=1 (launch.sh, for the games measured to run the same in
// both): a desktop of that size whose pixels are the panel's own ("looks like
// 1920x1080" on a 4K panel: not scaled) and no 1x mode of that size with a
// higher refresh rate: the desktop's mode stays (HiDPI on, no mode switch, a
// sharp desktop after Cmd-Tab); the hold only watches. A scaled desktop
// ("looks like 2560x1440" on a 4K panel, drawn at 5K) is still held at 1x:
// there every frame cost a 5K composition (BO1 ~75 FPS, Black Ops 4 52).
let keepUnscaled = ProcessInfo.processInfo.environment["SIL_KEEP_UNSCALED"] == "1"
  && original.width == w && original.height == h
  && original.ioFlags & UInt32(kDisplayModeNativeFlag) != 0
  && !oneX(w, h).contains(where: { $0.refreshRate > original.refreshRate + 0.5 })

if original.pixelWidth == w && original.pixelHeight == h {
  say("already \(w)x\(h) at 1x (\(Int(original.refreshRate)) Hz); watching pid \(pid)")
} else if keepUnscaled {
  say("kept the desktop's \(w)x\(h) mode (HiDPI at the panel's own \(original.pixelWidth)x\(original.pixelHeight), "
      + "\(Int(original.refreshRate)) Hz); watching pid \(pid)")
} else if let mode = oneX(w, h).max(by: { $0.refreshRate < $1.refreshRate }) {
  try? "\(desktop.ioDisplayModeID)\n\(mode.ioDisplayModeID)\n".write(toFile: stateFile, atomically: true, encoding: .utf8)
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
