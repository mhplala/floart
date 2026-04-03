export class Queue {
  private items: string[][] = [];
  private maxSize: number;
  private onEvict?: (items: string[]) => void;

  constructor(maxSize: number, onEvict?: (items: string[]) => void) {
    this.maxSize = maxSize;
    this.onEvict = onEvict;
  }

  enqueue(group: string[]): void {
    this.items.push(group);
    while (this.items.length > this.maxSize) {
      const evicted = this.items.shift()!;
      this.onEvict?.(evicted);
    }
  }

  dequeue(): string[] | undefined {
    return this.items.shift();
  }

  get size(): number {
    return this.items.length;
  }
}
