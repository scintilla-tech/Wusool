# WUSOOL System Audit

Audit date: 2026-10-12 (Asia/Riyadh)
Repository: `C:\Users\njood\Wasl\wasl`
Status: audit and repair pass complete; release blockers remain

## Evidence policy

This report distinguishes source-code presence from verified behavior. A feature is not marked verified merely because a route, service, widget, or earlier report exists. Final pass/fail results will be updated only from commands executed during this audit. Secrets and personal data are intentionally omitted.

## Progress checklist

- [x] Repository, documentation, manifests, configuration contract, schema, migrations, backend modules, Flutter screens, and existing tests inspected.
- [x] Initial architecture and feature inventory produced.
- [x] HTTP route inventory discovered from source (73 routes, including dual-attendance and push-token deactivation endpoints).
- [x] Backend typecheck, lint, tests, Prisma validation/generation, dependency audit, format check, and build executed.
- [x] Flutter analysis executed after the final mobile change; five widget tests passed earlier in the repair pass.
- [x] Final post-edit Flutter widget rerun completed (7/7 passed).
- [x] Flutter production web build completed successfully.
- [x] Endpoint-by-endpoint authentication/RBAC matrix completed and executed.
- [x] P0/P1 security, authorization, data-integrity, realtime, and integration defects repaired where the local environment allowed.
- [x] Regression, concurrency, malformed-input, and object-authorization tests executed at unit/mocked-HTTP level.
- [x] DB migrations, constraints, integration tests, and critical lifecycle E2E executed against isolated local PostgreSQL 16.
- [x] Independent code-review and security-review passes requested; findings incorporated before handoff.
- [x] Final documentation and readiness matrix completed.

## Current architecture

WUSOOL is an existing shared-schema, multi-tenant transportation system implemented as:

1. A TypeScript/Express modular monolith exposing REST endpoints under `/api/v1`, two health endpoints under `/health`, and a Socket.IO server on the same HTTP server.
2. PostgreSQL as the source of truth through Prisma ORM and ordered SQL migrations.
3. A Flutter/Riverpod client with role-aware screens for student, driver, supervisor/field supervisor, university administrator, and platform administrator.
4. In-process transient state for OTPs, GPS throttling, arrival samples, and latest bus location. This is explicitly single-instance behavior; no Redis adapter is present.
5. Local private-file storage and mock OTP/push providers as development implementations. Production S3-compatible storage and real notification delivery are not implemented.

Authentication uses Argon2id passwords, short HS256 access JWTs, opaque hashed refresh tokens, refresh rotation/reuse detection, and a fresh database lookup on authenticated requests. Tenant and role context are derived from that database lookup. PostgreSQL row-level security is not enabled; isolation depends on application queries and service checks.

## Technology stack

| Layer | Actual technology |
| --- | --- |
| Backend runtime | Node.js >= 20, TypeScript 5.7, Express 4 |
| Validation/security | Zod 3, Helmet, CORS allowlist, express-rate-limit, Argon2id, jsonwebtoken |
| Data | PostgreSQL, Prisma 6, raw SQL migrations for partial indexes/check constraints |
| Realtime | Socket.IO 4; in-memory latest-location and arrival sampling |
| Logging | Pino/pino-http with structured redaction and request IDs |
| Mobile/web client | Flutter 3-compatible Dart SDK constraint, Riverpod, Dio, socket_io_client, geolocator, flutter_map |
| Tests | Vitest, Supertest, Flutter widget tests; optional database integration tests; k6 scripts |

## Directory structure

| Path | Purpose |
| --- | --- |
| `backend/src/app.ts` | Express composition, security middleware, route mounts |
| `backend/src/modules/` | Auth, structure, employees, students, assignments, attendance, trips, tracking, supervisor, admin, platform, devices, notifications, documents |
| `backend/src/sockets/` | Socket.IO authentication and location event handling |
| `backend/prisma/` | Schema, guarded synthetic seed, and twelve ordered migrations |
| `backend/tests/` | Unit/service/HTTP tests and optional DB-backed N+1 tests |
| `backend/load/` | k6 smoke and morning-burst scenarios |
| `mobile/lib/` | Flutter application, shared API/socket clients, and role experiences |
| `mobile/test/` | Seven widget/auth/model tests |
| `docs/` | Product, architecture, API, data, security, realtime, deployment, and prior audit documents |

