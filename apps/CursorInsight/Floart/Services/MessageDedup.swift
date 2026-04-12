// Floart/Services/MessageDedup.swift
import Foundation

/// Per-conversation rolling dedup for tagged chat messages.
///
/// Feed it the raw OCR text block for a conversation; it returns the same
/// text with any `[我]/[对方]` lines whose normalized content has already
/// been seen in the rolling window stripped out. Non-tagged lines (sidebar,
/// header, buttons, etc.) are passed through untouched.
///
/// Normalization strips the `[我] / [对方]` prefix and collapses all
/// whitespace runs so "再确认一下" and " 再 确认一下 " hash to the same
/// key regardless of OCR whitespace noise or which side sent it.
///
/// In-memory only — a restart re-sees the current window of messages,
/// which is acceptable (one redundant analyze per session at most).
struct MessageDedup {
    /// Rolling window size per conversation.
    static let maxPerConversation = 500

    /// convKey → ordered list of normalized hashes (oldest first)
    private var seen: [String: [String]] = [:]

    struct Result: Equatable {
        let filtered: String
        let dropped: Int
        let kept: Int
    }

    /// Filter duplicate tagged messages out of `text`, updating the rolling
    /// window for `conversationKey`. Non-tagged lines pass through.
    mutating func filter(_ text: String, conversationKey: String) -> Result {
        var order = seen[conversationKey] ?? []
        var set = Set(order)
        var out: [String] = []
        var dropped = 0
        var kept = 0

        for line in text.components(separatedBy: "\n") {
            let tagged = line.hasPrefix("[我] ") || line.hasPrefix("[对方] ")
            guard tagged else {
                out.append(line)
                continue
            }
            let normalized = Self.normalize(line)
            guard !normalized.isEmpty else {
                out.append(line)
                continue
            }
            if set.contains(normalized) {
                dropped += 1
                continue
            }
            order.append(normalized)
            set.insert(normalized)
            out.append(line)
            kept += 1
        }

        // Trim rolling window
        if order.count > Self.maxPerConversation {
            let evict = order.count - Self.maxPerConversation
            let evicted = Array(order.prefix(evict))
            order.removeFirst(evict)
            for e in evicted { set.remove(e) }
        }
        seen[conversationKey] = order

        return Result(filtered: out.joined(separator: "\n"), dropped: dropped, kept: kept)
    }

    /// Normalize a tagged line to its content hash. Strips the
    /// `[我] / [对方]` prefix and collapses whitespace.
    static func normalize(_ line: String) -> String {
        var stripped: Substring = Substring(line)
        if stripped.hasPrefix("[我] ") {
            stripped = stripped.dropFirst(4)
        } else if stripped.hasPrefix("[对方] ") {
            stripped = stripped.dropFirst(5)
        }
        return stripped
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Count of unique normalized entries tracked for the given conversation.
    /// Test helper.
    func seenCount(forConversation key: String) -> Int {
        seen[key]?.count ?? 0
    }
}
