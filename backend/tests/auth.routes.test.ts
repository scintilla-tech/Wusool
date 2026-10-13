import express from 'express';
import request from 'supertest';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { createAuthRouter } from '../src/modules/auth/auth.routes';
import { errorHandler } from '../src/middlewares/errorHandler';
import { createLogger } from '../src/config/logger';
import { hashPassword } from '../src/utils/password';
import { signAccessToken } from '../src/utils/token';
import { testEnv } from './helpers';

const PASSWORD = 'correct-horse-battery-staple';

const mockUser = {
  id: 'u1',
  tenantId: 't1',
  role: 'STUDENT' as const,
  firstName: 'Noor',
  lastName: 'Ali',
  email: null,
  phone: '+966551234567',
  isActive: true,
  tenant: { isActive: true },
};

function makePrisma(overrides: Record<string, unknown> = {}) {
  const refreshSession = {
    findUnique: vi.fn().mockResolvedValue(null),
    create: vi.fn().mockImplementation(async (args: { data: unknown }) => args.data),
    update: vi.fn().mockImplementation(async (args: { data: unknown }) => args.data),
    updateMany: vi.fn().mockResolvedValue({ count: 1 }),
  };
  const deviceToken = { updateMany: vi.fn().mockResolvedValue({ count: 1 }) };
  return {
    tenant: { findUnique: vi.fn().mockResolvedValue({ id: 't1', code: 'KSU', isActive: true }) },
    user: { findUnique: vi.fn().mockResolvedValue(mockUser) },
    refreshSession,
    deviceToken,
    $transaction: vi.fn(async (input: unknown) => {
      if (typeof input === 'function') return input({ refreshSession });
      return Promise.all(input as unknown[]);
    }),
    ...overrides,
  };
}

async function buildApp(prisma: ReturnType<typeof makePrisma>) {
  const app = express();
  app.use(express.json());
  app.use(
    '/api/v1/auth',
    createAuthRouter({ prisma: prisma as unknown as PrismaClient, config: testEnv }),
  );
  app.use(errorHandler(createLogger(testEnv), false));
  return app;
}

