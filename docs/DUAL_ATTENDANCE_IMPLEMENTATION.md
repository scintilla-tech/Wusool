# WUSOOL Dual Attendance Implementation Report

Verified 13 October 2026 in `Asia/Riyadh` against local PostgreSQL 16, the rebuilt Express/Socket.IO backend, and the Flutter web client. No production resource was contacted.

## Delivered behavior

- OUTBOUND opens at 18:00 on the preceding Riyadh calendar day; RETURN opens at 11:00 on the operational day.
- Sessions, intents and closure state are direction-specific. No status is copied between directions.
- The assigned driver can register present/absent for roster members and close only that trip's attendance using **اكتمال التحضير**.
- Closure is a serializable conditional transition that records the driver and timestamp, rejects a second close, and prevents later attendance writes. It does not complete the trip.
- Every attendance write records student, session, new and prior state, actor, actor role, source and timestamp.
- OUTBOUND self-registration accepts an optional expected finish time; it may be changed or cleared while open and has no effect on RETURN attendance or trip state.
- `attendance:changed` is sent only to the affected student's user room and staff-only authorized trip rooms. `attendance:closed` is sent to authorized trip members and staff.

## Database migrations

- `20261012000000_dual_attendance_sessions`: adds direction, operational date, session status, closure metadata, actor/source metadata, finish time, audit history, constraints, indexes and safe legacy OUTBOUND backfill.
- `20261013000000_shorten_driver_direction_index_name`: gives the PostgreSQL driver/direction conflict index a stable non-truncated name.

Migration status: **12 migrations applied; schema up to date**. Constraint verification: **8 partial indexes, 1 unique index, 5 CHECK constraints**.

## API changes

| Method | Path | Result |
| --- | --- | --- |
| GET | `/api/v1/attendance/today` | Returns OUTBOUND and RETURN session views |
| PUT | `/api/v1/attendance/today/:direction` | Student direction-specific self-registration |
| GET | `/api/v1/driver/today/trips` | Assigned trips, sessions, totals and roster |
| PUT | `/api/v1/driver/:tripId/attendance/:studentProfileId` | Assigned-driver assisted registration |
| POST | `/api/v1/driver/:tripId/attendance/close` | Assigned-driver atomic closure with explicit confirmation |

Legacy `PUT /api/v1/attendance/today` remains compatible and defaults to OUTBOUND.

## Principal modified files

- Backend: `prisma/schema.prisma`, the two migrations above, `prisma/seed.ts`, `src/utils/date.ts`, `src/modules/attendance/*`, `src/modules/trips/{driver.routes.ts,trips.service.ts,trip-events.ts}`, `src/modules/supervisor/supervisor.service.ts`, `src/sockets/index.ts`.
- Flutter: `student/attendance_screen.dart`, `student/student_providers.dart`, `driver/driver_screen.dart`, `driver/driver_providers.dart`, `supervisor/supervisor_screen.dart`, `supervisor/supervisor_providers.dart`, `core/socket_service.dart`.
- Tests: `tests/e2e/dual-attendance.test.ts`, `tests/e2e/local-workflow.test.ts`, `tests/date.test.ts`, `tests/sockets.test.ts`, `mobile/test/attendance_models_test.dart`, endpoint inventory and constraint verifier.

## Executed evidence

| Check | Result |
| --- | --- |
| Backend typecheck / lint / production build | PASS / PASS / PASS |
| Complete backend + DB + E2E suite | **25 files, 325 tests passed, 0 failed, 0 skipped** |
| Endpoint inventory | **73/73 endpoints; 192 assertions passed** |
| PostgreSQL migration status | PASS — schema up to date |
| Raw constraint verification | PASS — 8 partial, 1 unique, 5 CHECK |
| Flutter analyze | PASS — no issues |
| Flutter tests | PASS — 7/7 |
| Flutter release web build | PASS |
| Interactive Flutter student/driver/supervisor walkthrough | PASS; real REST/PostgreSQL backend, no browser warnings/errors |

The database E2E specifically verifies both opening times, student registration with and without finish time, driver assistance, unrelated-student and unauthorized-driver denial, independent direction state, both closures, post-closure denial, concurrent close/write consistency, audit persistence, authorized Socket.IO delivery, and the existing GPS/trip lifecycle.

## Screenshots

- [Student dual sessions](evidence/attendance-student-dual-sessions.jpg)
- [Driver roster and assisted controls](evidence/attendance-driver-open-roster.jpg)
- [Closure confirmation and totals](evidence/attendance-driver-close-confirmation.jpg)
- [Closed roster while trip remains scheduled](evidence/attendance-driver-closed.jpg)
- [Supervisor direction-specific statistics](evidence/attendance-supervisor-stats.jpg)

## Remaining limitations

- The live walkthrough occurred before 11:00 Riyadh, so the UI correctly prevented live RETURN self-registration. The complete RETURN flow was executed with a controlled test clock against real PostgreSQL/REST/Socket.IO; this is not claimed as a real-device test.
- Physical Android/iOS GPS permissions, background execution and native secure-storage behavior remain blocked by local Android-license/toolchain availability.
- OTP, push delivery and durable document storage remain explicit local substitutes pending real provider contracts and credentials.
- Realtime event distribution remains in-process; multi-instance production requires a broker/Socket.IO adapter.
