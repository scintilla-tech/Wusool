# WASL Architecture Specification

Technical specification of the approved WASL architecture. This document is the reference for architectural decisions during implementation. It captures the contract in `AGENTS.md`; where they conflict, `AGENTS.md` is authoritative.

## 1. System Purpose

WASL is a multi-tenant university female transportation automation SaaS. It coordinates daily transportation for female students across multiple universities (tenants), including driver routing, supervisor oversight, student attendance/boarding, and arrival confirmation.

## 2. Roles

| Role | Scope |
| --- | --- |
| STUDENT | University tenant |
| DRIVER | University tenant |
| SUPERVISOR | University tenant |
| FIELD_SUPERVISOR | University tenant |
| UNIVERSITY_ADMIN | University tenant |
| PLATFORM_SUPER_ADMIN | Platform-level, `tenantId` may be `null` |

All university roles require a `tenantId`. `PLATFORM_SUPER_ADMIN` is platform-level and is the only role that may have `tenantId = null`.

## 3. Modular Monolith

- Single deployable backend application organized into modules (`config`, `modules`, `middlewares`, `providers`, `sockets`, `validation`, `utils`, `types`).
- Clear separation of concerns: controllers, services, validation, and data access are kept separate within modules.
- `sockets/` is scaffolding only until the Socket.IO phase begins.

## 4. Multi-Tenancy

- Shared PostgreSQL database / shared-schema multi-tenancy.
- Every tenant-owned row carries a `tenantId`.
- Tenant context is derived from the authenticated server context, never from client input.
- Cross-tenant relationships are forbidden; object-level authorization is mandatory.

## 5. Tenant Isolation

- Application-layer tenant isolation is mandatory.
- PostgreSQL Row-Level Security (RLS) is deferred and MUST NOT be claimed as active.
- All tenant-scoped queries must filter by `tenantId` from the authenticated server context.
- Tenant-aware uniqueness and relationships are enforced at the schema and service layer.

## 6. Backend Stack

- Node.js
- TypeScript
- Express
- PostgreSQL
- Prisma (ORM + migrations)
- Zod (validation)
- Socket.IO (deferred to a later phase)

## 7. Flutter / Riverpod Decision

- Mobile clients are Flutter with Riverpod for state management.
- No Flutter work is in scope for backend foundation phases.

## 8. PostgreSQL / Prisma

- PostgreSQL is the source of truth.
- One reusable `PrismaClient` per process; never per request.
- IDs and phone numbers are Strings, never numeric identifiers.
- Partial unique indexes (e.g. active-assignment constraints) that Prisma cannot express are created via raw PostgreSQL migrations.

## 9. Redis Decision

- Redis is NOT required for the first single-instance MVP.
- Redis becomes required only when multi-instance deployment needs distributed rate limiting, a Socket.IO adapter, or transient distributed state.

## 10. Realtime Architecture

- Socket.IO is introduced in a later phase.
- Driver GPS is shared only during ACTIVE morning trips.
- Socket authentication and resource authorization are required when Socket.IO begins.

## 11. Location Privacy

- Student home latitude/longitude is sensitive location data and is excluded from ordinary DTO exposure.
- Driver GPS sharing is limited to ACTIVE morning trips.
- Location history is never logged.

## 12. Geofence Arrival

- University arrival uses local Haversine geofence logic; no external Maps API calls for arrival detection.
- Auto-completion requires validated arrival samples/dwell logic.

## 13. Notification Abstraction

- A notification provider abstraction will support FCM, Huawei Push, and appropriate iOS/APNs handling. Deferred to a later phase.

## 14. Maps Abstraction

- Maps must use a provider abstraction. Deferred to a later phase.

## 15. Storage Strategy

- S3-compatible private object storage will be used later (documents, etc.). Deferred to a later phase.

## 16. Security Principles

- Strict Zod validation; reject unexpected properties.
- Helmet for security headers.
- CORS allowlist (no wildcard).
- Request body limits.
- Safe production errors (no stack traces in production responses).
- No secrets in logs; no OTP/token/password hashes/national IDs/document keys/location history in logs.
- Structured logging with request IDs.
- Argon2id preferred for password hashing when the auth phase begins.
- Short access JWT + rotating refresh session when the auth phase begins.
- Endpoint-specific rate limiting when applicable.

## 17. Performance Targets

- Initial expected scale: ~400 active users during morning burst.
- Design/load-test headroom: ~1000 concurrent clients/connections.
- Connection pooling, pagination, bounded queries, selective Prisma fields/DTOs, and indexes on real query patterns.

## 18. Backup Strategy

- Production Postgres will use automated backups + Point-In-Time Recovery (PITR).
- Initial targets: RPO <= 15 minutes, RTO <= 1 hour.
- Restore testing is required.
- Separate dev/staging/prod configuration.

## 19. Data Retention Principles

- Historical attendance, trips, assignments, and audit data must be preserved.
- National ID/Iqama and student home coordinates are sensitive and never exposed in normal DTOs.
- Never use destructive production reset commands.

## 20. Active Assignment Constraints

- At most one active `StudentAssignment` per student.
- At most one active `DriverAssignment` per bus.
- At most one active `SupervisorBusAssignment` per bus.
- Enforced with PostgreSQL partial unique indexes plus transactional service logic.
