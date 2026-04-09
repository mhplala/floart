// Floart/Services/AIEngine.swift
import Foundation

protocol AIProvider: Sendable {
    var providerName: String { get }
    var modelName: String { get }
    func analyze(text: String, context: String?) async throws -> String
}

enum AIResponseParser {
    /// Parse AI output — just trim and return as flat text.
    static func parse(_ raw: String, ocrText: String) -> AIResponse {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip any markdown formatting the model might add
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "# ", with: "")

        return AIResponse(
            advice: cleaned,
            timestamp: .now,
            rawText: ocrText
        )
    }
}

/// Orchestrates AI calls with timeout and fallback.
final class AIEngine: @unchecked Sendable {
    var primaryProvider: (any AIProvider)?
    var fallbackProvider: (any AIProvider)?
    private let timeoutSeconds: TimeInterval = 60

    func analyze(text: String, context: String?) async -> AIResponse {
        if let primary = primaryProvider {
            do {
                let raw = try await withTimeout(seconds: timeoutSeconds) {
                    try await primary.analyze(text: text, context: context)
                }
                return AIResponseParser.parse(raw, ocrText: text)
            } catch {
                Log.write("⚠️ Primary AI failed: \(error.localizedDescription)")
                if let fallback = fallbackProvider {
                    Log.write("🔄 Trying fallback provider...")
                    do {
                        let raw = try await withTimeout(seconds: timeoutSeconds) {
                            try await fallback.analyze(text: text, context: context)
                        }
                        return AIResponseParser.parse(raw, ocrText: text)
                    } catch {
                        Log.write("❌ Fallback also failed: \(error.localizedDescription)")
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
