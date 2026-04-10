// FloartTests/AIEngineTests.swift
import XCTest
@testable import Floart

final class AIEngineTests: XCTestCase {
    func testParseTrimsAndStripsMarkdown() {
        let raw = "  **总结** 用户在写代码\n## 观察  "
        let response = AIResponseParser.parse(raw, ocrText: "some ocr text")
        XCTAssertFalse(response.advice.contains("**"))
        XCTAssertFalse(response.advice.contains("##"))
        XCTAssertEqual(response.rawText, "some ocr text")
    }

    func testParseReturnsCleanedAdvice() {
        let raw = "just some unstructured text"
        let response = AIResponseParser.parse(raw, ocrText: "ocr")
        XCTAssertEqual(response.advice, "just some unstructured text")
    }
}
