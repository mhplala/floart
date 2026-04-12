// Floart/Utilities/AccessibilityHelper.swift
import AppKit
import ApplicationServices

/// Extract UI element info via macOS system APIs.
enum AccessibilityHelper {

    // MARK: - Focused input detection

    /// Info about the currently focused text input — used by SceneClassifier
    /// and (Step 2) the inline bubble positioning.
    struct FocusedInputInfo: Sendable {
        let role: String              // AXTextField / AXTextArea / AXComboBox / AXSearchField
        let placeholder: String?      // e.g. "Message #eng-platform", "Ask Claude anything"
        let title: String?
        let description: String?
        let frame: CGRect?            // screen coordinates (top-left origin from AX)
        let appName: String
        let bundleId: String?

        /// Concatenated hint text from placeholder/title/description for classifier + prompt.
        var hintText: String? {
            let parts = [placeholder, title, description].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    /// Detect the currently focused text input across apps (including web content).
    /// Returns nil if no text input has focus, or if AX cannot read it.
    ///
    /// Strategy (falls through on failure):
    ///   1. `kAXFocusedUIElement` on the frontmost app — works for native Cocoa apps.
    ///   2. Walk `kAXFocusedWindow` looking for a descendant with `AXFocused = true`
    ///      — rescues some Electron apps (Slack/Discord/VS Code) that don't expose
    ///      focusedUIElement directly.
    static func detectFocusedInput() -> FocusedInputInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appName = app.localizedName ?? ""
        let bundleId = app.bundleIdentifier

        let axApp = AXUIElementCreateApplication(pid)

        // Strategy 1: direct focused UI element
        var focusedRef: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let ref = focusedRef,
           CFGetTypeID(ref) == AXUIElementGetTypeID() {
            let elem = ref as! AXUIElement
            if let info = buildFocusedInputInfo(from: elem, appName: appName, bundleId: bundleId) {
                return info
            }
        }

        // Strategy 2: focused window descendants search
        var focusedWin: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success,
           let ref = focusedWin,
           CFGetTypeID(ref) == AXUIElementGetTypeID() {
            let win = ref as! AXUIElement
            if let elem = findFocusedTextElement(in: win, depth: 0),
               let info = buildFocusedInputInfo(from: elem, appName: appName, bundleId: bundleId) {
                return info
            }
        }

        return nil
    }

    private static let textInputRoles: Set<String> = [
        "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"
    ]

    private static func buildFocusedInputInfo(
        from elem: AXUIElement,
        appName: String,
        bundleId: String?
    ) -> FocusedInputInfo? {
        guard let role = axStringAttribute(elem, kAXRoleAttribute) else { return nil }
        guard textInputRoles.contains(role) else { return nil }

        return FocusedInputInfo(
            role: role,
            placeholder: axStringAttribute(elem, kAXPlaceholderValueAttribute),
            title: axStringAttribute(elem, kAXTitleAttribute),
            description: axStringAttribute(elem, kAXDescriptionAttribute),
            frame: axFrame(elem),
            appName: appName,
            bundleId: bundleId
        )
    }

    private static func findFocusedTextElement(in element: AXUIElement, depth: Int) -> AXUIElement? {
        if depth > 8 { return nil }  // guard against runaway recursion

        // Is this element itself a focused text input?
        var focusedValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &focusedValue) == .success,
           let isFocused = focusedValue as? Bool, isFocused,
           let role = axStringAttribute(element, kAXRoleAttribute),
           textInputRoles.contains(role) {
            return element
        }

        // Recurse
        var childrenRef: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFocusedTextElement(in: child, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    private static func axFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: AnyObject?
        var sizeRef: AnyObject?
        let posOK = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success
        let sizeOK = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success
        guard posOK, sizeOK, let posRef, let sizeRef else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    // MARK: - Window title (legacy)

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
