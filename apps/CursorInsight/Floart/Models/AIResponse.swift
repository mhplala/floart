// Floart/Models/AIResponse.swift
import Foundation

struct AIResponse: Sendable, Equatable {
    let advice: String
    let timestamp: Date
    let rawText: String

    var isEmpty: Bool { advice.isEmpty }

    /// Extract the actionable part — content AFTER the action marker, without the marker itself.
    /// New format uses `|ACTION|`. Legacy markers (`回复草稿:` etc.) are still recognized so
    /// old records continue to render correctly.
    var actionContent: String? {
        // New marker first.
        if let range = advice.range(of: "|ACTION|") {
            let content = String(advice[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        }
        // Legacy markers (pre-SceneClassifier records).
        let legacy = ["回复草稿：", "可以问：", "笔记：", "改进：",
                      "回复草稿:", "可以问:", "笔记:", "改进:"]
        var earliestEnd: String.Index?
        for marker in legacy {
            if let range = advice.range(of: marker) {
                if earliestEnd == nil || range.upperBound < earliestEnd! {
                    earliestEnd = range.upperBound
                }
            }
        }
        guard let start = earliestEnd else { return nil }
        let content = String(advice[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    static let empty = AIResponse(
        advice: "", timestamp: .now, rawText: ""
    )
}
