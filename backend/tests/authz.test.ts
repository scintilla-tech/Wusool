import express from 'express';
import request from 'supertest';
import { describe, it, expect, vi } from 'vitest';
import type { Role } from '@prisma/client';
import { authorize } from '../src/middlewares/authorize';
import { createRateLimiter } from '../src/middlewares/rateLimit';
import { AppError } from '../src/utils/appError';

describe('authorize middleware', () => {
  it('passes through when the role is allowed', () => {
    const next = vi.fn();
    const req = { auth: { userId: 'u1', tenantId: 't1', role: 'UNIVERSITY_ADMIN' as Role } };
    const res = {};
    authorize('UNIVERSITY_ADMIN')(req as never, res as never, next);
    expect(next).toHaveBeenCalledWith();
  });

  it('returns 403 when the role is not allowed', () => {
    const next = vi.fn();
    const req = { auth: { userId: 'u1', tenantId: 't1', role: 'STUDENT' as Role } };
    const res = {};
    authorize('UNIVERSITY_ADMIN')(req as never, res as never, next);
    const err = next.mock.calls[0][0] as AppError;
    expect(err.statusCode).toBe(403);
    expect(err.code).toBe('FORBIDDEN');
  });

  it('returns 401 when not authenticated', () => {
    const next = vi.fn();
    const req = { auth: undefined };
    const res = {};
    authorize('UNIVERSITY_ADMIN')(req as never, res as never, next);
    const err = next.mock.calls[0][0] as AppError;
    expect(err.statusCode).toBe(401);
    expect(err.code).toBe('UNAUTHORIZED');
  });

  it('allows multiple roles', () => {
    const next = vi.fn();
    const req = { auth: { userId: 'u1', tenantId: 't1', role: 'SUPERVISOR' as Role } };
    const res = {};
    authorize('DRIVER', 'SUPERVISOR')(req as never, res as never, next);
    expect(next).toHaveBeenCalledWith();
  });
});

describe('rate limiter middleware', () => {
  it('returns a JSON 429 after the limit is exceeded', async () => {
    const app = express();
    app.use(createRateLimiter({ windowMs: 60_000, limit: 2 }));
    app.get('/', (_req, res) => res.json({ ok: true }));

    await request(app).get('/');
    await request(app).get('/');
    const res = await request(app).get('/');

    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
  });
});
