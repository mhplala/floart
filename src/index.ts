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
