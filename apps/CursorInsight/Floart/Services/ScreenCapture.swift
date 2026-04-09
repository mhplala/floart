// Floart/Services/ScreenCapture.swift
import AppKit
import CoreGraphics
import ScreenCaptureKit

enum CaptureMode: String, Sendable, CaseIterable {
    case fixedArea = "fixed"
    case smartWindow = "window"
}

enum ScreenCapture {

    // MARK: - Fixed-area capture

    /// Capture a region around the current mouse position.
    static func captureAroundMouse(size: CGFloat) async throws -> CGImage? {
        let mouseLocation = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.main else { return nil }
        let screenHeight = mainScreen.frame.height

        let halfSize = size / 2
        var x = mouseLocation.x - halfSize
        var y = mouseLocation.y - halfSize

        // Clamp to screen bounds (NSScreen coordinates: origin bottom-left)
        let screenFrame = mainScreen.frame
        x = max(screenFrame.minX, min(x, screenFrame.maxX - size))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - size))

        // SCScreenshotManager.captureImage(in:) uses display-space points
        // with origin at top-left of the primary display.
        // Convert NSScreen (bottom-left origin) to display space (top-left origin).
        let displayY = screenHeight - (y + size)
        let captureRect = CGRect(x: x, y: displayY, width: size, height: size)

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: captureRect) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    // MARK: - Smart-window capture

    /// Capture the window under the current mouse position.
    /// Falls back to fixed-area capture if no window is found.
    static func captureWindowUnderMouse(fallbackSize: CGFloat) async throws -> CGImage? {
        let mouseLocation = NSEvent.mouseLocation

        let content = try await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true
        )

        // Find the topmost window that contains the mouse location.
        // SCWindow.frame uses the same coordinate system as NSScreen (bottom-left origin).
        for window in content.windows {
            let frame = window.frame
            guard frame.contains(mouseLocation) else { continue }
            guard frame.width >= 100, frame.height >= 100 else { continue }
            guard window.isOnScreen else { continue }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = Int(frame.width)
            config.height = Int(frame.height)

            return try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: image)
                    }
                }
            }
        }

        return try await captureAroundMouse(size: fallbackSize)
    }

    // MARK: - Unified entry point

    /// Capture using the specified mode.
    static func capture(mode: CaptureMode, fixedSize: CGFloat) async throws -> CGImage? {
        switch mode {
        case .fixedArea:
            return try await captureAroundMouse(size: fixedSize)
        case .smartWindow:
            return try await captureWindowUnderMouse(fallbackSize: fixedSize)
        }
    }
}
