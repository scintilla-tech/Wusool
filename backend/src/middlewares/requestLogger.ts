import { randomUUID } from 'node:crypto';
import pinoHttp from 'pino-http';
import type pino from 'pino';
import type { EnvConfig } from '../config/env';

const SAFE_REQUEST_ID = /^[a-zA-Z0-9._-]{1,64}$/;

export function createRequestLogger(logger: pino.Logger, _env: EnvConfig) {
  return pinoHttp({
    logger,
    genReqId: (req) => {
      const existing = req.headers['x-request-id'];
      if (typeof existing === 'string' && SAFE_REQUEST_ID.test(existing)) {
        return existing;
      }
      return randomUUID();
    },
    autoLogging: {
      ignore: (req) => req.url === '/health/live' || req.url === '/health/ready',
    },
  });
}
