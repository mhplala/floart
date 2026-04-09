// Floart/Models/AIResponse.swift
import Foundation

struct AIResponse: Sendable, Equatable {
    let advice: String
    let timestamp: Date
    let rawText: String

    var isEmpty: Bool { advice.isEmpty }

    /// Extract the actionable part — everything from the first action marker to the end.
    var actionContent: String? {
        let markers = ["回复草稿：", "可以问：", "笔记：", "改进：",
                       "回复草稿:", "可以问:", "笔记:", "改进:"]
        var earliest: String.Index?
        for marker in markers {
            if let range = advice.range(of: marker) {
                if earliest == nil || range.lowerBound < earliest! {
                    earliest = range.lowerBound
                }
            }
        }
        guard let start = earliest else { return nil }
        let content = String(advice[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    static let empty = AIResponse(
        advice: "", timestamp: .now, rawText: ""
    )
}
