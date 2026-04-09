// Floart/Models/DailyReport.swift
import Foundation
import SwiftData

@Model
final class DailyReport {
    var date: String           // "2026-04-09"
    var content: String        // Full report markdown
    var insightCount: Int
    var meetingCount: Int
    var appSummary: String     // "飞书会议 45min, Code 2h"
    var generatedAt: Date

    init(date: String, content: String, insightCount: Int = 0,
         meetingCount: Int = 0, appSummary: String = "", generatedAt: Date = .now) {
        self.date = date
        self.content = content
        self.insightCount = insightCount
        self.meetingCount = meetingCount
        self.appSummary = appSummary
        self.generatedAt = generatedAt
    }
}
