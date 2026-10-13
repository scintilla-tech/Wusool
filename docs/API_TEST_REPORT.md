# WUSOOL API Inventory and Test Report

Audit date: 2026-10-12
Source of truth: Express route registrations and `backend/tests/endpoint.inventory.test.ts`

## Result summary

| Measure | Result |
| --- | --- |
| Discovered HTTP endpoints | 73 |
| Endpoints exercised by the inventory suite | 73 |
| Inventory assertions | 192 passed / 0 failed / 0 skipped |
| Real database verification | Critical transportation lifecycle PASS; full administrative CRUD success paths remain partial |
| Socket events | client/server `trip:location`; server `trip:arrived`, `trip:completed`, `trip:error`, `attendance:changed`, `attendance:closed`; staff-only attendance payload isolation and Flutter-web simulated-GPS flow passed; real-device flow not run |

The maintained matrix is compared against route declarations extracted from all mounted route source files, so route drift fails the suite. Every route was checked for its unauthenticated/public-invalid-input behavior. Every protected route was checked with an expired JWT. Administrative, driver, supervisor, platform, assignment, structure, and managed-student routes were also checked with an authenticated student and returned `403`. These checks prove route registration and the outer authentication/RBAC boundary; they do **not** imply a successful state-changing request for all 73 routes.

PostgreSQL 16 was started locally, all 12 migrations were applied, and the full 325-test suite (25 files) passed with both DB and E2E gates enabled. The database-backed journeys validate student/driver separation, installation-scoped push-token deactivation, outbound and return attendance, optional finish time, driver assistance and closure, concurrency, audit persistence, trip start, GPS delivery and isolation, supervisor monitoring, administrator visibility, completion, and persistence.

Legend: `UA` = University Administrator; `PSA` = Platform Super Admin; `S` = Student; `D` = Driver; `SV` = Supervisor; `FSV` = Field Supervisor; `Any` = any active authenticated user. All normal JSON responses use `{ success: true, data }`; errors use `{ success: false, error: { code, message, details? } }`. `B` marks success paths not covered by the critical real-DB workflow; it no longer means PostgreSQL was unavailable. `P` means the available success and negative tests passed.

## Complete inventory

