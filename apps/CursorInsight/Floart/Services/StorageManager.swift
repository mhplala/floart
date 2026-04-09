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
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let time = f.string(from: response.timestamp)

        var entry = "## \(time)\n"
        if !response.rawText.isEmpty {
            // Full cleaned main content area text
            entry += "> \(response.rawText.replacingOccurrences(of: "\n", with: "\n> "))\n\n"
        }
        entry += "\(response.advice)\n\n---\n\n"
        return entry
    }

    func appendMarkdown(_ response: AIResponse) throws {
        let dateString = dateFormatter.string(from: response.timestamp)
        let filePath = archiveDirectory.appendingPathComponent("\(dateString).md")

        if !FileManager.default.fileExists(atPath: filePath.path) {
            let header = Self.dailyHeader(for: dateString)
            try header.write(to: filePath, atomically: true, encoding: .utf8)
        }

        let entry = Self.formatMarkdownEntry(response)
        guard let data = entry.data(using: .utf8) else { return }
        let handle = try FileHandle(forWritingTo: filePath)
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(data)
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
            summary: response.advice,
            observation: "",
            reflection: "",
            suggestion: "",
            aiProvider: provider,
            aiModel: model
        )
        context.insert(record)
    }
}
