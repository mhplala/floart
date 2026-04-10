// Floart/Services/InsightOrchestrator.swift
import SwiftUI
import Combine
import SwiftData
@MainActor
@Observable
final class InsightOrchestrator {
    // MARK: - Published state
    var latestResponse: AIResponse = .empty
    var responseHistory: [AIResponse] = []
    var historyIndex: Int = -1  // -1 = showing latest
    var isRunning: Bool = false
    var statusMessage: String = "Ready"

    /// The response currently displayed (latest or a history item)
    var displayedResponse: AIResponse {
        if historyIndex >= 0 && historyIndex < responseHistory.count {
            return responseHistory[historyIndex]
        }
        return latestResponse
    }

    var canGoBack: Bool { !responseHistory.isEmpty && historyIndex != 0 }
    var canGoForward: Bool { historyIndex >= 0 }

    func showPrevious() {
        if historyIndex < 0 {
            historyIndex = responseHistory.count - 2  // skip the very latest (already showing)
        } else if historyIndex > 0 {
            historyIndex -= 1
        }
    }

    func showNext() {
        if historyIndex >= 0 {
            historyIndex += 1
            if historyIndex >= responseHistory.count {
                historyIndex = -1  // back to latest
            }
        }
    }

    func showLatest() {
        historyIndex = -1
    }

    // MARK: - Configuration
    var captureMode: CaptureMode = .fixedArea
    var captureSize: CGFloat = 2000
    var captureInterval: TimeInterval = 5
    var analysisInterval: TimeInterval = 20
    private var isAnalyzing = false

    // MARK: - Dependencies
    let textBuffer = TextBuffer()
    let aiEngine = AIEngine()
    var storageManager: StorageManager?
    var modelContext: ModelContext?

    private var captureTimer: Timer?
    private var lastContext: String?
    private var lastMouseLocation: NSPoint = .zero
    private var lastImageHash: UInt64 = 0
    private var lastFrontAppName: String = ""

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

        // No separate analysis timer — analysis triggers immediately after OCR
        Log.write("🚀 Pipeline started — capture: \(self.captureInterval)s, mode: \(self.captureMode.rawValue), size: \(self.captureSize)")
        captureAndOCR()
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        isRunning = false
        statusMessage = "Paused"
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Pipeline

    /// Fast image fingerprint — sample pixels at multiple scanlines to detect scrolling.
    /// Returns a hash that changes when content scrolls, even if overall brightness stays the same.
    nonisolated private static func imageFingerprint(_ image: CGImage) -> UInt64 {
        let w = image.width
        let h = image.height
        guard w > 0, h > 0 else { return 0 }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: colorSpace, bitmapInfo: 0
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return 0 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h)

        // Sample 4 horizontal scanlines at 20%, 40%, 60%, 80% height
        // Take 16 evenly spaced pixels from each line
        var hash: UInt64 = 5381  // djb2 seed
        let sampleRows = [h / 5, h * 2 / 5, h * 3 / 5, h * 4 / 5]
        let sampleStep = max(1, w / 16)

