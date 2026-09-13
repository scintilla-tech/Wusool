# WASL — Security Specification

## 1. Authentication

- Argon2id password hashing (`@node-rs/argon2`, m=19456/t=2/p=1).
- Short access JWT (HS256, `iss`/`aud`, 15m) + opaque rotating refresh tokens (SHA-256 hashed, 30d).
- Login timing equalized (dummy Argon2 verify) to prevent enumeration.
- Refresh reuse detection revokes the user's sessions.
- Disabled accounts (`isActive=false`) rejected on authenticate and refresh.

## 2. Authorization & Tenant Isolation

- `tenantId`/`role` derived from a fresh server-side user lookup (never from client or token claims).
- `authorize(...roles)` middleware for role gates; object-level authorization in services.
- Every tenant-owned query scoped by `tenantId` from `req.auth`.
- Cross-tenant references forbidden; automated negative cross-tenant tests required.

## 3. Validation

- Strict Zod; reject unexpected properties (`validate` middleware + `.strict()`).
- Reusable schemas: UUID, email, Saudi phone (normalized), Arabic/English names, lat/lng, dates, pagination, enums.
- Env whitelist validation (rejects placeholder/weak secrets in production, min 32 chars).

## 4. Transport & Headers

- Helmet (default CSP etc.), CORS allowlist (no wildcard, `null` origin rejected), 100kb body limit, `x-powered-by` disabled.
- Endpoint rate limiting (login/refresh/logout); `TRUST_PROXY` configurable.

## 5. Secrets & Logging

- Never log passwords, JWTs, refresh tokens, OTP, national IDs, document keys, or location history.
- pino redaction + `scrub()` for error messages; request IDs; no stack traces in responses.
- No secrets committed; `.env.example` uses placeholders only.

## 6. Realtime

- Socket handshake authenticated; server controls room membership; per-event resource authorization.
- Driver location validated (role/tenant/active trip/assigned driver+bus/coords/timestamp/frequency).

## 7. Storage

- S3-compatible private storage via provider abstraction; random keys, signed URLs, MIME + magic-byte validation, size limits, authorization before access.

## 8. Sensitive Data

- `nationalIdOrIqama`, student home coordinates, document keys never exposed in ordinary DTOs/logs.
