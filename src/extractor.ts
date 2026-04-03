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
