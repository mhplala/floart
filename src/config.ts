import { resolve } from 'node:path';

export const CONFIG = {
  CAPTURE_INTERVAL: 10_000,
  SUMMARIZE_INTERVAL: 300_000,
  QUEUE_MAX_SIZE: 30,
  GEMMA_BASE_URL: 'http://localhost:11434',
  GEMMA_MODEL: 'qwen3.5:0.8b',
  DATA_DIR: resolve(import.meta.dirname, '..', 'data'),
};
