import AppKit
import CoreGraphics
import SwiftUI

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
        } catch {
            NSLog("MIDI init failed: \(error)")
        }

        model = OSKModel(midi: midi)
        panel = FloatingPanel(size: NSSize(width: 940, height: 230),
                              rootView: PianoView(model: model))

        status = StatusItem()
        status.onToggle = { [weak self] in self?.toggle() }
        status.onQuit = { NSApp.terminate(nil) }

        tap = KeyTap()
        tap.onEvent = { [weak self] type, event in
            self?.handle(type: type, event: event) ?? event
        }
        if !tap.start() {
            promptForInputMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tap?.stop()
    }

    // MARK: - Window

    private func toggle() {
        if panel.isVisible {
            model.releaseAll()
            panel.orderOut(nil)
            panelVisible = false
        } else {
            positionOnCursorDisplay()
            panel.orderFrontRegardless()
            panelVisible = true
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

        // Cmd+K always toggles the panel.
        if keyCode == KeyMap.kKey && flags.contains(.maskCommand) {
            DispatchQueue.main.async { [weak self] in self?.toggle() }
            return nil
        }

        // When panel is hidden, only Cmd+K is intercepted.
        guard panelVisible else { return event }

        // Don't intercept piano keys used as modifier shortcuts.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return event
        }

        // Piano keys (consume).
        if let def = KeyMap.byKeyCode[keyCode] {
            if !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.model.playKey(keyCode: def.keyCode, semitone: def.semitone)
                }
            }
            return nil
        }

        // Octave / sustain / escape (consume).
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
            DispatchQueue.main.async { [weak self] in self?.toggle() }
            return nil
        default:
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

        // Swallow keyUp for keys we consumed on keyDown so the host app doesn't see them.
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

    private func promptForInputMonitoring() {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring permission required"
        alert.informativeText = """
        OnScreen Keyboard needs Input Monitoring access to capture key \
        presses while another app is focused.

        Open System Settings → Privacy & Security → Input Monitoring \
        and enable OnScreen Keyboard, then relaunch the app.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        }
        NSApp.terminate(nil)
    }
}
