# Automemory - Screen Memory Service

## Overview

A persistent background service that captures MacBook Pro screenshots every 10 seconds, sends them to a local Gemma model (via Atomic Chat) for text extraction and scene description, and consolidates the results into structured daily memory files every 5 minutes.

**Goal:** Build a personal "work black box" — a continuous record of everything the user works on throughout the day, automatically summarized into readable daily logs.

## Architecture

Single Node.js process with three internal modules coordinated through an in-memory queue.

```
┌─────────────────────────────────────────────────┐
│               Automemory Service                │
│                                                 │
│  Screenshotter ──→ Queue ──→ Extractor          │
│  (10s timer)      (array)   (serial worker)     │
│                                  │              │
│                                  ▼              │
│                           raw log (MD)          │
│                                  │              │
│  Summarizer ◄────────────────────┘              │
│  (5min timer)                                   │
│         │                                       │
│         ▼                                       │
│   daily memory (MD)                             │
└─────────────────────────────────────────────────┘
```

## Technology

- **Language:** TypeScript, run with `tsx`
- **Runtime:** Node.js (built-in modules only, zero external runtime deps)
- **Screenshot:** macOS native `screencapture -x`
- **Screen detection:** `system_profiler SPDisplaysDataType`
- **AI Model:** Gemma 4 via Atomic Chat (`localhost:1337`, OpenAI-compatible API)
- **Dev deps only:** `tsx`, `typescript`

## File Structure

```
Automemory/
├── src/
│   ├── index.ts          # Entry point, starts service
│   ├── screenshotter.ts  # Screenshot capture module
│   ├── queue.ts          # In-memory queue
│   ├── extractor.ts      # Gemma text extraction module
│   ├── summarizer.ts     # Consolidation/summary module
│   └── config.ts         # Configuration constants
├── data/
│   ├── raw/              # Raw extraction logs (per day)
│   │   └── 2026-04-03.md
│   ├── memory/           # Summarized daily memory (per day)
│   │   └── 2026-04-03.md
│   └── tmp/              # Temporary screenshots (deleted after processing)
├── docs/
├── package.json
└── tsconfig.json
```

## Module Details

### Screenshotter (`src/screenshotter.ts`)

- Runs on a 10-second `setInterval`
- Uses `screencapture -x` (silent, no shutter sound) to capture all screens
- At startup, detects screen count via `system_profiler SPDisplaysDataType` to determine how many file paths to pass
- Saves screenshots to `data/tmp/` with timestamp filenames: `{timestamp}-screen{n}.png`
- Pushes the set of screenshot paths as one group into the queue

### Queue (`src/queue.ts`)

- Simple in-memory array; each element is a group of screenshot paths (`string[]`)
- Extractor shifts from the head when idle
- If queue exceeds 30 items (~5 minutes of backlog), drops the oldest entries (deleting their screenshot files) to prevent unbounded growth

### Extractor (`src/extractor.ts`)

- Processes queue items serially (one group at a time)
- For each group: reads all screenshot files, base64-encodes them, sends as a single message to Gemma API
- API call: `POST http://localhost:1337/v1/chat/completions` (OpenAI format)
- Content array includes all screen images + a text prompt
- Prompt: "Please extract all visible text from the screen and briefly describe the current work scene (what applications are in use, what the user is doing). Respond in Chinese."
- Appends Gemma's response to `data/raw/{YYYY-MM-DD}.md` with timestamp header
- Deletes screenshot files after successful extraction
- On API failure: logs warning, leaves screenshots in queue for retry on next cycle

### Raw Log Format (`data/raw/YYYY-MM-DD.md`)

```markdown
## 16:30:05

**屏幕描述：** 用户在 VS Code 中编辑 TypeScript 文件，左侧是文件树，右侧终端运行着 npm test。

**文字内容：**
- src/index.ts - Automemory Service
- Terminal: 3 tests passed
- ...

---

## 16:30:15

...
```

### Summarizer (`src/summarizer.ts`)

- Runs on a 5-minute `setInterval`
- Reads `data/raw/{today}.md` in full
- Sends to Gemma API with prompt: "Below are today's screen records. Please consolidate them into a structured work log organized by time periods, merging duplicate content and retaining key information. Output in Chinese."
- Overwrites `data/memory/{today}.md` with the result
- If raw log is too long for Gemma's context window (16K tokens), takes only the most recent content for incremental summarization and appends to the existing memory file

### Memory Format (`data/memory/YYYY-MM-DD.md`)

```markdown
# 2026-04-03 工作记录

## 16:00 - 16:30
在 VS Code 中开发 Automemory 项目，主要编写 TypeScript 代码。
运行了测试，3 个测试通过。

## 16:30 - 17:00
...
```

## Configuration (`src/config.ts`)

```typescript
export const CONFIG = {
  CAPTURE_INTERVAL: 10_000,       // Screenshot interval: 10s
  SUMMARIZE_INTERVAL: 300_000,    // Summary interval: 5min
  QUEUE_MAX_SIZE: 30,             // Max queue length before dropping
  GEMMA_BASE_URL: 'http://localhost:1337',
  GEMMA_MODEL: 'unsloth/gemma-4-E4B-it-Q4_K_M',
  DATA_DIR: './data',
}
```

## Service Lifecycle

### Startup Sequence

1. Ensure `data/raw/`, `data/memory/`, `data/tmp/` directories exist
2. Detect screen count via `system_profiler`
3. Verify Gemma API reachability (`GET http://localhost:1337/models`)
4. Start Screenshotter timer (10s interval)
5. Start Extractor worker (continuous queue polling)
6. Start Summarizer timer (5min interval)

### Graceful Shutdown (Ctrl+C)

1. Stop all timers
2. Wait for current extraction task to complete (if any)
3. Clean up remaining screenshots in `data/tmp/`

### CLI Interface

- `npm start` or `npx tsx src/index.ts` — start the service
- Future: LaunchAgent for auto-start on boot

## Constraints & Edge Cases

- **Gemma response time:** The 4B model may take 5-15s per screenshot. The queue decouples capture from extraction, so no screenshots are lost.
- **Multiple screens:** Each capture produces N images (one per screen), all sent together as one extraction request.
- **Context window limits:** If the daily raw log exceeds ~16K tokens, the summarizer switches to incremental mode.
- **Disk usage:** Screenshots are deleted immediately after extraction. Only markdown text persists.
- **API unavailability:** Extractor retries on next cycle; screenshots remain in queue. Summarizer simply skips the cycle.
