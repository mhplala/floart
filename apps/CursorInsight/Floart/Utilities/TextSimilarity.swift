// Floart/Utilities/TextSimilarity.swift
import Foundation

enum TextSimilarity {
    /// Jaccard similarity based on whitespace-split word sets.
    static func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let setA = Set(a.split(whereSeparator: \.isWhitespace))
        let setB = Set(b.split(whereSeparator: \.isWhitespace))

        if setA.isEmpty && setB.isEmpty { return 1.0 }
        if setA.isEmpty || setB.isEmpty { return 0.0 }

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        return Double(intersection) / Double(union)
    }

    /// Returns true if Jaccard similarity exceeds the threshold.
    static func isSimilar(_ a: String, _ b: String, threshold: Double = 0.9) -> Bool {
        jaccardSimilarity(a, b) >= threshold
    }
}
