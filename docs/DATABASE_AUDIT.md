# WUSOOL Database Audit

Audit date: 2026-10-12
ORM/schema: Prisma 6.19.3 with PostgreSQL migrations

## Scope and result

The schema contains 24 models and 9 enums in a shared-schema multi-tenant design. Prisma generation and schema validation passed. Twelve ordered migration directories are present. PostgreSQL 16 runs in the local Docker development environment; all 12 migrations applied successfully and the constraint verifier confirmed 8 partial indexes, 1 unique index, and 5 CHECK constraints. No production database was contacted and no destructive migration was run.

## Core entities

Tenant, User, StudentProfile, DriverProfile, SupervisorProfile, FieldSupervisorProfile, Branch, Neighborhood, Route, RouteNeighborhood, Bus, StudentAssignment, DriverAssignment, SupervisorBusAssignment, AttendanceSession, AttendanceIntent, AttendanceAudit, DailyTrip, TripStudent, DeviceToken, Notification, UserDocument, AuditLog, and RefreshSession.

There is no Incident/Emergency entity and no persisted GPS-location/history entity. Those intended capabilities must not be inferred from other tables.

## Integrity review

| Concern | Current control | Result |
| --- | --- | --- |
| Primary keys | CUID string IDs on models | Present |
| Tenant relationships | `tenantId` foreign keys and tenant-scoped service predicates | Present; no PostgreSQL RLS |
| User identity uniqueness | Compound tenant phone/email/national-ID constraints | Present |
| Student assignment duplication | Existing partial active-assignment index | Present |
| Driver assigned to multiple active buses | Partial unique index on active `driverProfileId` | Applied and verified |
| Bus assigned multiple active drivers | Existing active-bus partial index | Present |
| Conflicting active bus trips | Direction-aware scheduled conflict index plus global in-progress uniqueness | Applied and verified |
| Conflicting active driver trips | Direction-aware scheduled conflict index plus global in-progress uniqueness | Applied and verified |
| Duplicate trip attendance | Unique `(dailyTripId,studentProfileId)` | Present |
| Duplicate attendance intent | Unique `(attendanceSessionId,studentProfileId)` | Applied and verified |
| Attendance closure race | Conditional OPEN-to-CLOSED write inside serializable transaction | Real PostgreSQL concurrency test passed |
| Device token ownership | `DeviceToken.token @unique` plus global-token upsert | Applied and verified |
| Trip transitions | Conditional `updateMany` and transactional completion/audit | Fixed/unit-tested |
| Coordinates | Prisma fields plus Zod range/pair validation | Improved; existing incomplete rows not checked |
| Referential actions | Explicit relations; archival/deactivation preferred to hard deletion | Present |

The new migration runs inside an explicit transaction and intentionally raises an exception if duplicate device tokens, active driver assignments, or active same-day bus/driver trips already exist. It creates the stronger token index before dropping the weaker compound index and does not silently delete or merge production data. Operators must inspect and reconcile conflicts before deployment.

## Transactions and concurrency

- Assignment services already use transactions and partial unique indexes for active assignments.
- Trip start is a conditional SCHEDULED-to-IN_PROGRESS update; only one concurrent transition can win.
- Trip completion is a transaction containing the conditional state update, boarded-student confirmation, and audit-log creation.
- Student pickup status updates include tenant, assigned driver, active trip and student predicates in the write query.
- Database-level race verification is still required after PostgreSQL becomes available; unit mocks prove control flow, not PostgreSQL lock/index behavior.

## Query and performance review

- Lists use bounded pagination in structure, students, employees, assignments and notifications.
- Driver/student trip reads use targeted relation includes rather than per-row loops.
- A prior optional query-count integration suite exists for N+1 detection, but its four tests were skipped because the database was unavailable.
- `TripService.listTrips` is not paginated and can grow without bound; add date/status filters and pagination before large production use.
- Realtime locations are not written to PostgreSQL, avoiding a high-frequency write burden but also providing no durable history.

## Migration verification commands and outcomes

| Check | Result |
| --- | --- |
| `npm run prisma:generate` | PASS |
| `npm run prisma:validate` | PASS |
| TCP `localhost:5432` | FAIL / unreachable |
| `prisma migrate status` | PASS — 12 migrations, schema up to date |
| `npm run db:check-constraints` | PASS — 8 partial indexes, 1 unique index, 5 CHECK constraints |
| DB integration tests | PASS — 4/4 plus two real-database E2E journeys |

Before deployment, take a recoverable backup, run duplicate/conflict preflight queries, apply migrations in staging, run the raw-constraint check, seed synthetic staging data, and execute the DB integration/concurrency suite. No production migration was attempted by this audit.
