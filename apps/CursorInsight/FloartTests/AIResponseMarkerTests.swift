// FloartTests/AIResponseMarkerTests.swift
import XCTest
@testable import Floart

final class AIResponseMarkerTests: XCTestCase {

    private func response(_ advice: String) -> AIResponse {
        AIResponse(advice: advice, timestamp: .now, rawText: "")
    }

    // MARK: - New marker

    func testActionContentParsesNewMarker() {
        let r = response("""
        一段总结

        learning：something

        |ACTION| 你好这是要填进去的文本
        """)
        XCTAssertEqual(r.actionContent, "你好这是要填进去的文本")
    }

    func testActionContentTrimmedOfNewMarker() {
        let r = response("|ACTION|  leading-spaces  ")
        XCTAssertEqual(r.actionContent, "leading-spaces")
    }

    func testActionContentReturnsNilWhenEmpty() {
        let r = response("summary text only")
        XCTAssertNil(r.actionContent)
    }

    func testActionContentReturnsNilIfMarkerAtEnd() {
        let r = response("everything |ACTION|")
        XCTAssertNil(r.actionContent)
    }

    // MARK: - Legacy markers (backward compat for old stored records)

    func testActionContentFallsBackToLegacyReplyDraft() {
        let r = response("""
        总结文本

        回复草稿：老格式的回复
        """)
        XCTAssertEqual(r.actionContent, "老格式的回复")
    }

    func testActionContentFallsBackToLegacyNote() {
        let r = response("summary\n\n笔记:老格式笔记")
        XCTAssertEqual(r.actionContent, "老格式笔记")
    }

    func testNewMarkerWinsOverLegacyWhenBothPresent() {
        // If for some reason both appear, the new marker should be preferred.
        let r = response("|ACTION| 新的\n回复草稿：老的")
        XCTAssertEqual(r.actionContent, "新的\n回复草稿：老的")
    }

    // MARK: - Edge cases

    func testNoMarkerNoAction() {
        let r = response("just a plain summary with no action line")
        XCTAssertNil(r.actionContent)
    }

    func testActionMayContainMultilineText() {
        let r = response("|ACTION| line one\nline two\nline three")
        XCTAssertEqual(r.actionContent, "line one\nline two\nline three")
    }
}
