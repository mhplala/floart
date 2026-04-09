// CursorInsight/Services/InsightOrchestrator.swift
import SwiftUI
import Combine
import SwiftData

@MainActor
@Observable
final class InsightOrchestrator {
    // MARK: - Published state
    var latestResponse: AIResponse = .empty
    var isRunning: Bool = false
    var statusMessage: String = "Ready"

    // MARK: - Configuration
    var captureMode: CaptureMode = .fixedArea
    var captureSize: CGFloat = 2000
    var captureInterval: TimeInterval = 5
    var analysisInterval: TimeInterval = 20

    // MARK: - Dependencies
    let textBuffer = TextBuffer()
    let aiEngine = AIEngine()
    var storageManager: StorageManager?
    var modelContext: ModelContext?

    private var captureTimer: Timer?
    private var analysisTimer: Timer?
    private var lastContext: String?
    private var lastMouseLocation: NSPoint = .zero

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        statusMessage = "Running"

        captureTimer = Timer.scheduledTimer(
            withTimeInterval: captureInterval, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.captureAndOCR() }
        }

        analysisTimer = Timer.scheduledTimer(
            withTimeInterval: analysisInterval, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in await self?.analyzeBuffer() }
        }

        // Immediate first capture
        captureAndOCR()
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        analysisTimer?.invalidate()
        analysisTimer = nil
        isRunning = false
        statusMessage = "Paused"
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Pipeline

    private func captureAndOCR() {
        lastMouseLocation = NSEvent.mouseLocation

        // Read actor-isolated properties before crossing into a detached task,
        // avoiding Swift 6 actor-isolation violations.
        let mode = captureMode
        let size = captureSize
        let buffer = textBuffer

        Task.detached { [weak self] in
            do {
                guard let image = try await ScreenCapture.capture(
                    mode: mode, fixedSize: size
                ) else {
                    await MainActor.run { self?.statusMessage = "Capture failed" }
                    return
                }
                let text = try await OCREngine.recognizeText(in: image)
                if !text.isEmpty {
                    buffer.append(text, at: .now)
                }
            } catch {
                let message = "Error: \(error.localizedDescription)"
                await MainActor.run { self?.statusMessage = message }
            }
        }
    }

    private func analyzeBuffer() async {
        guard !textBuffer.isEmpty else { return }

        let entries = textBuffer.flush()
        let combinedText = entries.map(\.text).joined(separator: "\n\n---\n\n")

        statusMessage = "Analyzing..."
        let response = await aiEngine.analyze(text: combinedText, context: lastContext)

        if !response.summary.isEmpty {
            latestResponse = response
            lastContext = """
            总结：\(response.summary)
            观察：\(response.observation)
            思考：\(response.reflection)
            建议：\(response.suggestion)
            """

            // Persist to markdown archive
            if let storage = storageManager {
                try? storage.appendMarkdown(response)

                // Persist to SwiftData
                if let ctx = modelContext {
                    let providerName = aiEngine.primaryProvider?.providerName ?? "unknown"
                    let modelName = aiEngine.primaryProvider?.modelName ?? "unknown"
                    storage.saveRecord(
                        response,
                        mouseX: lastMouseLocation.x,
                        mouseY: lastMouseLocation.y,
                        captureMode: captureMode,
                        provider: providerName,
                        model: modelName,
                        context: ctx
                    )
                }
            }

            statusMessage = "Updated"
        } else {
            statusMessage = "AI returned empty"
        }
    }
}
