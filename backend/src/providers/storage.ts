import { randomBytes } from 'node:crypto';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

export interface StorageProvider {
  id: string;
  put(key: string, data: Buffer, contentType: string): Promise<void>;
  read(key: string): Promise<Buffer>;
  delete(key: string): Promise<void>;
}

/**
 * Development/local storage adapter. Stores objects under a private local
 * directory. Not production storage — an S3-compatible provider plugs in here.
 */
export class LocalStorageProvider implements StorageProvider {
  readonly id = 'local';
  constructor(private readonly baseDir: string) {}

  async put(key: string, data: Buffer, _contentType: string): Promise<void> {
    const path = join(this.baseDir, key);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, data);
  }

  async read(key: string): Promise<Buffer> {
    const { readFile } = await import('node:fs/promises');
    return readFile(join(this.baseDir, key));
  }

  async delete(key: string): Promise<void> {
    await rm(join(this.baseDir, key), { force: true });
  }
}

/** Random private object key (never derived from user input). */
export function generateStorageKey(tenantId: string, extension: string): string {
  const token = randomBytes(24).toString('hex');
  return `tenants/${tenantId}/${token}${extension}`;
}

export interface DetectedType {
  mime: string;
  extension: string;
}

/** Magic-byte detection for allowed document/image types. */
export function detectMime(buffer: Buffer): DetectedType | null {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { mime: 'image/jpeg', extension: '.jpg' };
  }
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return { mime: 'image/png', extension: '.png' };
  }
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return { mime: 'image/webp', extension: '.webp' };
  }
  if (buffer.length >= 5 && buffer.toString('ascii', 0, 5) === '%PDF-') {
    return { mime: 'application/pdf', extension: '.pdf' };
  }
  return null;
}
