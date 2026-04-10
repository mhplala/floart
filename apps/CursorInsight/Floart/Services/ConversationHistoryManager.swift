// Floart/Services/ConversationHistoryManager.swift
import Foundation

/// Maintains per-conversation message history for context continuity.
/// Each conversation (identified by "appName:chatTitle") has its own message file and summary.
final class ConversationHistoryManager: @unchecked Sendable {
    private let directory: URL
    private let lock = NSLock()
    private let maxMessages = 200
    private let recentExampleCount = 10
    private let dedupWindow = 20
    private let similarityThreshold = 0.85
    private let keyMatchThreshold = 0.7

    /// Cache: raw OCR key → canonical key (fuzzy matched)
    private var keyAliases: [String: String] = [:]
    /// Track new messages per conversation for summary refresh trigger
    private var newMessageCounts: [String: Int] = [:]
    private let summaryTriggerCount = 15

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Key Resolution

    /// Resolve a raw OCR key to a canonical key via fuzzy matching.
    /// "飞书:胡冰水" → "飞书:胡冰冰" if the latter already exists.
    func resolveKey(_ rawKey: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        // Check alias cache first
        if let cached = keyAliases[rawKey] { return cached }

        // Split into app:title
        let parts = rawKey.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return rawKey }
        let app = String(parts[0])
        let title = String(parts[1])

        // Scan existing conversation files for same app
        let existingKeys = listExistingKeys()
        var bestMatch: String?
        var bestScore: Double = 0

        for existing in existingKeys {
            let existParts = existing.split(separator: ":", maxSplits: 1)
            guard existParts.count == 2, String(existParts[0]) == app else { continue }
            let existTitle = String(existParts[1])

            // Use character-level similarity for short names
            let score = TextSimilarity.charSimilarity(title, existTitle)
            if score > bestScore {
                bestScore = score
                bestMatch = existing
            }
        }

