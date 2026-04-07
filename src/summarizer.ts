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

async function callLLM(messages: TextMessage[]): Promise<string> {
  // Use Ollama native API with think:false to disable reasoning mode
  const response = await fetch(`${CONFIG.LLM_BASE_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: CONFIG.SUMMARY_MODEL,
      messages,
      stream: false,
      think: false,
      options: { num_predict: 4096, num_ctx: 131072 },
    }),
  });

  if (!response.ok) {
    throw new Error(`LLM API error: ${response.status} ${response.statusText}`);
  }

  const data = await response.json() as { message: { content: string } };
  return data.message.content;
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
  const summary = await callLLM(messages);

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
