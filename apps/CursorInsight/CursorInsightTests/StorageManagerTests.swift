// CursorInsightTests/StorageManagerTests.swift
import XCTest
@testable import CursorInsight

final class StorageManagerTests: XCTestCase {
    func testFormatMarkdownEntry() {
        let response = AIResponse(
            summary: "用户在写代码",
            observation: "使用 SwiftUI",
            reflection: "结构清晰",
            suggestion: "加注释",
            timestamp: Date(timeIntervalSince1970: 0),
            rawText: "import SwiftUI"
        )
        let md = StorageManager.formatMarkdownEntry(response)
        XCTAssertTrue(md.contains("**总结：** 用户在写代码"))
        XCTAssertTrue(md.contains("**观察：** 使用 SwiftUI"))
        XCTAssertTrue(md.contains("**思考：** 结构清晰"))
        XCTAssertTrue(md.contains("**建议：** 加注释"))
        XCTAssertTrue(md.contains("import SwiftUI"))
        XCTAssertTrue(md.contains("---"))
    }

    func testFormatDailyHeader() {
        let header = StorageManager.dailyHeader(for: "2026-04-09")
        XCTAssertEqual(header, "# CursorInsight 日志 — 2026-04-09\n\n")
    }
}
