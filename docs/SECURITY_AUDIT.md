# WUSOOL Security and Privacy Audit

Audit date: 2026-10-12
Scope: local repository and local test environment only

## Executive result

The audit resolved the original material security/integrity issues and the local-deployment phase additionally moved bearer tokens to `flutter_secure_storage`, added push-token deactivation on logout, applied the database constraints in isolated PostgreSQL, and executed the critical browser/API/database/Socket.IO workflow. The backend production dependency audit reports zero known vulnerabilities. WUSOOL is still **not production-ready** because production OTP, push, and durable private document-storage integrations are absent and native-device secure-storage/GPS/background validation has not run.

The executable server now refuses `staging` or `production` startup while the mock OTP/push and local document-storage implementations are the only available providers. The demo seed independently requires a development/test environment, an explicit opt-in, and a loopback database host.

## Controls inspected

| Area | Finding and evidence | Status |
| --- | --- | --- |
| Passwords | Argon2id hashing; hashes never returned by auth DTO tests | Verified in unit/HTTP tests |
| Access tokens | HS256, issuer/audience, explicit `type=access`, short configured TTL, DB lookup on each request | Verified |
| Tenant invalidation | Authentication now selects Tenant and rejects a disabled tenant even for an unexpired JWT | Fixed and tested |
| Refresh sessions | Opaque random tokens stored as SHA-256 hashes, rotation and reuse detection; logout-all now revokes all active sessions | Fixed/tested |
| RBAC | Central authenticate/authorize middleware; all protected endpoints tested missing/expired auth; privileged routes tested as Student | Verified at route boundary |
| Object authorization | Services include tenant/user/assigned-driver predicates for student, notification, documents, trips | Critical student/driver/GPS paths verified with real DB E2E |
| GPS privacy | Trip-only rooms are derived server-side; JWT expiry disconnects sockets; authorization refreshes periodically and before publish; only Driver may publish | Fixed and integration-tested locally |
| GPS lifecycle | Driver restarts sharing on an active trip and stops on completion; stale client timestamps are rejected | Flutter-web simulated GPS passed; real-device recovery not run |
| Attendance authorization | Student self-registration is profile-scoped; assisted writes and closure require the assigned driver, active trip and roster membership; CLOSED is enforced transactionally | Real PostgreSQL authorization/concurrency E2E passed |
| Attendance privacy | Student sockets receive only their own change payload; roster identity/status changes use staff-only trip rooms; closure events contain no unrelated-student details | Fixed and tested |
| Input validation | Strict Zod body/query schemas, JSON size limit, coordinate pairing/ranges, GPS ranges/timestamp skew | Improved/tested |
| SQL injection | Prisma parameterized operations; raw SQL found only in migrations/health checks with static text | No direct finding |
| XSS | Flutter renders text rather than injecting HTML; Helmet enabled on API | No direct finding |
| CSRF | Bearer tokens, not cookies; API has explicit CORS allowlist | Not applicable to current auth transport |
| Rate limiting | Login, refresh/logout, registration/OTP, uploads, and global API controls present | Verified by source |
| File upload | 10 MiB memory limit, magic-byte allowlist, tenant/object authorization, private local storage | Partial; production storage absent |
| Error leakage | Central normalized errors; stack/details suppressed outside development; Pino redaction | Verified by source/tests |
| Dependency risk | `proxy-addr`, `multer`, `ip-address`, Vitest/Vite and transitive packages updated; `deepmerge-ts` pinned to patched 8.0.2; Prisma generate/validate passed | Fixed; `npm audit` 0 |

## Security fixes made

1. Socket clients now authenticate against the current user and tenant state and join only server-derived `user`, `trip`, or staff-only `trip` rooms justified by role and assignment.
2. `trip:location` publication is restricted to drivers; coordinates and device timestamp are validated; active assigned-trip authorization is rechecked before storage/broadcast. A per-socket throttle and in-flight guard protect the database.
3. Disabled tenants invalidate existing access tokens on the next authenticated request.
4. `POST /api/v1/auth/logout-all` revokes every active refresh session for the authenticated user. Refresh rotation now checks tenant state and atomically revokes/replaces the session.
5. Provider device tokens are globally unique and registration transfers ownership to the current user. The migration refuses to proceed if legacy duplicates exist rather than deleting data.
6. Trip start/completion/audit and per-student updates use conditional writes/transactions, reducing time-of-check/time-of-use authorization and duplicate-transition races. Manual and geofence completion share one lifecycle event path.
7. Dependency vulnerabilities were reduced from 14 total in the full initial toolchain (including critical findings) to zero reported by the final `npm audit`.
8. Attendance writes use immutable actor/source audit rows and serializable session locking. Only the affected student and authorized staff receive student-specific realtime changes.

## Remaining findings

### High — mobile refresh/access token storage

`mobile/lib/core/token_store.dart` now stores bearer credentials through `flutter_secure_storage`, with a one-time migration that removes the legacy `SharedPreferences` keys. Unit/widget tests use an in-memory storage backend. The demonstrated web target uses the package's browser implementation; native Keychain/Keystore/Credential Locker behavior still requires a real native-target validation before a mobile production release.

Each installation has a stable random identifier stored with the secure token store. Normal logout sends that identifier with the refresh token, and the backend atomically revokes the session and deactivates only that installation's push registrations. `DELETE /api/v1/devices` provides the same installation-scoped authenticated cleanup path; other signed-in devices are unaffected.

### High — production providers are not production implementations

OTP and push are mocks; uploaded documents use local disk; Socket.IO/location state is in-process; no Redis adapter exists. Mock OTP must never be enabled in production. Production startup should fail closed unless real providers and durable private storage are configured.

Installation-scoped logout now atomically revokes the refresh session and deactivates that installation's identified and legacy-null push registrations. Device registration requires a stable installation identifier, `DELETE /api/v1/devices` provides an authenticated cleanup fallback, and failed/offline mobile logout stores an encrypted retry marker. Real provider-rejected token cleanup still requires a production push implementation.

### Production-only blocker — database security changes not applied to production

The constraint migration was applied and verified in the isolated local PostgreSQL environment. Production application remains a separate, approval-gated operation and was not attempted.

### Medium — location retention is implicit

Only latest locations/arrival samples are kept in process; there is no persisted location history model or explicit retention configuration. This minimizes persistence but the intended privacy/retention policy is undocumented. Define authorized audiences, retention, deletion, and incident/legal-hold policy before adding history.

### Medium — path identifiers

Most Express `:id` values are not passed through a CUID schema. Prisma parameterization prevents injection, but a consistent `400` contract and length limits would reduce malformed-input ambiguity.

### Medium — supervisor scope ambiguity

Field supervisors currently receive all active tenant-trip socket rooms, while ordinary supervisors receive assigned-bus rooms. This follows current service behavior, but the product requirement “authorized operational scope” is not defined precisely enough to confirm that tenant-wide Field Supervisor access is intended.

## Secrets and privacy handling

- Environment variable names were inventoried; secret values were not copied into reports.
- No production student records were used. Tests use synthetic identifiers and coordinates.
- JWTs, passwords, refresh tokens, authorization headers and document bodies are redacted/not logged by the configured logger.
- No attack or load testing was performed against any external or production system.
