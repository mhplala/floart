# Conversation History — Design Spec

## Goal

Maintain per-conversation message history so that when the user switches back to a chat, the AI has full context of what was previously discussed, not just the current screen.

## Data Flow

```
OCR (with [我]/[对方] tags)
        ↓
  Extract chat title from top of screen → conversation key (e.g. "飞书:胡冰冰")
        ↓
  ConversationHistoryManager.addMessages(key, messages)
        ↓
  Dedup against last 20 stored messages (exact + similarity > 0.85)
        ↓
  Append to conversations/{key}.txt (max 200 lines FIFO)
        ↓
  Every 15 new messages → AI distills summary → {key}_summary.txt
        ↓
  promptFragment(key) → summary + last 10 messages → injected into AI prompt
```

## New File: `Floart/Services/ConversationHistoryManager.swift`

### Storage

Location: `~/Application Support/Floart/conversations/`

| File | Content | Size cap |
|------|---------|----------|
| `{safe_key}.txt` | Raw messages, one per line, prefixed with `[我]`/`[对方]` | 200 lines FIFO |
| `{safe_key}_summary.txt` | AI-distilled conversation summary | Overwritten each refresh |

`safe_key`: conversation key with `/`, `:`, spaces replaced by `_` for filesystem safety.

### Fuzzy Key Matching

OCR may misread chat titles (e.g. "胡冰冰" → "胡冰水"). To avoid creating duplicate conversation files:

1. When a new key arrives, split into `app` + `title` parts
2. Scan existing keys with the same `app` prefix
3. Compare `title` portion using TextSimilarity
4. If similarity > 0.7, map to the existing key (use the older/established one)
5. Cache the mapping in memory: `["飞书:胡冰水": "飞书:胡冰冰"]`

This keeps conversation history continuous even with OCR variance on names.

### Interface

```swift
final class ConversationHistoryManager: @unchecked Sendable {
    init(directory: URL)

    /// Resolve a raw OCR key to canonical key (fuzzy matching existing keys).
    func resolveKey(_ rawKey: String) -> String

    /// Add new messages for a conversation. Returns count of new (non-duplicate) messages added.
    func addMessages(_ messages: [String], forConversation key: String) -> Int

    /// Distill conversation summary using AI.
    func refreshSummary(forConversation key: String, using provider: AIProvider) async

    /// Return prompt fragment (summary + recent messages) or nil if no history.
    func promptFragment(forConversation key: String) -> String?

    /// Whether a summary exists for this conversation.
    func hasSummary(forConversation key: String) -> Bool

    /// Track new messages for summary refresh trigger.
    var newMessageCounts: [String: Int]  // key → count since last refresh
}
```

### Conversation Key Extraction

The chat title appears at the top of the screen. Currently the top 10% (cy > 0.90) is skipped in OCR.

Approach: In `InsightOrchestrator`, after OCR, extract the conversation title:
1. From the OCR blocks, find text in the top region (cy > 0.88, cy < 0.95) in the center zone (cx 0.25–0.75)
2. Take the first short text block (< 30 chars) — this is typically the chat name
3. Combine with frontmost app name: `"{appName}:{title}"`

Fallback: if no title found, use `"{appName}:unknown"`.

### addMessages Logic

1. Parse input: keep lines starting with `[我] ` or `[对方] `
2. Load last 20 lines from `{key}.txt`
3. For each new message, check against last 20:
   - Exact match → skip
   - TextSimilarity > 0.85 → skip (OCR variance of same message)
4. Append surviving messages to file
5. FIFO: if exceeds 200 lines, trim from top

### refreshSummary Logic

1. Read all messages from `{key}.txt`
2. If < 5 messages, skip
3. Send to AI with prompt:
   ```
   以下是一个即时通讯会话的消息记录。[我]是用户发的，[对方]是对方发的。
   请用2-3句话总结这个对话目前在讨论什么话题、双方的立场和进展。
   只输出总结，不要分析。用中文，100字以内。
   ```
4. If existing summary exists, include it as context:
   ```
   上一次的总结：{old_summary}
   
   新增消息：
   {new_messages}
   
   请更新总结。
   ```
5. Write result to `{key}_summary.txt`

### promptFragment Logic

1. Read `{key}_summary.txt` → summary
2. Read `{key}.txt` → take last 10 lines → recent messages
3. If both empty, return nil
4. Format:
   ```
   当前会话历史（与{title}的对话）：
   {summary}

   最近的消息：
   {messages}
   ```

### Summary Refresh Trigger

- Every 15 new messages added to a conversation → trigger refresh
- Tracked via in-memory `newMessageCounts` dict
- Reset count after refresh

## Changes to Existing Files

### OCREngine.swift

- Widen top skip threshold from 0.90 to 0.92, expose blocks in 0.88-0.92 range via a new method or return them separately for title extraction
- OR: add a separate static method `extractChatTitle(from blocks, in image)` that scans the top region

### InsightOrchestrator.swift

- Add `var conversationHistoryManager: ConversationHistoryManager?`
- After OCR, extract chat title → conversation key
- Call `addMessages` with [我]/[对方] lines
- Check `newMessageCounts` for summary refresh trigger
- Pass `conversationHistoryManager?.promptFragment(key)` to AI analysis

### AIEngine.swift

- `analyze()` accepts optional `conversationFragment: String?` in addition to `styleFragment`
- Both fragments appended to system prompt

### CloudProvider.swift / OllamaProvider.swift

- `systemPrompt(styleFragment:)` → `systemPrompt(styleFragment:, conversationFragment:)`
- Append conversation fragment after style fragment

### FloartApp.swift

- Create `ConversationHistoryManager` alongside `StyleProfileManager`
- Assign to orchestrator

## Interaction with StyleProfileManager

- StyleProfileManager: collects ALL [我] messages across ALL conversations → global style
- ConversationHistoryManager: collects [我]+[对方] messages PER conversation → local context
- Both produce prompt fragments, both injected into system prompt
- No conflict: style is about HOW the user talks, conversation is about WHAT is being discussed
