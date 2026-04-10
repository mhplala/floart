// Floart/Utilities/AccessibilityHelper.swift
import AppKit
import ApplicationServices

/// Extract UI element info via macOS system APIs.
enum AccessibilityHelper {

    /// Try to extract the chat title from the frontmost app's window.
    /// Uses CGWindowList (works without AX permission) then AX API as fallback.
    /// Returns nil if the app doesn't expose a useful window title
    /// (Electron apps like Feishu/WeChat typically don't).
    static func extractChatTitle() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appName = app.localizedName ?? ""

        // Strategy 1: CGWindowList — check if the window name contains a chat title
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for w in windowList {
            guard let ownerPID = w[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
            guard let name = w[kCGWindowName as String] as? String, !name.isEmpty else { continue }
            // Window name might be "AppName" or "ChatTitle - AppName"
            if let title = cleanTitle(name, appName: appName) {
                return title
            }
        }

        // Strategy 2: AX focused element — some apps expose title in the focus chain
        let axApp = AXUIElementCreateApplication(pid)
        var focusedValue: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedValue) == .success,
           let axWindow = focusedValue {
            if let title = axStringAttribute(axWindow as! AXUIElement, kAXTitleAttribute) {
                if let cleaned = cleanTitle(title, appName: appName) {
                    return cleaned
                }
            }
        }

        return nil
    }

    // MARK: - Helpers

    private static func axStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let str = value as? String, !str.isEmpty else { return nil }
        return str
    }

    /// Clean a raw window title to extract the chat name.
    private static func cleanTitle(_ title: String, appName: String?) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Skip if it's just the app name
        if let app = appName, trimmed == app { return nil }

        // "蔡菲 - 飞书" → "蔡菲"
        for separator in [" - ", " — ", " | "] {
            if let range = trimmed.range(of: separator) {
                let before = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if before.count >= 2 && before.count <= 30 && before != appName { return before }
            }
        }

        // If the title itself is short and not the app name
        if trimmed.count >= 2 && trimmed.count <= 30 && trimmed != appName {
            return trimmed
        }

        return nil
    }
}