| Method and path | Handler / purpose | Access | Validated request | Database dependencies | Frontend consumer | Result |
| --- | --- | --- | --- | --- | --- | --- |
| GET `/health/live` | health router / process liveness | Public | none | none | deployment | P |
| GET `/health/ready` | health router / DB readiness | Public | none | `$queryRaw` | deployment | P (mock and live PostgreSQL) |
| POST `/api/v1/auth/login` | AuthController.login | Public, rate-limited | tenant code, phone, password | Tenant, User, RefreshSession | all login screens | P |
| POST `/api/v1/auth/refresh` | AuthController.refresh | Public, rate-limited | refresh token | RefreshSession, User, Tenant | API client | P |
| POST `/api/v1/auth/logout` | AuthController.logout | Public, rate-limited | refresh token, optional installation deviceId | RefreshSession, DeviceToken | API client | P |
| POST `/api/v1/auth/logout-all` | AuthController.logoutAll | Any | bearer token | User/Tenant auth lookup, RefreshSession | API client | P |
| GET `/api/v1/auth/me` | AuthController.me | Any | bearer token | User, Tenant | auth bootstrap | P |
| POST `/api/v1/students/register` | student self router / register | Public, rate-limited | strict registration schema; coordinates paired | Tenant, User, StudentProfile; mock OTP | student registration | B |
| POST `/api/v1/students/verify` | student self router / OTP verify | Public, rate-limited | userId, code | User; in-memory mock OTP | student registration | B |
| GET `/api/v1/students/me` | StudentSelfService.getMe | S | bearer token | User, StudentProfile | student profile | B |
| PATCH `/api/v1/students/me` | StudentSelfService.updateMe | S | strict profile schema; coordinates paired | User, StudentProfile | student profile | B |
| GET `/api/v1/students/me/trip` | StudentTripService.getTodayTrip | S | bearer token | StudentProfile, assignment, trip, location | tracking screen | B |
| GET `/api/v1/students` | StudentsService.list | UA | page, limit | User, StudentProfile | admin students | B |
| GET `/api/v1/students/:id` | StudentsService.get | UA | path id not schema-validated | User, StudentProfile | admin students | B |
| POST `/api/v1/students` | StudentsService.create | UA | strict student-create schema; coordinates paired | User, StudentProfile | admin students | B |
| PATCH `/api/v1/students/:id` | StudentsService.update | UA | strict update schema; coordinates paired | User, StudentProfile | admin students | B |
| DELETE `/api/v1/students/:id` | StudentsService.deactivate | UA | path id not schema-validated | User | admin students | B |
| GET `/api/v1/structure/branches` | StructureService.listBranches | UA | page, limit, active | Branch | admin | B |
| POST `/api/v1/structure/branches` | createBranch | UA | branch schema | Branch | admin | B |
| PATCH `/api/v1/structure/branches/:id` | updateBranch | UA | branch update | Branch | admin | B |
| DELETE `/api/v1/structure/branches/:id` | archiveBranch | UA | path id | Branch | admin | B |
| GET `/api/v1/structure/neighborhoods` | listNeighborhoods | UA | page, limit, active | Neighborhood | admin | B |
| POST `/api/v1/structure/neighborhoods` | createNeighborhood | UA | neighborhood schema | Neighborhood | admin | B |
| PATCH `/api/v1/structure/neighborhoods/:id` | updateNeighborhood | UA | neighborhood update | Neighborhood | admin | B |
| DELETE `/api/v1/structure/neighborhoods/:id` | archiveNeighborhood | UA | path id | Neighborhood | admin | B |
| GET `/api/v1/structure/buses` | listBuses | UA | page, limit, active | Bus | admin buses | B |
| POST `/api/v1/structure/buses` | createBus | UA | bus schema | Bus | admin | B |
| PATCH `/api/v1/structure/buses/:id` | updateBus | UA | bus update | Bus | admin | B |
| DELETE `/api/v1/structure/buses/:id` | archiveBus | UA | path id | Bus | admin | B |
| GET `/api/v1/structure/routes` | listRoutes | UA | page, limit, active | Route, RouteNeighborhood | admin | B |
| GET `/api/v1/structure/routes/:id` | getRoute | UA | path id | Route, stops | admin | B |
| POST `/api/v1/structure/routes` | createRoute | UA | route schema | Route | admin | B |
| PATCH `/api/v1/structure/routes/:id` | updateRoute | UA | route update | Route | admin | B |
| DELETE `/api/v1/structure/routes/:id` | archiveRoute | UA | path id | Route | admin | B |
| PUT `/api/v1/structure/routes/:id/stops` | setRouteStops | UA | ordered stops schema | Route, Neighborhood, RouteNeighborhood | admin | B |
| GET `/api/v1/employees` | EmployeesService.list | UA | role, page, limit | User and role profile | admin | B |
| GET `/api/v1/employees/:id` | EmployeesService.get | UA | path id | User and role profile | admin | B |
| POST `/api/v1/employees` | EmployeesService.create | UA | employee schema | User and role profile | admin | B |
| PATCH `/api/v1/employees/:id` | EmployeesService.update | UA | employee update | User and role profile | admin | B |
| DELETE `/api/v1/employees/:id` | EmployeesService.deactivate | UA | path id | User | admin | B |
| GET `/api/v1/attendance/today` | AttendanceService.getTodayForUser | S | bearer token | StudentProfile, AttendanceIntent | student attendance | B |
| PUT `/api/v1/attendance/today` | AttendanceService.setIntentForUser | S | intent, optional note | StudentProfile, AttendanceIntent | student attendance | B |
| PUT `/api/v1/attendance/today/:direction` | AttendanceService.setIntentForUser | S | OUTBOUND/RETURN, intent, optional note/finish time | AttendanceSession, AttendanceIntent, AttendanceAudit | student attendance | P |
| GET `/api/v1/assignments/students` | listStudentAssignments | UA | page, limit | StudentAssignment | admin | B |
| POST `/api/v1/assignments/students` | assignStudent | UA | assignment schema | StudentProfile, Bus, Route, assignment | admin | B |
| DELETE `/api/v1/assignments/students/:studentProfileId` | unassignStudent | UA | path id | StudentAssignment | admin | B |
| GET `/api/v1/assignments/drivers` | listDriverAssignments | UA | page, limit | DriverAssignment | admin | B |
| POST `/api/v1/assignments/drivers` | assignDriver | UA | assignment schema | DriverProfile, Bus, assignment | admin | B |
| DELETE `/api/v1/assignments/drivers/:busId` | unassignDriver | UA | path id | DriverAssignment | admin | B |
| GET `/api/v1/assignments/supervisors` | listSupervisorAssignments | UA | page, limit | SupervisorBusAssignment | admin | B |
| POST `/api/v1/assignments/supervisors` | assignSupervisor | UA | assignment schema | supervisor profile, Bus, assignment | admin | B |
| DELETE `/api/v1/assignments/supervisors/:busId` | unassignSupervisor | UA | path id | SupervisorBusAssignment | admin | B |
| GET `/api/v1/trips` | TripService.listTrips | UA | bearer token | DailyTrip and relations | admin | B |
| POST `/api/v1/trips` | TripService.createTrip | UA | trip schema | DailyTrip, Bus, Route, DriverProfile, assignments | admin | B |
| GET `/api/v1/driver/today` | TripService.getDriverToday | D | bearer token | DriverProfile, DailyTrip, TripStudent | driver | B |
| GET `/api/v1/driver/today/trips` | AttendanceService.getDriverTodayTrips | D | bearer token | DailyTrip, AttendanceSession, TripStudent | driver attendance | P |
| PUT `/api/v1/driver/:tripId/attendance/:studentProfileId` | AttendanceService.setIntentByDriver | D, assigned driver only | intent, optional note/finish time | AttendanceSession, AttendanceIntent, AttendanceAudit | driver roster | P |
| POST `/api/v1/driver/:tripId/attendance/close` | AttendanceService.closeByDriver | D, assigned driver only | `{ confirm: true }` | AttendanceSession, Notification, AuditLog | driver roster | P |
| POST `/api/v1/driver/:tripId/start` | TripService.startTrip | D | path tripId | DriverProfile, DailyTrip | driver | B |
| PATCH `/api/v1/driver/:tripId/students/:studentProfileId` | setStudentStatus | D | status enum | DailyTrip, TripStudent | driver | B |
| POST `/api/v1/driver/:tripId/complete` | completeTrip | D | path tripId | DailyTrip, TripStudent, AuditLog | driver | B |
| GET `/api/v1/supervisor/buses` | SupervisorService.getMyBuses | SV, FSV | bearer token | supervisor profile/assignments, buses/trips | supervisor | B |
| GET `/api/v1/admin/dashboard` | AdminService.getDashboard | UA | bearer token | aggregate tenant tables | admin dashboard | B |
| GET `/api/v1/platform/tenants` | PlatformService.listTenants | PSA | bearer token | Tenant | platform admin | B |
| POST `/api/v1/platform/tenants` | PlatformService.createTenant | PSA | tenant schema | Tenant | platform admin | B |
| PATCH `/api/v1/platform/tenants/:id` | PlatformService.updateTenant | PSA | tenant update | Tenant | platform admin | B |
| POST `/api/v1/devices` | device router / register or transfer token | Any | token, platform, deviceId | User/Tenant auth lookup, DeviceToken | mobile bootstrap | B |
| DELETE `/api/v1/devices` | device router / deactivate current installation token(s) | Any | bearer token, deviceId | User/Tenant auth lookup, DeviceToken | logout fallback | P |
| GET `/api/v1/notifications` | NotificationService.listMine | Any | page, limit | Notification | notifications | B |
| PATCH `/api/v1/notifications/:id/read` | markRead | Any | path id | Notification (owner-scoped) | notifications | B |
| POST `/api/v1/documents` | DocumentsService.upload | Any tenant user | multipart file <=10 MiB, documentType | UserDocument; local storage | registration/profile | B |
| GET `/api/v1/documents/:id/url` | getSignedUrl | Any tenant user, object-authorized | path id | UserDocument | documents | B |
| GET `/api/v1/documents/:id/file` | readAuthorized | Any tenant user, object-authorized | path id | UserDocument; local storage | documents | B |

