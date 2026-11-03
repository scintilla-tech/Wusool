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
- `POST /api/v1/auth/activation/request` — `{tenantCode, phone}`; texts a 6-digit code to an account an admin added (no password yet). Always answers `{sent: true}`; development also returns `devOtp`
- `POST /api/v1/auth/activation/complete` — `{tenantCode, phone, code, password}`; sets the first password and signs in (same body as login)

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
- Accounts an admin creates have no password; the owner sets one through activation. Lists include `isActivated`.

### Adding people in bulk (UNIVERSITY_ADMIN)
Roles: `STUDENT`, `DRIVER`, `SUPERVISOR`, `FIELD_SUPERVISOR`. Rows are free-text values; checks return issues per row as `{field, code}`.
- `GET  /api/v1/imports/templates/:kind` — public header-only CSV (`students`, `drivers`, `supervisors`, `field-supervisors`)
- `POST /api/v1/imports/read-file` (multipart `file`, `role`, optional `name`) — reads .xlsx or .csv (≤ 2 MB, ≤ 1000 rows) into `{name, rows, issues, missingColumns}`; nothing is saved
- `POST /api/v1/imports/check` — `{role, rows}` → `{issues}`: formats, repeats within the list, values already in use
- `POST /api/v1/imports/submit` — `{role, rows, draftId?}` → `{created, rows, issues, draft}`; creates every row without issues, returns the rest, and with `draftId` keeps them in the draft (deleted once empty)
- `GET  /api/v1/imports/drafts?role=` — saved drafts; `POST /api/v1/imports/drafts` — `{role, name, rows}`
- `GET/PUT/DELETE /api/v1/imports/drafts/:id` — draft with rechecked issues / replace rows / delete

### People directory (UNIVERSITY_ADMIN)
The app's view of students and staff, one role at a time.
- `GET  /api/v1/people?role=&q=&status=&routeId=&busId=&page=&limit=` — newest first, 30 a page (≤ 100). `q`: every word must match a name, the email, the university or employee number, or the phone (typed `05…` or with Arabic digits). `status`: `all` (default), `active`, `pending` (no password yet), `disabled`, `unassigned` (not disabled and on no route or bus; not for field supervisors). `routeId` (students) and `busId` (drivers, supervisors) take an id or `none`. Returns `{items, page, limit, total, counts}`; `counts` has the total per status for the same search. Items carry `profileId` (for assignments), `number`, `isActivated`, and `route` or `bus`.
- `GET  /api/v1/people/:id` — the same plus `row`: the editable values as the add form shows them (phone as `05…`, dates as `YYYY-MM-DD`)
- `PUT  /api/v1/people/:id` — `{row}` replaces the details; optional values left out are cleared. → `{saved: true, person}` or `{saved: false, issues}` with the same issue codes as adding people (values in use are checked against other accounts only). Audited as `PERSON_UPDATED`.
- `POST /api/v1/people/:id/disable` — stops sign-in at once (open sessions included), revokes refresh tokens and push tokens, and ends the person's route or bus assignment. Audited as `PERSON_DISABLED`.
- `POST /api/v1/people/:id/enable` — lets the person sign in again; assignments are not restored. Audited as `PERSON_ENABLED`.

### Structure (UNIVERSITY_ADMIN)
- branches, neighborhoods, routes (+ route stops), buses — full CRUD; lists take `q` (search) and `active=true`
- Buses come with their current `driver` and `supervisor` (`{id, profileId, firstName, lastName, phone, isActive}` or null); `GET /api/v1/structure/buses/:id` returns one
- Routes come with `branch`, `routeNeighborhoods` in order and `studentCount`. `POST/PATCH /api/v1/structure/routes` take `stopIds` (neighborhood ids in visiting order; replaces every stop) in the same request
- `PATCH` with `isActive: false`, like `DELETE`, takes a bus or route out of service and ends its assignments (driver and supervisor; students). `isActive: true` returns it to service.
- Names of campuses (branches), routes and neighborhoods may contain digits. Taken plate numbers, route and campus codes answer `409 PLATE_TAKEN` / `409 CODE_TAKEN`; a second neighborhood with the same name (ignoring case) `409 NAME_TAKEN`.
- Campuses: `PATCH` clears `code`, `latitude`, `longitude` and `radius` with `null`. With all three location values set, a trip ends on its own when its bus enters the radius. Lists include `routeCount`.
- Neighborhoods list `routeCount` (routes in service stopping there).
- Buses take `routeId`: the **fixed route** the bus runs every school day (one bus per route, `409 ROUTE_TAKEN`; `null` clears it). Buses show `route`, routes show `bus`. Taking a bus or route out of service clears the link.

### Assignments (UNIVERSITY_ADMIN)
- `POST/DELETE /api/v1/assignments/students` — active student assignment; the branch defaults to the route's
- `POST /api/v1/assignments/students/batch` — `{routeId, studentProfileIds}` (≤ 500) puts students on a route; those on another route move, those already on it are left as they are → `{assigned}`. `422 INVALID_STUDENTS` when any is missing or disabled.
- `POST/DELETE /api/v1/assignments/drivers` — active driver→bus
- `POST/DELETE /api/v1/assignments/supervisors` — active supervisor→bus
- Disabled accounts cannot be assigned (`404`).

