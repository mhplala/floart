import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { shouldSummarize, buildSummaryPrompt } from '../summarizer.ts';

describe('shouldSummarize', () => {
  it('returns false when raw log does not exist', async () => {
    const result = await shouldSummarize('/nonexistent/path/2026-04-03.md');
    assert.equal(result, false);
  });

  it('returns true when raw log exists and has content', async () => {
    const testDir = join(tmpdir(), `automemory-sum-${Date.now()}`);
    await mkdir(testDir, { recursive: true });
    const logPath = join(testDir, '2026-04-03.md');
    await writeFile(logPath, '## 16:00:00\n\nSome content\n\n---\n\n');

    const result = await shouldSummarize(logPath);
    assert.equal(result, true);

    await rm(testDir, { recursive: true });
  });
});

describe('buildSummaryPrompt', () => {
  it('includes raw log content in the prompt', () => {
    const rawContent = '## 16:00:00\n\nSome screen content\n\n---\n\n';
    const messages = buildSummaryPrompt(rawContent);

    assert.equal(messages.length, 1);
    assert.equal(messages[0].role, 'user');
    assert.ok(typeof messages[0].content === 'string');
    assert.ok(messages[0].content.includes('Some screen content'));
    assert.ok(messages[0].content.includes('汇总'));
  });
});
