// Floart/Services/DailyReportGenerator.swift
import Foundation
import SwiftData

actor DailyReportGenerator {
    private let archiveDirectory: URL

    init() {
        self.archiveDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Floart/archive")
    }

    /// Check if yesterday's report exists, generate if not.
    func generateMissingReports(context: ModelContext) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

        // Check if report already exists
        let descriptor = FetchDescriptor<DailyReport>(
            predicate: #Predicate { $0.date == yesterday }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            Log.write("📊 Daily report for \(yesterday) already exists")
            return
        }

        // Check if archive exists for that day
        let archivePath = archiveDirectory.appendingPathComponent("\(yesterday).md")
        guard FileManager.default.fileExists(atPath: archivePath.path) else {
            Log.write("📊 No archive for \(yesterday), skipping report")
            return
        }

        Log.write("📊 Generating daily report for \(yesterday)...")
        await generateReport(for: yesterday, context: context)
    }

    /// Generate report for a specific date.
    func generateReport(for dateString: String, context: ModelContext) async {
        let archivePath = archiveDirectory.appendingPathComponent("\(dateString).md")

        guard let archiveContent = try? String(contentsOf: archivePath, encoding: .utf8) else {
            Log.write("❌ Cannot read archive for \(dateString)")
            return
        }

        // Count insights (## timestamps)
        let insightCount = archiveContent.components(separatedBy: "\n## ").count - 1

        // Truncate if too long for API (keep last ~8000 chars)
        let inputText: String
        if archiveContent.count > 8000 {
            inputText = String(archiveContent.suffix(8000))
        } else {
            inputText = archiveContent
        }

        // Use Cloud API to generate report
        let prompt = """
        以下是用户今天（\(dateString)）的屏幕阅读记录，包含OCR捕获的文字和AI分析。
        请生成一份简洁的工作日报。

        要求：
        1. 工作概览：今天主要做了什么，涉及哪些项目/话题
        2. 关键会议和对话：重要的讨论、决策、共识
        3. 今日洞察：最值得记住的发现和学习（3-5条）
        4. 待跟进：需要后续行动的事项

        格式：纯文本，用简洁的段落。不要用markdown标题符号。每个部分之间空一行。
        用中文。控制在500字以内。

        记录内容：
        \(inputText)
        """

        // Try to use configured Cloud API
        let report = await callCloudAPI(prompt: prompt)

        if report.isEmpty {
            Log.write("❌ Failed to generate report for \(dateString)")
            return
        }

        // Count meetings (rough heuristic)
        let meetingKeywords = ["会议", "meeting", "1:1", "kickoff", "sync", "standup"]
        let meetingCount = meetingKeywords.reduce(0) { count, keyword in
            count + archiveContent.lowercased().components(separatedBy: keyword.lowercased()).count - 1
        }

        let dailyReport = DailyReport(
            date: dateString,
            content: report,
            insightCount: insightCount,
            meetingCount: max(meetingCount, 0),
            appSummary: "",
            generatedAt: .now
        )

        context.insert(dailyReport)
        try? context.save()
        Log.write("📊 Daily report for \(dateString) saved — \(insightCount) insights, \(meetingCount) meetings")
    }

    /// Call the configured Cloud API for report generation.
    private func callCloudAPI(prompt: String) async -> String {
        // Read settings
        let defaults = UserDefaults.standard
        let apiType = defaults.string(forKey: "cloudAPIType") ?? "gemini"
        let apiKey = defaults.string(forKey: "cloudAPIKey") ?? ""
        let model = defaults.string(forKey: "cloudModel") ?? "gemini-2.5-flash"
        let endpoint = defaults.string(forKey: "cloudEndpoint") ?? "https://generativelanguage.googleapis.com"

        guard !apiKey.isEmpty else {
            Log.write("❌ No Cloud API key configured for daily report")
            return ""
        }

        let provider = CloudProvider(
            apiType: CloudAPIType(rawValue: apiType) ?? .gemini,
            apiKey: apiKey,
            model: model,
            endpoint: endpoint
        )

        do {
            return try await provider.analyze(text: prompt, context: nil)
        } catch {
            Log.write("❌ Cloud API error for report: \(error.localizedDescription)")
            return ""
        }
    }
}
