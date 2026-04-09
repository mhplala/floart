# CursorInsight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that captures the area around the mouse cursor every 5s, OCRs it, and every 20s sends the text to AI for structured analysis displayed in a Liquid Glass floating panel.

**Architecture:** Pure Swift/SwiftUI macOS 26+ app. Pipeline: ScreenCapture (5s timer) → OCREngine (Vision.framework) → TextBuffer (accumulates 20s) → AIEngine (Ollama or Cloud API) → FloatingPanel (Liquid Glass) + StorageManager (SwiftData + Markdown). Menu bar app with `.accessory` activation policy.

**Tech Stack:** Swift 6.2, SwiftUI, macOS 26+, Vision.framework, SwiftData, Liquid Glass (`.glassEffect`), URLSession (Ollama/Cloud API)

**Spec:** `docs/superpowers/specs/2026-04-09-cursor-insight-design.md`

---

## File Structure

```
apps/CursorInsight/
├── CursorInsight/
│   ├── CursorInsightApp.swift          # App entry, menu bar, lifecycle
│   ├── Models/
│   │   ├── InsightRecord.swift         # SwiftData @Model
│   │   └── AIResponse.swift            # AI response value type
│   ├── Services/
│   │   ├── ScreenCapture.swift         # Mouse tracking + screenshot
│   │   ├── OCREngine.swift             # Vision OCR wrapper
│   │   ├── TextBuffer.swift            # Sliding window text accumulator
│   │   ├── AIEngine.swift              # AIProvider protocol + orchestrator
│   │   ├── OllamaProvider.swift        # Ollama HTTP API
│   │   ├── CloudProvider.swift         # Claude/OpenAI API
│   │   ├── StorageManager.swift        # SwiftData + Markdown export
│   │   └── InsightOrchestrator.swift   # Main pipeline coordinator
│   ├── Views/
│   │   ├── FloatingPanelController.swift  # NSPanel wrapper
│   │   ├── CapsuleView.swift           # Collapsed state
│   │   ├── InsightPanelView.swift      # Expanded state
│   │   └── SettingsView.swift          # Preferences window
│   └── Utilities/
│       └── TextSimilarity.swift        # Jaccard similarity
├── CursorInsightTests/
│   ├── TextSimilarityTests.swift
│   ├── TextBufferTests.swift
│   ├── OCREngineTests.swift
│   ├── AIEngineTests.swift
│   └── StorageManagerTests.swift
└── Package.swift                       # SPM package (no .xcodeproj)
```

We use Swift Package Manager with an executable target instead of Xcode project for CLI-friendliness. The app bundle will be assembled via `swift build`.

---

### Task 1: Project Scaffold + App Entry Point

**Files:**
- Create: `apps/CursorInsight/Package.swift`
- Create: `apps/CursorInsight/CursorInsight/CursorInsightApp.swift`
- Create: `apps/CursorInsight/CursorInsight/Models/AIResponse.swift`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CursorInsight",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CursorInsight",
            path: "CursorInsight",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "CursorInsightTests",
            dependencies: ["CursorInsight"],
            path: "CursorInsightTests"
        ),
    ]
)
```

- [ ] **Step 2: Create AIResponse model**

```swift
// CursorInsight/Models/AIResponse.swift
import Foundation

struct AIResponse: Sendable, Equatable {
    let summary: String
    let observation: String
    let reflection: String
    let suggestion: String
    let timestamp: Date
    let rawText: String

    static let empty = AIResponse(
        summary: "", observation: "", reflection: "",
        suggestion: "", timestamp: .now, rawText: ""
    )
}
```

- [ ] **Step 3: Create the App entry point with menu bar**

```swift
// CursorInsight/CursorInsightApp.swift
import SwiftUI

@main
struct CursorInsightApp: App {
    @State private var isRunning = true

    var body: some Scene {
        MenuBarExtra("CursorInsight", systemImage: isRunning ? "brain.head.profile.fill" : "brain.head.profile") {
            Toggle(isRunning ? "Running" : "Paused", isOn: $isRunning)
            Divider()
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }.keyboardShortcut(",")
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }

        Settings {
            Text("Settings placeholder")
                .frame(width: 400, height: 300)
        }
    }
}
```

- [ ] **Step 4: Create Resources directory placeholder**

```bash
mkdir -p apps/CursorInsight/CursorInsight/Resources
touch apps/CursorInsight/CursorInsight/Resources/.gitkeep
```

- [ ] **Step 5: Verify it builds**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds. The app won't run properly without entitlements yet, but it should compile.

- [ ] **Step 6: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): scaffold project with menu bar entry point"
```

---

