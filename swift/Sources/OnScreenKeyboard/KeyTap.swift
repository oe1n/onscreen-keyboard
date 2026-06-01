import CoreGraphics
import Foundation
import os

private let log = Logger(subsystem: "com.oein.onscreen-keyboard", category: "tap")

final class KeyTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Called on the event-tap thread for every key event.
    /// Return `nil` to consume the event, or the (possibly-modified) event to pass through.
    var onEvent: ((CGEventType, CGEvent) -> CGEvent?)?

    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                log.warning("Tap disabled (type=\(type.rawValue)) — re-enabling")
                if let tap = me.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if let processed = me.onEvent?(type, event) {
                return Unmanaged.passUnretained(processed)
            }
            return nil
        }

        // Session-level tap. HID-level (.cghidEventTap) is tempting because it sits
        // earlier in the pipeline, but for a non-root, ad-hoc-signed process tapCreate
        // returns non-nil yet never delivers events — so the fallback never triggers
        // and the app silently dies. Session-level is reliable with Accessibility alone.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            log.error("CGEvent.tapCreate(.cgSessionEventTap) failed — Accessibility permission missing or not yet propagated for this binary")
            return false
        }
        log.info("Event tap created at .cgSessionEventTap")

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Event tap installed and enabled")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit { stop() }
}
