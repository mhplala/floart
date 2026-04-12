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
    var styleProfileManager: StyleProfileManager?
    var conversationHistoryManager: ConversationHistoryManager?
    /// Per-bucket editable context store. The single source of truth for
    /// "what Floart said last for this bucket" and "what the user wants
    /// Floart to remember for this bucket". Wired up by FloartApp on launch.
    var contextStore: ContextStore?
    /// Latest chat-partner key detected by the OCR loop, format "<localizedAppName>:<chatTitle>".
    /// Only set when in a chat app; stays stale after switching apps, so any consumer must
    /// verify it belongs to the current app before trusting it (see `contextKey` computation).
    private var currentConversationKey: String?

    private var captureTimer: Timer?
    private var styleRefreshTimer: Timer?
    private var focusPollTimer: Timer?
    /// Dedup key for the last focused input we reacted to. Format:
    /// "<bundleId>|<role>|<x>,<y>". When this changes we consider it a new focus event.
    private var lastFocusedSignature: String?
    /// The action text we last rendered into a bubble. Combined with
    /// `lastFocusedSignature` forms a two-dimensional dedup: we only
    /// suppress a re-show if BOTH the focused input and the action text
    /// are unchanged. A new analysis producing a different action breaks
    /// the dedup and the bubble re-appears — important after the user
    /// manually dismissed the previous bubble.
    private var lastShownAction: String?
    /// Inline bubble controller — shows the latest action above the focused input.
    let bubbleController = BubbleController()

    /// Master switch — when false, the focus poller still runs (for dedup
    /// state) but the bubble is never shown or filled. Bound to UserDefaults
    /// via FloartApp → SettingsView. Turning this off closes any currently
    /// visible bubble immediately.
    var enableBubble: Bool = true {
        didSet {
            if !enableBubble {
                bubbleController.close()
                lastFocusedSignature = nil
                lastShownAction = nil
            }
        }
    }

    // MARK: - Bubble cooldown (Option C: content-or-60s)
    /// The action text that was most recently written into a focused input.
    /// While this equals the action we'd otherwise show, the bubble stays
    /// suppressed — we don't want to pop the same suggestion again right
    /// after the user already accepted it.
    private var lastFilledAction: String?
    /// When `lastFilledAction` was set. Cooldown auto-expires after 60 s so
    /// the bubble can resume even if no new analysis has arrived yet.
    private var lastFilledAt: Date?
    private static let fillCooldown: TimeInterval = 60
    // (context storage lives in `contextStore` — see above)

    // MARK: - Chat message dedup (layer 1)
    /// Per-conversation rolling dedup for tagged OCR lines — see MessageDedup.
    private var messageDedup = MessageDedup()
    private var lastMouseLocation: NSPoint = .zero
    private var lastImageHash: UInt64 = 0
    private var lastFrontAppName: String = ""
    private var newMessagesSinceLastRefresh: Int = 0

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

        // Style profile refresh timer — every 60 minutes
        styleRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: 3600, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshStyleProfile() }
        }

        // Focus poller — detect when the user focuses a new text input and
        // pop the inline bubble with the latest action.
        focusPollTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.pollFocusedInput() }
        }

        Log.write("🚀 Pipeline started — capture: \(self.captureInterval)s, mode: \(self.captureMode.rawValue), size: \(self.captureSize)")
        captureAndOCR()
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        styleRefreshTimer?.invalidate()
        styleRefreshTimer = nil
        focusPollTimer?.invalidate()
        focusPollTimer = nil
        bubbleController.close()
        lastFocusedSignature = nil
        lastShownAction = nil
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
                    // Chat dedup (layer 1): if we're in a chat app, resolve
                    // the conversation key and strip any tagged-message lines
                    // we've already seen in this session. This prevents the
                    // same messages from being re-fed to the LLM on every
                    // OCR frame, and handles the "user scrolled up to re-read
                    // old messages" case correctly.
                    let chatApps: Set<String> = ["飞书", "微信", "WeChat", "Telegram", "Slack", "飞书会议"]
                    var textForBuffer = cleanedZoned
                    var convKeyForBuffer: String? = nil
                    if chatApps.contains(frontApp) {
                        let chatTitle = await MainActor.run {
                            AccessibilityHelper.extractChatTitle()
                        } ?? zonedResult.chatTitle ?? "unknown"
                        let rawKey = "\(frontApp):\(chatTitle)"
                        let key = await MainActor.run { () -> String in
                            self?.conversationHistoryManager?.resolveKey(rawKey) ?? rawKey
                        }
                        convKeyForBuffer = key

                        let filterResult = await MainActor.run { () -> MessageDedup.Result? in
                            guard let self else { return nil }
                            return self.messageDedup.filter(cleanedZoned, conversationKey: key)
                        }
                        if let r = filterResult {
                            textForBuffer = r.filtered
                            if r.dropped > 0 || r.kept > 0 {
                                Log.write("🔁 Dedup (\(key)): kept \(r.kept) new, dropped \(r.dropped) duplicate tagged lines")
                            }
                        }
                    }

                    buffer.append(textForBuffer, at: .now, appName: frontApp)

                    // Collect [我] messages for style profile (use the filtered
                    // text so style profile only sees each message once).
                    if let spm = await self?.styleProfileManager {
                        let newCount = spm.collectMessages(from: textForBuffer)
                        if newCount > 0 {
                            await MainActor.run {
                                self?.newMessagesSinceLastRefresh += newCount
                                if !(spm.hasProfile) && (self?.newMessagesSinceLastRefresh ?? 0) >= 10 {
                                    self?.newMessagesSinceLastRefresh = 0
                                    Task { await self?.refreshStyleProfile() }
                                }
                            }
                        }
                    }

                    // Collect messages for conversation history. Use the
                    // filtered text so CHM only appends genuinely-new lines.
                    if let chm = await self?.conversationHistoryManager,
                       let key = convKeyForBuffer {
                        let lines = textForBuffer.components(separatedBy: "\n")
                        let taggedMessages = lines.filter { $0.hasPrefix("[我] ") || $0.hasPrefix("[对方] ") }
                        if !taggedMessages.isEmpty {
                            chm.addMessages(taggedMessages, forConversation: key)
                            if chm.needsSummaryRefresh(forConversation: key) {
                                let convKey = key
                                await MainActor.run {
                                    self?.currentConversationKey = convKey
                                    Task { await self?.refreshConversationSummary(key: convKey) }
                                }
                            } else {
                                await MainActor.run { self?.currentConversationKey = key }
                            }
                        } else {
                            await MainActor.run { self?.currentConversationKey = key }
                        }
                    }

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

    private func refreshConversationSummary(key: String) async {
        guard let chm = conversationHistoryManager,
              let provider = aiEngine.primaryProvider else { return }
        Log.write("📚 Refreshing conversation summary for \"\(key)\"...")
        await chm.refreshSummary(forConversation: key, using: provider)
    }

    private func refreshStyleProfile() async {
        guard let spm = styleProfileManager,
              let provider = aiEngine.primaryProvider else { return }
        Log.write("📝 Refreshing style profile...")
        await spm.refreshProfile(using: provider)
        newMessagesSinceLastRefresh = 0
    }

    // MARK: - Focus polling

    /// Called every 0.5s while the pipeline is running.
    ///
    /// Responsibilities:
    /// 1. Dismiss the existing bubble when the frontmost app is no longer the
    ///    one that owns the bubble — context must not follow the user into a
    ///    different app.
    /// 2. When a new text input gains focus (dedup'd by position), show the
    ///    bubble with the latest cached action — unless the bubble feature
    ///    is disabled or the action is in its post-fill cooldown window.
    private func pollFocusedInput() {
        guard enableBubble else { return }

        let frontBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // (1) App-switch dismissal: if the bubble is showing but the current
        //     frontmost app isn't the owner, close it immediately. Also clear
        //     the dedup so re-focusing in the original app pops a fresh one.
        if bubbleController.isShowing,
           let owner = bubbleController.ownerBundleId,
           frontBundleId != owner {
            Log.write("🫧 App switched away from \(owner) → closing bubble")
            bubbleController.close()
            lastFocusedSignature = nil
            lastShownAction = nil
        }

        // (2) New-focus detection + bubble show.
        guard let input = AccessibilityHelper.detectFocusedInput(),
              let frame = input.frame else {
            return
        }

        // Focus signature — quantize position to 10px so 1px jitter doesn't re-trigger.
        let roundedX = Int(frame.origin.x / 10) * 10
        let roundedY = Int(frame.origin.y / 10) * 10
        let signature = "\(input.bundleId ?? input.appName)|\(input.role)|\(roundedX),\(roundedY)"

        // Fast path: bubble is already showing on this same input, and the
        // `updateAction` hook in analyzeBuffer takes care of refreshing its
        // content in place. Nothing for the poller to do.
        if bubbleController.isShowing, signature == lastFocusedSignature {
            return
        }

        // Only show an action that was actually generated for the CURRENT
        // app/chat. Without this gating, switching from App A to App B and
        // focusing an input would pop a bubble with App A's stale action.
        let sceneType = SceneClassifier.classify(bundleId: input.bundleId, focusedInput: input)
        let chatTitle = resolveChatTitle(sceneType: sceneType, appName: input.appName)
        let contextKey = contextKey(
            sceneType: sceneType,
            appName: input.appName,
            bundleId: input.bundleId
        )

        guard let bucket = contextStore?.read(
            appName: input.appName,
            bundleId: input.bundleId,
            scene: sceneType,
            chatTitle: chatTitle
        ),
        let advice = bucket.lastAdvice,
        let action = AIResponse(advice: advice, timestamp: .now, rawText: "").actionContent,
        !action.isEmpty else {
            if signature != lastFocusedSignature {
                Log.write("🫧 Focus changed (\(input.role) in \(input.appName)) but no cached action for \(contextKey)")
                lastFocusedSignature = signature
            }
            return
        }

        // (signature, action) dedup: suppress re-show when both the focused
        // input AND the action text are unchanged since we last showed
        // something. A new analysis producing a different action breaks
        // this dedup, so a dismissed bubble naturally re-appears when
        // there's genuinely new content to show.
        if signature == lastFocusedSignature, action == lastShownAction {
            return
        }

        // Cooldown: if the would-be action matches the one we just filled
        // and less than 60s has passed, stay quiet. A new analysis will
        // produce a different action and naturally break out.
        if let lastAction = lastFilledAction,
           let lastAt = lastFilledAt,
           lastAction == action,
           Date().timeIntervalSince(lastAt) < Self.fillCooldown {
            return
        }

        Log.write("🫧 Showing bubble — app: \(input.appName), role: \(input.role), context: \(contextKey), axFrame: \(frame)")
        bubbleController.show(
            action: action,
            near: frame,
            ownerBundleId: input.bundleId,
            onFill: { [weak self] in
                self?.handleBubbleFill()
            }
        )
        lastFocusedSignature = signature
        lastShownAction = action
    }

    /// Resolve the chat identity for the current moment. Single source of
    /// truth used by `contextKey()`, `analyzeBuffer`, `pollFocusedInput`,
    /// `handleBubbleFill`, and `ContextStore.read/append` — everyone gets
    /// the same chat title so file paths, bucket keys, and prompt fragments
    /// always agree.
    ///
    /// Strategy (falls through on failure):
    ///   1. Fresh AX window title via `AccessibilityHelper.extractChatTitle()`
    ///      (native Cocoa apps, native WeChat 3.x, feishu web, Slack main window)
    ///   2. Parsed out of `currentConversationKey` if it exists and belongs
    ///      to the current app — covers Electron apps where AX fails but
    ///      OCR already found a chat title earlier this session
    ///   3. nil — caller must treat as "chat identity unknown, don't inject
    ///      chat-specific context and don't write to a chat bucket file"
    private func resolveChatTitle(sceneType: SceneType, appName: String) -> String? {
        guard sceneType == .dmChat else { return nil }
        if let title = AccessibilityHelper.extractChatTitle(), !title.isEmpty {
            return title
        }
        if let stale = currentConversationKey,
           stale.hasPrefix("\(appName):") {
            return String(stale.dropFirst(appName.count + 1))
        }
        return nil
    }

    /// Compute the scene-aware context bucket key. Chat buckets require a
    /// resolved chat title — if we can't resolve one we deliberately fall
    /// back to the app bucket instead of smashing multiple chats into the
    /// same key via stale `currentConversationKey`.
    private func contextKey(sceneType: SceneType, appName: String, bundleId: String?) -> String {
        if sceneType == .dmChat,
           let title = resolveChatTitle(sceneType: sceneType, appName: appName) {
            return "chat:\(appName):\(title)"
        }
        return "app:\(bundleId ?? appName)"
    }

    /// Fill the cached action for the currently-focused input.
    /// Re-detects the focused input at click time so the fill always targets
    /// what the user is looking at (not a stale cached element).
    private func handleBubbleFill() {
        guard let input = AccessibilityHelper.detectFocusedInput() else {
            Log.write("🫧 Fill clicked but no focused input")
            return
        }
        let sceneType = SceneClassifier.classify(bundleId: input.bundleId, focusedInput: input)
        let chatTitle = resolveChatTitle(sceneType: sceneType, appName: input.appName)
        let key = contextKey(sceneType: sceneType, appName: input.appName, bundleId: input.bundleId)
        guard let bucket = contextStore?.read(
            appName: input.appName,
            bundleId: input.bundleId,
            scene: sceneType,
            chatTitle: chatTitle
        ),
        let advice = bucket.lastAdvice,
        let action = AIResponse(advice: advice, timestamp: .now, rawText: "").actionContent,
        !action.isEmpty else {
            Log.write("🫧 Fill clicked but no action cached for \(key)")
            return
        }
        let strategy = InputFiller.appendToFocusedInput(action)
        Log.write("🫧 Fill result: \(strategy?.rawValue ?? "failed")")
        if strategy != nil {
            // Engage cooldown — don't re-show this exact action again for 60s.
            lastFilledAction = action
            lastFilledAt = Date()
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

        // Extract main content only (strip zone headers)
        let mainContent = extractMainContent(from: combinedText)

        // Only send main content area to AI — sidebars contain unrelated chat previews
        let appName = entries.last?.appName ?? lastFrontAppName
        let textForAI = mainContent.isEmpty ? combinedText : mainContent

        // Classify the scene from frontmost app + focused input.
        // This determines the kind of |ACTION| the LLM will produce.
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleId = frontApp?.bundleIdentifier
        let focusedInput = AccessibilityHelper.detectFocusedInput()
        let sceneType = SceneClassifier.classify(bundleId: bundleId, focusedInput: focusedInput)
        let inputHint = focusedInput?.hintText

        // Compute a scene-aware context bucket, freshly for this analysis.
        // Unified chat identity — same function is called by the poller, the
        // fill handler, the contextKey helper, and here, so file paths and
        // bucket keys always agree.
        let chatTitleForStorage = resolveChatTitle(sceneType: sceneType, appName: appName)
        let contextKey = self.contextKey(sceneType: sceneType, appName: appName, bundleId: bundleId)

        let textWithContext = "[当前应用: \(appName)]\n\n\(textForAI)"

        Log.write("🧠 Analysis starting — app: \(appName), bundle: \(bundleId ?? "?"), scene: \(sceneType.label), focusedInput: \(focusedInput?.role ?? "none"), hint: \(inputHint ?? "none"), contextKey: \(contextKey)")
        Log.write("🧠 \(entries.count) entries, \(textForAI.count) chars (full: \(combinedText.count))")
        Log.write("🧠 Main content preview: \(String(textForAI.prefix(300)))")

        statusMessage = "Analyzing..."
        let aiStart = Date()
        let styleFragment = styleProfileManager?.promptFragment()
        // Conversation-history fragment must EXACTLY match the resolved
        // current chat title — otherwise switching chats inside the same app
        // (e.g. WeChat Alice → WeChat Bob) would leak Alice's history into
        // Bob's analysis during the brief window before the OCR loop catches
        // up and updates `currentConversationKey`.
        let conversationFragment: String? = {
            guard sceneType == .dmChat,
                  let title = chatTitleForStorage,
                  let chm = conversationHistoryManager else { return nil }
            let expectedKey = "\(appName):\(title)"
            // Only use the CHM fragment if its stored key matches. CHM stores
            // under its own canonicalized key; we verify by matching against
            // the stale currentConversationKey when present.
            if let stored = currentConversationKey, stored == expectedKey {
                return chm.promptFragment(forConversation: stored)
            }
            // Fall back: ask CHM directly for the expected key. If CHM has
            // never seen this chat, it returns nil, which is the safe result.
            return chm.promptFragment(forConversation: expectedKey)
        }()

        // Read the bucket from the editable context store — this gives us
        // both the user-curated Notes section (injected into the prompt)
        // and the previous advice (fed back as lastContext so the LLM
        // doesn't repeat itself).
        let bucket = contextStore?.read(
            appName: appName,
            bundleId: bundleId,
            scene: sceneType,
            chatTitle: chatTitleForStorage
        )
        let lastContext = bucket?.lastAdvice
        let notesFragment: String? = {
            guard let notes = bucket?.notes, !notes.isEmpty else { return nil }
            return "关于这个场景用户的自定义备注（请参考）：\n\(notes)"
        }()
        // Fold the notes into the existing style fragment slot — we don't
        // have a dedicated param for it, and styleFragment is concatenated
        // into the system prompt as-is, so piggybacking is safe.
        let combinedStyleFragment: String? = {
            switch (styleFragment, notesFragment) {
            case (nil, nil):       return nil
            case (let s?, nil):    return s
            case (nil, let n?):    return n
            case (let s?, let n?): return s + "\n\n" + n
            }
        }()
        let response = await aiEngine.analyze(
            text: textWithContext,
            context: lastContext,
            styleFragment: combinedStyleFragment,
            conversationFragment: conversationFragment,
            sceneType: sceneType,
            inputHint: inputHint
        )
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
            // Persist to the file-based context store — creates the bucket
            // file on first write and prepends to its History section.
            contextStore?.append(
                appName: appName,
                bundleId: bundleId,
                scene: sceneType,
                chatTitle: chatTitleForStorage,
                advice: response.advice,
                contextKey: contextKey
            )

            // If the inline bubble is currently showing, update its content
            // in place (don't re-trigger positioning or the auto-hide timer).
            if bubbleController.isShowing,
               let newAction = archiveResponse.actionContent, !newAction.isEmpty {
                bubbleController.updateAction(newAction, onFill: { [weak self] in
                    self?.handleBubbleFill()
                })
            }

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
    /// Scans line-by-line for robustness.
    private func extractMainContent(from text: String) -> String {
        let zoneHeaders: Set<String> = ["[左侧边栏]", "[主内容区]", "[右侧边栏]"]
        let lines = text.components(separatedBy: "\n")
        var mainLines: [String] = []
        var inMainSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if zoneHeaders.contains(trimmed) {
                inMainSection = (trimmed == "[主内容区]")
                continue
            }
            if inMainSection {
                mainLines.append(line)
            }
        }

        let result = mainLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // Fallback: if no [主内容区] found, strip all zone headers
        if result.isEmpty {
            return lines.filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !zoneHeaders.contains(t) && !t.hasPrefix("[当前应用:")
            }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}
