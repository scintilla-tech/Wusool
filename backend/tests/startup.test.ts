import request from 'supertest';
import { describe, it, expect } from 'vitest';
import { createTestApp } from './helpers';

describe('application startup', () => {
  it('creates an Express app without throwing', () => {
    const app = createTestApp();
    expect(app).toBeDefined();
  });

  it('responds on the health route via a bound listener', async () => {
    const app = createTestApp();
    const server = app.listen(0);
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    expect(address).not.toBeNull();

    const port = typeof address === 'object' && address ? address.port : null;
    expect(typeof port).toBe('number');

    const res = await request(`http://127.0.0.1:${port}`).get('/health/live');
    expect(res.status).toBe(200);

    await new Promise<void>((resolve, reject) =>
      server.close((err) => (err ? reject(err) : resolve())),
    );
  });
});
