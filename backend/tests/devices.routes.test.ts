import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { createDevicesRouter } from '../src/modules/devices/devices.routes';
import { errorHandler } from '../src/middlewares/errorHandler';
import { createLogger } from '../src/config/logger';
import { signAccessToken } from '../src/utils/token';
import { testEnv } from './helpers';

function buildApp() {
  const upsert = vi.fn().mockResolvedValue({ id: 'device-token-1' });
  const updateMany = vi.fn().mockResolvedValue({ count: 2 });
  const prisma = {
    user: {
      findUnique: vi.fn().mockResolvedValue({
        id: 'user-1',
        tenantId: 'tenant-1',
        role: 'STUDENT',
        isActive: true,
        tenant: { isActive: true },
      }),
    },
    deviceToken: { upsert, updateMany },
  };

  const app = express();
  app.use(express.json());
  app.use(
    '/api/v1/devices',
    createDevicesRouter({ prisma: prisma as unknown as PrismaClient, config: testEnv }),
  );
  app.use(errorHandler(createLogger(testEnv), false));
  return { app, upsert, updateMany };
}

describe('device registration', () => {
  it('uses the provider token as the ownership key so re-registration transfers it', async () => {
    const { app, upsert } = buildApp();
    const accessToken = signAccessToken(
      { sub: 'user-1', type: 'access' },
      testEnv.JWT_ACCESS_SECRET,
      testEnv.JWT_ACCESS_TTL,
    );

    const response = await request(app)
      .post('/api/v1/devices')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ token: 'provider-token-1234567890', platform: 'ANDROID', deviceId: 'phone-1' });

    expect(response.status).toBe(201);
    expect(upsert).toHaveBeenCalledWith({
      where: { token: 'provider-token-1234567890' },
      update: {
        userId: 'user-1',
        tenantId: 'tenant-1',
        platform: 'ANDROID',
        deviceId: 'phone-1',
        isActive: true,
      },
      create: {
        userId: 'user-1',
        tenantId: 'tenant-1',
        token: 'provider-token-1234567890',
        platform: 'ANDROID',
        deviceId: 'phone-1',
      },
    });
  });

  it('deactivates the authenticated user device registrations on logout', async () => {
    const { app, updateMany } = buildApp();
    const accessToken = signAccessToken(
      { sub: 'user-1', type: 'access' },
      testEnv.JWT_ACCESS_SECRET,
      testEnv.JWT_ACCESS_TTL,
    );

    const response = await request(app)
      .delete('/api/v1/devices')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ deviceId: 'phone-1' });

    expect(response.status).toBe(200);
    expect(response.body.data.deactivated).toBe(2);
    expect(updateMany).toHaveBeenCalledWith({
      where: {
        userId: 'user-1',
        isActive: true,
        OR: [{ deviceId: 'phone-1' }, { deviceId: null }],
      },
      data: { isActive: false },
    });
  });

  it('rejects registration without a stable installation identifier', async () => {
    const { app, upsert } = buildApp();
    const accessToken = signAccessToken(
      { sub: 'user-1', type: 'access' },
      testEnv.JWT_ACCESS_SECRET,
      testEnv.JWT_ACCESS_TTL,
    );

    const response = await request(app)
      .post('/api/v1/devices')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ token: 'provider-token-1234567890', platform: 'ANDROID' });

    expect(response.status).toBe(400);
    expect(upsert).not.toHaveBeenCalled();
  });
});
