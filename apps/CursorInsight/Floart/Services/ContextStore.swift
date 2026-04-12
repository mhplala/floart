// Floart/Services/ContextStore.swift
import Foundation

/// Per-bucket context store backed by editable Markdown files.
///
/// Layout: `<FloartDir>/contexts/<app>/<key>.md`
///   - `<app>` = localized app name (sanitized), falls back to bundle id
///   - `<key>` = `app.md` for app-level buckets, `<chatTitle>.md` for chats
///
/// Each file has two sections that Floart cares about:
///   - **Notes**: user-editable. Floart reads it and injects the content into
///     the next analysis's system prompt as extra context for this bucket.
///     Lets the user iteratively tune what Floart "knows" about each
///     conversation or app — a lightweight, file-based prompt-tuning harness.
///   - **History**: Floart-appended log of every advice generated for this
///     bucket, most recent first. The first entry is used as `lastContext`
///     for the next analysis so the LLM knows what it already said. Safe to
///     prune by hand — Floart will just have a shorter memory for that bucket.
///
/// The store is the **single source of truth** for per-bucket context —
/// there is no in-memory dictionary mirroring these files. That means user
/// edits to Notes/History take effect on the next analyze or next focus
/// poll, no restart needed.
struct ContextStore: Sendable {
    let rootDir: URL

    init(rootDir: URL) {
        self.rootDir = rootDir
        try? FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    struct Bucket {
        /// User-editable text from the `## Notes` section. Empty if the
        /// user hasn't added anything yet.
        let notes: String
        /// Body of the most recent history entry (the `lastContext` that
        /// feeds back into the next prompt).
        let lastAdvice: String?
    }

    // MARK: - Read

    func read(appName: String, bundleId: String?, scene: SceneType, chatTitle: String?) -> Bucket? {
        let url = fileURL(appName: appName, bundleId: bundleId, scene: scene, chatTitle: chatTitle)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let sections = parseSections(content)
        let notes = sections["Notes"].map(stripPlaceholder) ?? ""
        let lastAdvice = firstHistoryEntry(from: sections["History"] ?? "")
        return Bucket(notes: notes, lastAdvice: lastAdvice)
    }

    // MARK: - Write

    /// Prepend a new advice entry to the bucket's History section.
    /// Preserves Notes as-is. Creates the folder structure on first write.
    func append(
        appName: String,
        bundleId: String?,
        scene: SceneType,
        chatTitle: String?,
        advice: String,
        contextKey: String
    ) {
        let url = fileURL(appName: appName, bundleId: bundleId, scene: scene, chatTitle: chatTitle)
        let folderURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let sections = parseSections(existing)
        let existingNotes = sections["Notes"].map(stripPlaceholder) ?? ""
        let existingHistory = sections["History"] ?? ""

        let displayKey: String
        if scene == .dmChat, let title = chatTitle, !title.isEmpty {
            displayKey = title
        } else {
            displayKey = "app"
        }

        let notesBody = existingNotes.isEmpty
            ? "_(edit freely — this section gets injected into the analysis prompt for this bucket)_"
            : existingNotes

        let newEntry = "### \(timestamp())\n\n\(advice)"
        let newHistory: String
        if existingHistory.isEmpty {
            newHistory = newEntry
        } else {
            newHistory = newEntry + "\n\n" + existingHistory
        }

        let content = """
        # \(appName) / \(displayKey)

        bundleId: \(bundleId ?? "-")
        contextKey: \(contextKey)

        ## Notes

        \(notesBody)

        ## History

        \(newHistory)
        """

        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Path

    private func fileURL(appName: String, bundleId: String?, scene: SceneType, chatTitle: String?) -> URL {
        let folderRaw = appName.isEmpty ? (bundleId ?? "unknown") : appName
        let folder = sanitize(folderRaw)
        let file: String
        if scene == .dmChat, let title = chatTitle, !title.isEmpty {
            file = sanitize(title) + ".md"
        } else {
            file = "app.md"
        }
        return rootDir.appendingPathComponent(folder).appendingPathComponent(file)
    }

    private func sanitize(_ name: String) -> String {
        var s = name
        for bad in ["/", ":", "\\", "\0"] {
            s = s.replacingOccurrences(of: bad, with: "_")
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    private func timestamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: Date())
    }

    // MARK: - Markdown parsing (section + first-history-entry)

    /// Split the file into top-level `## Heading` sections. Returns a map
    /// of heading name (without the `## ` prefix) to body text.
    private func parseSections(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentHeading: String?
        var currentBody: [String] = []
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("## ") && !line.hasPrefix("### ") {
                if let h = currentHeading {
                    result[h] = currentBody.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentHeading = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        if let h = currentHeading {
            result[h] = currentBody.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    /// Return the body of the first `### <timestamp>` entry in the History
    /// section (i.e. the most recent advice).
    private func firstHistoryEntry(from history: String) -> String? {
        guard !history.isEmpty else { return nil }
        let lines = history.components(separatedBy: "\n")
        var entries: [[String]] = []
        var current: [String]? = nil
        for line in lines {
            if line.hasPrefix("### ") {
                if let c = current { entries.append(c) }
                current = []  // skip the heading line itself
            } else {
                current?.append(line)
            }
        }
        if let c = current { entries.append(c) }
        guard let first = entries.first else { return nil }
        let body = first.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    /// Drop the italicized placeholder line so user-empty Notes don't get
    /// re-injected as context.
    private func stripPlaceholder(_ text: String) -> String {
        let placeholder = "_(edit freely"
        if text.hasPrefix(placeholder) {
            return ""
        }
        return text
    }
}