## Scenario coverage

| Scenario | Evidence | Result |
| --- | --- | --- |
| Valid request | Focused auth, schema, service, socket and real-DB lifecycle tests; not every administrative mutation | PASS for the critical lifecycle; partial for the full CRUD surface |
| Missing authentication | All protected endpoints in inventory | PASS |
| Invalid/expired authentication | All protected endpoints use an expired signed JWT | PASS |
| Insufficient permissions | Role-sensitive routes tested with authenticated student | PASS for tested role boundary |
| Invalid/missing fields | Public auth/register/verify and focused Zod tests | PASS where covered; path-id validation inconsistent |
| Nonexistent resources | Focused service tests | Partial |
| Duplicate submissions | Refresh reuse, attendance upsert, trip completion/concurrency tests | Partial |
| Unauthorized resource access | Tenant/object service tests plus real-DB driver and socket isolation | PASS for the critical lifecycle |
| Database errors | readiness and error mapping mocks; healthy live database path | Partial; destructive live fault injection not run |
| Concurrent requests | conditional trip start/completion tests and applied DB constraints | PASS in bounded automated coverage |
| Pagination/filtering/sorting | Pagination schemas and service tests | Partial; no universal sorting contract |
| Malformed/unexpected payloads | strict Zod schemas and global JSON error handling | Partial |

## Error-contract observations

- Missing/expired authentication consistently returns `401`; known role mismatch returns `403`.
- Zod failures are normalized to `400 VALIDATION_ERROR`.
- Unknown tenant-scoped objects are generally returned as `404`, reducing cross-tenant enumeration.
- Most `:id` path parameters are not validated as CUIDs at the router boundary; this remains a P2 consistency issue.
- Binary document success is intentionally not JSON and returns the stored MIME type.
