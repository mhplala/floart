// FloartTests/StorageManagerTests.swift
import XCTest
@testable import Floart

final class StorageManagerTests: XCTestCase {
    func testFormatMarkdownEntry() {
        let response = AIResponse(
            advice: "用户在写代码，结构清晰",
            timestamp: Date(timeIntervalSince1970: 0),
            rawText: "import SwiftUI"
        )
        let md = StorageManager.formatMarkdownEntry(response)
        XCTAssertTrue(md.contains("用户在写代码"))
        XCTAssertTrue(md.contains("import SwiftUI"))
        XCTAssertTrue(md.contains("---"))
    }

    func testFormatDailyHeader() {
        let header = StorageManager.dailyHeader(for: "2026-04-09")
        XCTAssertEqual(header, "# Floart 日志 — 2026-04-09\n\n")
    }
}
