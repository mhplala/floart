import { appendFile, mkdir, unlink } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { join, dirname } from 'node:path';
import { promisify } from 'node:util';
import { CONFIG } from './config.ts';
import { Queue } from './queue.ts';

const execFileAsync = promisify(execFile);

const VISION_OCR_BIN = join(import.meta.dirname, '..', 'bin', 'vision_ocr');

const SCENE_PROMPT = `以下是用户屏幕的 OCR 文字提取结果。请根据这些文字内容，用一句话描述用户当前的工作场景（在用什么应用、在做什么）。

只输出一句话场景描述，不要重复 OCR 内容。

OCR 文字：
`;

export async function runVisionOCR(imagePath: string): Promise<string> {
  const { stdout } = await execFileAsync(VISION_OCR_BIN, [imagePath]);
  return stdout.trim();
}

export async function describeScene(ocrText: string): Promise<string> {
  const response = await fetch(`${CONFIG.LLM_BASE_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: CONFIG.VISION_MODEL,
      messages: [{ role: 'user', content: SCENE_PROMPT + ocrText }],
      stream: false,
      think: false,
      options: { num_predict: 200 },
    }),
  });

  if (!response.ok) {
    throw new Error(`LLM API error: ${response.status} ${response.statusText}`);
  }

  const data = await response.json() as { message: { content: string } };
  return data.message.content;
}

export async function appendToRawLog(logPath: string, time: string, content: string): Promise<void> {
  await mkdir(dirname(logPath), { recursive: true });
  const entry = `## ${time}\n\n${content}\n\n---\n\n`;
  await appendFile(logPath, entry, 'utf-8');
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

  // Step 1: Vision OCR for each screen
  const ocrResults: string[] = [];
  for (const imgPath of imagePaths) {
    const text = await runVisionOCR(imgPath);
    ocrResults.push(text);
  }
  const allOCR = ocrResults.join('\n\n--- Screen ---\n\n');

  // Step 2: LLM scene description from OCR text
  const scene = await describeScene(allOCR);

  // Step 3: Write to raw log
  const logEntry = `**场景：** ${scene}\n\n**OCR 内容：**\n${allOCR}`;
  const logPath = join(CONFIG.DATA_DIR, 'raw', `${formatDate(now)}.md`);
  await appendToRawLog(logPath, formatTime(now), logEntry);
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
