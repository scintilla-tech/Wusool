# WASL — Testing Strategy

## Layers

- Unit tests (utils, services, validation).
- Integration tests (HTTP routes via supertest, with mocked or real Prisma).
- Authorization tests (role gates).
- Tenant-isolation tests (negative cross-tenant).
- Security/negative tests.
- Load tests (k6, Phase 16).

## Critical Tests (mandatory)

- Tenant A cannot access Tenant B resources: users, students, buses, routes, trips, assignments, documents, sockets.
- AttendanceIntent vs TripStudent distinction.
- ATTENDING-but-never-BOARDED student must NOT become transport-attendance-confirmed.
- Driver cannot publish location for another driver's trip.
- Location rejected when trip inactive.
- Geofence completion (arrival → auto-complete).
- Active assignment uniqueness (partial indexes + transactional logic).
- Disabled accounts rejected.
- Refresh token/session behavior (rotation, reuse).
- Mass-assignment rejection (strict Zod).

## Load Tests (k6)

Scenarios: ~400 active users, attendance actions, dashboards, ~200 buses, 3-min location updates, supervisor monitoring, auth, 1000-connection headroom. Do not run destructive load against production.

## Conventions

- `npm run test` is hermetic (no live DB required); DB-backed checks use the running dev PostgreSQL or mocks.
- Do not weaken tests to make them pass; do not remove security controls to fix tests.
