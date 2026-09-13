# WASL — Implementation Roadmap

Living plan for WASL (multi-tenant university female transportation SaaS). Each phase has a spec in `docs/phases/PHASE_X.md`. Workflow per `AGENTS.md`: PLAN → IMPLEMENT → FORMAT → TYPECHECK → LINT → TEST → REVIEW → SECURITY REVIEW → FIX → RETEST → COMMIT → CONTINUE.

## Status legend
✅ VERIFIED · 🚧 IN PROGRESS · ⬜ PLANNED

| Phase | Title | Status |
| --- | --- | --- |
| 1 | Backend Foundation | ✅ VERIFIED |
| 2 | Authentication + Tenant Context + Authorization | ✅ VERIFIED |
| 3 | University Structure + Users + Employee Management + Assignments | ✅ VERIFIED |
| 4 | Student Registration + Profile + Attendance Intent | ✅ VERIFIED |
| 5 | Trip Lifecycle + Driver Workflow + TripStudent | ✅ VERIFIED |
| 6 | Realtime Secure Tracking + Geofence | ✅ VERIFIED |
| 7 | Notifications + Device Management | ✅ VERIFIED |
| 8 | Flutter Foundation + Design System + Authentication | ✅ VERIFIED |
| 9 | Student Flutter Experience | ✅ VERIFIED |
| 10 | Driver Flutter Experience | ✅ VERIFIED |
| 11 | Supervisor + Field Supervisor Experience | ✅ VERIFIED |
| 12 | University Administration Experience | ✅ VERIFIED |
| 13 | Platform Administration | ✅ VERIFIED |
| 14 | Storage/Documents + Provider Integrations | ✅ VERIFIED |
| 15 | Full Security/Integration Audit | ✅ VERIFIED |
| 16 | Performance + k6 Load Testing + Optimization | 🚧 IN PROGRESS |
| 17 | Deployment Readiness + Documentation + Final QA | ⬜ PLANNED |

## Phase boundaries

- Each phase implemented, tested, reviewed (reviewer + security-reviewer where applicable), fixed, re-tested, committed before the next.
- Auth/tenant/sensitive-data/sockets/storage/security phases MUST also pass security-reviewer.
- Cross-tenant composite FKs and `DeviceToken/Notification/UserDocument/AuditLog` tenantId derivation are Phase 2+ preconditions (`backend/README.md`).
- Redis only when multi-instance deployment requires it.

## Vertical slice priority

Prioritize the first end-to-end vertical slice (student login → attendance intent → dashboard; driver login → trip → pickup list) before deep backend breadth. Begin Flutter as soon as the slice's backend exists.
