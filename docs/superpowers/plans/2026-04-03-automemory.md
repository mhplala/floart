# Automemory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a persistent background service that captures screenshots every 10s, extracts text via local Gemma model, and consolidates into daily memory files every 5 minutes.

**Architecture:** Single Node.js process with three modules — Screenshotter (timer-based capture), Extractor (serial queue worker), Summarizer (periodic consolidation) — coordinated through an in-memory queue. All AI calls go to Atomic Chat's OpenAI-compatible API at localhost:1337.

**Tech Stack:** TypeScript, Node.js built-in modules only (node:fs/promises, node:child_process, fetch), tsx for dev runtime, macOS screencapture CLI.

---

## File Map

| File | Responsibility |
|------|---------------|
| `package.json` | Project metadata, scripts, dev dependencies |
| `tsconfig.json` | TypeScript config |
| `src/config.ts` | All configuration constants |
| `src/queue.ts` | In-memory queue with max-size eviction |
| `src/screenshotter.ts` | Screen detection + periodic screenshot capture |
| `src/extractor.ts` | Serial queue consumer, Gemma API calls, raw log writing |
| `src/summarizer.ts` | Periodic raw log consolidation into memory files |
| `src/index.ts` | Entry point, wires modules, lifecycle management |
| `src/__tests__/queue.test.ts` | Queue unit tests |
| `src/__tests__/extractor.test.ts` | Extractor unit tests (mocked API) |
| `src/__tests__/summarizer.test.ts` | Summarizer unit tests (mocked API) |

---

### Task 1: Project Scaffolding

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `.gitignore`

- [ ] **Step 1: Initialize package.json**

```json
{
  "name": "automemory",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "start": "tsx src/index.ts",
    "build": "tsc",
    "test": "node --test --experimental-strip-types src/__tests__/*.test.ts"
  },
  "devDependencies": {
    "tsx": "^4",
    "typescript": "^5"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "allowImportingTsExtensions": true,
    "noEmit": true
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create .gitignore**

```
node_modules/
dist/
data/
```

- [ ] **Step 4: Install dependencies**

Run: `cd /Users/stev/Dev/Automemory && npm install`
Expected: `added N packages`

- [ ] **Step 5: Commit**

```bash
git add package.json tsconfig.json .gitignore package-lock.json
git commit -m "chore: scaffold project with tsx and typescript"
```

---

### Task 2: Config Module

**Files:**
- Create: `src/config.ts`

- [ ] **Step 1: Create config.ts**

```typescript
import { resolve } from 'node:path';

export const CONFIG = {
  CAPTURE_INTERVAL: 10_000,
  SUMMARIZE_INTERVAL: 300_000,
  QUEUE_MAX_SIZE: 30,
  GEMMA_BASE_URL: 'http://localhost:1337',
  GEMMA_MODEL: 'unsloth/gemma-4-E4B-it-Q4_K_M',
  DATA_DIR: resolve(import.meta.dirname, '..', 'data'),
};
```

- [ ] **Step 2: Commit**

```bash
git add src/config.ts
git commit -m "feat: add configuration module"
```

---

### Task 3: Queue Module (TDD)

**Files:**
- Create: `src/queue.ts`
- Create: `src/__tests__/queue.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
import { describe, it, beforeEach, mock } from 'node:test';
import assert from 'node:assert/strict';
import { Queue } from '../queue.ts';

