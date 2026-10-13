import { createHash, randomBytes } from 'node:crypto';
import jwt, { type SignOptions } from 'jsonwebtoken';

export interface AccessTokenPayload {
  sub: string;
  type: 'access';
  exp?: number;
}

const REFRESH_TOKEN_BYTES = 32;
export const JWT_ISSUER = 'wasl';
export const JWT_AUDIENCE = 'wasl-api';

export function signAccessToken(
  payload: AccessTokenPayload,
  secret: string,
  expiresIn: string,
): string {
  return jwt.sign(payload, secret, {
    expiresIn,
    algorithm: 'HS256',
    issuer: JWT_ISSUER,
    audience: JWT_AUDIENCE,
  } as SignOptions);
}

export function verifyAccessToken(token: string, secret: string): AccessTokenPayload {
  const decoded = jwt.verify(token, secret, {
    algorithms: ['HS256'],
    issuer: JWT_ISSUER,
    audience: JWT_AUDIENCE,
  });
  if (typeof decoded === 'string' || typeof decoded !== 'object' || decoded === null) {
    throw new Error('Invalid access token payload');
  }
  if (decoded.type !== 'access' || typeof decoded.sub !== 'string' || decoded.sub.length === 0) {
    throw new Error('Invalid access token claims');
  }
  return {
    sub: decoded.sub,
    type: 'access',
    ...(typeof decoded.exp === 'number' ? { exp: decoded.exp } : {}),
  };
}

export function generateRefreshToken(): string {
  return randomBytes(REFRESH_TOKEN_BYTES).toString('hex');
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
