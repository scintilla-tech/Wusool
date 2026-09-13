# PHASE 2 — Authentication & Authorization

Phase 2 adds authentication and authorization on top of the Phase 1 foundation. It introduces password hashing, short-lived access JWTs, rotating refresh sessions, role-based authorization, tenant-context derivation, and endpoint-specific rate limiting.

## 1. Approved Scope

- Argon2id password hashing
- Short-lived access JWT + rotating refresh session architecture
- Login / refresh / logout / current-user endpoints
- Authentication middleware (verify Bearer access token, attach server-side context)
- Role-based authorization middleware
- Tenant context derived from authenticated server context (never from the client)
- Endpoint-specific rate limiting for auth endpoints
- Safe user DTOs (no password hash, no national ID, no home coordinates)
- Tests for hashing, tokens, auth endpoints, and middleware

## 2. Design Decisions

- **Password hashing:** Argon2id via `@node-rs/argon2` (N-API prebuilt binaries; Argon2id is the AGENTS.md-preferred algorithm).
- **Access token:** short-lived JWT (default 15m), signed with `JWT_ACCESS_SECRET`, payload `{ sub, type: 'access' }`. `role` and `tenantId` are NOT embedded in the token — they are re-derived from a fresh server-side user lookup on every authenticated request.
- **Refresh token:** opaque random 256-bit token; only its SHA-256 hash is stored in `RefreshSession.tokenHash`. Rotates on every refresh. Expiry (default 30d) enforced by `RefreshSession.expiresAt`. `JWT_REFRESH_SECRET` is reserved for a future JWT-based refresh design and is currently unused.
- **Login identity:** `tenantCode` + Saudi-normalized `phone` + `password`. (Phone is the primary Saudi identity; `tenantCode` disambiguates across tenants. Email may become a secondary identifier in a later phase.)
- **Tenant context:** `tenantId` is read from the authenticated user record — never accepted from the client request.
- **Authorization:** `requireRole(...roles)` middleware guards role-restricted routes.

## 3. Endpoints

- `POST /auth/login` — `{ tenantCode, phone, password }` → `{ accessToken, refreshToken, user }`
- `POST /auth/refresh` — `{ refreshToken }` → `{ accessToken, refreshToken }` (rotates refresh session)
- `POST /auth/logout` — `{ refreshToken }` → revokes the session
- `GET /auth/me` — returns the authenticated user (requires `Authorization: Bearer <accessToken>`)

## 4. Security Requirements

- Never log tokens, password hashes, or phone numbers.
- Refresh tokens are stored only as hashes.
- Generic error messages for login failures (no user enumeration).
- Rate limit login/refresh endpoints.
- Reject unexpected request properties (strict Zod).
- Refresh-token reuse detection: reusing an already-rotated token revokes the user's session.

## 5. Out of Scope (MUST NOT implement in Phase 2)

- User/tenant provisioning (registration) — Phase 3
- OTP / SMS / email verification flows
- Password reset / forgot-password
- Flutter clients
- Any transportation business logic

## 6. Quality Checks

- Prisma format / validate
- TypeScript typecheck
- lint
- full tests
- development server + manual endpoint smoke test
- reviewer subagent + security-reviewer subagent

## 7. Final Report Checklist

Same structure as Phase 1: files created/modified, dependencies added + justification, commands executed, test results, reviewer + security-reviewer findings, findings fixed, unresolved issues, architecture deviations.

End exactly with:

```
PHASE 2 PASSED — READY FOR REVIEW
```

or

```
PHASE 2 FAILED — REVIEW REQUIRED
```
