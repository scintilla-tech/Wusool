import express from 'express';
import request from 'supertest';
import { describe, it, expect } from 'vitest';
import { z } from 'zod';
import { errorHandler, notFoundHandler } from '../src/middlewares/errorHandler';
import { AppError } from '../src/utils/appError';
import { createLogger } from '../src/config/logger';
import { testEnv } from './helpers';

describe('centralized error handling', () => {
  it('notFoundHandler returns 404 JSON for unknown routes', async () => {
    const app = express();
    app.use(notFoundHandler);
    const res = await request(app).get('/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('errorHandler maps AppError to its status and code', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new AppError(418, 'TEAPOT', 'I am a teapot');
    });
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app).get('/boom');
    expect(res.status).toBe(418);
    expect(res.body.error.code).toBe('TEAPOT');
  });

  it('keeps the code of an AppError whose status a body parser also uses', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new AppError(415, 'UNSUPPORTED_FILE', 'Upload an Excel or CSV file');
    });
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app).get('/boom');
    expect(res.status).toBe(415);
    expect(res.body.error.code).toBe('UNSUPPORTED_FILE');
  });

  it('errorHandler masks internal errors and never leaks stack traces', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new Error('secret postgresql://user:pass@host/db connection string');
    });
    app.use(errorHandler(createLogger(testEnv), true));
    const res = await request(app).get('/boom');
    expect(res.status).toBe(500);
    expect(res.body.error.message).toBe('Internal server error');
    expect(JSON.stringify(res.body)).not.toContain('secret');
    expect(JSON.stringify(res.body)).not.toContain('postgresql://');
  });

  it('errorHandler converts ZodError into a 400 validation error', async () => {
    const app = express();
    app.get('/boom', () => {
      z.string().parse(123);
    });
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app).get('/boom');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('errorHandler maps malformed JSON body to 400 INVALID_BODY', async () => {
    const app = express();
    app.use(express.json());
    app.post('/echo', (_req, res) => res.json({ ok: true }));
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app)
      .post('/echo')
      .set('Content-Type', 'application/json')
      .send('{"bad json');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_BODY');
  });

  it('errorHandler maps oversized body to 413 PAYLOAD_TOO_LARGE', async () => {
    const app = express();
    app.use(express.json({ limit: '10b' }));
    app.post('/echo', (_req, res) => res.json({ ok: true }));
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app)
      .post('/echo')
      .send({ big: 'x'.repeat(100) });
    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });
});
