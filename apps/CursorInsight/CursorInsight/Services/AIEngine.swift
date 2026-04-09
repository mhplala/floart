// CursorInsight/Services/AIEngine.swift
import Foundation

protocol AIProvider: Sendable {
    var providerName: String { get }
    var modelName: String { get }
    func analyze(text: String, context: String?) async throws -> String
}

enum AIResponseParser {
    /// Parse AI output into structured AIResponse.
    /// Expects lines like: **总结：** content
    static func parse(_ raw: String, ocrText: String) -> AIResponse {
        let patterns: [(key: String, keyPath: WritableKeyPath<_Builder, String>)] = [
            ("总结", \_Builder.summary),
            ("观察", \_Builder.observation),
            ("思考", \_Builder.reflection),
            ("建议", \_Builder.suggestion),
        ]

        var builder = _Builder()
        var matched = false

        for (key, keyPath) in patterns {
            let pattern = "\\*\\*\(key)[：:]\\*\\*\\s*(.+)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                   in: raw,
                   range: NSRange(raw.startIndex..., in: raw)
               ),
               let range = Range(match.range(at: 1), in: raw) {
                builder[keyPath: keyPath] = String(raw[range]).trimmingCharacters(in: .whitespaces)
                matched = true
            }
        }

        if !matched {
            builder.summary = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return AIResponse(
            summary: builder.summary,
            observation: builder.observation,
            reflection: builder.reflection,
            suggestion: builder.suggestion,
            timestamp: .now,
            rawText: ocrText
        )
    }

    struct _Builder {
        var summary = ""
        var observation = ""
        var reflection = ""
        var suggestion = ""
    }
}

/// Orchestrates AI calls with timeout and fallback.
final class AIEngine: @unchecked Sendable {
    var primaryProvider: (any AIProvider)?
    var fallbackProvider: (any AIProvider)?
    private let timeoutSeconds: TimeInterval = 15

    func analyze(text: String, context: String?) async -> AIResponse {
        if let primary = primaryProvider {
            do {
                let raw = try await withTimeout(seconds: timeoutSeconds) {
                    try await primary.analyze(text: text, context: context)
                }
                return AIResponseParser.parse(raw, ocrText: text)
            } catch {
                if let fallback = fallbackProvider {
                    do {
                        let raw = try await withTimeout(seconds: timeoutSeconds) {
                            try await fallback.analyze(text: text, context: context)
                        }
                        return AIResponseParser.parse(raw, ocrText: text)
                    } catch {
                        return AIResponse.empty
                    }
                }
                return AIResponse.empty
            }
        }
        return AIResponse.empty
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
