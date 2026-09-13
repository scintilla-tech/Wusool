import { rateLimit, type Options } from 'express-rate-limit';

export interface RateLimiterOptions {
  windowMs: number;
  limit: number;
}

/**
 * Endpoint-specific rate limiter. Returns a JSON 429 response.
 */
export function createRateLimiter(options: RateLimiterOptions): ReturnType<typeof rateLimit> {
  const config: Partial<Options> = {
    windowMs: options.windowMs,
    limit: options.limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        success: false,
        error: { code: 'RATE_LIMITED', message: 'Too many requests, please try again later' },
      });
    },
  };
  return rateLimit(config);
}
