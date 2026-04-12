// Floart/Services/SceneClassifier.swift
import Foundation

/// Decides the current SceneType from the frontmost app and focused-input signals.
///
/// Design: focused-input *placeholder/title* hints trump app category, because
/// the same app can host multiple scenes (Notion can be document-writing or AI chat;
/// Slack's "Jump to" search looks like a chat input but shouldn't produce a reply).
/// When no focused input is detected, fall back to app bundle classification.
enum SceneClassifier {

    // MARK: - Bundle ID sets

    private static let dmChatBundles: Set<String> = [
        "com.apple.MobileSMS",              // Messages
        "com.tencent.xinWeChat",            // WeChat
        "com.tencent.qq",                   // QQ
        "com.tinyspeck.slackmacgap",        // Slack
        "org.telegram.desktop",             // Telegram
        "ru.keepcoder.Telegram",            // Telegram (Mac App Store)
        "com.hnc.Discord",                  // Discord
        "com.microsoft.teams2",             // Teams (new)
        "com.microsoft.teams",              // Teams (classic)
        "net.whatsapp.WhatsApp",            // WhatsApp
        "com.electron.lark",                // Lark/Feishu (Electron)
        "com.bytedance.feishu",             // Feishu
        "com.bytedance.lark",               // Lark
        "com.alibaba.DingTalkMac",          // DingTalk
        "im.dingtalk.mac",                  // DingTalk (alt)
    ]

    private static let meetingBundles: Set<String> = [
        "us.zoom.xos",                      // Zoom
        "com.tencent.meeting",              // Tencent Meeting
        "com.bytedance.lark.meeting",       // Lark Meeting
        // Note: Google Meet lives inside a browser — detected via hints, not bundle id.
    ]

    /// Apps where "writing in the text area" means "give me a prompt".
    /// User decision: VS Code counts as vibe coding (not plain code editor).
    private static let vibeCodingBundles: Set<String> = [
        "com.todesktop.230313mzl4w4u92",    // Cursor
        "com.microsoft.VSCode",             // VS Code
        "com.anthropic.claudeforhumans",    // Claude desktop
        "com.anthropic.claude",             // Claude desktop (alt)
        "com.openai.chat",                  // ChatGPT desktop
        "dev.zed.Zed",                      // Zed
        "com.exafunction.windsurf",         // Windsurf
        "com.codeium.windsurf",             // Windsurf (alt)
    ]

    private static let codeEditorBundles: Set<String> = [
        "com.apple.dt.Xcode",               // Xcode
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.pycharm",
        "com.jetbrains.pycharm.ce",
        "com.jetbrains.goland",
        "com.jetbrains.CLion",
        "com.jetbrains.WebStorm",
        "com.jetbrains.RubyMine",
        "com.jetbrains.AppCode",
        "com.sublimetext.4",
        "com.github.atom",
        "com.panic.Nova",
    ]

    private static let documentBundles: Set<String> = [
        "com.apple.iWork.Pages",            // Pages
        "com.microsoft.Word",               // Word
        "notion.id",                        // Notion
        "md.obsidian",                      // Obsidian
        "net.shinyfrog.bear",               // Bear
        "com.agiletortoise.Drafts-OSX",     // Drafts
        "com.literatureandlatte.scrivener3",// Scrivener
        "com.quip.desktop",                 // Quip
        "com.craft.craftdocs",              // Craft
        "com.apple.Notes",                  // Apple Notes
        "com.culturedcode.ThingsMac",       // Things (arguable, but fine as .document)
    ]

    private static let browserBundles: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.apple.Safari",
        "company.thebrowser.Browser",       // Arc
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.brave.Browser",
    ]

    // MARK: - Classification

    /// Classify the current scene.
    /// - Parameters:
    ///   - bundleId: frontmost app's bundle identifier (nil if unknown)
    ///   - focusedInput: detected focused text input, or nil if none / AX failed
    ///
    /// Priority:
    ///   1. Search hint (always wins — search fields look like DM inputs otherwise).
    ///   2. Known "strong" bundle id (DM app / vibe-coding / docs / code editor / meeting).
    ///      A hint like "Message input" inside VS Code is still vibe-coding, not DM.
    ///   3. Browser bundle → use hints (or fall back to .note if none).
    ///   4. Unknown bundle → use hints.
    ///   5. Final fallback → .note.
    static func classify(
        bundleId: String?,
        focusedInput: AccessibilityHelper.FocusedInputInfo?
    ) -> SceneType {
        let hint = focusedInput?.hintText?.lowercased()

        // 1. Search hint always wins (search boxes must never produce a DM/prompt action).
        if let hint, containsAny(hint, ["search", "搜索", "查找", "搜一搜", "find in"]) {
            return .search
        }

        // 2. Strong bundle-id categories win over hints.
        //    Rationale: an AI chat panel inside VS Code is still vibe-coding, even if
        //    its placeholder is "Message input". A reply draft in WeChat is still a
        //    DM reply, even if the focused input has no placeholder.
        if let bundleId {
            if dmChatBundles.contains(bundleId)     { return .dmChat }
            if vibeCodingBundles.contains(bundleId) { return .vibeCoding }
            if documentBundles.contains(bundleId)   { return .document }
            if codeEditorBundles.contains(bundleId) { return .codeEditor }
            if meetingBundles.contains(bundleId)    { return .meeting }
        }

        // 3. Browser or unknown bundle: hints are the only signal we have.
        if let hint {
            if containsAny(hint, ["ask claude", "ask chatgpt", "ask gemini",
                                  "ask anything", "message claude", "message chatgpt",
                                  "message copilot", "prompt", "问 ai", "ask copilot"]) {
                return .vibeCoding
            }
            if containsAny(hint, ["comment", "评论", "批注", "add a note"]) {
                return .document
            }
            if containsAny(hint, ["message ", "reply", "send a message",
                                  "type a message", "消息", "回复"]) {
                return .dmChat
            }
        }

        // 4. Browsers without a useful hint → assume reading.
        if let bundleId, browserBundles.contains(bundleId) {
            return .note
        }

        // 5. Total fallback.
        return .note
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        for n in needles {
            if haystack.contains(n) { return true }
        }
        return false
    }
}