describe('auth routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /auth/login', () => {
    it('returns tokens and a safe user DTO for valid credentials', async () => {
      const passwordHash = await hashPassword(PASSWORD);
      const prisma = makePrisma();
      prisma.user.findUnique.mockResolvedValue({ ...mockUser, passwordHash });

      const app = await buildApp(prisma);
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ tenantCode: 'KSU', phone: '0551234567', password: PASSWORD });

      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeTruthy();
      expect(res.body.data.refreshToken).toBeTruthy();
      expect(res.body.data.user.id).toBe('u1');
      expect(res.body.data.user).not.toHaveProperty('passwordHash');
      expect(res.body.data.user).not.toHaveProperty('nationalIdOrIqama');

      // user lookup used the normalized phone + tenant
      expect(prisma.user.findUnique).toHaveBeenCalledWith({
        where: { tenantId_phone: { tenantId: 't1', phone: '+966551234567' } },
      });

      // refresh token stored only as a hash
      const createCall = prisma.refreshSession.create.mock.calls[0][0];
      expect(createCall.data.tokenHash).toMatch(/^[0-9a-f]{64}$/);
      expect(createCall.data.tokenHash).not.toBe(res.body.data.refreshToken);
    });

    it('returns 401 for a wrong password', async () => {
      const passwordHash = await hashPassword('a-different-password');
      const prisma = makePrisma();
      prisma.user.findUnique.mockResolvedValue({ ...mockUser, passwordHash });

      const app = await buildApp(prisma);
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ tenantCode: 'KSU', phone: '0551234567', password: PASSWORD });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
    });

    it('returns 401 (generic) for an unknown tenant or user', async () => {
      const prisma = makePrisma();
      prisma.tenant.findUnique.mockResolvedValue(null);
      prisma.user.findUnique.mockResolvedValue(null);

      const app = await buildApp(prisma);
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ tenantCode: 'NOPE', phone: '0551234567', password: PASSWORD });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
    });

    it('returns 400 for a malformed body (extra property rejected)', async () => {
      const app = await buildApp(makePrisma());
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ tenantCode: 'KSU', phone: '0551234567', password: PASSWORD, role: 'STUDENT' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 for a missing body', async () => {
      const app = await buildApp(makePrisma());
      const res = await request(app).post('/api/v1/auth/login').send({});
      expect(res.status).toBe(400);
    });
  });

  describe('GET /auth/me', () => {
    it('returns 401 without a token', async () => {
      const app = await buildApp(makePrisma());
      const res = await request(app).get('/api/v1/auth/me');
      expect(res.status).toBe(401);
    });

    it('returns the user DTO with a valid token', async () => {
      const prisma = makePrisma();
      const app = await buildApp(prisma);
      const token = signAccessToken(
        { sub: 'u1', type: 'access' },
        testEnv.JWT_ACCESS_SECRET,
        '15m',
      );

      const res = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe('u1');
      expect(res.body.data.role).toBe('STUDENT');
      expect(res.body.data).not.toHaveProperty('passwordHash');
    });

    it('returns 401 for an inactive user', async () => {
      const prisma = makePrisma();
      prisma.user.findUnique.mockResolvedValue({ ...mockUser, isActive: false });
      const app = await buildApp(prisma);
      const token = signAccessToken(
        { sub: 'u1', type: 'access' },
        testEnv.JWT_ACCESS_SECRET,
        '15m',
      );

      const res = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(401);
    });

    it('returns 401 when the authenticated user tenant has been disabled', async () => {
      const prisma = makePrisma();
      prisma.user.findUnique.mockResolvedValue({
        ...mockUser,
        tenant: { isActive: false },
      });
      const app = await buildApp(prisma);
      const token = signAccessToken(
        { sub: 'u1', type: 'access' },
        testEnv.JWT_ACCESS_SECRET,
        '15m',
      );

      const res = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(401);
    });
  });

  describe('POST /auth/refresh', () => {
    it('rejects and revokes sessions when the tenant has been disabled', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 60_000),
        revokedAt: null,
      });
      prisma.user.findUnique.mockResolvedValue({
        ...mockUser,
        tenant: { isActive: false },
      });

      const app = await buildApp(prisma);
      const response = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: 'a'.repeat(64) });

      expect(response.status).toBe(401);
      expect(response.body.error.code).toBe('INVALID_REFRESH_TOKEN');
      expect(prisma.refreshSession.updateMany).toHaveBeenCalledWith({
        where: { userId: 'u1', revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
    });

    const refreshToken = 'refresh-token-value-123456';

    it('rotates the refresh session and returns new tokens', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 86_400_000),
        revokedAt: null,
      });

      const app = await buildApp(prisma);
      const res = await request(app).post('/api/v1/auth/refresh').send({ refreshToken });

      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeTruthy();
      expect(res.body.data.refreshToken).toBeTruthy();

      expect(prisma.refreshSession.updateMany).toHaveBeenCalledWith({
        where: { id: 's1', revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
      expect(prisma.refreshSession.create).toHaveBeenCalled();
    });

    it('revokes all sessions and returns 401 when a concurrent rotation wins', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 86_400_000),
        revokedAt: null,
      });
      prisma.refreshSession.updateMany.mockResolvedValue({ count: 0 });

      const app = await buildApp(prisma);
      const res = await request(app).post('/api/v1/auth/refresh').send({ refreshToken });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('REFRESH_TOKEN_REUSED');
      expect(prisma.refreshSession.updateMany).toHaveBeenCalled();
    });

    it('returns 401 for an unknown refresh token', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue(null);

      const app = await buildApp(prisma);
      const res = await request(app).post('/api/v1/auth/refresh').send({ refreshToken });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('INVALID_REFRESH_TOKEN');
    });

    it('revokes all sessions and returns 401 on token reuse', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 86_400_000),
        revokedAt: new Date(),
      });

      const app = await buildApp(prisma);
      const res = await request(app).post('/api/v1/auth/refresh').send({ refreshToken });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('REFRESH_TOKEN_REUSED');
      expect(prisma.refreshSession.updateMany).toHaveBeenCalled();
    });
  });

  describe('POST /auth/logout', () => {
    it('revokes the session and returns 200', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 86_400_000),
        revokedAt: null,
      });

      const app = await buildApp(prisma);
      const res = await request(app)
        .post('/api/v1/auth/logout')
        .send({ refreshToken: 'refresh-token-value-123456' });
      expect(res.status).toBe(200);
      expect(prisma.refreshSession.update).toHaveBeenCalledWith({
        where: { id: 's1' },
        data: { revokedAt: expect.any(Date) },
      });
    });

    it('is idempotent for an unknown token', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue(null);

      const app = await buildApp(prisma);
      const res = await request(app)
        .post('/api/v1/auth/logout')
        .send({ refreshToken: 'refresh-token-value-123456' });
      expect(res.status).toBe(200);
    });

    it('atomically revokes the session and current installation push token', async () => {
      const prisma = makePrisma();
      prisma.refreshSession.findUnique.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        tokenHash: 'hash',
        expiresAt: new Date(Date.now() + 86_400_000),
        revokedAt: null,
      });

      const app = await buildApp(prisma);
      const res = await request(app).post('/api/v1/auth/logout').send({
        refreshToken: 'refresh-token-value-123456',
        deviceId: 'phone-1',
      });

      expect(res.status).toBe(200);
      expect(prisma.$transaction).toHaveBeenCalled();
      expect(prisma.deviceToken.updateMany).toHaveBeenCalledWith({
        where: {
          userId: 'u1',
          isActive: true,
          OR: [{ deviceId: 'phone-1' }, { deviceId: null }],
        },
        data: { isActive: false },
      });
    });
  });

  describe('POST /auth/logout-all', () => {
    it('requires authentication', async () => {
      const app = await buildApp(makePrisma());
      const res = await request(app).post('/api/v1/auth/logout-all');
      expect(res.status).toBe(401);
    });

    it('revokes every active refresh session for the authenticated user', async () => {
      const prisma = makePrisma();
      const app = await buildApp(prisma);
      const token = signAccessToken(
        { sub: 'u1', type: 'access' },
        testEnv.JWT_ACCESS_SECRET,
        '15m',
      );
      const res = await request(app)
        .post('/api/v1/auth/logout-all')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(prisma.refreshSession.updateMany).toHaveBeenCalledWith({
        where: { userId: 'u1', revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
    });
  });
});
