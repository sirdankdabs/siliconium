import AppKit
import Foundation
import IOKit.hid

/// Bluetooth game controllers on macOS are HID devices behind Input
/// Monitoring (`kTCCServiceListenEvent`). Reading their buttons and sticks
/// needs that permission, and Wine — which reads the controller for every
/// game Siliconium starts — inherits it from this app (the responsible process).
///
/// Wired and USB-dongle controllers do not need it: only the Bluetooth HID
/// service reports `RequiresTCCAuthorization = Yes`. So Siliconium asks only when
/// a Bluetooth gamepad is actually connected and the permission is missing.
enum BluetoothControllerAccess {
    /// Whether this app (and therefore the Wine processes it starts) may read
    /// HID input. On macOS 10.15+ this is the Input Monitoring permission.
    static var isGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Names of the game controllers currently connected over Bluetooth.
    /// Listing HID devices does not open them, so this works without the
    /// permission (and does not trigger a prompt on its own).
    static func connected() -> [String] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Gamepads (DualShock 4, DualSense, Xbox), but also controllers that
        // describe themselves as a joystick or multi-axis controller (Switch
        // Pro, Joy-Con, many 8BitDo and third-party pads).
        let usages = [kHIDUsage_GD_GamePad, kHIDUsage_GD_Joystick, kHIDUsage_GD_MultiAxisController]
        let matches: [[String: Any]] = usages.map {
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: $0]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        let names = devices.compactMap { device -> String? in
            // A wireless controller reports "Bluetooth", or "Bluetooth Low
            // Energy" (Xbox Series X|S and other BLE pads); wired and USB
            // dongles report "USB" and need no permission.
            guard let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String,
                  transport.hasPrefix("Bluetooth")
            else { return nil }
            return IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
                ?? "Bluetooth controller"
        }
        // One controller can expose several matching interfaces.
        return Array(Set(names)).sorted()
    }

    /// Opens System Settings → Privacy & Security → Input Monitoring.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AppState {
    /// Explains the Bluetooth permission, but only if it is actually needed:
    /// a Bluetooth gamepad is connected and Input Monitoring is not granted.
    /// `force` is for the Settings button (shows the explanation or the
    /// current state even when no controller is connected).
    func checkBluetoothController(force: Bool = false) {
        if BluetoothControllerAccess.isGranted {
            // The permission was just granted (from our prompt or from System
            // Settings): reopen Siliconium so every game it starts inherits it.
            if didRequestBluetoothAccess && !didRelaunchForBluetooth {
                relaunchForBluetoothController()
                return
            }
            guard force else { return }
            let alert = NSAlert()
            alert.icon = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 44, weight: .regular))
            alert.messageText = "Bluetooth controllers are ready"
            alert.informativeText = """
                Input Monitoring is on for Siliconium. Connect your controller before starting the game.

                Wired and USB-dongle controllers work without this permission.
                """
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let controllers = BluetoothControllerAccess.connected()
        guard force || !controllers.isEmpty else { return }
        // Ask once per app run; the Settings button can ask again.
        guard force || !didOfferBluetoothAccess else { return }
        didOfferBluetoothAccess = true
        didRequestBluetoothAccess = true

        let name = controllers.first
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 44, weight: .regular))
        alert.messageText = name.map { "Use your \($0) with Siliconium?" } ?? "Use a Bluetooth controller"
        alert.informativeText = """
            macOS needs your OK once so Siliconium and its games can read wireless controllers (Input Monitoring). Wired and USB-dongle controllers don't need it.

            Click Allow. If System Settings opens, turn on Siliconium there: Siliconium reopens by itself, ready to play.
            """
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // IOHIDRequestAccess shows macOS's own prompt. Do it off the main
        // thread: the call waits for the user, and the window must not freeze.
        DispatchQueue.global(qos: .userInitiated).async {
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            Task { @MainActor in
                if granted {
                    // Reopen the app so the permission belongs to a clean
                    // process before any game starts (the same as the update).
                    self.relaunchForBluetoothController()
                } else {
                    // macOS shows its prompt only once: after an earlier "Don't
                    // Allow" it answers no at once. Go straight to the switch.
                    BluetoothControllerAccess.openSettings()
                    self.waitForInputMonitoring()
                }
            }
        }
    }

    /// Watches for the Input Monitoring switch (up to 5 minutes) and reopens
    /// the app as soon as it is on, so the player never has to come back and
    /// start over.
    func waitForInputMonitoring() {
        Task { @MainActor in
            for _ in 0..<300 {
                try? await Task.sleep(for: .seconds(1))
                if BluetoothControllerAccess.isGranted {
                    NSApp.activate(ignoringOtherApps: true)
                    self.relaunchForBluetoothController()
                    return
                }
            }
        }
    }

    /// Reopens Siliconium once the permission is granted, so Wine (and every game
    /// it starts) inherits it. A game already running is never killed: it says
    /// to start it again instead.
    func relaunchForBluetoothController() {
        guard !didRelaunchForBluetooth else { return }
        didRelaunchForBluetooth = true
        if let running {
            let alert = NSAlert()
            alert.messageText = "Input Monitoring is on"
            alert.informativeText = "Quit \(running.title) and start it again so it can see the Bluetooth controller."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        UserDefaults.standard.set(true, forKey: "siliconiumBluetoothPermissionGranted")
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; open -n \"$0\"", Bundle.main.bundleURL.path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    /// After that relaunch: one short confirmation, then the flag is cleared.
    func confirmBluetoothPermissionAfterRelaunch() {
        guard UserDefaults.standard.bool(forKey: "siliconiumBluetoothPermissionGranted") else { return }
        UserDefaults.standard.removeObject(forKey: "siliconiumBluetoothPermissionGranted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Bluetooth controller ready"
            alert.informativeText = """
                Input Monitoring is on. Start a game with the controller connected.

                Wired and USB-dongle controllers work as before.
                """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
