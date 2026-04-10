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
        let zoned: String         // Text annotated with spatial zones + speaker tags
        let chatTitle: String?    // Extracted chat title from top of screen (if any)
    }

    // MARK: - Bubble Color Detection

    /// Speaker in a chat bubble, detected by background color.
    private enum SpeakerTag {
        case me      // Blue bubble (Feishu: user's own messages)
        case other   // White/gray bubble (other person's messages)
        case unknown // Background, card, or undetermined
    }

    /// Sample the average color above a text bounding box to detect bubble background.
    private static func sampleBackgroundColor(
        in image: CGImage, boundingBox box: CGRect
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let w = CGFloat(image.width), h = CGFloat(image.height)

        // Vision coords (origin bottom-left) → pixel coords (origin top-left)
        let pixelX = Int(box.origin.x * w)
        let pixelY = Int((1.0 - box.origin.y - box.height) * h)
        let pixelW = max(Int(box.width * w), 1)

        // Sample a strip ABOVE the text (bubble background, avoids text pixels)
        let sampleX = pixelX + pixelW / 4
        let sampleW = max(pixelW / 2, 4)
        let sampleY = max(pixelY - 12, 0)
        let sampleH = 8

        guard let cropped = image.cropping(to: CGRect(
            x: sampleX, y: sampleY, width: sampleW, height: sampleH
        )) else { return (0, 0, 0) }

        // Draw into 1x1 bitmap → average color
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let ctx = CGContext(
            data: &pixel, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0, 0) }
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return (CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255)
    }

    /// Classify bubble color → speaker tag.
    /// Feishu blue bubble: B - R > 0.12, B > 0.95
    /// Feishu white/gray bubble: RGB ≈ equal, avg 0.88–0.96
    private static func detectSpeaker(
        in image: CGImage, boundingBox box: CGRect
    ) -> SpeakerTag {
        let (r, g, b) = sampleBackgroundColor(in: image, boundingBox: box)

        // Pure white = background, not a bubble (use 0.99 threshold;
        // WeChat white bubbles are ~0.97 which should count as "other")
        if r > 0.99 && g > 0.99 && b > 0.99 { return .unknown }

        // Feishu blue bubble (user): B clearly higher than R
        if b - r > 0.12 && b > 0.95 { return .me }

        // WeChat green bubble (user): G much higher than R and B (G~0.93, R~0.58, B~0.41)
        if g - r > 0.2 && g - b > 0.3 && g > 0.8 { return .me }

        // Gray/white bubble (other): RGB close together, mid-to-high brightness
        // Feishu: ~0.92, WeChat: ~0.97
        let avg = (r + g + b) / 3
        if avg > 0.88 && avg < 0.99 && abs(r - g) < 0.04 && abs(g - b) < 0.04 {
            return .other
        }

        return .unknown
    }

    // MARK: - OCR with Zones

    /// Internal: run Vision OCR and return observations as a Sendable array.
    private struct TextBlock: Sendable {
        let text: String
        let boundingBox: CGRect
    }

    private static func performOCR(on image: CGImage) async throws -> [TextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let obs = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks = obs.compactMap { o -> TextBlock? in
                    guard let t = o.topCandidates(1).first?.string else { return nil }
                    return TextBlock(text: t, boundingBox: o.boundingBox)
                }
                continuation.resume(returning: blocks)
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

    /// Common short UI labels that look like names but aren't.
    private static let nicknameBlacklist: Set<String> = [
        "你可阅读", "权限变更", "权限申请", "已编辑", "已撤回",
        "群聊会话记录", "群公告", "新消息", "条回复", "条新消息",
        "进行中", "已完成", "已结束", "发布主体", "业务视角",
    ]

    /// Check if a short text looks like a chat nickname.
    /// Group chat nicknames: 2–5 CJK chars (Chinese name) or short English name.
    /// Must not match known UI labels.
    private static func looksLikeNickname(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // Strip trailing icons/badges OCR might pick up (田, 国, 園, 画, |, etc.)
        let cleaned = trimmed.replacingOccurrences(
            of: "[\\s田国國園画聞|◎©⑥]+$", with: "", options: .regularExpression
        )
        guard cleaned.count >= 2 && cleaned.count <= 6 else { return false }

        // Blacklist known UI labels
        if nicknameBlacklist.contains(cleaned) { return false }

        // Must NOT contain punctuation, digits, or common UI characters
        let hasPunctuation = cleaned.unicodeScalars.contains {
            CharacterSet.punctuationCharacters.contains($0) ||
            CharacterSet.decimalDigits.contains($0) ||
            CharacterSet(charactersIn: "：:@[]【】「」（）()").contains($0)
        }
        if hasPunctuation { return false }

        // Must be mostly CJK or Latin letters
        let letterCount = cleaned.unicodeScalars.filter {
            CharacterSet.letters.contains($0) ||
            CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}").contains($0)
        }.count
        return letterCount >= 2 && Double(letterCount) / Double(cleaned.count) > 0.8
    }

    /// Run OCR and return text with spatial zone annotations, speaker tags, and nickname merging.
    /// Zones: left (0–20%), center (20–80%), right (80–100%).
    /// Skips top 10% and bottom 8%.
    /// For center-zone text:
    ///   - Detects bubble background color to tag [我]/[对方]
    ///   - Merges nickname lines (short text above a message) into "昵称：消息" format
    static func recognizeWithZones(in image: CGImage) async throws -> ZonedText {
        let blocks = try await performOCR(on: image)

        let raw = blocks.map(\.text).joined(separator: "\n")

        var left: [String] = []
        var right: [String] = []

        // Collect center-zone blocks with metadata for nickname merging
        struct CenterBlock {
            let text: String
            let box: CGRect
            let speaker: SpeakerTag
        }
        var centerBlocks: [CenterBlock] = []

        // boundingBox: origin bottom-left, x=0..1 (left→right), y=0..1 (bottom→top)
        // Left sidebar (cx < 0.2): always sidebar, no color check.
        // Center/right (cx >= 0.2): detect bubble color first.
        //   If it's a chat bubble (me/other), put in center regardless of X.
        //   This handles WeChat where user's green bubbles are right-aligned (cx > 0.8).
        for block in blocks {
            let box = block.boundingBox
            let cx = box.origin.x + box.width / 2
            let cy = box.origin.y + box.height / 2

            if cy > 0.90 || cy < 0.08 { continue }

            // Left sidebar: always left, skip color detection
            // Use 0.25 to cover WeChat's wider sidebar (~25% of window)
            if cx < 0.25 {
                left.append(block.text)
                continue
            }

            // Center/right: check bubble color first
            let speaker = detectSpeaker(in: image, boundingBox: box)
            if speaker == .me || speaker == .other {
                centerBlocks.append(CenterBlock(text: block.text, box: box, speaker: speaker))
            } else if cx > 0.8 {
                right.append(block.text)
            } else {
                centerBlocks.append(CenterBlock(text: block.text, box: box, speaker: .unknown))
            }
        }

        // Sort center blocks top-to-bottom (high Y = top of screen → comes first)
        centerBlocks.sort { $0.box.origin.y + $0.box.height / 2 > $1.box.origin.y + $1.box.height / 2 }

        // Merge nicknames: if a short nickname-like text is directly above a message
        // (small vertical gap, similar X position), merge as "昵称：消息"
        var center: [String] = []
        var i = 0
        while i < centerBlocks.count {
            let current = centerBlocks[i]

            // Check if current block looks like a nickname and next block is close below
            if looksLikeNickname(current.text), i + 1 < centerBlocks.count {
                let next = centerBlocks[i + 1]
                // Vertical gap: current is above next (current.cy > next.cy in Vision coords)
                let currentBottom = current.box.origin.y  // bottom edge of current block
                let nextTop = next.box.origin.y + next.box.height  // top edge of next block
                let gap = currentBottom - nextTop
                // Horizontal overlap: nickname and message should be roughly aligned
                let xOverlap = abs(current.box.origin.x - next.box.origin.x) < 0.15

                if gap >= 0 && gap < 0.04 && xOverlap {
                    // Merge: use the message's speaker tag, prepend nickname
                    let nickname = current.text.trimmingCharacters(in: .whitespaces)
                    let tag: String
                    switch next.speaker {
                    case .me:    tag = "[我] "
                    case .other: tag = "[对方] "
                    case .unknown: tag = ""
                    }
                    center.append("\(tag)\(nickname)：\(next.text)")
                    i += 2
                    continue
                }
            }

            // Normal block (not a nickname)
            switch current.speaker {
            case .me:    center.append("[我] \(current.text)")
            case .other: center.append("[对方] \(current.text)")
            case .unknown: center.append(current.text)
            }
            i += 1
        }

        // Extract chat title from top of the chat panel.
        // In Feishu/WeChat, the title is in the right panel header area:
        //   cx > 0.35 (right of sidebar), cy > 0.90 (near top)
        // Filter out: numbers/counters (303/351), timestamps, watermarks, UI buttons
        let chatTitle: String? = {
            var candidates: [(text: String, cx: CGFloat, cy: CGFloat)] = []
            for block in blocks {
                let box = block.boundingBox
                let cx = box.origin.x + box.width / 2
                let cy = box.origin.y + box.height / 2
                // Top of chat panel, right of sidebar
                guard cy > 0.90 && cx > 0.30 && cx < 0.65 else { continue }
                let text = block.text.trimmingCharacters(in: .whitespaces)
                guard text.count >= 2 && text.count <= 25 else { continue }
                // Skip numbers, counters, timestamps, watermarks
                if text.contains("/") || text.contains(">") { continue }
                if text.allSatisfy({ $0.isNumber || $0 == ":" || $0 == "." || $0 == " " }) { continue }
                if text.contains("4272") || text.contains("王金鑫 ") { continue }
                // Skip common UI labels
                if text.contains("消息") || text.contains("搜索") { continue }
                candidates.append((text: text, cx: cx, cy: cy))
            }
            // Pick the candidate closest to top-left of chat panel
            // (highest cy = most top, then leftmost cx, then shortest)
            return candidates
                .sorted { ($0.cy, -$0.cx, -Double($0.text.count)) > ($1.cy, -$1.cx, -Double($1.text.count)) }
                .first?.text
        }()

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
        return ZonedText(raw: raw, zoned: zoned, chatTitle: chatTitle)
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
        // Feishu/Lark notifications
        "机器人", "待评估", "待审批", "发起了一个", "你负责的",
        "你有一份", "数据平台推送", "周会", "视频会议",
        "云文档助手", "飞书招聘", "飞书People", "审批 机器人",
        "飞书超前体验", "核心数据进展",
        // IM UI elements
        "正在输入", "已读", "未读", "在线", "离线", "忙碌",
        "输入消息", "按Enter发送", "发送", "表情", "截屏",
        "语音通话", "视频通话", "共享屏幕",
        "群成员", "群公告", "群设置",
        "Typing", "Online", "Last seen",
        "输入自己熟悉的语言",
        "权限变更",
    ]

    static func cleanText(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")

        let cleaned = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Speaker-tagged lines ([我]/[对方]) always survive — they are chat messages
            let hasSpeakerTag = trimmed.hasPrefix("[我] ") || trimmed.hasPrefix("[对方] ")
            // Strip tag for content checks below
            let content = hasSpeakerTag
                ? String(trimmed.drop(while: { $0 != " " }).dropFirst())
                : trimmed

            // Check if line contains CJK characters
            let hasCJK = content.unicodeScalars.contains {
                CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}").contains($0) ||
                CharacterSet(charactersIn: "\u{3400}"..."\u{4DBF}").contains($0)
            }

            // CJK text: keep lines >= 4 chars
            // Latin text: keep lines >= 15 chars
            // Speaker-tagged lines: keep if >= 2 chars (short chat messages like "好的")
            let minLength = hasSpeakerTag ? 2 : (hasCJK ? 4 : 15)
            guard content.count >= minLength else { return false }

            // Speaker-tagged chat messages skip noise filters
            if hasSpeakerTag { return true }

            // Drop common UI menu items (exact match)
            let lower = content.lowercased()
            if uiNoisePatterns.contains(lower) { return false }

            // Drop notification/sidebar noise (substring match)
            for noise in noiseSubstrings {
                if content.contains(noise) { return false }
            }

            // Drop lines that look like IM sidebar entries:
            // short lines with names + truncation markers (… or ..)
            if content.count < 30 && (content.hasSuffix("…") || content.hasSuffix("..") || content.hasSuffix("⋯")) {
                return false
            }

            // Drop lines that look like file paths
            if content.hasPrefix("/") || content.hasPrefix("~") || content.contains("://") {
                if content.count < 50 { return false }
            }

            // Drop lines that are just punctuation/symbols
            let alphanumCount = content.unicodeScalars.filter {
                CharacterSet.alphanumerics.contains($0) ||
                CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}").contains($0)
            }.count
            // CJK chat messages can be short (e.g. "策略运营？" = 4 CJK + punctuation)
            let minAlphanum = hasCJK ? 3 : 5
            if alphanumCount < minAlphanum { return false }

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

        // Regex for "name + optional space + 3-5 digit number" pattern
        // Matches: "王金鑫 4272", "Steve Wang 4272", "張三 1234"
        // Also catches OCR-garbled variants: "蓋4272", "系A272" (no space, partial misread)
        let watermarkRegex = try? NSRegularExpression(
            pattern: "^[\\p{L}\\s]{1,20}\\s*\\d{3,5}$"
        )
        // Short lines ending in 3-5 digits with mixed letters/digits (garbled watermark)
        // Matches: "系A272", "5A272" where OCR misread the watermark
        let garbledWatermarkRegex = try? NSRegularExpression(
            pattern: "^.{1,6}\\d{3,5}$"
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

            // Garbled watermark (OCR misread, short + ends in digits)
            if trimmed.count <= 8, let regex = garbledWatermarkRegex {
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

    /// Zone header names used in zoned output.
    private static let zoneHeaders: Set<String> = ["[左侧边栏]", "[主内容区]", "[右侧边栏]"]

    /// Clean zoned text — apply cleanText to each zone section, preserve zone headers
    /// and speaker tags ([我]/[对方]).
    static func cleanZonedText(_ zoned: String) -> String {
        let sections = zoned.components(separatedBy: "\n\n")
        var result: [String] = []

        for section in sections {
            let lines = section.components(separatedBy: "\n")
            guard let header = lines.first, zoneHeaders.contains(header) else {
                // No zone header, clean as regular text
                let cleaned = cleanText(section)
                if !cleaned.isEmpty { result.append(cleaned) }
                continue
            }

            // Clean lines after the zone header, preserving speaker tags
            let contentLines = Array(lines.dropFirst())
            let cleaned = cleanLinesPreservingSpeakerTags(contentLines)
            if !cleaned.isEmpty {
                result.append("\(header)\n\(cleaned)")
            }
        }

        return result.joined(separator: "\n\n")
    }

    /// Clean lines while preserving [我]/[对方] speaker tags.
    /// Tagged lines are kept as-is (they are confirmed chat messages).
    /// Untagged lines go through cleanText filtering.
    private static func cleanLinesPreservingSpeakerTags(_ lines: [String]) -> String {
        // Split into tagged (keep) and untagged (filter)
        var untaggedLines: [String] = []
        for line in lines {
            if !line.hasPrefix("[我] ") && !line.hasPrefix("[对方] ") {
                untaggedLines.append(line)
            }
        }

        // Clean only untagged lines
        let cleanedUntagged = cleanText(untaggedLines.joined(separator: "\n"))
        let cleanedSet = Set(cleanedUntagged.components(separatedBy: "\n"))

        // Rebuild: tagged lines pass through, untagged lines must survive cleanText
        var seen = Set<String>()
        var result: [String] = []
        // Watermark regex for tagged lines
        let watermarkRegex = try? NSRegularExpression(pattern: "^[\\p{L}\\s]{1,20}\\s*\\d{3,5}[。.]?$")

        for line in lines {
            if line.hasPrefix("[我] ") || line.hasPrefix("[对方] ") {
                // Tagged: keep but still filter watermarks and timestamps
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                let content = String(line.drop(while: { $0 != " " }).dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                if content.count < 2 { continue }
                if seen.contains(trimmedLine) { continue }
                // Filter watermarks (name + 3-5 digits)
                if let regex = watermarkRegex {
                    let range = NSRange(content.startIndex..., in: content)
                    if regex.firstMatch(in: content, range: range) != nil { continue }
                }
                // Filter pure timestamps like "16:50", "4月7日"
                if content.count <= 6 && content.contains(":") &&
                   content.allSatisfy({ $0.isNumber || $0 == ":" }) { continue }
                if content.count <= 5 && content.contains("月") && content.contains("日") { continue }

                seen.insert(trimmedLine)
                result.append(line)
            } else {
                // Untagged: only keep if it survived cleanText
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if cleanedSet.contains(trimmed) && !seen.contains(trimmed) {
                    seen.insert(trimmed)
                    result.append(trimmed)
                }
            }
        }

        return result.joined(separator: "\n")
    }
}