### Task 2: TextSimilarity Utility (TDD)

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Utilities/TextSimilarity.swift`
- Create: `apps/CursorInsight/CursorInsightTests/TextSimilarityTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// CursorInsightTests/TextSimilarityTests.swift
import Testing
@testable import CursorInsight

@Suite("TextSimilarity")
struct TextSimilarityTests {
    @Test func identicalTextsReturn1() {
        let score = TextSimilarity.jaccardSimilarity("hello world", "hello world")
        #expect(score == 1.0)
    }

    @Test func completelyDifferentTextsReturn0() {
        let score = TextSimilarity.jaccardSimilarity("aaa", "bbb")
        #expect(score == 0.0)
    }

    @Test func partialOverlap() {
        let score = TextSimilarity.jaccardSimilarity("hello world foo", "hello world bar")
        // intersection: {"hello", "world"} = 2, union: {"hello", "world", "foo", "bar"} = 4
        #expect(score == 0.5)
    }

    @Test func emptyStringsReturn1() {
        let score = TextSimilarity.jaccardSimilarity("", "")
        #expect(score == 1.0)
    }

    @Test func oneEmptyStringReturns0() {
        let score = TextSimilarity.jaccardSimilarity("hello", "")
        #expect(score == 0.0)
    }

    @Test func isSimilarAboveThreshold() {
        #expect(TextSimilarity.isSimilar("hello world", "hello world", threshold: 0.9))
    }

