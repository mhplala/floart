import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, writeFile, readFile, rm } from 'node:fs/promises';
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
    assert.ok(content[0].image_url.url.startsWith('data:image/jpeg;base64,'));
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
