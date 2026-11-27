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
import CoreVideo
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
// Wait (up to 3 s) until the display reports that mode: launch.sh reads the
// desktop's size and rate right after a restore, and read during the switch
// it got the old mode's 160 Hz for a desktop at 144 Hz (Modern Warfare 3 then
// ran capped at 160 against a 144 Hz vsync, 2026-11-24).
func settled(on mode: CGDisplayMode) -> Bool {
  for _ in 0..<30 {
    if let now = CGDisplayCopyDisplayMode(display), now.ioDisplayModeID == mode.ioDisplayModeID { return true }
    usleep(100_000)
  }
  return true   // switched; the display just has not said so yet
}
func oneX(_ w: Int, _ h: Int) -> [CGDisplayMode] {
  allModes.filter { $0.width == w && $0.height == h && $0.pixelWidth == w && $0.pixelHeight == h }
}
// The 1x modes of that size a hold may use: the ones macOS offers for the
// desktop (all of them if it offers none).
func usableOneX(_ w: Int, _ h: Int) -> [CGDisplayMode] {
  let modes = oneX(w, h)
  let usable = modes.filter { $0.isUsableForDesktopGUI() }
  return usable.isEmpty ? modes : usable
}
// A mode's refresh rate in Hz. Some panels (older Mac laptops' built-in
// displays) report 0 for every mode: then the display's own nominal rate,
// else 60. Never 0: launch.sh writes it into the games ("0 Hz").
func hz(_ mode: CGDisplayMode) -> Int {
  if mode.refreshRate >= 1 { return Int(mode.refreshRate.rounded()) }
  var link: CVDisplayLink?
  if CVDisplayLinkCreateWithCGDisplay(display, &link) == kCVReturnSuccess, let link = link {
    let period = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(link)
    if period.timeValue > 0 && period.timeScale > 0 {
      let rate = Double(period.timeScale) / Double(period.timeValue)
      if rate >= 1 { return Int(rate.rounded()) }
    }
  }
  return 60
}
// What a hold of <w>x<h> does on the display as it is now (one rule for the
// hold itself, for "plan" and so for launch.sh's frame caps and refresh
// settings, and for the app's display view):
//   "1x"      switch to the 1x mode of that size with the highest refresh
//             rate: a scaled HiDPI desktop ("looks like 2560x1440" on a 4K
//             panel, drawn at 5K, every frame cost a 5K composition: BO1 ~75
//             FPS, Black Ops 4 52), an unscaled HiDPI one when a 1x mode of
//             its size is faster, or a 1x desktop at a lower rate than its
//             size's best (the games ask for the best rate anyway);
//   "kept"    the desktop's HiDPI mode stays (SIL_KEEP_UNSCALED, below);
//   "already" the desktop is that 1x mode at its best rate;
//   "none"    no 1x mode of that size: the desktop's mode stays.
// SIL_KEEP_UNSCALED=1 (launch.sh's default, KEEP_HIDPI=1): a desktop of that
// size whose pixels are the panel's own ("looks like 1920x1080" on a 4K
// panel: not scaled) and no 1x mode of its size with a higher refresh rate
// stays as it is (HiDPI on, no mode switch, a sharp desktop after Cmd-Tab;
// Black Ops 159.0 FPS held at 1x, 158.9 kept, 2026-11-23).
// SIL_KEEP_UNSCALED=2 (KEEP_HIDPI=2): any HiDPI desktop of that size stays,
// scaled too. 3 (Smart HiDPI, used for mtld3d and lightweight DXMT games that
// present a 1x drawable without a 5K stall): any HiDPI desktop of that size
// stays whenever no 1x mode of its size offers a higher refresh rate.
// 0: every HiDPI desktop at 1x.
func decide(_ w: Int, _ h: Int) -> (mode: CGDisplayMode, kind: String) {
  let best = usableOneX(w, h).max(by: { $0.refreshRate < $1.refreshRate })
  let faster = best.map { $0.refreshRate > original.refreshRate + 0.5 } ?? false
  if original.width == w && original.height == h && original.pixelWidth == w && original.pixelHeight == h {
    if faster, let best = best { return (best, "1x") }
    return (original, "already")
  }
  let keepMode = ProcessInfo.processInfo.environment["SIL_KEEP_UNSCALED"] ?? ""
  if original.width == w && original.height == h
      && (keepMode == "2"
          || (keepMode == "3" && !faster)
          || (keepMode == "1" && original.ioFlags & UInt32(kDisplayModeNativeFlag) != 0 && !faster)) {
    return (original, "kept")
  }
  if let best = best { return (best, "1x") }
  return (original, "none")
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
  print("\(original.width) \(original.height) \(hz(original))")
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
      let ok = apply(saved, .forSession) && settled(on: saved)
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
// displaymode plan [<width> <height>]: what a hold of that size (the
// desktop's own size by default) would do now, as decide() says, in one line:
// "<width> <height> <Hz> <1x|kept|already|none> <pixel width> <pixel height>".
// launch.sh takes the games' refresh rate and frame caps from it (the rate of
// the mode the display ends up in); the hold itself runs the same decide().
// displaymode info: the desktop and that plan as key=value lines (the app).
if (args.count == 2 || args.count == 4) && args[1] == "plan" {
  let w = args.count == 4 ? Int(args[2]) ?? original.width : original.width
  let h = args.count == 4 ? Int(args[3]) ?? original.height : original.height
  let (mode, kind) = decide(w, h)
  print("\(mode.width) \(mode.height) \(hz(mode)) \(kind) \(mode.pixelWidth) \(mode.pixelHeight)")
  exit(0)
}
if args.count == 2 && args[1] == "plan-full" {
  let (mode, kind) = decide(original.width, original.height)
  print("\(original.width) \(original.height) \(hz(original)) \(mode.width) \(mode.height) \(hz(mode)) \(kind)")
  exit(0)
}
if args.count == 2 && args[1] == "info" {
  let (mode, kind) = decide(original.width, original.height)
  let hidpi = original.pixelWidth != original.width || original.pixelHeight != original.height
  let native = original.ioFlags & UInt32(kDisplayModeNativeFlag) != 0
  print("""
    desktop_width=\(original.width)
    desktop_height=\(original.height)
    desktop_pixel_width=\(original.pixelWidth)
    desktop_pixel_height=\(original.pixelHeight)
    desktop_hz=\(hz(original))
    desktop_kind=\(hidpi ? (native ? "hidpi" : "hidpi-scaled") : "1x")
    game_width=\(mode.width)
    game_height=\(mode.height)
    game_pixel_width=\(mode.pixelWidth)
    game_pixel_height=\(mode.pixelHeight)
    game_hz=\(hz(mode))
    plan=\(kind)
    """)
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
    "usage: displaymode <width> <height> <pid> | current | restore | plan [<width> <height>] | info | best <width> <height> | set <width> <height> <hz>\n"
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

// What decide() chose for this hold (set below; restore() needs it).
var holdKind = ""
// Put the desktop's mode back if the game (Wine) left another one.
// When this hold did not switch the mode (kept, already, none) and the display
// now has the desktop's size and pixels at another refresh rate, that rate is
// the player's (System Settings or BetterDisplay while the game ran): left as
// it is. Modern Warfare 3, 2026-11-24: the player set 160 Hz during the game
// and the hold put the 144 Hz it had started with back when the game ended.
// (A game's own size change is still undone: Black Ops II switched a
// 1920x1080 desktop to 2560x1440 the same night.)
func restore() {
  guard let now = CGDisplayCopyDisplayMode(display) else { return }
  if holdKind != "1x" && now.ioDisplayModeID != desktop.ioDisplayModeID
      && now.width == desktop.width && now.height == desktop.height
      && now.pixelWidth == desktop.pixelWidth && now.pixelHeight == desktop.pixelHeight {
    say("left \(now.width)x\(now.height) at \(hz(now)) Hz: the refresh rate was changed during the game")
    try? FileManager.default.removeItem(atPath: stateFile)
    return
  }
  if now.ioDisplayModeID != desktop.ioDisplayModeID || now.refreshRate != desktop.refreshRate {
    // (settled: launch.sh stops an earlier hold, then reads the desktop's mode)
    let ok = apply(desktop, .forSession) && settled(on: desktop)
    say("restored \(desktop.width)x\(desktop.height) \(hz(desktop)) Hz" + (ok ? "" : " FAILED"))
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

// What to do: decide() (see there), the same rule "plan" reports.
let (target, kind) = decide(w, h)
holdKind = kind
switch kind {
case "already":
  say("already \(w)x\(h) at 1x (\(hz(original)) Hz); watching pid \(pid)")
case "kept":
  say("kept the desktop's \(w)x\(h) mode (HiDPI at \(original.pixelWidth)x\(original.pixelHeight), "
      + "\(hz(original)) Hz); watching pid \(pid)")
case "1x":
  try? "\(desktop.ioDisplayModeID)\n\(target.ioDisplayModeID)\n".write(toFile: stateFile, atomically: true, encoding: .utf8)
  if apply(target, .forSession) {
    _ = settled(on: target)
    say("\(w)x\(h) at 1x, \(hz(target)) Hz, until pid \(pid) ends")
  } else {
    say("could not switch mode")
  }
default:
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
