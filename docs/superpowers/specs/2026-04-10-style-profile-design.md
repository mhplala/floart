# Style Profile — Design Spec

## Goal

Let Floart learn the user's writing style from real-time chat messages and feed it into the AI system prompt, so reply suggestions sound like the user wrote them.

## Data Flow

```
OCR (with [我] tags) → StyleProfileManager.collectMessages()
                              ↓
                     style_messages.txt  (raw messages, max 200, FIFO)
                              ↓
               refreshProfile() triggered by timer or cold-start
                              ↓
                     style_profile.txt   (AI-distilled summary)
                              ↓
              promptFragment() → system prompt injection
```

## New File: `Floart/Services/StyleProfileManager.swift`

### Storage

Location: `~/Application Support/Floart/`

| File | Content | Size cap |
|------|---------|----------|
| `style_messages.txt` | Raw `[我]` messages, one per line | 200 lines (FIFO) |
| `style_profile.txt` | AI-distilled style summary | Overwritten each refresh |

### Interface

```swift
final class StyleProfileManager: @unchecked Sendable {
    init(directory: URL)

    /// Extract [我] lines from cleaned zoned text, append to style_messages.txt.
    /// Returns count of new messages added.
    func collectMessages(from cleanedText: String) -> Int

    /// Distill style profile from accumulated messages using AI.
    func refreshProfile(using provider: AIProvider) async

    /// Return prompt fragment (summary + recent examples) or nil if no data.
    func promptFragment() -> String?

    /// Whether a profile file exists (for cold-start logic).
    var hasProfile: Bool { get }
}
```

### collectMessages logic

1. Split `cleanedText` by newlines
2. Filter lines starting with `[我] `, strip the prefix
3. Skip lines < 4 chars (noise)
4. Deduplicate against last 20 stored lines (avoid repeated OCR captures)
5. Append to `style_messages.txt`
6. If file exceeds 200 lines, trim from the top

### refreshProfile logic

1. Read all lines from `style_messages.txt`
2. If < 5 messages, skip (not enough data)
3. Send to AI with a dedicated distillation prompt:
   ```
   以下是一个用户在即时通讯中发送的消息。请总结这个人的说话风格特征。
   只输出特征列表，不要分析消息内容本身。
   涵盖：语气、句子长度、用词习惯、语言偏好（中/英/混）、标点习惯、emoji使用、
   是否拆成多条短消息发送、口头禅或高频词。
   用中文输出，控制在150字以内。
   ```
4. Write result to `style_profile.txt` (overwrite)

### promptFragment logic

1. Read `style_profile.txt` → summary (may be empty)
2. Read `style_messages.txt` → take last 10 lines → examples
3. If both empty, return nil
4. Format:
   ```
   用户说话风格（从历史消息学习）：
   {summary}

   用户最近的消息示例：
   - "{msg1}"
   - "{msg2}"
   ...
   ```

## Refresh Timing

| State | Trigger |
|-------|---------|
| Cold start (no `style_profile.txt`) | Every 10 new `[我]` messages collected |
| Warm (profile exists) | Every 60 minutes |

Implementation: `InsightOrchestrator` tracks `newMessagesSinceLastRefresh` counter. After each `collectMessages` call, check:
- If `!styleProfileManager.hasProfile && newMessages >= 10` → refresh
- Else use a 60-minute timer

## Changes to Existing Files

### InsightOrchestrator.swift

- Add `var styleProfileManager: StyleProfileManager?`
- After OCR clean, call `styleProfileManager?.collectMessages(from: cleanedText)`
- Track `newMessagesSinceLastRefresh` counter for cold-start trigger
- Add 60-minute repeating timer for warm refresh in `start()`
- Pass current `aiEngine.primaryProvider` to `refreshProfile()`

### CloudProvider.swift / OllamaProvider.swift

- Change `systemPrompt` from stored property to method: `func systemPrompt(styleFragment: String?) -> String`
- If styleFragment is non-nil, append it after the main prompt before the "禁止" section
- AIProvider protocol: `analyze(text:context:)` unchanged; style fragment passed at call site

### AIEngine.swift

- `analyze()` accepts optional `styleFragment: String?` parameter
- Passes it through to the provider's prompt assembly

### FloartApp.swift

- Create `StyleProfileManager(directory: archiveDir.deletingLastPathComponent())` 
- Assign to orchestrator

## Testing

Unit test `StyleProfileManagerTests.swift`:
- `testCollectMessagesExtractsMyLines` — verify [我] extraction
- `testCollectMessagesDeduplicates` — same message twice → stored once
- `testFIFOTruncation` — exceed 200 → oldest removed
- `testPromptFragmentFormat` — verify output shape
- `testPromptFragmentNilWhenEmpty` — no data → nil

Integration: manual E2E with Feishu screenshot (same pattern as previous tests).