        for row in sampleRows {
            let rowOffset = row * w
            for i in stride(from: 0, to: w, by: sampleStep) {
                let pixel = UInt64(pixels[rowOffset + i])
                hash = hash &* 33 &+ pixel  // djb2 hash
            }
        }
        return hash
    }

    /// Check if two fingerprints are different (any change = different).
    nonisolated private static func fingerprintChanged(_ a: UInt64, _ b: UInt64) -> Bool {
        return a != b
    }

    private func captureAndOCR() {
        lastMouseLocation = NSEvent.mouseLocation

        let mode = captureMode
        let size = captureSize
        let buffer = textBuffer
        let prevHash = lastImageHash
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let prevFrontApp = lastFrontAppName
        let appChanged = frontApp != prevFrontApp
        lastFrontAppName = frontApp

        Log.write("📸 Capture starting — mouse: (\(lastMouseLocation.x), \(lastMouseLocation.y))")

        Task.detached { [weak self] in
            do {
                let captureStart = Date()
                guard let image = try await ScreenCapture.capture(
                    mode: mode, fixedSize: size
                ) else {
                    Log.write("📸 Capture returned nil")
                    await MainActor.run { self?.statusMessage = "Capture failed" }
                    return
                }
                let captureMs = Int(Date().timeIntervalSince(captureStart) * 1000)
                Log.write("📸 Captured \(image.width)x\(image.height) in \(captureMs)ms")

                // Check if screen changed since last capture
                let currentHash = InsightOrchestrator.imageFingerprint(image)
                let changed = InsightOrchestrator.fingerprintChanged(prevHash, currentHash)
                await MainActor.run { self?.lastImageHash = currentHash }

                if appChanged {
                    Log.write("🔄 App changed → \(frontApp), forcing OCR")
                } else if prevHash != 0 && !changed {
                    Log.write("💤 Screen unchanged, skipping OCR")
                    return
                } else {
                    Log.write("🔄 Screen changed")
                }

                let ocrStart = Date()
                let zonedResult = try await OCREngine.recognizeWithZones(in: image)
                let cleanedZoned = OCREngine.cleanZonedText(zonedResult.zoned)
                let ocrMs = Int(Date().timeIntervalSince(ocrStart) * 1000)
                Log.write("🔍 OCR done in \(ocrMs)ms — raw: \(zonedResult.raw.count) chars → zoned+cleaned: \(cleanedZoned.count) chars")
                if !cleanedZoned.isEmpty {
                    Log.write("🔍 Zoned text:\n\(String(cleanedZoned.prefix(500)))")
                    buffer.append(cleanedZoned, at: .now, appName: frontApp)
                    // Trigger analysis immediately
                    await MainActor.run { Task { await self?.analyzeBuffer() } }
                } else {
                    Log.write("🔍 All text filtered out (raw was \(zonedResult.raw.count) chars)")
                }
            } catch {
                Log.write("❌ Capture/OCR error: \(error.localizedDescription)")
                let message = "Error: \(error.localizedDescription)"
                await MainActor.run { self?.statusMessage = message }
            }
        }
    }

    private func analyzeBuffer() async {
        guard !isAnalyzing else {
            Log.write("🧠 Analysis skipped — already running")
            return
        }
        guard !textBuffer.isEmpty else {
            return
        }
        isAnalyzing = true
        defer { isAnalyzing = false }

        let entries = textBuffer.flush()
        let combinedText = entries.map(\.text).joined(separator: "\n\n---\n\n")

        // Skip if too little meaningful content
        if combinedText.count < 50 {
            Log.write("🧠 Analysis skipped — only \(combinedText.count) chars after cleaning (min 50)")
            return
        }

        // Extract main content only (strip zone headers) for archiving
        let mainContent = extractMainContent(from: combinedText)

        // Build context with app name for scene-aware analysis
        let appName = entries.last?.appName ?? lastFrontAppName
        let textWithContext = "[当前应用: \(appName)]\n\n\(combinedText)"

        Log.write("🧠 Analysis starting — app: \(appName), \(entries.count) entries, \(combinedText.count) chars")
        Log.write("🧠 Combined text preview: \(String(combinedText.prefix(300)))")

        statusMessage = "Analyzing..."
        let aiStart = Date()
        let response = await aiEngine.analyze(text: textWithContext, context: lastContext)
        let aiMs = Int(Date().timeIntervalSince(aiStart) * 1000)
        Log.write("🧠 AI responded in \(aiMs)ms")

        if !response.isEmpty {
            // Store main content (cleaned, no zone headers) as rawText for archive
            let archiveResponse = AIResponse(
                advice: response.advice,
                timestamp: response.timestamp,
                rawText: mainContent
            )
            Log.write("✅ Advice: \(response.advice)")
            latestResponse = archiveResponse
            responseHistory.append(archiveResponse)
            // Keep last 50 entries in memory
            if responseHistory.count > 50 { responseHistory.removeFirst() }
            historyIndex = -1  // reset to latest
            lastContext = response.advice

            // Persist to markdown archive
            if let storage = storageManager {
                try? storage.appendMarkdown(response)

                // Persist to SwiftData
                if let ctx = modelContext {
                    let providerName = aiEngine.primaryProvider?.providerName ?? "unknown"
                    let modelName = aiEngine.primaryProvider?.modelName ?? "unknown"
                    storage.saveRecord(
                        archiveResponse,
                        mouseX: lastMouseLocation.x,
                        mouseY: lastMouseLocation.y,
                        captureMode: captureMode,
                        provider: providerName,
                        model: modelName,
                        appName: appName,
                        context: ctx
                    )
                }
            }

            statusMessage = "Updated"
        } else {
            Log.write("⚠️ AI returned empty response")
            statusMessage = "AI returned empty"
        }
    }

    /// Extract only the [主内容区] text, stripped of zone headers.
    private func extractMainContent(from text: String) -> String {
        let sections = text.components(separatedBy: "\n\n")
        var mainLines: [String] = []
        var inMainSection = false

        for section in sections {
            let lines = section.components(separatedBy: "\n")
            if let first = lines.first {
                if first.contains("[主内容区]") {
                    inMainSection = true
                    mainLines.append(contentsOf: lines.dropFirst())
                    continue
                } else if first.hasPrefix("[") && first.hasSuffix("]") {
                    inMainSection = false
                    continue
                }
            }
            if inMainSection {
                mainLines.append(contentsOf: lines)
            }
        }

        // If no zone headers found, return original text
        if mainLines.isEmpty {
            return text.replacingOccurrences(of: "[当前应用:", with: "")
                .replacingOccurrences(of: "[主内容区]", with: "")
                .replacingOccurrences(of: "[左侧边栏]", with: "")
                .replacingOccurrences(of: "[右侧边栏]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return mainLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
