import AppKit
import ApplicationServices
import CoreGraphics
import IOKit.hid
import SwiftUI
import os

private let log = Logger(subsystem: "com.oein.onscreen-keyboard", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var midi: MIDIEngine?
    private var model: OSKModel!
    private var status: StatusItem!
    private var tap: KeyTap!

    /// Read from the event-tap thread on every key event. Bool reads are atomic on aarch64.
    private var panelVisible: Bool = false

    /// Previous CGEvent flags — only mutated from the tap thread.
    private var prevFlags: CGEventFlags = []

    // Device-level shift bits inside CGEventFlags.rawValue (from IOLLEvent.h).
    private let leftShiftBit:  UInt64 = 0x02
    private let rightShiftBit: UInt64 = 0x04

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            midi = try MIDIEngine()
            log.info(" MIDI source created")
        } catch {
            log.info(" MIDI init failed: \(error)")
        }

        model = OSKModel(midi: midi)
        panel = FloatingPanel(size: NSSize(width: 940, height: 230),
                              rootView: PianoView(model: model))

        status = StatusItem()
        status.onToggle = { [weak self] in self?.toggle() }
        status.onQuit = { NSApp.terminate(nil) }

        let trusted = isAccessibilityTrusted(prompt: true)
        log.info(" Accessibility trusted: \(trusted)")
        guard trusted else {
            showPermissionAlert(.accessibility)
            return
        }

        // macOS 10.15+: a CGEventTap in .defaultTap mode on key events also requires
        // Input Monitoring. Without it, tapCreate returns a valid CFMachPort but no
        // events are ever delivered — the silent-fail mode that wasted us hours.
        let inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        log.info(" Input Monitoring access: \(inputMonitoring.rawValue, privacy: .public)")
        if inputMonitoring != kIOHIDAccessTypeGranted {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            showPermissionAlert(.inputMonitoring)
            return
        }

        tap = KeyTap()
        tap.onEvent = { [weak self] type, event in
            // handle() returns nil to consume the event; only fall back to `event`
            // when self is gone. The previous `?? event` form folded "consume" and
            // "self gone" into the same pass-through, so piano keys leaked through.
            guard let self else { return event }
            return self.handle(type: type, event: event)
        }
        if tap.start() {
            log.info(" Event tap started")
        } else {
            log.info(" Event tap failed to start")
            showPermissionAlert(.accessibility)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tap?.stop()
    }

    // MARK: - Window

    private func toggle() {
        // Drive state from our own flag, not panel.isVisible (which can lag
        // or stay true if a previous orderOut hadn't committed yet).
        if panelVisible {
            model.releaseAll()
            panel.orderOut(nil)
            panelVisible = false
            log.info("toggle → hidden")
        } else {
            positionOnCursorDisplay()
            panel.orderFrontRegardless()
            panelVisible = true
            log.info("toggle → visible")
        }
    }

    private func positionOnCursorDisplay() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSPointInRect(mouse, $0.frame) } ?? NSScreen.main
        guard let s = screen else { return }
        let frame = s.visibleFrame
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.minY + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Event handling (runs on the event-tap thread)

    /// Returns `nil` to consume, or the event to pass through.
    private func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        switch type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        case .flagsChanged:
            return handleFlagsChanged(event)
        default:
            return event
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> CGEvent? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        log.info("keyDown kc=\(keyCode, privacy: .public) cmd=\(flags.contains(.maskCommand), privacy: .public) visible=\(self.panelVisible, privacy: .public)")

        // Cmd+K always toggles the panel.
        if keyCode == KeyMap.kKey && flags.contains(.maskCommand) {
            log.info("Cmd+K detected → dispatching toggle")
            DispatchQueue.main.async { [weak self] in self?.toggle() }
            return nil
        }

        // When panel is hidden, only Cmd+K is intercepted.
        guard panelVisible else { return event }

        // Piano keys.
        if let def = KeyMap.byKeyCode[keyCode] {
            if !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.model.playKey(keyCode: def.keyCode, semitone: def.semitone)
                }
            }
            return nil
        }

        // Octave / sustain / escape — consume only these.
        switch keyCode {
        case KeyMap.zKey, KeyMap.leftArrow:
            if !isRepeat { dispatchModel { $0.shiftOctave(-1) } }
            return nil
        case KeyMap.xKey, KeyMap.rightArrow:
            if !isRepeat { dispatchModel { $0.shiftOctave(+1) } }
            return nil
        case KeyMap.tabKey:
            if !isRepeat { dispatchModel { $0.setSustain(true) } }
            return nil
        case KeyMap.escapeKey:
            // When the panel is up, ESC fully quits the app.
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return nil
        default:
            // Not a piano/control key — pass through to the focused app.
            return event
        }
    }

    private func handleKeyUp(_ event: CGEvent) -> CGEvent? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        guard panelVisible else { return event }

        if KeyMap.byKeyCode[keyCode] != nil {
            dispatchModel { $0.releaseKey(keyCode: keyCode) }
            return nil
        }
        if keyCode == KeyMap.tabKey {
            dispatchModel { $0.setSustain(false) }
            return nil
        }
        // Swallow keyUp for special keys whose keyDown we consumed,
        // so the focused app doesn't see a stray release.
        if keyCode == KeyMap.zKey || keyCode == KeyMap.xKey ||
           keyCode == KeyMap.leftArrow || keyCode == KeyMap.rightArrow ||
           keyCode == KeyMap.escapeKey {
            return nil
        }
        return event
    }

    private func handleFlagsChanged(_ event: CGEvent) -> CGEvent? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        defer { prevFlags = flags }

        guard panelVisible else { return event }

        let lWas = (prevFlags.rawValue & leftShiftBit)  != 0
        let lNow = (flags.rawValue     & leftShiftBit)  != 0
        let rWas = (prevFlags.rawValue & rightShiftBit) != 0
        let rNow = (flags.rawValue     & rightShiftBit) != 0

        if keyCode == KeyMap.leftShift && !lWas && lNow {
            dispatchModel { $0.shiftOctave(-1) }
        }
        if keyCode == KeyMap.rightShift && !rWas && rNow {
            dispatchModel { $0.shiftOctave(+1) }
        }

        // Don't consume — Shift is too fundamental to swallow system-wide.
        return event
    }

    private func dispatchModel(_ action: @escaping (OSKModel) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            action(self.model)
        }
    }

    // MARK: - Permission helper

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private enum PermissionKind {
        case accessibility
        case inputMonitoring

        var title: String {
            switch self {
            case .accessibility:   return "Accessibility (손쉬운 사용) permission required"
            case .inputMonitoring: return "Input Monitoring (입력 모니터링) permission required"
            }
        }
        var settingsURL: URL? {
            switch self {
            case .accessibility:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            case .inputMonitoring:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
            }
        }
    }

    private func showPermissionAlert(_ kind: PermissionKind) {
        let alert = NSAlert()
        alert.messageText = kind.title
        alert.informativeText = """
        OnScreen Keyboard needs BOTH Accessibility AND Input Monitoring to \
        intercept piano-mapped keys globally and route them to MIDI instead \
        of the focused app.

        Steps:
        1. Open the System Settings pane below.
        2. Toggle ON OnScreen Keyboard. \
           If it's already on but the app was just rebuilt, REMOVE it (–) and \
           let the next launch re-add it — toggling alone won't refresh the \
           ad-hoc code signature.
        3. Quit and relaunch this app.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let url = kind.settingsURL {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }
}