## Existing modules and observed status

| Capability | Source status | Initial verification status |
| --- | --- | --- |
| Login, refresh, logout, `/auth/me` | Implemented | Focused HTTP tests pass |
| Logout-all | Implemented during audit | HTTP revocation test passes |
| Student registration + OTP | Implemented with in-memory mock OTP | Partially tested; production provider absent |
| Student profile | Read/update implemented | No route-level coverage; delete-request is missing and the UI confirmation is a no-op |
| Dual attendance | Independent OUTBOUND/RETURN sessions with direction windows, optional outbound finish time, driver assistance and driver closure | Real PostgreSQL E2E, Flutter widget/model tests and interactive role walkthrough pass |
| University structure CRUD | Implemented | Mostly service-level tests; most routes have no direct HTTP matrix coverage |
| Employee/student management | Implemented | Service coverage is partial; frontend only lists students/buses |
| Assignments | Implemented with transactions and three partial unique indexes | Some tenant tests; concurrent assignment coverage pending |
| Trip creation/lifecycle | Implemented and verified | Assignment/conflict/atomic transition tests and real DB lifecycle pass |
| Per-student trip status | Implemented and hardened | Atomic assigned-driver predicate tested; allowed transition policy remains ambiguous |
| Realtime driver GPS | Implemented and repaired | Authenticated simulated GPS reached the real server and authorized Flutter client |
| Student tracking | REST snapshot plus realtime subscription/freshness | Flutter web map received real local Socket.IO update; native-device test not run |
| Supervisor monitoring | Assigned buses/tenant buses list exists | No realtime map/incident workflow; no route-level tests |
| Emergency/incident reporting | Mentioned in requirements/spec | Missing database entity, API, and UI; business rules are ambiguous |
| Notifications/devices | Inbox/device registration and mock provider exist | Token ownership hardened/tested; real providers absent |
| Documents | Local upload/read with magic-byte allowlist | Development-only storage; authorization tests absent |
| Platform tenants | List/create/update implemented | Route-level tests absent |
| Admin dashboard | Aggregate counts implemented | Read-only Flutter dashboard; broader management UI missing |
| Trip history, schedules, ETA | Intended capabilities | Missing or not exposed as complete workflows |
| Reports/analytics/settings | Intended capabilities | Only a small dashboard aggregate exists |

## Configuration and external integrations

Expected environment keys (names only): `NODE_ENV`, `PORT`, `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL`, `CORS_ALLOWED_ORIGINS`, `TRUST_PROXY`, `LOGIN_RATE_LIMIT`, `ATTENDANCE_CUTOFF`, and `LOG_LEVEL`.

Required local integration: PostgreSQL. Optional/unfinished integrations: FCM, Huawei Push, APNs, production object storage, production OTP delivery, and vendor-independent maps. OpenStreetMap public tiles are currently called directly by the Flutter tracking screen, so the documented maps-provider abstraction is not actually present.

## Initial risks

### P0/P1

- Bearer tokens now use `flutter_secure_storage` with one-time removal of legacy `SharedPreferences` keys; native-device verification is still outstanding.
- All 12 migrations and the raw-constraint verifier passed against the isolated local PostgreSQL 16 container; no production database was contacted.
- OTP/push/local-storage providers are development implementations, and no Redis-backed realtime/OTP state exists.
- Installation-scoped push-device deactivation is implemented for logout, including encrypted retry of failed/offline cleanup; provider-rejected token cleanup still depends on a real push provider.
- Flutter web browser E2E and the release build passed. Native device GPS and secure-storage behavior remain unverified because of the documented Android-license and Windows ATL blockers.

### P2

