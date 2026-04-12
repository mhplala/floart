// Floart/Services/InputFiller.swift
import AppKit
import ApplicationServices

/// Fills text into the currently focused text input using a tiered strategy:
///
/// 1. **AXSetValue (append)**: read the current value via
///    `kAXValueAttribute`, concatenate, write back. Clean — no clipboard
///    pollution and no synthetic keystrokes. Works for native Cocoa text
///    views (Messages, Notes, Xcode, Pages, Safari address bar, …).
///
/// 2. **Clipboard + synthetic ⌘V**: fallback for apps where AXSetValue is
///    read-only (WeChat, Electron-based apps like Slack/Discord/VS Code).
///    We move the caret to the end first (`kAXSelectedTextRangeAttribute`)
///    so the paste appends rather than inserting mid-text. After the paste
///    is dispatched, the old clipboard is restored on a short delay.
///
/// Both strategies assume the caller already holds macOS Accessibility
/// permission (which Floart requires for its existing focus-detection code).
enum InputFiller {
    enum Strategy: String { case axSetValue, clipboardPaste }

    /// Append `text` to whatever text input currently has keyboard focus.
    /// Returns the strategy that succeeded, or nil if both failed.
    @MainActor
    static func appendToFocusedInput(_ text: String) -> Strategy? {
        guard !text.isEmpty else { return nil }

        if axAppend(text: text) {
            Log.write("🪣 Fill: AXSetValue ok (\(text.count) chars)")
            return .axSetValue
        }

        if clipboardPaste(text: text) {
            Log.write("🪣 Fill: clipboard-paste (\(text.count) chars)")
            return .clipboardPaste
        }

        Log.write("🪣 Fill: FAILED — both strategies")
        return nil
    }

    // MARK: - Strategy 1 — AXSetValue

    private static func axAppend(text: String) -> Bool {
        guard let elem = focusedElement() else { return false }

        // Read current value. Absence of the attribute is treated as empty.
        var currentRef: AnyObject?
        _ = AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &currentRef)
        let current = (currentRef as? String) ?? ""

        let appended = current + text

        let setResult = AXUIElementSetAttributeValue(
            elem, kAXValueAttribute as CFString, appended as CFString
        )
        if setResult != .success {
            Log.write("🪣 AXSetValue failed: \(setResult.rawValue)")
            return false
        }
        return true
    }

    // MARK: - Strategy 2 — clipboard + paste

    private static func clipboardPaste(text: String) -> Bool {
        let pb = NSPasteboard.general
        let oldString = pb.string(forType: .string)

        pb.clearContents()
        pb.setString(text, forType: .string)

        // Try to move the caret to end so the paste appends, not inserts.
        if let elem = focusedElement() {
            moveCaretToEnd(elem)
        }

        guard postCmdV() else {
            // Restore clipboard right away if we couldn't even dispatch.
            pb.clearContents()
            if let old = oldString { pb.setString(old, forType: .string) }
            return false
        }

        // Restore the old clipboard after the paste has been processed.
        // 250ms is enough for even slow apps (Electron) to consume the paste.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            pb.clearContents()
            if let old = oldString { pb.setString(old, forType: .string) }
        }
        return true
    }

    /// Move the caret to the end of the text in the given element via
    /// `kAXSelectedTextRangeAttribute`. Best-effort — if the app doesn't
    /// expose the range attribute, we silently skip and let the paste land
    /// at the user's current caret position.
    private static func moveCaretToEnd(_ elem: AXUIElement) {
        var lengthRef: AnyObject?
        guard AXUIElementCopyAttributeValue(elem, kAXNumberOfCharactersAttribute as CFString, &lengthRef) == .success,
              let length = lengthRef as? Int else {
            return
        }
        var range = CFRange(location: length, length: 0)
        if let value = AXValueCreate(.cfRange, &range) {
            _ = AXUIElementSetAttributeValue(elem, kAXSelectedTextRangeAttribute as CFString, value)
        }
    }

    private static func postCmdV() -> Bool {
        let vKey: CGKeyCode = 0x09  // kVK_ANSI_V
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Focused element lookup

    /// Re-read the current focused UI element at fill time (rather than
    /// caching it at bubble-show time, which can go stale if the user clicks
    /// around before hitting 填入).
    private static func focusedElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
              let ref,
              CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            return nil
        }
        return (ref as! AXUIElement)
    }
}
