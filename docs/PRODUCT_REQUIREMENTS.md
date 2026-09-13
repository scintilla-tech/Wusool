# WASL — Product Requirements

## 1. Overview

وَصْل | WASL is a multi-tenant SaaS platform for university female transportation management. It replaces fragmented WhatsApp/paper workflows with structured registration, attendance intent, assignment, trip workflow, tracking, boarding status, supervision, notifications, and auditability.

## 2. Initial Scenario

- ~200 buses per university
- ~15 students per bus
- ~3,000 students
- Multiple universities (tenants) supported

## 3. Roles

| Role | Scope |
| --- | --- |
| PLATFORM_SUPER_ADMIN | Platform-level; `tenantId` may be null; manages tenants |
| UNIVERSITY_ADMIN | Tenant-level; manages branches/routes/buses/employees/students/assignments |
| STUDENT | Tenant-level; attendance intent, tracking, profile |
| DRIVER | Tenant-level; assigned bus/route/trip workflow |
| SUPERVISOR | Tenant-level; monitors assigned buses/trips |
| FIELD_SUPERVISOR | Tenant-level; mobile operational/incident workflow |

All university roles require `tenantId`. `PLATFORM_SUPER_ADMIN` never inherits a university scope.

## 4. Multi-Tenancy

- Shared backend, shared PostgreSQL, shared schema, `tenantId`-based isolation.
- Tenant context derived server-side from authentication; never trust `tenantId` from clients.
- Every tenant-owned query is tenant-scoped; object-level authorization; cross-tenant relations forbidden; tenant-aware unique constraints; automated negative cross-tenant tests.
- PostgreSQL RLS is DEFERRED and not claimed as active.

## 5. Core Domain Rules

- `AttendanceIntent` ∈ {ATTENDING, ABSENT} — a declaration, NOT proof of transportation.
- `TripStudent` ∈ {WAITING, BOARDED, NOT_READY, MISSED} — kept separate from intent.
- Only BOARDED students become TRANSPORT_ATTENDANCE_CONFIRMED after trip completion.
- Driver GPS is shared only during ACTIVE morning trips (~3 min interval).
- University arrival uses local Haversine geofence (no external Maps API).
- Auto-completion requires validated arrival samples/dwell logic.
- Historical data (attendance/trips/assignments/audit) is preserved.

## 6. Active Assignment Constraints

- One active `StudentAssignment` per student.
- One active `DriverAssignment` per bus.
- One active `SupervisorBusAssignment` per bus.
- Enforced via PostgreSQL partial unique indexes + transactional service logic.

## 7. MVP Scope (end-to-end vertical slice priority)

1. Auth (login/refresh/logout/me) — done in Phase 2.
2. University structure + employee/student management + assignments.
3. Student registration + attendance intent + tracking.
4. Driver trip workflow + TripStudent states.
5. Realtime tracking + geofence arrival.
6. Notifications (abstraction + mock provider).
7. Flutter apps (student + driver first, then supervisor/admin).

## 8. Non-Functional

- p95 reads <= 500ms, p95 writes <= 800ms (excluding external providers) — not claimed until load-tested.
- ~400 active users morning burst; ~1000 concurrent connection headroom.
- Location privacy is critical; no permanent high-frequency driver tracking.
