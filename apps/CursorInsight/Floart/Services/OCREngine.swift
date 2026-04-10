// Floart/Services/OCREngine.swift
import Vision
import CoreGraphics

enum OCREngine {
    /// Runs Vision OCR on a CGImage, then cleans the result.
    static func recognizeText(in image: CGImage) async throws -> String {
        let raw = try await rawRecognizeText(in: image)
        return cleanText(raw)
    }

    /// OCR result with spatial zone info for each text block.
    struct ZonedText {
        let raw: String           // All text joined
        let zoned: String         // Text annotated with spatial zones
    }

    /// Run OCR and return text with spatial zone annotations.
    /// Divides the screen into zones: left (0-20%), center (20-80%), right (80-100%)
    /// and top (0-10%), bottom (90-100%).
    static func recognizeWithZones(in image: CGImage) async throws -> ZonedText {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []

                // Collect raw text
                let rawLines = observations.compactMap { $0.topCandidates(1).first?.string }
                let raw = rawLines.joined(separator: "\n")

                // Group by horizontal zone
                // boundingBox: origin is bottom-left, x=0..1 (left to right), y=0..1 (bottom to top)
                var left: [String] = []
                var center: [String] = []
                var right: [String] = []

                for obs in observations {
                    guard let text = obs.topCandidates(1).first?.string else { continue }
                    let box = obs.boundingBox
                    let centerX = box.origin.x + box.width / 2

                    if centerX < 0.2 {
                        left.append(text)
                    } else if centerX > 0.8 {
                        right.append(text)
                    } else {
                        center.append(text)
                    }
                }

                // Build zoned output
                var parts: [String] = []
                if !left.isEmpty {
                    parts.append("[左侧边栏]\n\(left.joined(separator: "\n"))")
                }
                if !center.isEmpty {
                    parts.append("[主内容区]\n\(center.joined(separator: "\n"))")
                }
                if !right.isEmpty {
                    parts.append("[右侧边栏]\n\(right.joined(separator: "\n"))")
                }

                let zoned = parts.joined(separator: "\n\n")
                continuation.resume(returning: ZonedText(raw: raw, zoned: zoned))
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

    /// Raw OCR without cleaning.
    static func rawRecognizeText(in image: CGImage) async throws -> String {
        let result = try await recognizeWithZones(in: image)
        return result.raw
    }

    // MARK: - Text Cleaning

    /// Common UI noise patterns to filter out (exact match, lowercased)
    private static let uiNoisePatterns: Set<String> = [
        "file", "edit", "view", "help", "window", "go", "format",
        "finder", "safari", "chrome", "firefox",
        "copy", "paste", "cut", "undo", "redo", "select all",
        "close", "minimize", "zoom", "quit",
        "ok", "cancel", "done", "save", "delete", "open",
        "settings", "preferences",
    ]

    /// Patterns that indicate notification/sidebar noise (substring match)
    private static let noiseSubstrings: [String] = [
        "机器人", "待评估", "待审批", "发起了一个", "你负责的",
        "你有一份", "数据平台推送", "周会", "视频会议",
        "云文档助手", "飞书招聘", "飞书People", "审批 机器人",
        "飞书超前体验", "核心数据进展",
        "输入自己熟悉的语言",
    ]

    static func cleanText(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")

        let cleaned = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if line contains CJK characters
            let hasCJK = trimmed.unicodeScalars.contains {
                CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}").contains($0) ||
                CharacterSet(charactersIn: "\u{3400}"..."\u{4DBF}").contains($0)
            }

            // CJK text: keep lines >= 4 chars
            // Latin text: keep lines >= 15 chars
            let minLength = hasCJK ? 4 : 15
            guard trimmed.count >= minLength else { return false }

            // Drop common UI menu items (exact match)
            let lower = trimmed.lowercased()
            if uiNoisePatterns.contains(lower) { return false }

            // Drop notification/sidebar noise (substring match)
            for noise in noiseSubstrings {
                if trimmed.contains(noise) { return false }
            }

            // Drop lines that look like IM sidebar entries:
            // short lines with names + truncation markers (… or ..)
            if trimmed.count < 30 && (trimmed.hasSuffix("…") || trimmed.hasSuffix("..") || trimmed.hasSuffix("⋯")) {
                return false
            }

            // Drop lines that look like file paths
            if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") || trimmed.contains("://") {
                if trimmed.count < 50 { return false }
            }

            // Drop lines that are just punctuation/symbols
            let alphanumCount = trimmed.unicodeScalars.filter {
                CharacterSet.alphanumerics.contains($0) ||
                CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}").contains($0)
            }.count
            if alphanumCount < 5 { return false }

            return true
        }

        // Deduplicate: remove repeated lines (keep first occurrence)
        var seen = Set<String>()
        let deduped = cleaned.filter { line in
            let key = line.trimmingCharacters(in: .whitespaces)
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // Remove watermarks
        let noWatermark = removeWatermarks(from: deduped)

        return noWatermark.joined(separator: "\n")
    }

    // MARK: - Watermark Detection

    /// Remove watermark lines using two strategies:
    /// 1. Auto-detect: short lines appearing 3+ times (common in screen watermarks)
    /// 2. Pattern match: "name + 3-5 digit number" format (Feishu/Lark watermark)
    /// 3. User-configured watermark keywords from Settings
    private static func removeWatermarks(from lines: [String]) -> [String] {
        // Count occurrences of short lines (watermarks are short + repeated)
        var lineCounts: [String: Int] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count < 25 { // watermarks are typically short
                lineCounts[trimmed, default: 0] += 1
            }
        }

        // Lines that appear 3+ times are watermarks
        let autoWatermarks = Set(lineCounts.filter { $0.value >= 3 }.keys)

        // Regex for "name + space + 3-5 digit number" pattern
        // Matches: "王金鑫 4272", "Steve Wang 4272", "张三 1234"
        let watermarkRegex = try? NSRegularExpression(
            pattern: "^[\\p{L}\\s]{2,20}\\s+\\d{3,5}$"
        )

        // User-configured watermark keywords
        let userWatermarkText = UserDefaults.standard.string(forKey: "watermarkKeywords") ?? ""
        let userKeywords = userWatermarkText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Auto-detected watermark (repeated 3+ times)
            if autoWatermarks.contains(trimmed) { return false }

            // Name + number pattern
            if let regex = watermarkRegex {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil { return false }
            }

            // User-configured keywords
            for keyword in userKeywords {
                if trimmed.contains(keyword) { return false }
            }

            return true
        }
    }

    /// Clean zoned text — apply cleanText to each zone section, preserve zone headers.
    static func cleanZonedText(_ zoned: String) -> String {
        let sections = zoned.components(separatedBy: "\n\n")
        var result: [String] = []

        for section in sections {
            let lines = section.components(separatedBy: "\n")
            guard let header = lines.first, header.hasPrefix("[") else {
                // No zone header, clean as regular text
                let cleaned = cleanText(section)
                if !cleaned.isEmpty { result.append(cleaned) }
                continue
            }

            // Clean lines after the zone header
            let content = lines.dropFirst().joined(separator: "\n")
            let cleaned = cleanText(content)
            if !cleaned.isEmpty {
                result.append("\(header)\n\(cleaned)")
            }
        }

        return result.joined(separator: "\n\n")
    }
}
