// FloartTests/AIEngineTests.swift
import XCTest
@testable import Floart

final class AIEngineTests: XCTestCase {
    func testParseStructuredResponseWithAllSections() {
        let raw = """
        **总结：** 用户在写代码
        **观察：** 使用了 SwiftUI
        **思考：** 代码结构清晰
        **建议：** 可以加注释
        """
        let response = AIResponseParser.parse(raw, ocrText: "some ocr text")
        XCTAssertEqual(response.summary, "用户在写代码")
        XCTAssertEqual(response.observation, "使用了 SwiftUI")
        XCTAssertEqual(response.reflection, "代码结构清晰")
        XCTAssertEqual(response.suggestion, "可以加注释")
        XCTAssertEqual(response.rawText, "some ocr text")
    }

    func testParseResponseWithMissingSectionsUsesDefaults() {
        let raw = "just some unstructured text"
        let response = AIResponseParser.parse(raw, ocrText: "ocr")
        XCTAssertEqual(response.summary, "just some unstructured text")
        XCTAssertTrue(response.observation.isEmpty)
        XCTAssertTrue(response.reflection.isEmpty)
        XCTAssertTrue(response.suggestion.isEmpty)
    }
}