        let resolved: String
        if bestScore >= keyMatchThreshold, let match = bestMatch {
            resolved = match
            keyAliases[rawKey] = match
            Log.write("📚 ConvHistory: fuzzy key match \"\(rawKey)\" → \"\(match)\" (score: \(String(format: "%.2f", bestScore)))")
        } else {
            resolved = rawKey
        }
        return resolved
    }

    /// List existing conversation keys from filenames on disk.
    private func listExistingKeys() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        let suffix = Self.messagesSuffix
        return files
            .filter { $0.hasSuffix(suffix) }
            .map { keyFromFilename(String($0.dropLast(suffix.count))) }
    }

    // MARK: - Message Storage

    /// Patterns that indicate Floart's own AI output or UI noise — not real chat messages.
    private static let noisePatterns: [String] = [
        "关键人物观点", "回复草稿", "learning", "English translation",
        "客观提炼", "核心结论", "行动项", "可以问：", "笔记：", "改进：",
        "Advice:", "✅", "📥", "📤", "🧠", "📸", "📝", "📚",
        "Analysis starting", "Main content", "Combined text",
        "Gemini", "Ollama", "thinkingBudget",
    ]

    /// Check if a message is actually a timestamp or pure noise.
    private static func isNoise(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        // Pure timestamp: "16:49", "17:05", "14:37"
        if trimmed.count <= 5 && trimmed.contains(":") &&
           trimmed.allSatisfy({ $0.isNumber || $0 == ":" }) { return true }
        // Floart AI output leaked back via OCR
        for pattern in noisePatterns {
            if trimmed.contains(pattern) { return true }
        }
        // Too short to be meaningful
        if trimmed.count < 2 { return true }
        return false
    }

    /// Add new messages for a conversation. Returns count of non-duplicate messages added.
    @discardableResult
    func addMessages(_ messages: [String], forConversation key: String) -> Int {
        // Only keep [我]/[对方] tagged lines, filter noise
        let tagged = messages.filter { line in
            guard line.hasPrefix("[我] ") || line.hasPrefix("[对方] ") else { return false }
            let content = String(line.drop(while: { $0 != " " }).dropFirst())
            return !Self.isNoise(content)
        }
        guard !tagged.isEmpty else { return 0 }

        lock.lock()
        defer { lock.unlock() }

        let file = messagesFile(for: key)
        var existing = readLines(from: file)
        let recentForDedup = Array(existing.suffix(dedupWindow))

        // Dedup: exact + similarity against last N
        var newMessages: [String] = []
        for msg in tagged {
            let isDup = recentForDedup.contains { stored in
                if stored == msg { return true }
                // Strip tags for similarity comparison
                let msgContent = stripTag(msg)
                let storedContent = stripTag(stored)
                return TextSimilarity.isSimilar(msgContent, storedContent, threshold: similarityThreshold)
            }
            // Also check against messages we're about to add (within this batch)
            let batchDup = newMessages.contains { added in
                if added == msg { return true }
                return TextSimilarity.isSimilar(stripTag(msg), stripTag(added), threshold: similarityThreshold)
            }
            if !isDup && !batchDup {
                newMessages.append(msg)
            }
        }

        guard !newMessages.isEmpty else { return 0 }

        existing.append(contentsOf: newMessages)
        if existing.count > maxMessages {
            existing = Array(existing.suffix(maxMessages))
        }

        writeLines(existing, to: file)
        newMessageCounts[key, default: 0] += newMessages.count

        Log.write("📚 ConvHistory: +\(newMessages.count) messages for \"\(key)\" (total: \(existing.count))")
        return newMessages.count
    }

    /// Whether this conversation has accumulated enough new messages for a summary refresh.
    func needsSummaryRefresh(forConversation key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return (newMessageCounts[key] ?? 0) >= summaryTriggerCount
    }

    // MARK: - Summary

    /// Distill or update conversation summary using AI.
    func refreshSummary(forConversation key: String, using provider: any AIProvider) async {
        let messages = readMessagesThreadSafe(for: key)
        guard messages.count >= 5 else {
            Log.write("📚 ConvHistory: only \(messages.count) messages for \"\(key)\", need 5+")
            return
        }

        let summaryFile = summaryFile(for: key)
        let oldSummary = readFileThreadSafe(summaryFile)

        let prompt: String
        if let old = oldSummary, !old.isEmpty {
            // Incremental update: give AI the old summary + new messages
            let recentMessages = Array(messages.suffix(30)).joined(separator: "\n")
            prompt = """
            以下是一个即时通讯会话的上一次总结和最近的新消息。
            [我]是用户发的，[对方]是对方发的。
            请更新总结，反映最新的讨论进展。2-3句话，100字以内，只输出总结。

            上一次总结：
            \(old)

            最近消息：
            \(recentMessages)
            """
        } else {
            // First summary
            let allMessages = messages.joined(separator: "\n")
            prompt = """
            以下是一个即时通讯会话的消息记录。[我]是用户发的，[对方]是对方发的。
            请用2-3句话总结这个对话目前在讨论什么话题、双方的立场和进展。
            只输出总结，不要分析。用中文，100字以内。

            消息记录：
            \(allMessages)
            """
        }

        do {
            let result = try await provider.rawComplete(prompt: prompt)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            writeFileThreadSafe(trimmed, to: summaryFile)
            resetMessageCount(for: key)

            Log.write("📚 ConvHistory: refreshed summary for \"\(key)\" (\(trimmed.count) chars)")
        } catch {
            Log.write("❌ ConvHistory: summary refresh failed for \"\(key)\" — \(error.localizedDescription)")
        }
    }

    // MARK: - Prompt Fragment

    /// Return prompt fragment (summary + recent messages) or nil if no history.
    func promptFragment(forConversation key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let summary = (try? String(contentsOf: summaryFile(for: key), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let messages = readLines(from: messagesFile(for: key))
        let recent = Array(messages.suffix(recentExampleCount))

        if summary.isEmpty && recent.isEmpty { return nil }

        // Extract title from key for readability
        let title = key.split(separator: ":", maxSplits: 1).last.map(String.init) ?? key

        var parts: [String] = []
        parts.append("当前会话历史（与\(title)的对话）：")
        if !summary.isEmpty {
            parts.append(summary)
        }
        if !recent.isEmpty {
            parts.append("")
            parts.append("最近的消息：")
            for msg in recent {
                parts.append(msg)
            }
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - File Helpers

    /// Encode key to a safe filename using percent-encoding (reversible).
    private func safeFilename(for key: String) -> String {
        // Percent-encode everything except alphanumerics, hyphens, and CJK characters
        key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }

    /// Decode filename back to key.
    private func keyFromFilename(_ filename: String) -> String {
        filename.removingPercentEncoding ?? filename
    }

    private static let messagesSuffix = ".msgs"
    private static let summarySuffix = ".summary"

    private func messagesFile(for key: String) -> URL {
        directory.appendingPathComponent(safeFilename(for: key) + Self.messagesSuffix)
    }

    private func summaryFile(for key: String) -> URL {
        directory.appendingPathComponent(safeFilename(for: key) + Self.summarySuffix)
    }

    private func readLines(from file: URL) -> [String] {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func writeLines(_ lines: [String], to file: URL) {
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: file, atomically: true, encoding: .utf8)
    }

    private func stripTag(_ line: String) -> String {
        if line.hasPrefix("[我] ") { return String(line.dropFirst(4)) }
        if line.hasPrefix("[对方] ") { return String(line.dropFirst(5)) }
        return line
    }

    // Thread-safe wrappers for async contexts
    private func readMessagesThreadSafe(for key: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return readLines(from: messagesFile(for: key))
    }

    private func readFileThreadSafe(_ file: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return try? String(contentsOf: file, encoding: .utf8)
    }

    private func writeFileThreadSafe(_ text: String, to file: URL) {
        lock.lock()
        defer { lock.unlock() }
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func resetMessageCount(for key: String) {
        lock.lock()
        defer { lock.unlock() }
        newMessageCounts[key] = 0
    }
}
