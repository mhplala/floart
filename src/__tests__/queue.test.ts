import { describe, it, beforeEach, mock } from 'node:test';
import assert from 'node:assert/strict';
import { Queue } from '../queue.ts';

describe('Queue', () => {
  let queue: Queue;

  beforeEach(() => {
    queue = new Queue(3); // max size 3 for testing
  });

  it('enqueues and dequeues in FIFO order', () => {
    queue.enqueue(['a.png']);
    queue.enqueue(['b.png']);
    assert.deepEqual(queue.dequeue(), ['a.png']);
    assert.deepEqual(queue.dequeue(), ['b.png']);
  });

  it('returns undefined when empty', () => {
    assert.equal(queue.dequeue(), undefined);
  });

  it('reports size correctly', () => {
    queue.enqueue(['a.png']);
    queue.enqueue(['b.png']);
    assert.equal(queue.size, 2);
  });

  it('evicts oldest items when exceeding max size and calls onEvict', () => {
    const evicted: string[][] = [];
    queue = new Queue(3, (items) => evicted.push(items));

    queue.enqueue(['1.png']);
    queue.enqueue(['2.png']);
    queue.enqueue(['3.png']);
    queue.enqueue(['4.png']); // should evict ['1.png']

    assert.equal(queue.size, 3);
    assert.deepEqual(evicted, [['1.png']]);
    assert.deepEqual(queue.dequeue(), ['2.png']);
  });
});
