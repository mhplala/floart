// Floart/Services/TextBuffer.swift
import Foundation

struct BufferEntry: Sendable {
    let text: String
    let timestamp: Date
    let appName: String
}

final class TextBuffer: @unchecked Sendable {
    private var entries: [BufferEntry] = []
    private let lock = NSLock()
    private let similarityThreshold: Double = 0.9

    func append(_ text: String, at timestamp: Date, appName: String = "") {
        lock.lock()
        defer { lock.unlock() }

        // Deduplicate: skip if too similar to the last entry
        if let last = entries.last,
           TextSimilarity.isSimilar(last.text, text, threshold: similarityThreshold) {
            return
        }
        entries.append(BufferEntry(text: text, timestamp: timestamp, appName: appName))
    }

    func flush() -> [BufferEntry] {
        lock.lock()
        defer { lock.unlock() }
        let result = entries
        entries.removeAll()
        return result
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries.isEmpty
    }
}
