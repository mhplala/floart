import { resolve } from 'node:path';

export const CONFIG = {
  CAPTURE_INTERVAL: 10_000,
  SUMMARIZE_INTERVAL: 300_000,
  QUEUE_MAX_SIZE: 30,
  GEMMA_BASE_URL: 'http://localhost:1337',
  GEMMA_MODEL: 'unsloth/gemma-4-E4B-it-Q4_K_M',
  DATA_DIR: resolve(import.meta.dirname, '..', 'data'),
};
