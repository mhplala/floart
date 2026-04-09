// CursorInsightTests/OCREngineTests.swift
import XCTest
import CoreGraphics
@testable import CursorInsight

final class OCREngineTests: XCTestCase {
    func testRecognizeTextFromBlankImage() async throws {
        // Create a 100x100 blank image — OCR should return empty or near-empty
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: 100, height: 100,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = context.makeImage()!
        let result = try await OCREngine.recognizeText(in: image)
        // Blank image should yield empty text
        XCTAssertTrue(result.isEmpty)
    }
}
