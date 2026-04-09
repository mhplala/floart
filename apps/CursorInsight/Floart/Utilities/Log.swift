// Floart/Utilities/Log.swift
import Foundation

enum Log {
    private static let maxLogSize: UInt64 = 5 * 1024 * 1024  // 5MB
    private static let maxScreenshotAge: TimeInterval = 24 * 3600  // 24 hours

    private static let baseDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Floart")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let logFile: URL = baseDir.appendingPathComponent("debug.log")

    static func write(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(message)\n"
        print(message)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    defer { handle.closeFile() }
                    handle.seekToEndOfFile()
                    handle.write(data)
                }
            } else {
                try? data.write(to: logFile)
            }
        }

        // Check log size periodically (cheap: only stat the file)
        rotateIfNeeded()
    }

    static var path: String { logFile.path }

    // MARK: - Log Rotation

    private static func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let size = attrs[.size] as? UInt64,
              size > maxLogSize else { return }

        let backupPath = baseDir.appendingPathComponent("debug.log.old")
        try? FileManager.default.removeItem(at: backupPath)
        try? FileManager.default.moveItem(at: logFile, to: backupPath)
    }

    // MARK: - Screenshot Cleanup

    /// Delete screenshots older than 24 hours. Call periodically.
    static func cleanOldScreenshots() {
        let screenshotDir = baseDir.appendingPathComponent("screenshots")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: screenshotDir, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-maxScreenshotAge)
        var deletedCount = 0

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let created = attrs.creationDate,
                  created < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
            deletedCount += 1
        }

        if deletedCount > 0 {
            write("🧹 Cleaned \(deletedCount) old screenshots")
        }
    }
}
