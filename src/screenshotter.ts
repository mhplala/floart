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
  const pngPaths: string[] = [];
  const jpgPaths: string[] = [];
  for (let i = 0; i < screenCount; i++) {
    const png = join(tmpDir, `${timestamp}-screen${i}.png`);
    const jpg = join(tmpDir, `${timestamp}-screen${i}.jpg`);
    pngPaths.push(png);
    jpgPaths.push(jpg);
  }

  await execFileAsync('screencapture', ['-x', ...pngPaths]);

  // Convert to JPEG and resize to reduce payload for the LLM
  for (let i = 0; i < pngPaths.length; i++) {
    await execFileAsync('sips', ['-Z', '1440', '-s', 'format', 'jpeg', '-s', 'formatOptions', '85', pngPaths[i], '--out', jpgPaths[i]]);
    await execFileAsync('rm', [pngPaths[i]]);
  }

  return jpgPaths;
}