    @Test func isNotSimilarBelowThreshold() {
        #expect(!TextSimilarity.isSimilar("hello", "goodbye", threshold: 0.9))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd apps/CursorInsight && swift test --filter TextSimilarity 2>&1
```

Expected: FAIL — `TextSimilarity` not found.

- [ ] **Step 3: Implement TextSimilarity**

```swift
// CursorInsight/Utilities/TextSimilarity.swift
import Foundation

enum TextSimilarity {
    /// Jaccard similarity based on whitespace-split word sets.
    static func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let setA = Set(a.split(whereSeparator: \.isWhitespace))
        let setB = Set(b.split(whereSeparator: \.isWhitespace))

        if setA.isEmpty && setB.isEmpty { return 1.0 }
        if setA.isEmpty || setB.isEmpty { return 0.0 }

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        return Double(intersection) / Double(union)
    }

    /// Returns true if Jaccard similarity exceeds the threshold.
    static func isSimilar(_ a: String, _ b: String, threshold: Double = 0.9) -> Bool {
        jaccardSimilarity(a, b) >= threshold
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd apps/CursorInsight && swift test --filter TextSimilarity 2>&1
```

Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add TextSimilarity with Jaccard word-set comparison"
```

---

### Task 3: TextBuffer (TDD)

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Services/TextBuffer.swift`
- Create: `apps/CursorInsight/CursorInsightTests/TextBufferTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// CursorInsightTests/TextBufferTests.swift
import Testing
@testable import CursorInsight

@Suite("TextBuffer")
struct TextBufferTests {
    @Test func appendAndFlushReturnsAccumulatedText() {
        let buffer = TextBuffer()
        buffer.append("first ocr result", at: .now)
        buffer.append("second ocr result", at: .now)
        let flushed = buffer.flush()
        #expect(flushed.count == 2)
        #expect(flushed[0].text == "first ocr result")
        #expect(flushed[1].text == "second ocr result")
    }

    @Test func flushClearsBuffer() {
        let buffer = TextBuffer()
        buffer.append("text", at: .now)
        _ = buffer.flush()
        let second = buffer.flush()
        #expect(second.isEmpty)
    }

    @Test func deduplicatesSimilarConsecutiveTexts() {
        let buffer = TextBuffer()
        buffer.append("hello world foo bar baz qux", at: .now)
        buffer.append("hello world foo bar baz qux", at: .now) // identical
        let flushed = buffer.flush()
        #expect(flushed.count == 1)
    }

    @Test func keepsDifferentTexts() {
        let buffer = TextBuffer()
        buffer.append("completely different text one", at: .now)
        buffer.append("another unrelated text here now", at: .now)
        let flushed = buffer.flush()
        #expect(flushed.count == 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd apps/CursorInsight && swift test --filter TextBuffer 2>&1
```

Expected: FAIL — `TextBuffer` not found.

- [ ] **Step 3: Implement TextBuffer**

```swift
// CursorInsight/Services/TextBuffer.swift
import Foundation

struct BufferEntry: Sendable {
    let text: String
    let timestamp: Date
}

final class TextBuffer: @unchecked Sendable {
    private var entries: [BufferEntry] = []
    private let lock = NSLock()
    private let similarityThreshold: Double = 0.9

    func append(_ text: String, at timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }

        // Deduplicate: skip if too similar to the last entry
        if let last = entries.last,
           TextSimilarity.isSimilar(last.text, text, threshold: similarityThreshold) {
            return
        }
        entries.append(BufferEntry(text: text, timestamp: timestamp))
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd apps/CursorInsight && swift test --filter TextBuffer 2>&1
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add TextBuffer with deduplication"
```

---

### Task 4: OCREngine (TDD)

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Services/OCREngine.swift`
- Create: `apps/CursorInsight/CursorInsightTests/OCREngineTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// CursorInsightTests/OCREngineTests.swift
import Testing
import CoreGraphics
@testable import CursorInsight

@Suite("OCREngine")
struct OCREngineTests {
    @Test func recognizeTextFromCGImage() async throws {
        // Create a 100x100 blank image — OCR should return empty or near-empty
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: 100, height: 100,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = context.makeImage()!
        let result = try await OCREngine.recognizeText(in: image)
        // Blank image should yield empty text
        #expect(result.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/CursorInsight && swift test --filter OCREngine 2>&1
```

Expected: FAIL — `OCREngine` not found.

- [ ] **Step 3: Implement OCREngine**

```swift
// CursorInsight/Services/OCREngine.swift
import Vision
import CoreGraphics

enum OCREngine {
    /// Runs Vision OCR on a CGImage. Returns recognized text as a single string.
    static func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd apps/CursorInsight && swift test --filter OCREngine 2>&1
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add OCREngine with Vision.framework"
```

---

### Task 5: ScreenCapture Service

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Services/ScreenCapture.swift`

This module uses macOS screen capture APIs that require the app to be running with screen recording permission — not unit-testable in CI. We test it manually.

- [ ] **Step 1: Implement ScreenCapture**

```swift
// CursorInsight/Services/ScreenCapture.swift
import AppKit
import CoreGraphics

enum CaptureMode: String, Sendable, CaseIterable {
    case fixedArea = "fixed"
    case smartWindow = "window"
}

enum ScreenCapture {

    /// Capture a region around the current mouse position.
    /// - Parameters:
    ///   - size: Width and height of capture area in pixels.
    /// - Returns: A CGImage of the captured area, or nil on failure.
    static func captureAroundMouse(size: CGFloat) -> CGImage? {
        let mouseLocation = NSEvent.mouseLocation
        // Convert from bottom-left (AppKit) to top-left (CG) coordinates
        guard let mainScreen = NSScreen.main else { return nil }
        let screenHeight = mainScreen.frame.height
        let cgMouseY = screenHeight - mouseLocation.y

        let halfSize = size / 2
        var x = mouseLocation.x - halfSize
        var y = cgMouseY - halfSize

        // Clamp to screen bounds
        let screenFrame = mainScreen.frame
        x = max(screenFrame.minX, min(x, screenFrame.maxX - size))
        y = max(0, min(y, screenHeight - size))

        let captureRect = CGRect(x: x, y: y, width: size, height: size)
        return CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }

    /// Capture the window under the current mouse position.
    /// Falls back to fixed-area capture if no window is found.
    static func captureWindowUnderMouse(fallbackSize: CGFloat) -> CGImage? {
        let mouseLocation = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.main else { return nil }
        let screenHeight = mainScreen.frame.height
        let cgMouseY = screenHeight - mouseLocation.y
        let cgPoint = CGPoint(x: mouseLocation.x, y: cgMouseY)

        // Find window under mouse
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[CFString: Any]] else {
            return captureAroundMouse(size: fallbackSize)
        }

        for windowInfo in windowList {
            guard let boundsDict = windowInfo[kCGWindowBounds] as? [String: CGFloat],
                  let wx = boundsDict["X"], let wy = boundsDict["Y"],
                  let ww = boundsDict["Width"], let wh = boundsDict["Height"],
                  let windowID = windowInfo[kCGWindowNumber] as? CGWindowID else {
                continue
            }
            let windowRect = CGRect(x: wx, y: wy, width: ww, height: wh)
            if windowRect.contains(cgPoint) {
                // Skip tiny windows (menu bar items, etc.)
                if ww < 100 || wh < 100 { continue }
                return CGWindowListCreateImage(
                    windowRect,
                    .optionIncludingWindow,
                    windowID,
                    .bestResolution
                )
            }
        }

        // No window found — fallback
        return captureAroundMouse(size: fallbackSize)
    }

    /// Capture using the specified mode.
    static func capture(mode: CaptureMode, fixedSize: CGFloat) -> CGImage? {
        switch mode {
        case .fixedArea:
            return captureAroundMouse(size: fixedSize)
        case .smartWindow:
            return captureWindowUnderMouse(fallbackSize: fixedSize)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add ScreenCapture with fixed-area and smart-window modes"
```

---

### Task 6: AIEngine — Protocol + OllamaProvider (TDD)

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Services/AIEngine.swift`
- Create: `apps/CursorInsight/CursorInsight/Services/OllamaProvider.swift`
- Create: `apps/CursorInsight/CursorInsightTests/AIEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// CursorInsightTests/AIEngineTests.swift
import Testing
@testable import CursorInsight

@Suite("AIEngine")
struct AIEngineTests {
    @Test func parseStructuredResponseWithAllSections() {
        let raw = """
        **总结：** 用户在写代码
        **观察：** 使用了 SwiftUI
        **思考：** 代码结构清晰
        **建议：** 可以加注释
        """
        let response = AIResponseParser.parse(raw, ocrText: "some ocr text")
        #expect(response.summary == "用户在写代码")
        #expect(response.observation == "使用了 SwiftUI")
        #expect(response.reflection == "代码结构清晰")
        #expect(response.suggestion == "可以加注释")
        #expect(response.rawText == "some ocr text")
    }

    @Test func parseResponseWithMissingSectionsUsesDefaults() {
        let raw = "just some unstructured text"
        let response = AIResponseParser.parse(raw, ocrText: "ocr")
        // When no sections found, put everything in summary
        #expect(response.summary == "just some unstructured text")
        #expect(response.observation.isEmpty)
        #expect(response.reflection.isEmpty)
        #expect(response.suggestion.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd apps/CursorInsight && swift test --filter AIEngine 2>&1
```

Expected: FAIL — types not found.

- [ ] **Step 3: Implement AIEngine protocol and parser**

```swift
// CursorInsight/Services/AIEngine.swift
import Foundation

protocol AIProvider: Sendable {
    func analyze(text: String, context: String?) async throws -> String
}

enum AIResponseParser {
    /// Parse AI output into structured AIResponse.
    /// Expects lines like: **总结：** content
    static func parse(_ raw: String, ocrText: String) -> AIResponse {
        let patterns: [(key: String, path: WritableKeyPath<_Builder, String>)] = [
            ("总结", \._Builder.summary),
            ("观察", \._Builder.observation),
            ("思考", \._Builder.reflection),
            ("建议", \._Builder.suggestion),
        ]

        var builder = _Builder()
        var matched = false

        for (key, keyPath) in patterns {
            // Match **总结：** or **总结:** (full-width or half-width colon)
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
                // Try fallback
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
```

- [ ] **Step 4: Implement OllamaProvider**

```swift
// CursorInsight/Services/OllamaProvider.swift
import Foundation

struct OllamaProvider: AIProvider {
    let baseURL: String
    let model: String

    func analyze(text: String, context: String?) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        你是一个智能工作助手。根据用户屏幕上的OCR文字内容，提供结构化的分析。
        请严格按以下格式输出：
        **总结：** （用1-2句话描述用户当前在做什么）
        **观察：** （注意到的细节或模式）
        **思考：** （对当前工作的分析和反思）
        **建议：** （可操作的建议或提醒）
        """

        var prompt = "屏幕OCR内容：\n\(text)"
        if let context {
            prompt = "上一轮分析：\n\(context)\n\n\(prompt)"
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["response"] as? String ?? ""
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd apps/CursorInsight && swift test --filter AIEngine 2>&1
```

Expected: All 2 tests PASS (parser tests only — provider tests need a running Ollama).

- [ ] **Step 6: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add AIEngine with protocol, parser, and OllamaProvider"
```

---

### Task 7: CloudProvider

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Services/CloudProvider.swift`

- [ ] **Step 1: Implement CloudProvider**

```swift
// CursorInsight/Services/CloudProvider.swift
import Foundation

enum CloudAPIType: String, Sendable, CaseIterable {
    case claude = "claude"
    case openai = "openai"
}

struct CloudProvider: AIProvider {
    let apiType: CloudAPIType
    let apiKey: String
    let model: String
    let endpoint: String

    func analyze(text: String, context: String?) async throws -> String {
        switch apiType {
        case .claude:
            return try await callClaude(text: text, context: context)
        case .openai:
            return try await callOpenAI(text: text, context: context)
        }
    }

    private var systemPrompt: String {
        """
        你是一个智能工作助手。根据用户屏幕上的OCR文字内容，提供结构化的分析。
        请严格按以下格式输出：
        **总结：** （用1-2句话描述用户当前在做什么）
        **观察：** （注意到的细节或模式）
        **思考：** （对当前工作的分析和反思）
        **建议：** （可操作的建议或提醒）
        """
    }

    private func userPrompt(text: String, context: String?) -> String {
        var prompt = "屏幕OCR内容：\n\(text)"
        if let context {
            prompt = "上一轮分析：\n\(context)\n\n\(prompt)"
        }
        return prompt
    }

    private func callClaude(text: String, context: String?) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt(text: text, context: context)]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? ""
    }

    private func callOpenAI(text: String, context: String?) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt(text: text, context: context)],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add CloudProvider for Claude and OpenAI APIs"
```

---

### Task 8: SwiftData Model + StorageManager (TDD)

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Models/InsightRecord.swift`
- Create: `apps/CursorInsight/CursorInsight/Services/StorageManager.swift`
- Create: `apps/CursorInsight/CursorInsightTests/StorageManagerTests.swift`

- [ ] **Step 1: Create the SwiftData model**

```swift
// CursorInsight/Models/InsightRecord.swift
import Foundation
import SwiftData

@Model
final class InsightRecord {
    var timestamp: Date
    var mouseX: Double
    var mouseY: Double
    var captureMode: String
    var rawOCRText: String
    var summary: String
    var observation: String
    var reflection: String
    var suggestion: String
    var aiProvider: String
    var aiModel: String

    init(
        timestamp: Date, mouseX: Double, mouseY: Double,
        captureMode: String, rawOCRText: String,
        summary: String, observation: String,
        reflection: String, suggestion: String,
        aiProvider: String, aiModel: String
    ) {
        self.timestamp = timestamp
        self.mouseX = mouseX
        self.mouseY = mouseY
        self.captureMode = captureMode
        self.rawOCRText = rawOCRText
        self.summary = summary
        self.observation = observation
        self.reflection = reflection
        self.suggestion = suggestion
        self.aiProvider = aiProvider
        self.aiModel = aiModel
    }
}
```

- [ ] **Step 2: Write the failing tests for Markdown export**

```swift
// CursorInsightTests/StorageManagerTests.swift
import Testing
import Foundation
@testable import CursorInsight

@Suite("StorageManager")
struct StorageManagerTests {
    @Test func formatMarkdownEntry() {
        let response = AIResponse(
            summary: "用户在写代码",
            observation: "使用 SwiftUI",
            reflection: "结构清晰",
            suggestion: "加注释",
            timestamp: Date(timeIntervalSince1970: 0), // 1970-01-01 00:00:00 UTC
            rawText: "import SwiftUI"
        )
        let md = StorageManager.formatMarkdownEntry(response)
        #expect(md.contains("**总结：** 用户在写代码"))
        #expect(md.contains("**观察：** 使用 SwiftUI"))
        #expect(md.contains("**思考：** 结构清晰"))
        #expect(md.contains("**建议：** 加注释"))
        #expect(md.contains("import SwiftUI"))
        #expect(md.contains("---"))
    }

    @Test func formatDailyHeader() {
        let header = StorageManager.dailyHeader(for: "2026-04-09")
        #expect(header == "# CursorInsight 日志 — 2026-04-09\n\n")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd apps/CursorInsight && swift test --filter StorageManager 2>&1
```

Expected: FAIL — `StorageManager` not found.

- [ ] **Step 4: Implement StorageManager**

```swift
// CursorInsight/Services/StorageManager.swift
import Foundation
import SwiftData

final class StorageManager: @unchecked Sendable {
    private let archiveDirectory: URL
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    init(archiveDirectory: URL) {
        self.archiveDirectory = archiveDirectory
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.timeFormatter = DateFormatter()
        self.timeFormatter.dateFormat = "HH:mm:ss"
        try? FileManager.default.createDirectory(
            at: archiveDirectory, withIntermediateDirectories: true
        )
    }

    // MARK: - Markdown

    static func dailyHeader(for dateString: String) -> String {
        "# CursorInsight 日志 — \(dateString)\n\n"
    }

    static func formatMarkdownEntry(_ response: AIResponse) -> String {
        let time = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f.string(from: response.timestamp)
        }()
        return """
        ## \(time)
        **总结：** \(response.summary)
        **观察：** \(response.observation)
        **思考：** \(response.reflection)
        **建议：** \(response.suggestion)

        > OCR 原文：
        > \(response.rawText.replacingOccurrences(of: "\n", with: "\n> "))

        ---

        """
    }

    func appendMarkdown(_ response: AIResponse) throws {
        let dateString = dateFormatter.string(from: response.timestamp)
        let filePath = archiveDirectory.appendingPathComponent("\(dateString).md")

        if !FileManager.default.fileExists(atPath: filePath.path) {
            let header = Self.dailyHeader(for: dateString)
            try header.write(to: filePath, atomically: true, encoding: .utf8)
        }

        let entry = Self.formatMarkdownEntry(response)
        let handle = try FileHandle(forWritingTo: filePath)
        handle.seekToEndOfFile()
        handle.write(entry.data(using: .utf8)!)
        handle.closeFile()
    }

    // MARK: - SwiftData

    @MainActor
    func saveRecord(
        _ response: AIResponse,
        mouseX: Double, mouseY: Double,
        captureMode: CaptureMode,
        provider: String, model: String,
        context: ModelContext
    ) {
        let record = InsightRecord(
            timestamp: response.timestamp,
            mouseX: mouseX, mouseY: mouseY,
            captureMode: captureMode.rawValue,
            rawOCRText: response.rawText,
            summary: response.summary,
            observation: response.observation,
            reflection: response.reflection,
            suggestion: response.suggestion,
            aiProvider: provider,
            aiModel: model
        )
        context.insert(record)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd apps/CursorInsight && swift test --filter StorageManager 2>&1
```

Expected: All 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add InsightRecord model and StorageManager"
```

---

### Task 9: InsightOrchestrator — Main Pipeline

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Services/InsightOrchestrator.swift`

- [ ] **Step 1: Implement the orchestrator**

```swift
// CursorInsight/Services/InsightOrchestrator.swift
import SwiftUI
import Combine

@MainActor
@Observable
final class InsightOrchestrator {
    // MARK: - Published state
    var latestResponse: AIResponse = .empty
    var isRunning: Bool = false
    var statusMessage: String = "Ready"

    // MARK: - Configuration (bound to @AppStorage in SettingsView)
    var captureMode: CaptureMode = .fixedArea
    var captureSize: CGFloat = 2000
    var captureInterval: TimeInterval = 5
    var analysisInterval: TimeInterval = 20

    // MARK: - Dependencies
    let textBuffer = TextBuffer()
    let aiEngine = AIEngine()
    var storageManager: StorageManager?

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

        guard let image = ScreenCapture.capture(
            mode: captureMode, fixedSize: captureSize
        ) else {
            statusMessage = "Capture failed"
            return
        }

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let text = try await OCREngine.recognizeText(in: image)
                if !text.isEmpty {
                    self.textBuffer.append(text, at: .now)
                }
            } catch {
                await MainActor.run { self.statusMessage = "OCR error" }
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

            // Persist
            if let storage = storageManager {
                try? storage.appendMarkdown(response)
            }

            statusMessage = "Updated"
        } else {
            statusMessage = "AI returned empty"
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add InsightOrchestrator pipeline coordinator"
```

---

### Task 10: Floating Panel — NSPanel + Liquid Glass Views

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Views/FloatingPanelController.swift`
- Create: `apps/CursorInsight/CursorInsight/Views/CapsuleView.swift`
- Create: `apps/CursorInsight/CursorInsight/Views/InsightPanelView.swift`

- [ ] **Step 1: Implement FloatingPanelController**

```swift
// CursorInsight/Views/FloatingPanelController.swift
import AppKit
import SwiftUI

final class FloatingPanelController {
    private var panel: NSPanel?

    func show<Content: View>(_ content: Content) {
        if let panel {
            panel.contentView = NSHostingView(rootView: content)
            panel.orderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        panel.contentView = NSHostingView(rootView: content)

        // Position in top-right corner
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 340
            let y = screen.visibleFrame.maxY - 420
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func updateSize(width: CGFloat, height: CGFloat) {
        guard let panel else { return }
        var frame = panel.frame
        frame.size = NSSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
    }
}
```

- [ ] **Step 2: Implement CapsuleView (collapsed state)**

```swift
// CursorInsight/Views/CapsuleView.swift
import SwiftUI

struct CapsuleView: View {
    let isRunning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14))
                Circle()
                    .fill(isRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive, in: .capsule)
    }
}
```

- [ ] **Step 3: Implement InsightPanelView (expanded state)**

```swift
// CursorInsight/Views/InsightPanelView.swift
import SwiftUI

struct InsightPanelView: View {
    @Bindable var orchestrator: InsightOrchestrator
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 16))
                Text("CursorInsight")
                    .font(.headline)
                Spacer()
                Button {
                    if orchestrator.isRunning { orchestrator.stop() }
                    else { orchestrator.start() }
                } label: {
                    Image(systemName: orchestrator.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                Button(action: onCollapse) {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            // Content cards
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    insightCard(icon: "doc.text", title: "总结", text: orchestrator.latestResponse.summary)
                    insightCard(icon: "eye", title: "观察", text: orchestrator.latestResponse.observation)
                    insightCard(icon: "lightbulb", title: "思考", text: orchestrator.latestResponse.reflection)
                    insightCard(icon: "checkmark.seal", title: "建议", text: orchestrator.latestResponse.suggestion)
                }
                .padding(16)
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Text(timeString(orchestrator.latestResponse.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(orchestrator.isRunning ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
        .contentTransition(.numericText())
        .animation(.smooth, value: orchestrator.latestResponse.summary)
    }

    private func insightCard(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text.isEmpty ? "—" : text)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "Updated \(f.string(from: date))"
    }
}
```

- [ ] **Step 4: Verify it compiles**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add Liquid Glass floating panel views"
```

---

### Task 11: SettingsView

**Files:**
- Create: `apps/CursorInsight/CursorInsight/Views/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView**

```swift
// CursorInsight/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    // Capture
    @AppStorage("captureMode") private var captureMode: String = CaptureMode.fixedArea.rawValue
    @AppStorage("captureSize") private var captureSize: Double = 2000
    @AppStorage("captureInterval") private var captureInterval: Double = 5

    // AI
    @AppStorage("aiBackend") private var aiBackend: String = "ollama"
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel: String = "gemma4:e4b"
    @AppStorage("cloudAPIType") private var cloudAPIType: String = CloudAPIType.claude.rawValue
    @AppStorage("cloudAPIKey") private var cloudAPIKey: String = ""
    @AppStorage("cloudModel") private var cloudModel: String = "claude-sonnet-4-6-20250514"
    @AppStorage("cloudEndpoint") private var cloudEndpoint: String = "https://api.anthropic.com/v1/messages"
    @AppStorage("analysisInterval") private var analysisInterval: Double = 20

    // Storage
    @AppStorage("retentionDays") private var retentionDays: Double = 30

    @State private var showAdvanced = false

    var body: some View {
        TabView {
            captureSettings
                .tabItem { Label("Capture", systemImage: "camera") }
            aiSettings
                .tabItem { Label("AI", systemImage: "brain") }
            storageSettings
                .tabItem { Label("Storage", systemImage: "externaldrive") }
        }
        .frame(width: 480, height: 400)
        .padding()
    }

    // MARK: - Capture Tab

    private var captureSettings: some View {
        Form {
            Picker("Mode", selection: $captureMode) {
                Text("Fixed Area").tag(CaptureMode.fixedArea.rawValue)
                Text("Smart Window").tag(CaptureMode.smartWindow.rawValue)
            }

            if captureMode == CaptureMode.fixedArea.rawValue {
                HStack {
                    Text("Size: \(Int(captureSize))px")
                    Slider(value: $captureSize, in: 800...3000, step: 100)
                }
            }

            HStack {
                Text("Interval: \(Int(captureInterval))s")
                Slider(value: $captureInterval, in: 1...30, step: 1)
            }
        }
    }

    // MARK: - AI Tab

    private var aiSettings: some View {
        Form {
            Picker("Backend", selection: $aiBackend) {
                Text("Ollama (Local)").tag("ollama")
                Text("Cloud API").tag("cloud")
            }

            if aiBackend == "ollama" {
                TextField("Ollama URL", text: $ollamaURL)
                TextField("Model", text: $ollamaModel)
            } else {
                Picker("Provider", selection: $cloudAPIType) {
                    Text("Claude").tag(CloudAPIType.claude.rawValue)
                    Text("OpenAI").tag(CloudAPIType.openai.rawValue)
                }
                SecureField("API Key", text: $cloudAPIKey)
                TextField("Model", text: $cloudModel)
                TextField("Endpoint", text: $cloudEndpoint)
            }

            HStack {
                Text("Analysis interval: \(Int(analysisInterval))s")
                Slider(value: $analysisInterval, in: 10...60, step: 5)
            }
        }
    }

    // MARK: - Storage Tab

    private var storageSettings: some View {
        Form {
            HStack {
                Text("Keep records: \(Int(retentionDays)) days")
                Slider(value: $retentionDays, in: 7...365, step: 1)
            }

            Button("Open Archive Folder") {
                let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("CursorInsight/archive")
                NSWorkspace.shared.open(path)
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): add SettingsView with capture, AI, and storage tabs"
```

---

### Task 12: Wire Everything Together in App Entry

**Files:**
- Modify: `apps/CursorInsight/CursorInsight/CursorInsightApp.swift`

- [ ] **Step 1: Create AppDelegate for activation policy**

```swift
// Add to CursorInsightApp.swift (top of file, before @main)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

- [ ] **Step 2: Update CursorInsightApp to wire all modules**

Replace the entire file with:

```swift
// CursorInsight/CursorInsightApp.swift
import SwiftUI
import SwiftData
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CursorInsightApp: App {
    @State private var orchestrator = InsightOrchestrator()
    @State private var isExpanded = false
    @State private var panelController = FloatingPanelController()

    // Settings bindings
    @AppStorage("captureMode") private var captureMode: String = CaptureMode.fixedArea.rawValue
    @AppStorage("captureSize") private var captureSize: Double = 2000
    @AppStorage("captureInterval") private var captureInterval: Double = 5
    @AppStorage("analysisInterval") private var analysisInterval: Double = 20
    @AppStorage("aiBackend") private var aiBackend: String = "ollama"
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel: String = "gemma4:e4b"
    @AppStorage("cloudAPIType") private var cloudAPIType: String = CloudAPIType.claude.rawValue
    @AppStorage("cloudAPIKey") private var cloudAPIKey: String = ""
    @AppStorage("cloudModel") private var cloudModel: String = "claude-sonnet-4-6-20250514"
    @AppStorage("cloudEndpoint") private var cloudEndpoint: String = "https://api.anthropic.com/v1/messages"

    var body: some Scene {
        MenuBarExtra("CursorInsight", systemImage: orchestrator.isRunning ? "brain.head.profile.fill" : "brain.head.profile") {
            Toggle(orchestrator.isRunning ? "Running" : "Paused", isOn: Binding(
                get: { orchestrator.isRunning },
                set: { $0 ? orchestrator.start() : orchestrator.stop() }
            ))
            Button(isExpanded ? "Collapse Panel" : "Expand Panel") {
                togglePanel()
            }
            Divider()
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }.keyboardShortcut(",")
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }

    // Use a delegate to set activation policy after app launches
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private func configureOrchestrator() {
        orchestrator.captureMode = CaptureMode(rawValue: captureMode) ?? .fixedArea
        orchestrator.captureSize = captureSize
        orchestrator.captureInterval = captureInterval
        orchestrator.analysisInterval = analysisInterval

        // Configure AI
        if aiBackend == "ollama" {
            orchestrator.aiEngine.primaryProvider = OllamaProvider(
                baseURL: ollamaURL, model: ollamaModel
            )
        } else {
            let cloud = CloudProvider(
                apiType: CloudAPIType(rawValue: cloudAPIType) ?? .claude,
                apiKey: cloudAPIKey,
                model: cloudModel,
                endpoint: cloudEndpoint
            )
            orchestrator.aiEngine.primaryProvider = cloud
            orchestrator.aiEngine.fallbackProvider = OllamaProvider(
                baseURL: ollamaURL, model: ollamaModel
            )
        }

        // Configure storage
        let archiveDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CursorInsight/archive")
        orchestrator.storageManager = StorageManager(archiveDirectory: archiveDir)
    }

    private func togglePanel() {
        isExpanded.toggle()
        if isExpanded {
            let panelView = InsightPanelView(
                orchestrator: orchestrator,
                onCollapse: { togglePanel() }
            )
            panelController.show(panelView)
        } else {
            panelController.close()
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd apps/CursorInsight && swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/CursorInsight/
git commit -m "feat(cursor-insight): wire orchestrator, panel, settings into app entry"
```

---

### Task 13: Integration Test — Full Pipeline Manual Verification

This task verifies the complete pipeline works end-to-end.

- [ ] **Step 1: Run all unit tests**

```bash
cd apps/CursorInsight && swift test 2>&1
```

Expected: All tests pass (TextSimilarity: 7, TextBuffer: 4, OCREngine: 1, AIEngine: 2, StorageManager: 2 = 16 total).

- [ ] **Step 2: Build and run the app**

```bash
cd apps/CursorInsight && swift build && .build/debug/CursorInsight &
```

Expected: Menu bar icon appears. App does not show in Dock.

- [ ] **Step 3: Manual verification checklist**

Verify each of these by hand:
1. Menu bar icon shows brain icon
2. Click menu → "Running" toggle works (starts/stops)
3. "Expand Panel" shows the Liquid Glass floating window
4. After ~5s, status changes (capture happening)
5. After ~20s (if Ollama is running), panel shows AI analysis
6. Check `~/Library/Application Support/CursorInsight/archive/` for today's markdown file
7. Settings window opens with Cmd+,
8. Panel can be dragged around
9. Panel collapse button works

- [ ] **Step 4: Fix any issues found, then commit**

```bash
git add apps/CursorInsight/
git commit -m "fix(cursor-insight): address integration test findings"
```

- [ ] **Step 5: Final commit — mark v0.1 milestone**

```bash
git add -A
git commit -m "milestone(cursor-insight): v0.1 — core pipeline working"
```

---

## Deferred to v0.2

These spec requirements are intentionally deferred to keep v0.1 focused on the core pipeline:

- **Mouse hover pause** — pause capture when mouse hovers over the floating panel
- **Excluded app list** — skip capture when certain apps are in foreground (e.g. password managers)
- **Global shortcut** — `Cmd+Shift+P` to toggle pause/resume without clicking menu bar
- **Launch at login** — `SMAppService` integration for auto-start
- **SwiftData retention cleanup** — auto-delete records older than configured retention period
- **Main window** — history viewer, search, data management UI
