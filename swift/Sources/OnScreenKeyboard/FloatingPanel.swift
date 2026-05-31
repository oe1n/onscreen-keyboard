import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init<Content: View>(size: NSSize, rootView: Content) {
        let rect = NSRect(origin: .zero, size: size)
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        worksWhenModal = true

        let host = NSHostingView(rootView: rootView)
        host.frame = rect
        host.autoresizingMask = [.width, .height]
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
