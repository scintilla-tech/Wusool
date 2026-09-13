import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { detectMime, generateStorageKey, type StorageProvider } from '../../providers/storage';

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_DOC_BYTES = 10 * 1024 * 1024;

export class DocumentsService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly storage: StorageProvider,
  ) {}

  async upload(tenantId: string, userId: string, buffer: Buffer, documentType: string) {
    const detected = detectMime(buffer);
    if (!detected) {
      throw new AppError(415, 'UNSUPPORTED_TYPE', 'Unsupported file type');
    }
    const maxBytes = detected.mime.startsWith('image/') ? MAX_IMAGE_BYTES : MAX_DOC_BYTES;
    if (buffer.length > maxBytes) {
      throw new AppError(413, 'FILE_TOO_LARGE', 'File too large');
    }

    const key = generateStorageKey(tenantId, detected.extension);
    await this.storage.put(key, buffer, detected.mime);

    // Never return documentKey (private storage key).
    return this.prisma.userDocument.create({
      data: { tenantId, userId, documentType, documentKey: key, mimeType: detected.mime },
      select: { id: true, documentType: true, mimeType: true, createdAt: true },
    });
  }

  async getSignedUrl(tenantId: string, userId: string, role: string, id: string) {
    const doc = await this.findAuthorized(tenantId, userId, role, id);
    return { url: `/api/v1/documents/${doc.id}/file`, expiresIn: 300 };
  }

  async readAuthorized(tenantId: string, userId: string, role: string, id: string) {
    const doc = await this.findAuthorized(tenantId, userId, role, id);
    const buffer = await this.storage.read(doc.documentKey);
    return { mimeType: doc.mimeType, buffer };
  }

  private async findAuthorized(tenantId: string, userId: string, role: string, id: string) {
    const doc = await this.prisma.userDocument.findFirst({ where: { id, tenantId } });
    if (!doc) throw new AppError(404, 'NOT_FOUND', 'Document not found');
    const privileged = role === 'UNIVERSITY_ADMIN' || role === 'PLATFORM_SUPER_ADMIN';
    if (doc.userId !== userId && !privileged) {
      throw new AppError(403, 'FORBIDDEN', 'Not allowed');
    }
    return doc;
  }
}
