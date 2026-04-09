// Floart/Models/AIResponse.swift
import Foundation

struct AIResponse: Sendable, Equatable {
    let summary: String
    let observation: String
    let reflection: String
    let suggestion: String
    let timestamp: Date
    let rawText: String

    static let empty = AIResponse(
        summary: "", observation: "", reflection: "",
        suggestion: "", timestamp: .now, rawText: ""
    )
}
