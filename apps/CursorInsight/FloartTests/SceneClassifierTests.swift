// FloartTests/SceneClassifierTests.swift
import XCTest
@testable import Floart

final class SceneClassifierTests: XCTestCase {

    private func input(
        role: String = "AXTextArea",
        placeholder: String? = nil,
        title: String? = nil,
        description: String? = nil,
        bundleId: String? = nil,
        appName: String = "App"
    ) -> AccessibilityHelper.FocusedInputInfo {
        AccessibilityHelper.FocusedInputInfo(
            role: role,
            placeholder: placeholder,
            title: title,
            description: description,
            frame: CGRect(x: 0, y: 0, width: 100, height: 20),
            appName: appName,
            bundleId: bundleId
        )
    }

    // MARK: - Search hint wins

    func testSearchHintOverridesVibeCodingBundle() {
        // User focuses a search box inside VS Code. Scene must be .search,
        // not .vibeCoding — the scene instruction for .search is "guess
        // what they'd search for", which is what the user wants.
        let info = input(placeholder: "Search files by name", bundleId: "com.microsoft.VSCode")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.microsoft.VSCode", focusedInput: info), .search)
    }

    func testSearchHintOverridesDmChatBundle() {
        let info = input(placeholder: "搜索", bundleId: "com.tencent.xinWeChat")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.tencent.xinWeChat", focusedInput: info), .search)
    }

    // MARK: - Strong bundle beats hint

    func testVsCodeWithMessageInputHintIsVibeCoding() {
        // Regression: earlier, a "Message input" placeholder (from an AI
        // chat extension inside VS Code) was misclassified as .dmChat
        // because the hint regex caught "message ". VS Code is a strong
        // vibe-coding bundle and must override the hint.
        let info = input(placeholder: "Message input", bundleId: "com.microsoft.VSCode")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.microsoft.VSCode", focusedInput: info), .vibeCoding)
    }

    func testWeChatAlwaysIsDmChat() {
        let info = input(bundleId: "com.tencent.xinWeChat")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.tencent.xinWeChat", focusedInput: info), .dmChat)
    }

    func testCursorIsVibeCoding() {
        let info = input(bundleId: "com.todesktop.230313mzl4w4u92")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.todesktop.230313mzl4w4u92", focusedInput: info), .vibeCoding)
    }

    func testXcodeIsCodeEditor() {
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.apple.dt.Xcode", focusedInput: nil), .codeEditor)
    }

    func testNotionIsDocument() {
        XCTAssertEqual(SceneClassifier.classify(bundleId: "notion.id", focusedInput: nil), .document)
    }

    // MARK: - Hints for unknown / browser bundles

    func testBrowserWithAskAnythingHintIsVibeCoding() {
        // Chrome + placeholder "Ask anything" → user is on ChatGPT/Claude web.
        let info = input(placeholder: "Ask anything", bundleId: "com.google.Chrome")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.google.Chrome", focusedInput: info), .vibeCoding)
    }

    func testBrowserWithCommentHintIsDocument() {
        let info = input(placeholder: "Add a comment", bundleId: "com.google.Chrome")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.google.Chrome", focusedInput: info), .document)
    }

    func testBrowserWithMessageHintIsDmChat() {
        // Unknown-app reply-style hint → DM chat (e.g. Gmail web reply).
        let info = input(placeholder: "Type a message", bundleId: "com.google.Chrome")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.google.Chrome", focusedInput: info), .dmChat)
    }

    func testBrowserWithoutHintIsNote() {
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.google.Chrome", focusedInput: nil), .note)
    }

    // MARK: - Unknown bundle

    func testUnknownBundleWithoutHintIsNote() {
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.unknown.app", focusedInput: nil), .note)
    }

    func testUnknownBundleWithSearchHintIsSearch() {
        let info = input(placeholder: "搜索", bundleId: "com.unknown.app")
        XCTAssertEqual(SceneClassifier.classify(bundleId: "com.unknown.app", focusedInput: info), .search)
    }
}
