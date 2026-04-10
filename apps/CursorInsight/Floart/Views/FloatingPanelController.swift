// Floart/Views/FloatingPanelController.swift
import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?
    private var sizeObserver: NSObjectProtocol?
    private var sizeTimer: Timer?

    func show<Content: View>(_ content: Content, size: NSSize? = nil) {
        let hostingView = NSHostingView(rootView: content)
        let fittingSize = size ?? hostingView.fittingSize

        if let panel {
            // Remove old observer
            if let obs = sizeObserver {
                NotificationCenter.default.removeObserver(obs)
            }
            panel.contentView = hostingView
            resizePanel(to: fittingSize)
            observeContentSize(hostingView)
            panel.orderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height),
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
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true

        panel.contentView = hostingView

        // Position in top-right corner, clamped to visible area
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let x = min(vf.maxX - fittingSize.width - 16, vf.maxX - 16)
            let y = max(vf.maxY - fittingSize.height - 8, vf.minY)
            panel.setFrameOrigin(NSPoint(x: max(x, vf.minX), y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
        observeContentSize(hostingView)
    }

    func close() {
        if let obs = sizeObserver {
            NotificationCenter.default.removeObserver(obs)
            sizeObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    /// Watch the hosting view's intrinsic size and resize panel when content changes.
    private func observeContentSize(_ hostingView: NSHostingView<some View>) {
        // Invalidate any existing timer to prevent stacking
        sizeTimer?.invalidate()
        // Use a timer to poll fittingSize since NSHostingView doesn't notify on size changes
        sizeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak hostingView] timer in
            guard let self, let panel = self.panel, let hv = hostingView else {
                timer.invalidate()
                return
            }
            let newSize = hv.fittingSize
            let currentSize = panel.frame.size
            // Only resize if significantly different (avoid jitter)
            if abs(newSize.height - currentSize.height) > 5 || abs(newSize.width - currentSize.width) > 5 {
                self.resizePanel(to: newSize)
            }
        }
    }

    private func resizePanel(to size: NSSize) {
        guard let panel else { return }
        // Clamp height to reasonable bounds
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 800
        let clampedHeight = min(size.height, maxHeight * 0.8)
        let newSize = NSSize(width: size.width, height: clampedHeight)

        // Keep top-right corner fixed (resize from bottom)
        var frame = panel.frame
        let topY = frame.origin.y + frame.size.height
        frame.size = newSize
        frame.origin.y = topY - newSize.height

        // Clamp to visible screen
        if let vf = NSScreen.main?.visibleFrame {
            frame.origin.x = min(frame.origin.x, vf.maxX - frame.width)
            frame.origin.x = max(frame.origin.x, vf.minX)
            frame.origin.y = max(frame.origin.y, vf.minY)
            if frame.origin.y + frame.height > vf.maxY {
                frame.origin.y = vf.maxY - frame.height
            }
        }
        panel.setFrame(frame, display: true, animate: true)
    }
}
