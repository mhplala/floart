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
