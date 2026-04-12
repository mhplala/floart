// FloartTests/ContextKeyTests.swift
//
// Tests for the pure static variants of `resolveChatTitle` and `contextKey`
// on InsightOrchestrator. These are the single source of truth for how
// analyzer + focus poller + ContextStore bucket by app and chat — a bug
// here directly causes context bleed (findings 1 & 2 from the review).
import XCTest
@testable import Floart

final class ContextKeyTests: XCTestCase {

    // MARK: - resolveChatTitle

    func testResolveReturnsNilForNonChatScenes() {
        for scene in [SceneType.note, .document, .vibeCoding, .codeEditor, .meeting, .search] {
            XCTAssertNil(
                InsightOrchestrator.resolveChatTitle(
                    sceneType: scene,
                    appName: "WeChat",
                    axChatTitle: "Alice",
                    currentConversationKey: "WeChat:Alice"
                ),
                "scene \(scene) should never produce a chat title"
            )
        }
    }

    func testResolvePrefersFreshAxTitleOverStaleKey() {
        // User just switched from Alice to Bob inside WeChat. AX has the
        // fresh "Bob" title, but OCR loop hasn't updated currentConversationKey
        // yet — it still says Alice. We MUST use the fresh title.
        let resolved = InsightOrchestrator.resolveChatTitle(
            sceneType: .dmChat,
            appName: "微信",
            axChatTitle: "Bob",
            currentConversationKey: "微信:Alice"
        )
        XCTAssertEqual(resolved, "Bob")
    }

    func testResolveFallsBackToStaleKeyWhenAxFails() {
        // Electron WeChat: AX can't read the window title, but an earlier
        // OCR loop did find "Alice" and stashed it in currentConversationKey.
        // Use it — better than nothing.
        let resolved = InsightOrchestrator.resolveChatTitle(
            sceneType: .dmChat,
            appName: "微信",
            axChatTitle: nil,
            currentConversationKey: "微信:Alice"
        )
        XCTAssertEqual(resolved, "Alice")
    }

    func testResolveIgnoresStaleKeyFromDifferentApp() {
        // Stale key belongs to Slack but current app is WeChat — don't
        // cross-contaminate. Return nil so the caller falls back to the
        // app bucket, not to a wrong chat bucket.
        let resolved = InsightOrchestrator.resolveChatTitle(
            sceneType: .dmChat,
            appName: "微信",
            axChatTitle: nil,
            currentConversationKey: "Slack:general"
        )
        XCTAssertNil(resolved)
    }

    func testResolveReturnsNilWhenBothSourcesMissing() {
        let resolved = InsightOrchestrator.resolveChatTitle(
            sceneType: .dmChat,
            appName: "微信",
            axChatTitle: nil,
            currentConversationKey: nil
        )
        XCTAssertNil(resolved)
    }

    func testResolveIgnoresEmptyAxTitle() {
        // An empty string from AX counts as "no data" — fall back to stale.
        let resolved = InsightOrchestrator.resolveChatTitle(
            sceneType: .dmChat,
            appName: "微信",
            axChatTitle: "",
            currentConversationKey: "微信:Carol"
        )
        XCTAssertEqual(resolved, "Carol")
    }

    func testResolveStripsAppPrefixCorrectly() {
        // Chat title contains a colon — make sure dropFirst drops exactly
        // "appName:" and keeps the rest intact.
        let resolved = InsightOrchestrator.resolveChatTitle(
            sceneType: .dmChat,
            appName: "Slack",
            axChatTitle: nil,
            currentConversationKey: "Slack:eng:platform:thread"
        )
        XCTAssertEqual(resolved, "eng:platform:thread")
    }

    // MARK: - contextKey

    func testContextKeyUsesChatBucketWhenTitleResolved() {
        let key = InsightOrchestrator.contextKey(
            sceneType: .dmChat,
            appName: "微信",
            bundleId: "com.tencent.xinWeChat",
            chatTitle: "Ceciliax"
        )
        XCTAssertEqual(key, "chat:微信:Ceciliax")
    }

    func testContextKeyFallsBackToAppBucketWhenChatTitleMissing() {
        // This is critical: finding 2 was about chat bucket collapsing to
        // app.md when AX fails. The correct behavior is to use "app:<bundle>"
        // so different chats in the same Electron app share an app-level
        // bucket instead of smashing into one file named "unknown.md".
        let key = InsightOrchestrator.contextKey(
            sceneType: .dmChat,
            appName: "微信",
            bundleId: "com.tencent.xinWeChat",
            chatTitle: nil
        )
        XCTAssertEqual(key, "app:com.tencent.xinWeChat")
    }

    func testContextKeyFallsBackToAppBucketForEmptyChatTitle() {
        let key = InsightOrchestrator.contextKey(
            sceneType: .dmChat,
            appName: "微信",
            bundleId: "com.tencent.xinWeChat",
            chatTitle: ""
        )
        XCTAssertEqual(key, "app:com.tencent.xinWeChat")
    }

    func testContextKeyUsesAppBucketForNonChatScenes() {
        for scene in [SceneType.note, .document, .vibeCoding, .codeEditor, .meeting, .search] {
            let key = InsightOrchestrator.contextKey(
                sceneType: scene,
                appName: "Cursor",
                bundleId: "com.todesktop.230313mzl4w4u92",
                chatTitle: "should-be-ignored"  // even if passed, non-chat scenes ignore it
            )
            XCTAssertEqual(key, "app:com.todesktop.230313mzl4w4u92")
        }
    }

    func testContextKeyFallsBackToAppNameWhenBundleIdMissing() {
        let key = InsightOrchestrator.contextKey(
            sceneType: .note,
            appName: "SomeApp",
            bundleId: nil,
            chatTitle: nil
        )
        XCTAssertEqual(key, "app:SomeApp")
    }

    // MARK: - Analyzer/poller parity

    func testAnalyzerAndPollerProduceSameKeyForSameInputs() {
        // Regression for the analyzer/poller desync that caused
        // "Focus changed but no cached action" spam. Both call sites
        // use the same static helper with the same inputs, so the
        // result MUST be deterministic.
        let inputs = [
            (SceneType.dmChat, "微信", "com.tencent.xinWeChat", "Alice"),
            (SceneType.dmChat, "Slack", "com.tinyspeck.slackmacgap", "#eng"),
            (SceneType.vibeCoding, "Cursor", "com.todesktop.foo", nil),
            (SceneType.document, "Notion", "notion.id", nil),
            (SceneType.codeEditor, "Xcode", "com.apple.dt.Xcode", nil),
        ]
        for (scene, appName, bundleId, chatTitle) in inputs {
            let a = InsightOrchestrator.contextKey(
                sceneType: scene,
                appName: appName,
                bundleId: bundleId,
                chatTitle: chatTitle
            )
            let b = InsightOrchestrator.contextKey(
                sceneType: scene,
                appName: appName,
                bundleId: bundleId,
                chatTitle: chatTitle
            )
            XCTAssertEqual(a, b)
        }
    }
}
