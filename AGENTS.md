# AGENTS.md — WASL Engineering Contract

This file is the persistent engineering contract for every AI/OpenCode session in this repository. Read it fully before doing any work.

## PROJECT

WASL — multi-tenant university female transportation automation SaaS.

## APPROVED STACK

### Backend
- Node.js
- TypeScript
- Express
- PostgreSQL
- Prisma
- Zod
- Socket.IO (only when its later phase begins)

### Mobile
- Flutter
- Riverpod

### Infrastructure rules
- PostgreSQL is source of truth.
- Redis is NOT required for the first single-instance MVP.
- Redis becomes required when multi-instance deployment needs distributed rate limiting / Socket.IO adapter / transient distributed state.
- S3-compatible private object storage will be used later.
- Notification provider abstraction will support FCM, Huawei Push, and appropriate iOS/APNs handling.
- Maps must use provider abstraction.

## ARCHITECTURE

- Modular monolith.
- Shared PostgreSQL database / shared schema multi-tenancy.
- Strict tenant isolation.
- Application-layer tenant isolation is mandatory.
- PostgreSQL RLS is deferred and MUST NOT be claimed as active.
- Never trust tenantId from Flutter/client.
- Tenant context must come from authenticated server context.
- Object-level authorization is mandatory.
- Cross-tenant relationships are forbidden.
- PLATFORM_SUPER_ADMIN is platform-level and may have tenantId = null.
- All university roles require tenantId.

## ROLES

- STUDENT
- DRIVER
- SUPERVISOR
- FIELD_SUPERVISOR
- UNIVERSITY_ADMIN
- PLATFORM_SUPER_ADMIN

## TRANSPORTATION DOMAIN RULES

- AttendanceIntent: ATTENDING / ABSENT.
- TripStudent: WAITING / BOARDED / NOT_READY / MISSED.
- Attendance intent is NOT proof of transportation.
- Only BOARDED students become transport-attendance-confirmed after appropriate trip completion.
- Driver GPS is shared only during ACTIVE morning trips.
- Target location update interval is approximately 3 minutes.
- University arrival uses local Haversine geofence logic without external Maps API calls.
- Auto-completion requires validated arrival samples/dwell logic.
- Historical attendance/trips/assignments/audit data must be preserved.

## DATABASE RULES

- Prisma + PostgreSQL only.
- One reusable PrismaClient per process.
- Never PrismaClient per request.
- IDs and phone numbers are Strings, never numeric identifiers.
- Phone normalized to Saudi format where applicable.
- National ID/Iqama is HIGHLY SENSITIVE and never exposed in normal DTOs.
- Student home latitude/longitude is sensitive location data.
- Tenant-aware uniqueness and relationships are required.
- Partial unique indexes required for active assignments where Prisma cannot express them.
- Raw PostgreSQL migration is allowed/required for those indexes.
- Never use destructive production reset commands.

## ACTIVE ASSIGNMENT RULES

- one active StudentAssignment per student
- one active DriverAssignment per bus
- one active SupervisorBusAssignment per bus
- protect with PostgreSQL partial unique indexes plus transactional service logic

## SECURITY

- Strict Zod validation.
- Reject unexpected properties.
- Helmet.
- CORS allowlist.
- Request body limits.
- Safe production errors.
- No stack traces in production responses.
- No secrets in logs.
- No OTP/token/password hashes/national IDs/document keys/location history in logs.
- Structured logging with request IDs.
- Argon2id preferred when authentication phase begins.
- Short access JWT + rotating refresh session architecture when auth phase begins.
- Endpoint-specific rate limiting when applicable.
- Socket authentication and resource authorization when Socket.IO phase begins.

## PERFORMANCE

- Initial expected scale approximately 400 active users during morning burst.
- Design/load-test headroom around 1000 concurrent clients/connections.
- Connection pooling architecture.
- Pagination and bounded queries.
- Selective Prisma fields/DTOs.
- Index real query patterns.

## BACKUP/OPERATIONS

- Production Postgres must eventually use automated backups + PITR.
- Initial targets RPO <= 15 minutes and RTO <= 1 hour.
- Restore testing is required.
- Separate dev/staging/prod configuration.

## DEVELOPMENT PROCESS

For EVERY implementation phase:

1. Read AGENTS.md.
2. Read the relevant docs/phases/PHASE_X.md.
3. Inspect existing repository state.
4. Create a short implementation plan.
5. Implement ONLY the approved current phase.
6. Run relevant formatter/typecheck/lint/tests/schema validation.
7. Invoke the reviewer subagent.
8. If the phase touches database, tenant isolation, auth, authorization, sensitive data, sockets, storage, or security, invoke security-reviewer.
9. Review findings.
10. Fix all valid CRITICAL, HIGH, and MEDIUM findings.
11. Rerun validation/tests.
12. Invoke reviewer again for final verification.
13. If security-sensitive changes were made, perform final security-reviewer verification too.
14. Produce a truthful phase report with actual commands/results.
15. STOP.
16. NEVER begin the next phase without explicit user approval.

Never claim a command/test/migration passed unless actually executed.

Never conceal failures.

Do not weaken tests to make them pass.

Do not remove security controls simply to fix a test.

Do not silently change architecture.

If architecture must change, STOP and report the proposed deviation before implementing it.

## REFERENCE REPOSITORY

`LakshayD02/Full_Stack_Uber_Clone` may be used ONLY as an architectural reference for:

- Express organization
- middleware patterns
- controller/service separation
- error handling
- Socket.IO bootstrap later

Never copy Uber:
- rides
- payments
- pricing
- matching
- unrelated business logic
