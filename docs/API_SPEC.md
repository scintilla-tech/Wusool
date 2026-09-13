# WASL — REST API Specification

Base: `/api/v1`. JSON. `Authorization: Bearer <accessToken>`. Responses: `{ success, data | error: { code, message, details? } }`.

## Conventions

- Routes → controllers → services → Prisma (repositories where useful). Avoid over-abstraction.
- Strict Zod validation (reject unexpected properties). Idempotency for retry-prone operations (e.g., attendance intent upsert, device-token register).
- Pagination: `page` (default 1), `limit` (default 20, max 100); response `{ items, page, limit, total }`.
- Tenant scoping from `req.auth`; object-level authorization in services.
- Never return `passwordHash`, `tokenHash`, `nationalIdOrIqama`, `documentKey`, or student home coordinates in ordinary responses.

## Endpoint Catalog

### Auth (public / bearer)
- `POST /api/v1/auth/login` — `{tenantCode, phone, password}`
- `POST /api/v1/auth/refresh` — `{refreshToken}`
- `POST /api/v1/auth/logout` — `{refreshToken}`
- `POST /api/v1/auth/logout-all` — bearer
- `GET  /api/v1/auth/me` — bearer

### Student (STUDENT)
- `POST /api/v1/students/register` — public registration (OTP verification step)
- `POST /api/v1/students/verify` — OTP verify
- `GET/PATCH /api/v1/students/me` — profile (phone, home location, branch where allowed)
- `POST /api/v1/students/me/delete-request` — delete account request
- `PUT  /api/v1/attendance/today` — set intent (ATTENDING/ABSENT) before cutoff
- `GET  /api/v1/attendance/today` — current intent
- `GET  /api/v1/students/me/trip` — current trip status + latest bus location

### Employees (UNIVERSITY_ADMIN)
- `GET/POST /api/v1/employees/drivers`, `GET/PATCH/DELETE /api/v1/employees/drivers/:id`
- `GET/POST /api/v1/employees/supervisors`, `.../:id`
- `GET/POST /api/v1/employees/field-supervisors`, `.../:id`
- `GET/POST /api/v1/students`, `GET/PATCH/DELETE /api/v1/students/:id`

### Structure (UNIVERSITY_ADMIN)
- branches, neighborhoods, routes (+ route stops), buses — full CRUD

### Assignments (UNIVERSITY_ADMIN)
- `POST/DELETE /api/v1/assignments/students` — active student assignment
- `POST/DELETE /api/v1/assignments/drivers` — active driver→bus
- `POST/DELETE /api/v1/assignments/supervisors` — active supervisor→bus

### Trips (DRIVER / SUPERVISOR / ADMIN)
- `GET /api/v1/driver/today` — assigned trip + students (ATTENDING only)
- `POST /api/v1/trips/:id/start` — driver starts trip
- `GET /api/v1/trips/:id/students` — trip students + statuses
- `PATCH /api/v1/trips/:id/students/:studentId` — set WAITING/BOARDED/NOT_READY/MISSED
- `POST /api/v1/trips/:id/complete` — manual completion (authorized, audited)
- `GET /api/v1/trips/:id` — trip detail

### Supervisor / Field Supervisor
- `GET /api/v1/supervisor/buses` — assigned buses + trip states
- `GET /api/v1/supervisor/trips/:id` — trip overview (attending/boarded/missed)
- `POST /api/v1/field/incidents` — incident recording
- `POST /api/v1/field/stops/:id/confirm` — stop/operational confirmation

### Platform Admin (PLATFORM_SUPER_ADMIN)
- `GET/POST /api/v1/platform/tenants`, `GET/PATCH /api/v1/platform/tenants/:id` (status, config)

### Devices / Notifications / Docs / Audit
- `POST /api/v1/devices` — register device token
- `GET /api/v1/notifications` — list mine
- `POST /api/v1/documents` (multipart) / `GET /api/v1/documents/:id/url` — metadata + signed URL
- `GET /api/v1/audit` — authorized audit listing

## Response Codes

- 200 ok, 201 created, 400 validation, 401 unauthenticated, 403 forbidden, 404 not found, 409 conflict (e.g., active assignment exists), 422 domain violation, 429 rate limited, 500 internal (generic).
