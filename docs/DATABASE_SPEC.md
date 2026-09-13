# WASL — Database Specification

Source of truth: PostgreSQL + Prisma. See `backend/prisma/schema.prisma` for the authoritative schema and `backend/prisma/migrations/` for migrations.

## 1. Conventions

- IDs and phone numbers are Strings, never numeric identifiers.
- Phone normalized to Saudi format (`+9665xxxxxxxx`).
- National ID/Iqama HIGHLY SENSITIVE — never exposed in DTOs.
- Student home latitude/longitude sensitive — excluded from ordinary DTOs.
- Tenant-aware uniqueness; application-layer tenant isolation (RLS deferred).
- One reusable PrismaClient per process; never per request.

## 2. Models

Tenant, User, StudentProfile, DriverProfile, SupervisorProfile, FieldSupervisorProfile, Branch, Neighborhood, Route, RouteNeighborhood, Bus, StudentAssignment, DriverAssignment, SupervisorBusAssignment, AttendanceIntent, DailyTrip, TripStudent, DeviceToken, Notification, UserDocument, AuditLog, RefreshSession.

Enums: Role, EmploymentStatus, AttendanceIntentType, TripStudentStatus, TripStatus, DevicePlatform.

## 3. Key Constraints

- `User @@unique([tenantId, phone])`, `@@unique([tenantId, email])`.
- Employee profiles `@@unique([tenantId, employeeId])`; `StudentProfile @@unique([tenantId, studentId])`; `Bus @@unique([tenantId, plateNumber])`.
- `User_role_tenant_check`: `role = 'PLATFORM_SUPER_ADMIN' OR tenantId IS NOT NULL` (raw SQL CHECK).
- History-bearing relations use `RESTRICT` (no cascade delete of trips/assignments/attendance).

## 4. Active Assignment Partial Indexes (raw SQL)

- `StudentAssignment (tenantId, studentProfileId) WHERE isActive = true`
- `DriverAssignment (tenantId, busId) WHERE isActive = true`
- `SupervisorBusAssignment (tenantId, busId) WHERE isActive = true`

Verified by `npm run db:check-constraints`.

## 5. Sensitive Fields

- `User.passwordHash`, `RefreshSession.tokenHash` — never returned.
- `DriverProfile/SupervisorProfile/FieldSupervisorProfile.nationalIdOrIqama` — never in lists/responses.
- `StudentProfile.homeLatitude/homeLongitude` — restricted to authorized consumers.
- `UserDocument.documentKey` — random private storage key, never returned.

## 6. Tenant Scoping

Every tenant-owned table carries `tenantId`. Services must scope all queries by `tenantId` from `req.auth`. Cross-tenant composite FKs are deferred (Phase 2+ preconditions in `backend/README.md`).

## 7. Migrations

Development-only migrations via `prisma migrate dev`. Never use destructive production reset. Raw SQL (partial indexes, CHECK) is drift-prone — guard with `db:check-constraints`.
