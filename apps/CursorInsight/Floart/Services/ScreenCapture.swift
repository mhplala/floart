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

    static func captureAroundMouse(size: CGFloat) async throws -> CGImage? {
        let mouseLocation = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.main else { return nil }
        let screenHeight = mainScreen.frame.height
        let scale = mainScreen.backingScaleFactor

        let halfSize = size / 2
        let cgMouseX = mouseLocation.x
        let cgMouseY = screenHeight - mouseLocation.y

        var x = cgMouseX - halfSize
        var y = cgMouseY - halfSize
        x = max(0, min(x, mainScreen.frame.width - size))
        y = max(0, min(y, screenHeight - size))

        let captureRect = CGRect(x: x, y: y, width: size, height: size)

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myWindows = content.windows.filter { $0.owningApplication?.processID == myPID }

        guard let display = content.displays.first else { return nil }

        let filter = SCContentFilter(display: display, excludingWindows: myWindows)
        let config = SCStreamConfiguration()
        config.sourceRect = captureRect
        config.width = Int(size * scale)
        config.height = Int(size * scale)
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    // MARK: - Smart window: capture the frontmost app's main window

    static func captureFrontmostWindow() async throws -> CGImage? {
        let myPID = ProcessInfo.processInfo.processIdentifier

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != myPID else {
            Log.write("🪟 No frontmost app or it's us, fallback")
            return try await captureAroundMouse(size: 2000)
        }

        let appPID = frontApp.processIdentifier
        Log.write("🪟 Frontmost: \(frontApp.localizedName ?? "?") (pid: \(appPID))")

        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

        // Find the largest on-screen window belonging to the frontmost app
        let appWindows = content.windows.filter {
            $0.owningApplication?.processID == appPID &&
            $0.isOnScreen &&
            $0.frame.width >= 100 &&
            $0.frame.height >= 100
        }.sorted { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }

        guard let window = appWindows.first else {
            Log.write("🪟 No window found for \(frontApp.localizedName ?? "?"), fallback")
            return try await captureAroundMouse(size: 2000)
        }

        let frame = window.frame
        Log.write("🪟 Capturing: \(Int(frame.width))x\(Int(frame.height))")

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(frame.width * 2) // Retina
        config.height = Int(frame.height * 2)
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    // MARK: - Unified entry point

    static func capture(mode: CaptureMode, fixedSize: CGFloat) async throws -> CGImage? {
        switch mode {
        case .fixedArea:
            return try await captureAroundMouse(size: fixedSize)
        case .smartWindow:
            return try await captureFrontmostWindow()
        }
    }
}
