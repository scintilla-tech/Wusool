# PHASE 1 — Backend Foundation

> **STATUS: VERIFIED** (independent audit passed — see commit history / ROADMAP.md).

Phase 1 is **BACKEND FOUNDATION ONLY**. It establishes the project skeleton, database schema, security middleware, and foundation tests. No business logic, no Flutter, no auth/OTP, no trips/attendance, no sockets/GPS.

## 1. Approved Scope

- backend project structure
- Node.js + TypeScript
- Express
- PostgreSQL
- Prisma
- Zod
- Helmet
- strict CORS
- environment validation
- structured logging
- request IDs
- centralized errors
- 404 handling
- health endpoints
- Prisma schema
- Prisma migrations
- required raw partial unique indexes
- validation utilities
- basic foundation tests

## 2. Backend Directory

```
backend/
  prisma/
    schema.prisma
    migrations/
  src/
    config/
    modules/
    middlewares/
    providers/
    sockets/
    validation/
    utils/
    types/
    app.ts
    server.ts
  tests/
  .env.example
  package.json
  tsconfig.json
  README.md
```

The structure may be improved without violating the modular-monolith architecture.

## 3. Database Models

Tenant, User, StudentProfile, DriverProfile, SupervisorProfile, FieldSupervisorProfile, Branch, Neighborhood, Route, RouteNeighborhood, Bus, StudentAssignment, DriverAssignment, SupervisorBusAssignment, AttendanceIntent, DailyTrip, TripStudent, DeviceToken, Notification, UserDocument, AuditLog, RefreshSession.

### Requirements

- `SupervisorProfile` and `FieldSupervisorProfile` must be explicitly modeled.
- Employee-related fields where appropriate: `firstName`, `lastName`, `phone`, `employeeId`, `nationalIdOrIqama`, `nationality`, `joinDate`, `iqamaExpiry`, `employmentStatus`.
- `PLATFORM_SUPER_ADMIN`: `tenantId` nullable.
- All university roles: `tenantId` required by application/domain invariant.
- Student home coordinates: sensitive and excluded from ordinary DTO exposure.
- IDs and phone numbers are Strings. Phone normalized to Saudi format where applicable.
- National ID/Iqama is HIGHLY SENSITIVE and never exposed in normal DTOs.

## 4. Active Assignment Constraints

PostgreSQL raw partial unique indexes:

- `StudentAssignment`: unique active assignment on `tenantId + studentId` where `isActive = true`.
- `DriverAssignment`: unique active assignment on `tenantId + busId` where `isActive = true`.
- `SupervisorBusAssignment`: unique active assignment on `tenantId + busId` where `isActive = true`.

Prisma cannot be falsely claimed to represent partial unique indexes — they MUST be created via raw PostgreSQL migration.

Cross-tenant FK safety is addressed through tenant-aware queries/constraints/service validation as appropriate (application-layer isolation; RLS is deferred).

## 5. Environment

At minimum:

- `NODE_ENV`
- `PORT`
- `DATABASE_URL`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `CORS_ALLOWED_ORIGINS`

Provide `.env.example` only. Never create or expose real secrets.

## 6. Health Endpoints

- `GET /health/live` — process liveness.
- `GET /health/ready` — database readiness.

Do not leak database information.

## 7. Validation Utilities

UUID, email, Saudi phone, Arabic/English human names, latitude, longitude, dates, pagination.

## 8. Quality Checks

Actually run where available:

- install
- Prisma format
- Prisma validate
- TypeScript typecheck
- lint
- tests
- development server
- `/health/live`
- `/health/ready`

Migrations must target DEVELOPMENT ONLY.

If PostgreSQL / `DATABASE_URL` is unavailable, do not fabricate successful migration/readiness results. Report the exact blocker.

## 9. Tests (minimum)

- application startup
- environment validation
- `/health/live`
- `/health/ready`
- centralized error handling
- invalid routes
- database connectivity behavior

## 10. Out of Scope (MUST NOT implement)

- Flutter
- login/authentication business logic
- OTP
- tenant provisioning workflows
- attendance business logic
- trips business logic
- Socket.IO tracking
- GPS tracking
- geofence implementation
- notification providers
- FCM
- Huawei Push
- maps
- reports

Scaffolding directories/interfaces are acceptable only where needed by the foundation.

## 11. Final Report Checklist

1. files created
2. files modified
3. final folder tree
4. reference repository patterns actually used
5. Prisma models created
6. migrations created
7. raw partial indexes
8. environment variables
9. security middleware
10. tests created
11. commands actually executed
12. exact test results
13. lint result
14. TypeScript result
15. Prisma format/validation result
16. health endpoint results
17. reviewer findings
18. security-reviewer findings
19. findings fixed
20. unresolved issues
21. architecture deviations
22. additional dependencies and justification

End exactly with:

```
PHASE 1 PASSED — READY FOR REVIEW
```

or

```
PHASE 1 FAILED — REVIEW REQUIRED
```
