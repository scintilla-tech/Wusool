import { beforeAll, describe, it, expect } from 'vitest';
import { createPrismaClient, getPrismaClient, disconnectPrisma } from '../src/providers/prisma';

describe('database connectivity behavior', () => {
  beforeAll(() => {
    process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/wasl_test?schema=public';
  });

  it('creates a PrismaClient instance without connecting', async () => {
    const prisma = createPrismaClient();
    expect(prisma).toBeDefined();
    expect(typeof prisma.$queryRaw).toBe('function');
    await prisma.$disconnect();
  });

  it('reuses a single PrismaClient per process', async () => {
    const a = getPrismaClient();
    const b = getPrismaClient();
    expect(a).toBe(b);
    await disconnectPrisma();
  });
});