### Daily trips
- **Automatic:** every school day (Sunday–Thursday) that is not a holiday, at the university's time (default 05:30 Riyadh time), each bus in service with a driver and a fixed route gets its going and return trips (`origin: AUTOMATIC`), unless one already exists; its driver is notified (`TRIPS_READY`). When the driver reported that day off and the supervisor picked a cover, the trips are made with the cover (`coveredDriverProfileId` = the bus's driver) and the cover is notified; with no cover yet, the trips are made with the bus's driver and the supervisors are reminded (`COVER_NEEDED`). A driver whose bus has no fixed route is reminded to build it (`TRIP_NEEDED`). Each tenant's day runs once (`AutoTripRun`), whichever server gets there first; a server started after the time runs it at once. Trips carry the bus's supervisor.
- `GET/PATCH /api/v1/admin/settings` (UNIVERSITY_ADMIN) — `{autoTrips, autoTripTime}`; `autoTripTime` is `HH:MM` (24-hour, Riyadh). `PATCH {autoTrips: false}` pauses automatic trips. Audited.
- `GET/POST /api/v1/admin/holidays`, `PATCH/DELETE /api/v1/admin/holidays/:id` — the holiday calendar: `{name, startDate, endDate}` (`YYYY-MM-DD`, inclusive, ≤ 120 days, `422 INVALID_RANGE`). Lists holidays not over yet, with `days`. Audited.
- `GET /api/v1/driver/bus` — the driver's bus, its fixed `route` (with `branch` and `stops` in order), `today`'s trips on it, `autoTrips`, `autoTripTime` and today's `holiday` name if any
- **A driver's route:** a driver whose bus has no fixed route builds it once; it becomes the bus's fixed route and admins are notified to add students (`ROUTE_BY_DRIVER`). `GET /api/v1/driver/route-options` (campuses, neighborhoods), `POST /api/v1/driver/neighborhoods` (`{name}`), `POST /api/v1/driver/route` (`{name, branchId?, stopIds}` with at least one stop; `409 ROUTE_EXISTS`), `PATCH /api/v1/driver/route` (any of those; `409 NO_ROUTE`). Audited.
- `POST /api/v1/driver/trips` — `{direction}` creates today's trip on the driver's bus, on its fixed route (`origin: DRIVER`; `409 NO_ROUTE` before the route is built). `409 TRIP_EXISTS` when the bus has it already. A route has at most one trip per direction a day (`409 ROUTE_TRIP_EXISTS`).
- **Days off:** `GET /api/v1/driver/absences` (today onwards, with `coverName`), `POST /api/v1/driver/absences` (`{date, note?}` today to 60 days ahead; `409 ABSENCE_EXISTS`, `409 NO_SUPERVISOR`) notifies the bus's supervisors (`DRIVER_ABSENT`); `DELETE /api/v1/driver/absences/:id` takes it back until a cover is chosen (`409 COVER_CHOSEN`) and tells them (`ABSENCE_CANCELLED`).
- **Cover drivers** (SUPERVISOR of the bus; field supervisors `403`):
  - `GET /api/v1/supervisor/buses/:busId/drivers?date=` — drivers with their `bus`, `busy` directions, `current`, `regular` (the bus's own driver) and `absent` for that day (today by default). On a coming day, a driver who runs their own bus's fixed route or covers another bus is busy.
  - `POST /api/v1/supervisor/buses/:busId/cover` — `{driverProfileId, date?}`. Today: gives the bus's trips that have not started to that driver; trips remember the bus's own driver (`coveredDriverProfileId`); choosing the bus's own driver hands them back. A coming day (or today before its trips are made): sets the cover on the driver's reported day off (`409 NO_ABSENCE` without one) and that morning's trips are made with the cover. `409 DRIVER_BUSY`, `409 NO_TRIPS_TO_COVER`. The new driver, the previous one and the bus's own driver are notified (`COVER_ASSIGNED`, `COVER_CANCELLED`, `COVER_REPLACED`, `COVER_ENDED`). Audited.
  - `GET /api/v1/supervisor/buses` adds `regularDriverName`, `coverable` (trips not started), `drivers` (each trip's driver, going first), `absences` (days off from today, with `coverName`) and on `trip` the `driverName` / `coveredDriverName`.

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
- Notifications are kept for the in-app list: `GET /api/v1/notifications`, `GET /api/v1/notifications/unread-count`, `POST /api/v1/notifications/read-all`, `PATCH /api/v1/notifications/:id/read`. Push to phones goes through the push provider, a placeholder until FCM / Huawei / APNs credentials are configured.
- `POST /api/v1/devices` — register device token
- `GET /api/v1/notifications` — list mine
- `POST /api/v1/documents` (multipart) / `GET /api/v1/documents/:id/url` — metadata + signed URL
- `GET /api/v1/audit` — authorized audit listing

## Response Codes

- 200 ok, 201 created, 400 validation, 401 unauthenticated, 403 forbidden, 404 not found, 409 conflict (e.g., active assignment exists), 422 domain violation, 429 rate limited, 500 internal (generic).
