# WASL — Implementation Roadmap

This is the living implementation plan for WASL (multi-tenant university female transportation automation SaaS). Each phase is documented in `docs/phases/PHASE_X.md` and implemented following the workflow in `AGENTS.md`.

## Status legend
- ✅ VERIFIED — implemented, reviewed, and independently audited
- 🚧 IN PROGRESS — currently being implemented
- ⬜ PLANNED — not started

## Backend phases

| Phase | Title | Status | Notes |
| --- | --- | --- | --- |
| 1 | Backend Foundation | ✅ VERIFIED | Express + TS + Prisma + Zod + Helmet + CORS + logging + errors + health + schema/migrations |
| 2 | Authentication & Authorization | ⬜ PLANNED | Argon2id, short access JWT + rotating refresh sessions, role-based authZ, tenant-context middleware, endpoint rate limiting |
| 3 | Tenants, Users & Identity | ⬜ PLANNED | Tenant provisioning, user CRUD, role profiles (student/driver/supervisor/field-supervisor), sensitive-field DTOs |
| 4 | Transportation Master Data | ⬜ PLANNED | Branches, neighborhoods, routes, route stops, buses |
| 5 | Assignments | ⬜ PLANNED | Active StudentAssignment / DriverAssignment / SupervisorBusAssignment with transactional service logic + partial-index constraints |
| 6 | Trips & Attendance | ⬜ PLANNED | DailyTrip, AttendanceIntent, TripStudent (WAITING/BOARDED/NOT_READY/MISSED), boarding flow |
| 7 | Notifications | ⬜ PLANNED | Provider abstraction (FCM / Huawei Push / APNs), device tokens |
| 8 | Realtime (Socket.IO) | ⬜ PLANNED | Socket auth + resource authorization, driver GPS during ACTIVE morning trips (3-min interval), location privacy |
| 9 | Maps & Geofence | ⬜ PLANNED | Maps provider abstraction, local Haversine arrival geofence, validated arrival/dwell auto-completion |
| 10 | Reports & Audit | ⬜ PLANNED | Historical reports, audit trail surfacing |

## Mobile phase

| Phase | Title | Status | Notes |
| --- | --- | --- | --- |
| M1 | Flutter + Riverpod apps | ⬜ PLANNED | Student / Driver / Supervisor apps (starts after core backend phases) |

## Phase boundaries

- Each phase is implemented, tested, reviewed (reviewer + security-reviewer where applicable), fixed, re-tested, and committed before the next begins.
- Phases that touch auth, tenant isolation, sensitive data, sockets, storage, or security MUST also pass the security-reviewer.
- Cross-tenant composite foreign keys and `DeviceToken`/`Notification`/`UserDocument`/`AuditLog` tenantId derivation are **Phase 2+ preconditions** (documented in `backend/README.md`).
- Redis is introduced only when multi-instance deployment needs distributed rate limiting / Socket.IO adapter / distributed state.