describe('Queue', () => {
  let queue: Queue;

  beforeEach(() => {
    queue = new Queue(3); // max size 3 for testing
  });

  it('enqueues and dequeues in FIFO order', () => {
    queue.enqueue(['a.png']);
    queue.enqueue(['b.png']);
    assert.deepEqual(queue.dequeue(), ['a.png']);
    assert.deepEqual(queue.dequeue(), ['b.png']);
  });

  it('returns undefined when empty', () => {
    assert.equal(queue.dequeue(), undefined);
  });

  it('reports size correctly', () => {
    queue.enqueue(['a.png']);
    queue.enqueue(['b.png']);
    assert.equal(queue.size, 2);
  });

  it('evicts oldest items when exceeding max size and calls onEvict', () => {
    const evicted: string[][] = [];
    queue = new Queue(3, (items) => evicted.push(items));

    queue.enqueue(['1.png']);
    queue.enqueue(['2.png']);
    queue.enqueue(['3.png']);
    queue.enqueue(['4.png']); // should evict ['1.png']

    assert.equal(queue.size, 3);
    assert.deepEqual(evicted, [['1.png']]);
    assert.deepEqual(queue.dequeue(), ['2.png']);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/stev/Dev/Automemory && npx tsx --test src/__tests__/queue.test.ts`
Expected: FAIL — cannot find module `../queue.ts`

- [ ] **Step 3: Implement Queue**

```typescript
export class Queue {
  private items: string[][] = [];
  private maxSize: number;
  private onEvict?: (items: string[]) => void;

  constructor(maxSize: number, onEvict?: (items: string[]) => void) {
    this.maxSize = maxSize;
    this.onEvict = onEvict;
  }

  enqueue(group: string[]): void {
    this.items.push(group);
    while (this.items.length > this.maxSize) {
      const evicted = this.items.shift()!;
      this.onEvict?.(evicted);
    }
  }

  dequeue(): string[] | undefined {
    return this.items.shift();
  }

  get size(): number {
    return this.items.length;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/stev/Dev/Automemory && npx tsx --test src/__tests__/queue.test.ts`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/queue.ts src/__tests__/queue.test.ts
git commit -m "feat: add in-memory queue with max-size eviction"
```

---

### Task 4: Screenshotter Module

**Files:**
- Create: `src/screenshotter.ts`

- [ ] **Step 1: Create screenshotter.ts**

```typescript
import { execFile } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { CONFIG } from './config.ts';

const execFileAsync = promisify(execFile);

export async function detectScreenCount(): Promise<number> {
  const { stdout } = await execFileAsync('system_profiler', ['SPDisplaysDataType']);
  const matches = stdout.match(/Resolution:/g);
  return matches ? matches.length : 1;
}

export async function captureScreens(screenCount: number): Promise<string[]> {
  const tmpDir = join(CONFIG.DATA_DIR, 'tmp');
  await mkdir(tmpDir, { recursive: true });

  const timestamp = Date.now();
  const paths: string[] = [];
  for (let i = 0; i < screenCount; i++) {
    paths.push(join(tmpDir, `${timestamp}-screen${i}.png`));
  }

  await execFileAsync('screencapture', ['-x', ...paths]);
  return paths;
}
```

- [ ] **Step 2: Manually test screen detection**

Run: `cd /Users/stev/Dev/Automemory && npx tsx -e "import { detectScreenCount } from './src/screenshotter.ts'; detectScreenCount().then(n => console.log('Screens:', n))"`
Expected: prints `Screens: N` where N matches your actual screen count

- [ ] **Step 3: Manually test screenshot capture**

Run: `cd /Users/stev/Dev/Automemory && mkdir -p data/tmp && npx tsx -e "import { detectScreenCount, captureScreens } from './src/screenshotter.ts'; detectScreenCount().then(n => captureScreens(n)).then(p => console.log('Captured:', p))"`
Expected: prints file paths, verify PNG files exist in `data/tmp/`, then delete them

- [ ] **Step 4: Commit**

```bash
git add src/screenshotter.ts
git commit -m "feat: add screenshotter with multi-display support"
```

---

### Task 5: Extractor Module (TDD)

**Files:**
- Create: `src/extractor.ts`
- Create: `src/__tests__/extractor.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, writeFile, readFile, rm, access } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { buildExtractionPrompt, appendToRawLog } from '../extractor.ts';

describe('buildExtractionPrompt', () => {
  it('creates OpenAI-format message with base64 images and text prompt', async () => {
    const testDir = join(tmpdir(), `automemory-test-${Date.now()}`);
    await mkdir(testDir, { recursive: true });
    // Create a minimal valid PNG (1x1 pixel)
    const pngHeader = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]);
    const testFile = join(testDir, 'test.png');
    await writeFile(testFile, pngHeader);

    const messages = await buildExtractionPrompt([testFile]);

    assert.equal(messages.length, 1);
    const content = messages[0].content;
    assert.ok(Array.isArray(content));
    // Should have 1 image + 1 text
    assert.equal(content.length, 2);
    assert.equal(content[0].type, 'image_url');
    assert.ok(content[0].image_url.url.startsWith('data:image/png;base64,'));
    assert.equal(content[1].type, 'text');
    assert.ok(content[1].text.includes('提取'));

    await rm(testDir, { recursive: true });
  });
});

describe('appendToRawLog', () => {
  it('appends timestamped entry to the daily raw log file', async () => {
    const testDir = join(tmpdir(), `automemory-rawlog-${Date.now()}`);
    await mkdir(testDir, { recursive: true });

    const logPath = join(testDir, '2026-04-03.md');
    await appendToRawLog(logPath, '16:30:05', 'Test extraction content');

    const content = await readFile(logPath, 'utf-8');
    assert.ok(content.includes('## 16:30:05'));
    assert.ok(content.includes('Test extraction content'));
    assert.ok(content.includes('---'));

    // Append again
    await appendToRawLog(logPath, '16:30:15', 'Second entry');
    const content2 = await readFile(logPath, 'utf-8');
    assert.ok(content2.includes('## 16:30:15'));
    assert.ok(content2.includes('Second entry'));

    await rm(testDir, { recursive: true });
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/stev/Dev/Automemory && npx tsx --test src/__tests__/extractor.test.ts`
Expected: FAIL — cannot find module `../extractor.ts`

- [ ] **Step 3: Implement extractor**

```typescript
import { readFile, appendFile, mkdir, unlink } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { CONFIG } from './config.ts';
import { Queue } from './queue.ts';

interface ImageContent {
  type: 'image_url';
  image_url: { url: string };
}

interface TextContent {
  type: 'text';
  text: string;
}

interface Message {
  role: string;
  content: (ImageContent | TextContent)[];
}

const EXTRACT_PROMPT = `请提取屏幕上所有可见的文字内容，并简要描述当前屏幕的工作场景（在用什么应用、在做什么）。

请按以下格式输出：

**屏幕描述：** （描述当前工作场景）

**文字内容：**
（列出所有可见文字）`;

export async function buildExtractionPrompt(imagePaths: string[]): Promise<Message[]> {
  const content: (ImageContent | TextContent)[] = [];

  for (const imgPath of imagePaths) {
    const buf = await readFile(imgPath);
    const base64 = buf.toString('base64');
    content.push({
      type: 'image_url',
      image_url: { url: `data:image/png;base64,${base64}` },
    });
  }

  content.push({ type: 'text', text: EXTRACT_PROMPT });

  return [{ role: 'user', content }];
}

export async function appendToRawLog(logPath: string, time: string, content: string): Promise<void> {
  await mkdir(dirname(logPath), { recursive: true });
  const entry = `## ${time}\n\n${content}\n\n---\n\n`;
  await appendFile(logPath, entry, 'utf-8');
}

async function callGemma(messages: Message[]): Promise<string> {
  const response = await fetch(`${CONFIG.GEMMA_BASE_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: CONFIG.GEMMA_MODEL,
      messages,
      max_tokens: 2048,
    }),
  });

  if (!response.ok) {
    throw new Error(`Gemma API error: ${response.status} ${response.statusText}`);
  }

  const data = await response.json() as { choices: { message: { content: string } }[] };
  return data.choices[0].message.content;
}

function formatTime(date: Date): string {
  return date.toTimeString().slice(0, 8);
}

function formatDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

async function deleteFiles(paths: string[]): Promise<void> {
  for (const p of paths) {
    try {
      await unlink(p);
    } catch {
      // file already deleted, ignore
    }
  }
}

export async function processOneGroup(imagePaths: string[]): Promise<void> {
  const now = new Date();
  const messages = await buildExtractionPrompt(imagePaths);
  const result = await callGemma(messages);

  const logPath = join(CONFIG.DATA_DIR, 'raw', `${formatDate(now)}.md`);
  await appendToRawLog(logPath, formatTime(now), result);
  await deleteFiles(imagePaths);
}

export function startExtractor(queue: Queue): { stop: () => void } {
  let running = true;
  let processing = false;

  async function tick() {
    if (!running || processing) return;

    const group = queue.dequeue();
    if (!group) return;

    processing = true;
    try {
      await processOneGroup(group);
    } catch (err) {
      console.error('[Extractor] Error:', err);
      // Re-enqueue for retry
      queue.enqueue(group);
    } finally {
      processing = false;
    }
  }

  const interval = setInterval(tick, 1000);

  return {
    stop() {
      running = false;
      clearInterval(interval);
    },
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/stev/Dev/Automemory && npx tsx --test src/__tests__/extractor.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/extractor.ts src/__tests__/extractor.test.ts
git commit -m "feat: add extractor module with Gemma API integration"
```

---

### Task 6: Summarizer Module (TDD)

**Files:**
- Create: `src/summarizer.ts`
- Create: `src/__tests__/summarizer.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { shouldSummarize, buildSummaryPrompt } from '../summarizer.ts';

describe('shouldSummarize', () => {
  it('returns false when raw log does not exist', async () => {
    const result = await shouldSummarize('/nonexistent/path/2026-04-03.md');
    assert.equal(result, false);
  });

  it('returns true when raw log exists and has content', async () => {
    const testDir = join(tmpdir(), `automemory-sum-${Date.now()}`);
    await mkdir(testDir, { recursive: true });
    const logPath = join(testDir, '2026-04-03.md');
    await writeFile(logPath, '## 16:00:00\n\nSome content\n\n---\n\n');

    const result = await shouldSummarize(logPath);
    assert.equal(result, true);

    await rm(testDir, { recursive: true });
  });
});

describe('buildSummaryPrompt', () => {
  it('includes raw log content in the prompt', () => {
    const rawContent = '## 16:00:00\n\nSome screen content\n\n---\n\n';
    const messages = buildSummaryPrompt(rawContent);

    assert.equal(messages.length, 1);
    assert.equal(messages[0].role, 'user');
    assert.ok(typeof messages[0].content === 'string');
    assert.ok(messages[0].content.includes('Some screen content'));
    assert.ok(messages[0].content.includes('汇总'));
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/stev/Dev/Automemory && npx tsx --test src/__tests__/summarizer.test.ts`
Expected: FAIL — cannot find module `../summarizer.ts`

- [ ] **Step 3: Implement summarizer**

```typescript
import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { CONFIG } from './config.ts';

interface TextMessage {
  role: string;
  content: string;
}

const SUMMARY_PROMPT_TEMPLATE = `以下是今天的屏幕记录。请按时间段汇总整理成结构化的工作记录。要求：
1. 按时间段分组（如 16:00 - 16:30）
2. 合并重复内容
3. 保留关键信息（在做什么、用什么工具、重要的文字内容）
4. 用中文输出

格式：
# {日期} 工作记录

## HH:MM - HH:MM
工作内容描述...

---

屏幕记录如下：

`;

export async function shouldSummarize(rawLogPath: string): Promise<boolean> {
  try {
    await access(rawLogPath);
    const content = await readFile(rawLogPath, 'utf-8');
    return content.trim().length > 0;
  } catch {
    return false;
  }
}

export function buildSummaryPrompt(rawContent: string): TextMessage[] {
  return [
    {
      role: 'user',
      content: SUMMARY_PROMPT_TEMPLATE + rawContent,
    },
  ];
}

async function callGemma(messages: TextMessage[]): Promise<string> {
  const response = await fetch(`${CONFIG.GEMMA_BASE_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: CONFIG.GEMMA_MODEL,
      messages,
      max_tokens: 4096,
    }),
  });

  if (!response.ok) {
    throw new Error(`Gemma API error: ${response.status} ${response.statusText}`);
  }

  const data = await response.json() as { choices: { message: { content: string } }[] };
  return data.choices[0].message.content;
}

function formatDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

// Rough token estimate: ~4 chars per token for mixed CJK/English
const MAX_RAW_CHARS = 16_000 * 4;

export async function summarize(): Promise<void> {
  const today = formatDate(new Date());
  const rawPath = join(CONFIG.DATA_DIR, 'raw', `${today}.md`);
  const memoryPath = join(CONFIG.DATA_DIR, 'memory', `${today}.md`);

  if (!(await shouldSummarize(rawPath))) {
    return;
  }

  let rawContent = await readFile(rawPath, 'utf-8');

  // If raw log is too large, only take the tail for incremental summary
  if (rawContent.length > MAX_RAW_CHARS) {
    rawContent = rawContent.slice(-MAX_RAW_CHARS);
    // Find the first complete entry boundary
    const firstEntry = rawContent.indexOf('\n## ');
    if (firstEntry > 0) {
      rawContent = rawContent.slice(firstEntry + 1);
    }
  }

  const messages = buildSummaryPrompt(rawContent);
  const summary = await callGemma(messages);

  await mkdir(dirname(memoryPath), { recursive: true });
  await writeFile(memoryPath, summary, 'utf-8');
  console.log(`[Summarizer] Updated memory: ${memoryPath}`);
}

export function startSummarizer(): { stop: () => void } {
  const interval = setInterval(async () => {
    try {
      await summarize();
    } catch (err) {
      console.error('[Summarizer] Error:', err);
    }
  }, CONFIG.SUMMARIZE_INTERVAL);

  // Run once immediately on start
  summarize().catch((err) => console.error('[Summarizer] Initial run error:', err));

  return {
    stop() {
      clearInterval(interval);
    },
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/stev/Dev/Automemory && npx tsx --test src/__tests__/summarizer.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/summarizer.ts src/__tests__/summarizer.test.ts
git commit -m "feat: add summarizer module with incremental support"
```

---

### Task 7: Entry Point — Wire Everything Together

**Files:**
- Create: `src/index.ts`

- [ ] **Step 1: Create index.ts**

```typescript
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { CONFIG } from './config.ts';
import { Queue } from './queue.ts';
import { detectScreenCount, captureScreens } from './screenshotter.ts';
import { startExtractor } from './extractor.ts';
import { startSummarizer } from './summarizer.ts';

async function ensureDataDirs(): Promise<void> {
  const dirs = ['raw', 'memory', 'tmp'].map((d) => join(CONFIG.DATA_DIR, d));
  for (const dir of dirs) {
    await mkdir(dir, { recursive: true });
  }
}

async function checkGemmaApi(): Promise<void> {
  const res = await fetch(`${CONFIG.GEMMA_BASE_URL}/models`);
  if (!res.ok) {
    throw new Error(`Gemma API not reachable: ${res.status}`);
  }
  console.log('[Automemory] Gemma API connected');
}

async function main(): Promise<void> {
  console.log('[Automemory] Starting...');

  await ensureDataDirs();
  await checkGemmaApi();

  const screenCount = await detectScreenCount();
  console.log(`[Automemory] Detected ${screenCount} screen(s)`);

  // Queue with eviction that deletes orphaned screenshot files
  const queue = new Queue(CONFIG.QUEUE_MAX_SIZE, async (evicted) => {
    for (const path of evicted) {
      try {
        const { unlink } = await import('node:fs/promises');
        await unlink(path);
      } catch { /* ignore */ }
    }
  });

  // Start extractor (polls queue every 1s)
  const extractor = startExtractor(queue);
  console.log('[Automemory] Extractor started');

  // Start summarizer (runs every 5min)
  const summarizer = startSummarizer();
  console.log('[Automemory] Summarizer started');

  // Start screenshotter (captures every 10s)
  const screenshotTimer = setInterval(async () => {
    try {
      const paths = await captureScreens(screenCount);
      queue.enqueue(paths);
    } catch (err) {
      console.error('[Screenshotter] Error:', err);
    }
  }, CONFIG.CAPTURE_INTERVAL);

  // Capture immediately on start
  try {
    const paths = await captureScreens(screenCount);
    queue.enqueue(paths);
    console.log('[Automemory] First capture done');
  } catch (err) {
    console.error('[Screenshotter] Initial capture error:', err);
  }

  console.log('[Automemory] Running. Press Ctrl+C to stop.');

  // Graceful shutdown
  const shutdown = () => {
    console.log('\n[Automemory] Shutting down...');
    clearInterval(screenshotTimer);
    extractor.stop();
    summarizer.stop();
    console.log('[Automemory] Stopped.');
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('[Automemory] Fatal error:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Commit**

```bash
git add src/index.ts
git commit -m "feat: add entry point wiring all modules together"
```

---

### Task 8: End-to-End Manual Test

- [ ] **Step 1: Ensure Atomic Chat is running with Gemma loaded**

Run: `curl -s http://localhost:1337/models | head -c 200`
Expected: JSON response containing model info

- [ ] **Step 2: Start the service**

Run: `cd /Users/stev/Dev/Automemory && npm start`
Expected output:
```
[Automemory] Starting...
[Automemory] Gemma API connected
[Automemory] Detected N screen(s)
[Automemory] Extractor started
[Automemory] Summarizer started
[Automemory] First capture done
[Automemory] Running. Press Ctrl+C to stop.
```

- [ ] **Step 3: Wait ~30 seconds, then check raw log**

Run (in another terminal): `ls data/raw/ && head -50 data/raw/$(date +%Y-%m-%d).md`
Expected: A markdown file with timestamped entries containing screen descriptions and extracted text in Chinese

- [ ] **Step 4: Verify screenshots are cleaned up**

Run: `ls data/tmp/`
Expected: Empty or only the most recently captured files (not yet processed)

- [ ] **Step 5: Stop with Ctrl+C, verify clean shutdown**

Expected:
```
[Automemory] Shutting down...
[Automemory] Stopped.
```

- [ ] **Step 6: Commit any adjustments from manual testing**

```bash
git add -A
git commit -m "fix: adjustments from end-to-end testing"
```
