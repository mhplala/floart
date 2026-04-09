// Floart/Views/FloatingPanelController.swift
import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?

    func show<Content: View>(_ content: Content, size: NSSize = NSSize(width: 320, height: 400)) {
        if let panel {
            panel.contentView = NSHostingView(rootView: content)
            updateSize(width: size.width, height: size.height)
            panel.orderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        panel.contentView = NSHostingView(rootView: content)

        // Position in top-right corner
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 340
            let y = screen.visibleFrame.maxY - 420
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func updateSize(width: CGFloat, height: CGFloat) {
        guard let panel else { return }
        var frame = panel.frame
        frame.size = NSSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
    }
}
