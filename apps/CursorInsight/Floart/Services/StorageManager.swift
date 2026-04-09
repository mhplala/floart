// Floart/Services/StorageManager.swift
import Foundation
import SwiftData

final class StorageManager: @unchecked Sendable {
    private let archiveDirectory: URL
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    init(archiveDirectory: URL) {
        self.archiveDirectory = archiveDirectory
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.timeFormatter = DateFormatter()
        self.timeFormatter.dateFormat = "HH:mm:ss"
        try? FileManager.default.createDirectory(
            at: archiveDirectory, withIntermediateDirectories: true
        )
    }

    // MARK: - Markdown

    static func dailyHeader(for dateString: String) -> String {
        "# Floart 日志 — \(dateString)\n\n"
    }

    static func formatMarkdownEntry(_ response: AIResponse) -> String {
        let time = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f.string(from: response.timestamp)
        }()
        return """
        ## \(time)
        **总结：** \(response.summary)
        **观察：** \(response.observation)
        **思考：** \(response.reflection)
        **建议：** \(response.suggestion)

        > OCR 原文：
        > \(response.rawText.replacingOccurrences(of: "\n", with: "\n> "))

        ---

        """
    }

    func appendMarkdown(_ response: AIResponse) throws {
        let dateString = dateFormatter.string(from: response.timestamp)
        let filePath = archiveDirectory.appendingPathComponent("\(dateString).md")

        if !FileManager.default.fileExists(atPath: filePath.path) {
            let header = Self.dailyHeader(for: dateString)
            try header.write(to: filePath, atomically: true, encoding: .utf8)
        }

        let entry = Self.formatMarkdownEntry(response)
        let handle = try FileHandle(forWritingTo: filePath)
        handle.seekToEndOfFile()
        handle.write(entry.data(using: .utf8)!)
        handle.closeFile()
    }

    // MARK: - SwiftData

    @MainActor
    func saveRecord(
        _ response: AIResponse,
        mouseX: Double, mouseY: Double,
        captureMode: CaptureMode,
        provider: String, model: String,
        context: ModelContext
    ) {
        let record = InsightRecord(
            timestamp: response.timestamp,
            mouseX: mouseX, mouseY: mouseY,
            captureMode: captureMode.rawValue,
            rawOCRText: response.rawText,
            summary: response.summary,
            observation: response.observation,
            reflection: response.reflection,
            suggestion: response.suggestion,
            aiProvider: provider,
            aiModel: model
        )
        context.insert(record)
    }
}
