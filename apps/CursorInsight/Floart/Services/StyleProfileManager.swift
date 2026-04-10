// Floart/Services/StyleProfileManager.swift
import Foundation

/// Learns the user's writing style from [我] chat messages and provides
/// a prompt fragment for AI reply generation.
final class StyleProfileManager: @unchecked Sendable {
    private let directory: URL
    private let messagesFile: URL
    private let profileFile: URL
    private let maxMessages = 200
    private let recentExampleCount = 10
    private let lock = NSLock()

    /// Recent messages kept in memory to deduplicate OCR captures.
    private var recentDedup: [String] = []
    private let dedupWindow = 20

    init(directory: URL) {
        self.directory = directory
        self.messagesFile = directory.appendingPathComponent("style_messages.txt")
        self.profileFile = directory.appendingPathComponent("style_profile.txt")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Load last N lines for dedup
        if let content = try? String(contentsOf: messagesFile, encoding: .utf8) {
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            recentDedup = Array(lines.suffix(dedupWindow))
        }
    }

    /// Whether a distilled profile exists.
    var hasProfile: Bool {
        FileManager.default.fileExists(atPath: profileFile.path)
    }

    // MARK: - Collect

    /// Extract [我] lines from cleaned zoned text, append to style_messages.txt.
    /// Returns count of new messages added.
    @discardableResult
    func collectMessages(from cleanedText: String) -> Int {
        let lines = cleanedText.components(separatedBy: "\n")
        var newMessages: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[我] ") else { continue }
            let msg = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            guard msg.count >= 4 else { continue }

            // Deduplicate against recent messages
            lock.lock()
            let isDup = recentDedup.contains(msg)
            lock.unlock()
            if isDup { continue }

            newMessages.append(msg)
        }

        guard !newMessages.isEmpty else { return 0 }

        lock.lock()
        defer { lock.unlock() }

        // Append to file
        var existing: [String] = []
        if let content = try? String(contentsOf: messagesFile, encoding: .utf8) {
            existing = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        existing.append(contentsOf: newMessages)

        // FIFO: keep last maxMessages
        if existing.count > maxMessages {
            existing = Array(existing.suffix(maxMessages))
        }

        let output = existing.joined(separator: "\n") + "\n"
        try? output.write(to: messagesFile, atomically: true, encoding: .utf8)

        // Update dedup window
        recentDedup = Array(existing.suffix(dedupWindow))

        Log.write("📝 StyleProfile: collected \(newMessages.count) new [我] messages (total: \(existing.count))")
        return newMessages.count
    }

    // MARK: - Refresh

    /// Distill style profile from accumulated messages using AI.
    func refreshProfile(using provider: any AIProvider) async {
        // Read messages synchronously before entering async context
        let messages = readMessages()

        guard messages.count >= 5 else {
            Log.write("📝 StyleProfile: only \(messages.count) messages, need 5+ to distill")
            return
        }

        let sample = messages.joined(separator: "\n")
        let prompt = """
        以下是一个用户在即时通讯中发送的消息。请总结这个人的说话风格特征。
        只输出特征列表，不要分析消息内容本身。
        涵盖：语气、句子长度、用词习惯、语言偏好（中/英/混）、标点习惯、emoji使用、\
        是否拆成多条短消息发送、口头禅或高频词。
        用中文输出，控制在150字以内。

        消息列表：
        \(sample)
        """

        do {
            let result = try await provider.rawComplete(prompt: prompt)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            writeProfile(trimmed)
            Log.write("📝 StyleProfile: refreshed profile (\(trimmed.count) chars)")
        } catch {
            Log.write("❌ StyleProfile: refresh failed — \(error.localizedDescription)")
        }
    }

    /// Read all stored messages (thread-safe).
    private func readMessages() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let content = try? String(contentsOf: messagesFile, encoding: .utf8) else { return [] }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    /// Write profile to disk (thread-safe).
    private func writeProfile(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        try? text.write(to: profileFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Prompt Fragment

    /// Return prompt fragment (summary + recent examples) or nil if no data.
    func promptFragment() -> String? {
        lock.lock()
        defer { lock.unlock() }

        let summary = (try? String(contentsOf: profileFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let messagesContent = (try? String(contentsOf: messagesFile, encoding: .utf8)) ?? ""
        let allMessages = messagesContent.components(separatedBy: "\n").filter { !$0.isEmpty }
        let examples = Array(allMessages.suffix(recentExampleCount))

        if summary.isEmpty && examples.isEmpty { return nil }

        var parts: [String] = []
        parts.append("用户说话风格（从历史消息学习）：")
        if !summary.isEmpty {
            parts.append(summary)
        }
        if !examples.isEmpty {
            parts.append("")
            parts.append("用户最近的消息示例：")
            for msg in examples {
                parts.append("- \"\(msg)\"")
            }
        }
        return parts.joined(separator: "\n")
    }
}
