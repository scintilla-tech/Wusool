import request from 'supertest';
import { describe, it, expect, vi } from 'vitest';
import { createTestApp, mockPrisma } from './helpers';

describe('health endpoints', () => {
  it('GET /health/live returns 200 ok', async () => {
    const app = createTestApp();
    const res = await request(app).get('/health/live');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('GET /health/ready returns 200 when database is up', async () => {
    const app = createTestApp();
    const res = await request(app).get('/health/ready');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', database: 'up' });
  });

  it('GET /health/ready returns 503 when database is down', async () => {
    const prisma = {
      ...mockPrisma(),
      $queryRaw: vi.fn().mockRejectedValue(new Error('connection refused')),
    } as never;
    const app = createTestApp(prisma);
    const res = await request(app).get('/health/ready');
    expect(res.status).toBe(503);
    expect(res.body).toEqual({ status: 'unavailable', database: 'down' });
    expect(JSON.stringify(res.body)).not.toContain('connection refused');
  });
});
