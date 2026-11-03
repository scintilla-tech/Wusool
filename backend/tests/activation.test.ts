import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { createTestApp } from './helpers';
import { ActivationService } from '../src/modules/auth/activation.service';
import { AuthService } from '../src/modules/auth/auth.service';
import { OtpService } from '../src/modules/otp/otp.service';
import type { OtpProvider } from '../src/providers/otp';

const newDriver = {
  id: 'driver1',
  tenantId: 'tenant1',
  role: 'DRIVER',
  firstName: 'Khalid',
  lastName: 'Saleh',
  email: null,
  phone: '+966500000301',
  passwordHash: null as string | null,
  isActive: true,
};

function setup(user: typeof newDriver | null = newDriver) {
  const sent: Array<{ to: string; code: string }> = [];
  const provider: OtpProvider = {
    send: async (to, code) => {
      sent.push({ to, code });
    },
  };
  const tx = {
    user: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
  };
  const prisma = {
    tenant: { findUnique: vi.fn().mockResolvedValue({ id: 'tenant1', isActive: true }) },
    user: { findUnique: vi.fn().mockResolvedValue(user) },
    refreshSession: { create: vi.fn().mockResolvedValue({}) },
    $transaction: vi.fn(async (fn: (client: typeof tx) => unknown) => fn(tx)),
  } as unknown as PrismaClient;
  const auth = new AuthService(prisma, {
    accessSecret: 'test-access-secret-0123456789abcdefghij',
    accessTtl: '15m',
    refreshTtl: '30d',
  });
  const service = new ActivationService(prisma, new OtpService(provider), auth, false);
  return { service, sent, tx };
}

describe('first sign-in with a one-time code', () => {
  it('texts a code to the phone of an account that has no password yet', async () => {
    const { service, sent } = setup();

    expect(await service.request('KKU', '+966500000301')).toEqual({});
    expect(sent).toHaveLength(1);
    expect(sent[0].to).toBe('+966500000301');
    expect(sent[0].code).toMatch(/^\d{6}$/);
  });

  it('sets the password and signs the person in when the code matches', async () => {
    const { service, sent, tx } = setup();
    await service.request('KKU', '+966500000301');

    const session = await service.complete('KKU', '+966500000301', sent[0].code, 'new-pass-123');

    expect(session.accessToken).toBeTruthy();
    expect(session.user).toMatchObject({ id: 'driver1', role: 'DRIVER' });
    expect(session.user).not.toHaveProperty('passwordHash');
    const update = tx.user.updateMany.mock.calls[0][0];
    expect(update.where).toEqual({ id: 'driver1', passwordHash: null });
    expect(update.data.passwordHash).toMatch(/^\$argon2id\$/);
    expect(tx.auditLog.create.mock.calls[0][0].data.action).toBe('ACCOUNT_ACTIVATED');
  });

  it('rejects a wrong code', async () => {
    const { service } = setup();
    await service.request('KKU', '+966500000301');

    await expect(
      service.complete('KKU', '+966500000301', '000000', 'new-pass-123'),
    ).rejects.toMatchObject({ statusCode: 400, code: 'INVALID_CODE' });
  });

  it('sends nothing for accounts that already have a password, are disabled, or do not exist', async () => {
    for (const user of [
      { ...newDriver, passwordHash: '$argon2id$existing' },
      { ...newDriver, isActive: false },
      null,
    ]) {
      const { service, sent } = setup(user);
      expect(await service.request('KKU', '+966500000301')).toEqual({});
      expect(sent).toEqual([]);
    }
  });

  it('lets only one of two racing completions set the password', async () => {
    const { service, sent, tx } = setup();
    await service.request('KKU', '+966500000301');
    tx.user.updateMany.mockResolvedValueOnce({ count: 0 });

    await expect(
      service.complete('KKU', '+966500000301', sent[0].code, 'new-pass-123'),
    ).rejects.toMatchObject({ code: 'INVALID_CODE' });
  });
});

describe('activation endpoints', () => {
  it('answers the same whether or not the phone has an account', async () => {
    const prisma = {
      tenant: { findUnique: vi.fn().mockResolvedValue(null) },
    } as unknown as PrismaClient;

    const response = await request(createTestApp(prisma))
      .post('/api/v1/auth/activation/request')
      .send({ tenantCode: 'KKU', phone: '0500000301' });

    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({ sent: true });
  });

  it('requires a six-digit code and a password of at least 8 characters', async () => {
    const response = await request(createTestApp())
      .post('/api/v1/auth/activation/complete')
      .send({ tenantCode: 'KKU', phone: '0500000301', code: '12', password: 'short' });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});
