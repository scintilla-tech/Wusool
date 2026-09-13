import { rateLimit, ipKeyGenerator, type Options } from 'express-rate-limit';
import type { Request } from 'express';

export interface RateLimiterOptions {
  windowMs: number;
  limit: number;
  /** Optional custom key generator (defaults to the client IP). */
  keyGenerator?: (req: Request) => string;
}

/**
 * Endpoint-specific rate limiter. Returns a JSON 429 response.
 *
 * For auth endpoints, key by the login identifier rather than the IP so that
 * many users behind a shared campus NAT are not blocked, while a single account
 * remains protected against brute force.
 */
export function createRateLimiter(options: RateLimiterOptions): ReturnType<typeof rateLimit> {
  const config: Partial<Options> = {
    windowMs: options.windowMs,
    limit: options.limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    ...(options.keyGenerator ? { keyGenerator: options.keyGenerator } : {}),
    handler: (_req, res) => {
      res.status(429).json({
        success: false,
        error: { code: 'RATE_LIMITED', message: 'Too many requests, please try again later' },
      });
    },
  };
  return rateLimit(config);
}

/** Key by the login identifier (tenantCode:phone) with an IP fallback. */
export function loginKeyGenerator(req: Request): string {
  const body = req.body as { tenantCode?: string; phone?: string } | undefined;
  if (body && typeof body.phone === 'string' && body.phone.length > 0) {
    return `${body.tenantCode ?? ''}:${body.phone}`;
  }
  return ipKeyGenerator(req.ip ?? 'unknown');
}
