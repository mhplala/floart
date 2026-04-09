// FloartTests/TextSimilarityTests.swift
import XCTest
@testable import Floart

final class TextSimilarityTests: XCTestCase {
    func testIdenticalTextsReturn1() {
        let score = TextSimilarity.jaccardSimilarity("hello world", "hello world")
        XCTAssertEqual(score, 1.0)
    }

    func testCompletelyDifferentTextsReturn0() {
        let score = TextSimilarity.jaccardSimilarity("aaa", "bbb")
        XCTAssertEqual(score, 0.0)
    }

    func testPartialOverlap() {
        let score = TextSimilarity.jaccardSimilarity("hello world foo", "hello world bar")
        // intersection: {"hello", "world"} = 2, union: {"hello", "world", "foo", "bar"} = 4
        XCTAssertEqual(score, 0.5)
    }

    func testEmptyStringsReturn1() {
        let score = TextSimilarity.jaccardSimilarity("", "")
        XCTAssertEqual(score, 1.0)
    }

    func testOneEmptyStringReturns0() {
        let score = TextSimilarity.jaccardSimilarity("hello", "")
        XCTAssertEqual(score, 0.0)
    }

    func testIsSimilarAboveThreshold() {
        XCTAssertTrue(TextSimilarity.isSimilar("hello world", "hello world", threshold: 0.9))
    }

    func testIsNotSimilarBelowThreshold() {
        XCTAssertFalse(TextSimilarity.isSimilar("hello", "goodbye", threshold: 0.9))
    }
}
