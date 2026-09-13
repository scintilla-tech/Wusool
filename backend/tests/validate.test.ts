import express from 'express';
import request from 'supertest';
import { describe, it, expect } from 'vitest';
import { z } from 'zod';
import { validate } from '../src/middlewares/validate';
import { errorHandler } from '../src/middlewares/errorHandler';
import { createLogger } from '../src/config/logger';
import { testEnv } from './helpers';

describe('validate middleware', () => {
  it('parses and replaces req.body with validated values', async () => {
    const app = express();
    app.use(express.json());
    app.post(
      '/echo',
      validate({ body: z.object({ name: z.string(), age: z.coerce.number() }).strict() }),
      (req, res) => {
        res.json({ body: req.body });
      },
    );
    const res = await request(app).post('/echo').send({ name: 'Noor', age: '21' });
    expect(res.status).toBe(200);
    expect(res.body.body).toEqual({ name: 'Noor', age: 21 });
  });

  it('parses and replaces req.query (coerces types)', async () => {
    const app = express();
    app.get(
      '/list',
      validate({ query: z.object({ page: z.coerce.number().int() }).strict() }),
      (req, res) => {
        res.json({ page: req.query.page, isNumber: typeof req.query.page === 'number' });
      },
    );
    const res = await request(app).get('/list?page=3');
    expect(res.status).toBe(200);
    expect(res.body.page).toBe(3);
    expect(res.body.isNumber).toBe(true);
  });

  it('parses and replaces req.params', async () => {
    const app = express();
    app.get(
      '/users/:id',
      validate({ params: z.object({ id: z.string().uuid() }).strict() }),
      (req, res) => {
        res.json({ id: req.params.id });
      },
    );
    const res = await request(app).get('/users/123e4567-e89b-12d3-a456-426614174000');
    expect(res.status).toBe(200);
    expect(res.body.id).toBe('123e4567-e89b-12d3-a456-426614174000');
  });

  it('rejects unexpected body properties (strict)', async () => {
    const app = express();
    app.use(express.json());
    app.post('/echo', validate({ body: z.object({ name: z.string() }).strict() }), (req, res) => {
      res.json({ body: req.body });
    });
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app).post('/echo').send({ name: 'Noor', extra: 'unexpected' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('propagates validation errors to the error handler', async () => {
    const app = express();
    app.use(express.json());
    app.post('/echo', validate({ body: z.object({ age: z.number() }).strict() }), (req, res) => {
      res.json({ ok: true });
    });
    app.use(errorHandler(createLogger(testEnv), false));
    const res = await request(app).post('/echo').send({ age: 'not-a-number' });
    expect(res.status).toBe(400);
  });
});