- URL path parameters generally are not passed through strict ID schemas; malformed identifiers normally degrade to 404 but the contract is inconsistent.
- Student home coordinates can be updated one coordinate at a time, permitting incomplete location pairs.
- PostgreSQL `DATE` normalization and attendance cutoff explicitly use `Asia/Riyadh`, independent of the server OS timezone. A per-tenant timezone model is still not defined.
- In-memory OTP/location state prevents safe multi-instance deployment and loses state on restart.
- Device token ownership and driver timestamp validation were repaired; live provider/device behavior remains unverified.
- Several Flutter actions silently swallow errors; attendance submission has no busy state, explicit success/failure result, or duplicate-tap guard.
- Visible student contact and account-deletion controls currently perform no action.

## Missing dependencies/capabilities

- A reachable PostgreSQL test database is required for migrations, raw-constraint checks, database integration tests, seeding, and true end-to-end API execution.
- Flutter SDK commands worked with the required local SDK access. Doctor, analysis, widget tests, and the release web build passed; Android licenses remain outstanding.
- No Playwright (or equivalent browser E2E harness) is configured.
- No real OTP, push, object-storage, or maps-provider credentials/implementations are present. These must remain recorded as mocked/blocked rather than production-ready.

## Technical debt and consistency findings

- `README.md`, `ROADMAP.md`, `API_SPEC.md`, and prior performance claims overstate present verification and do not match the actual route/features inventory.
- Backend route handlers repeat tenant extraction and often omit parameter validation.
- Date-only and attendance-cutoff logic is centralized and explicitly uses the `Asia/Riyadh` business timezone; a future multi-region design still needs a per-tenant timezone model.
- The Flutter admin experience exposes only dashboards and lists despite backend CRUD breadth.
- Synthetic role credentials are documented by account identifier only; password values remain exclusively in the ignored local demo environment file.
- There is no audit-list endpoint even though it is documented.
- The `backend/.gitignore` file contains a pre-existing uncommitted user change and is outside this audit's edits.

## Prioritized improvement plan

1. Completed locally: provision isolated PostgreSQL 16, apply all migrations, verify raw constraints, and execute DB integration/concurrency tests. Production migration remains approval-gated.
2. Validate the new `flutter_secure_storage` migration/logout behavior on real Android and iOS devices.
3. Implement production OTP, push and private object storage and fail closed when they are absent in production.
4. Repair the local Flutter SDK issue, run the release web build, and add browser/device E2E including network-loss/recovery.
5. Define requirements for emergency incidents, scheduling, history/retention, ETA, reports, settings and supervisor scope before implementing them.

## Final feature matrix

| Capability | Classification | Evidence / blocker |
| --- | --- | --- |
| Authentication/profile | Implemented and verified at API layer | Focused HTTP tests pass; secure mobile storage remains blocker |
| Student assigned route/trip | Implemented and verified | Real DB and Flutter UI passed |
| Attendance/absence | Implemented and verified | Real API and persistence passed |
| Live tracking | Partially verified | Socket authorization tests and client analysis pass; no live device E2E |
| Notifications | Partially implemented | Inbox/device API; push provider is mock |
| Trip history | Missing | No history endpoint/UI |
| Emergency reporting | Missing | No model/API/UI |
| Driver trip lifecycle | Implemented and verified | Start, GPS, and completion passed through UI/API/DB |
| Driver pickup/attendance | Implemented and verified | Boarded state persisted and appeared in supervisor UI |
| Vehicle issue reporting | Missing | No model/API/UI |
| Supervisor fleet monitoring | Partially implemented | Assigned-bus API; incomplete realtime UI |
| Route/assignment management | Backend implemented; UI partial | Existing student/bus lists verified; create/edit UI remains limited |
| Admin users/fleet/routes | Backend implemented; UI partial | CRUD services/routes; limited Flutter screens |
| Reports/analytics/settings | Mostly missing | Only dashboard aggregates exist |
| Platform tenant management | Implemented; success path not in critical UI E2E | API and role boundary tests pass |
