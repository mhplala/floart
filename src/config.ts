import { resolve } from 'node:path';

export const CONFIG = {
  CAPTURE_INTERVAL: 10_000,
  SUMMARIZE_INTERVAL: 90_000,
  QUEUE_MAX_SIZE: 30,
  LLM_BASE_URL: 'http://localhost:11434',
  VISION_MODEL: 'gemma4:e4b',
  SUMMARY_MODEL: 'gemma4:e4b',
  DATA_DIR: resolve(import.meta.dirname, '..', 'data'),
};
