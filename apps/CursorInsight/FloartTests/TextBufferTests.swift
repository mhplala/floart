// FloartTests/TextBufferTests.swift
import XCTest
@testable import Floart

final class TextBufferTests: XCTestCase {
    func testAppendAndFlushReturnsAccumulatedText() {
        let buffer = TextBuffer()
        buffer.append("first ocr result", at: .now)
        buffer.append("second ocr result", at: .now)
        let flushed = buffer.flush()
        XCTAssertEqual(flushed.count, 2)
        XCTAssertEqual(flushed[0].text, "first ocr result")
        XCTAssertEqual(flushed[1].text, "second ocr result")
    }

    func testFlushClearsBuffer() {
        let buffer = TextBuffer()
        buffer.append("text", at: .now)
        _ = buffer.flush()
        let second = buffer.flush()
        XCTAssertTrue(second.isEmpty)
    }

    func testDeduplicatesSimilarConsecutiveTexts() {
        let buffer = TextBuffer()
        buffer.append("hello world foo bar baz qux", at: .now)
        buffer.append("hello world foo bar baz qux", at: .now) // identical
        let flushed = buffer.flush()
        XCTAssertEqual(flushed.count, 1)
    }

    func testKeepsDifferentTexts() {
        let buffer = TextBuffer()
        buffer.append("completely different text one", at: .now)
        buffer.append("another unrelated text here now", at: .now)
        let flushed = buffer.flush()
        XCTAssertEqual(flushed.count, 2)
    }
}
