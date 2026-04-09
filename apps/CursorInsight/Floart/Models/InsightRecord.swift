// Floart/Models/InsightRecord.swift
import Foundation
import SwiftData

@Model
final class InsightRecord {
    var timestamp: Date
    var mouseX: Double
    var mouseY: Double
    var captureMode: String
    var rawOCRText: String
    var summary: String
    var observation: String
    var reflection: String
    var suggestion: String
    var aiProvider: String
    var aiModel: String

    init(
        timestamp: Date, mouseX: Double, mouseY: Double,
        captureMode: String, rawOCRText: String,
        summary: String, observation: String,
        reflection: String, suggestion: String,
        aiProvider: String, aiModel: String
    ) {
        self.timestamp = timestamp
        self.mouseX = mouseX
        self.mouseY = mouseY
        self.captureMode = captureMode
        self.rawOCRText = rawOCRText
        self.summary = summary
        self.observation = observation
        self.reflection = reflection
        self.suggestion = suggestion
        self.aiProvider = aiProvider
        self.aiModel = aiModel
    }
}
