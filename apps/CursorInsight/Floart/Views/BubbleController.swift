// Floart/Views/BubbleController.swift
import AppKit
import SwiftUI

/// NSPanel wrapper for the inline action bubble. Positioning is computed from
/// the focused input's AX rect; the actual show/hide animation is driven by a
/// SwiftUI `BubbleState` so both entrance and exit play through the view's
/// `transition`.
///
/// Dismissal policy:
///   - Close button
///   - Fill button
///   - 60-second auto-hide timeout
///   - App-switch: orchestrator calls `close()` when frontmost app ≠ owner
///   - Explicit `close()` from the orchestrator
///
/// NOT dismissed by: focus leaving the input (within the same app), clicks
/// outside, or new analysis arriving. New analysis updates content in place.
@MainActor
final class BubbleController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<BubbleView>?
    private var state: BubbleState?
    private var autoHideTimer: Timer?
    private var lastTargetRect: CGRect?

    /// Bundle id of the app that owned the focused input when the bubble
    /// was last shown. Used by the orchestrator to dismiss on app switch.
    private(set) var ownerBundleId: String?

    var isShowing: Bool { panel != nil && (state?.visible ?? false) }

    /// Gap between bubble and input edge.
    private static let gap: CGFloat = 10
    /// Exit animation duration — must be slightly longer than the SwiftUI
    /// spring so the window doesn't orderOut mid-animation.
    private static let exitDuration: TimeInterval = 0.55

    /// Show or retarget the bubble.
    func show(action: String, near axRect: CGRect, ownerBundleId: String?, onFill: @escaping () -> Void) {
        self.lastTargetRect = axRect
        self.ownerBundleId = ownerBundleId
        resetAutoHideTimer()

        // Reuse an existing panel if we have one — update state and reposition.
        if let panel, let state {
            let fitting = hostingView?.fittingSize ?? panel.frame.size
            let (origin, anchor) = computeLayout(size: fitting, axRect: axRect)
            panel.setFrame(NSRect(origin: origin, size: fitting), display: true)
            state.action = action
            state.anchor = anchor
            state.onFill = { [weak self] in
                onFill()
                self?.close()
            }
            state.onClose = { [weak self] in self?.close() }
            // Kick the visibility to retrigger the entrance transition.
            if state.visible == false {
                state.visible = true
            }
            panel.orderFront(nil)
            return
        }

        // Fresh panel. Content is always in the layout, so fittingSize works
        // even while state.visible is false — no measurement dance needed.
        let newState = BubbleState()
        newState.action = action
        newState.onFill = { [weak self] in
            onFill()
            self?.close()
        }
        newState.onClose = { [weak self] in self?.close() }

        let hv = NSHostingView(rootView: BubbleView(state: newState))
        hv.wantsLayer = true
        hv.layer?.backgroundColor = .clear
        let fitting = hv.fittingSize
        let (origin, anchor) = computeLayout(size: fitting, axRect: axRect)
        newState.anchor = anchor

        let newPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: fitting),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false  // glass modifier supplies the shadow
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.hidesOnDeactivate = false
        newPanel.alphaValue = 1
        newPanel.contentView = hv
        newPanel.orderFront(nil)

        self.panel = newPanel
        self.hostingView = hv
        self.state = newState

        // Trigger the entrance animation on the next runloop tick.
        DispatchQueue.main.async {
            newState.visible = true
        }
    }

    /// Update the displayed action text without resetting the auto-hide timer.
    /// Used when a new analysis arrives while the bubble is still on screen.
    func updateAction(_ action: String, onFill: @escaping () -> Void) {
        guard let state, let panel, let rect = lastTargetRect else { return }
        state.action = action
        state.onFill = { [weak self] in
            onFill()
            self?.close()
        }
        state.onClose = { [weak self] in self?.close() }
        if let hv = hostingView {
            let fitting = hv.fittingSize
            let (origin, _) = computeLayout(size: fitting, axRect: rect)
            panel.setFrame(NSRect(origin: origin, size: fitting), display: true)
        }
    }

    /// Play the exit animation, then orderOut the panel.
    /// Idempotent — a second call while already closing is a no-op.
    func close() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil

        guard let panel, let state, state.visible else {
            // Already closing or not shown — just make sure we're clean.
            hardCleanup()
            return
        }

        // Trigger exit animation.
        state.visible = false

        // Capture the outgoing panel and release instance state so a
        // subsequent show() creates a fresh bubble immediately.
        let outgoing = panel
        self.panel = nil
        self.hostingView = nil
        self.state = nil
        self.lastTargetRect = nil
        self.ownerBundleId = nil

        // Orderly removal after the SwiftUI exit transition finishes.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.exitDuration) { [weak outgoing] in
            outgoing?.orderOut(nil)
        }
    }

    private func hardCleanup() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        state = nil
        lastTargetRect = nil
        ownerBundleId = nil
    }

    // MARK: - Positioning

    /// Compute the bubble's AppKit-space origin and its growth anchor given
    /// the input's AX-space rect. Multi-monitor handled by locating the
    /// screen that contains the input center (after AX→AppKit coord flip).
    ///
    /// Thin instance wrapper around the pure static variant — tests drive
    /// the static one with a fixed screen geometry.
    private func computeLayout(size: NSSize, axRect: CGRect) -> (CGPoint, BubbleGrowthAnchor) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let axCenterInAppKit = CGPoint(
            x: axRect.midX,
            y: primaryHeight - axRect.midY
        )
        let screen = NSScreen.screens.first(where: { $0.frame.contains(axCenterInAppKit) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return (.zero, .fromBottom) }

        var (origin, anchor) = Self.computeLayout(
            size: size,
            axRect: axRect,
            visibleFrame: screen.visibleFrame,
            primaryScreenHeight: primaryHeight,
            gap: Self.gap
        )

        // Avoid overlapping any other Floart panel (e.g. the main
        // InsightPanelView sitting in the top-right). Only shifts X so the
        // bubble still reads as "near the input".
        origin = avoidOtherFloartPanels(origin: origin, size: size, visibleFrame: screen.visibleFrame)

        return (origin, anchor)
    }

    /// Pure positioning logic. AX coords are top-left global (measured from
    /// primary screen top); result is in AppKit bottom-left global coords.
    ///
    /// - Parameters:
    ///   - size: bubble panel's fitting size
    ///   - axRect: input rect in AX coords
    ///   - visibleFrame: visible frame of the screen the bubble should land on
    ///   - primaryScreenHeight: height of the primary screen (needed for AX flip)
    ///   - gap: padding between bubble and input edges
    /// - Returns: (origin, growth anchor). Origin does NOT include the
    ///   other-panel avoidance step — the instance method layers that on top.
    nonisolated static func computeLayout(
        size: NSSize,
        axRect: CGRect,
        visibleFrame: NSRect,
        primaryScreenHeight: CGFloat,
        gap: CGFloat
    ) -> (CGPoint, BubbleGrowthAnchor) {
        let inputTopY    = primaryScreenHeight - axRect.origin.y
        let inputBottomY = primaryScreenHeight - axRect.origin.y - axRect.size.height
        let inputLeftX   = axRect.origin.x

        let spaceAbove = visibleFrame.maxY - inputTopY
        let fitsAbove = spaceAbove >= size.height + gap + 8

        var origin: CGPoint
        let anchor: BubbleGrowthAnchor
        if fitsAbove {
            origin = CGPoint(x: inputLeftX, y: inputTopY + gap)
            anchor = .fromBottom
        } else {
            origin = CGPoint(x: inputLeftX, y: inputBottomY - size.height - gap)
            anchor = .fromTop
        }

        // Clamp x into the visible frame.
        if origin.x + size.width > visibleFrame.maxX { origin.x = visibleFrame.maxX - size.width - 4 }
        if origin.x < visibleFrame.minX { origin.x = visibleFrame.minX + 4 }
        // Safety y clamp for degenerate cases (tiny screen, huge bubble).
        if origin.y + size.height > visibleFrame.maxY { origin.y = visibleFrame.maxY - size.height - 4 }
        if origin.y < visibleFrame.minY { origin.y = visibleFrame.minY + 4 }

        return (origin, anchor)
    }

    /// Shift the computed origin horizontally to avoid intersecting any other
    /// visible panel owned by this app. Returns the original origin if no
    /// overlap, or a shifted one otherwise.
    ///
    /// Strategy: try placing the bubble to the **left** of the offending
    /// panel first (since the main Floart panel anchors top-right, this is
    /// usually where there's the most free space). If that goes off-screen,
    /// try the right side. If both fail, fall back to the original (we'd
    /// rather overlap slightly than push the bubble off-screen).
    private func avoidOtherFloartPanels(origin: CGPoint, size: NSSize, visibleFrame: NSRect) -> CGPoint {
        let bubbleRect = NSRect(origin: origin, size: size)
        // Consider only other panels from this process that are visible and
        // at a floating level (i.e. likely overlays, not background windows).
        let others = NSApplication.shared.windows.filter { win in
            win !== self.panel &&
            win.isVisible &&
            win.level.rawValue >= NSWindow.Level.floating.rawValue
        }

        for other in others {
            let otherFrame = other.frame
            guard bubbleRect.intersects(otherFrame) else { continue }

            let gap: CGFloat = 8

            // Try left of the offending panel.
            let leftX = otherFrame.minX - size.width - gap
            if leftX >= visibleFrame.minX + 4 {
                return CGPoint(x: leftX, y: origin.y)
            }

            // Try right of the offending panel.
            let rightX = otherFrame.maxX + gap
            if rightX + size.width <= visibleFrame.maxX - 4 {
                return CGPoint(x: rightX, y: origin.y)
            }

            // Neither side fits — leave as-is. The bubble will overlap but at
            // least remains on-screen and near the input.
            break
        }

        return origin
    }

    private func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }
}
