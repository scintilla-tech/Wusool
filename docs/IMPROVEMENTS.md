# WUSOOL Improvements Applied

Audit date: 2026-10-12

## P0/P1 repairs

| Root cause | Repair | Regression evidence |
| --- | --- | --- |
| Socket clients were never joined to authorized trip rooms | Added fresh DB-authenticated, role/assignment-derived trip-room membership | `sockets.test.ts` |
| Any authenticated socket could attempt GPS publication | Restricted publication to Driver, validated payload/timestamp, rechecked active assigned trip | socket/location tests |
| Existing JWT remained usable after tenant suspension | Authentication middleware now requires an active tenant | auth route test |
| No user-wide session revocation endpoint | Implemented authenticated `POST /auth/logout-all` | auth route test |
| Concurrent trip state changes could both succeed | Conditional updates and transactional completion/audit | `phase5.test.ts` |
| Trip creation did not require the driver/bus assignment or reject active conflicts | Exact active assignment check, preflight conflict detection, DB partial unique indexes | trip service tests + migration |
| Driver attendance update had a check/write authorization window | Moved tenant/driver/trip/student conditions into the update predicate | service tests/typecheck |
| One push provider token could belong to multiple users | Globally unique token plus ownership-transferring upsert | device route test + migration |
| Long-lived sockets retained stale assignment/user access | JWT-expiry disconnect, periodic/per-publish authorization refresh, trip-only rooms and completion room removal | Socket resolver + real client/server test |
| Student REST tracking exposed same-route trips without membership | Require an explicit `TripStudent` relation before returning trip/location | privacy regression test |
| Manual completion did not notify Socket clients | Shared in-process trip event bus for manual and geofence completion | lifecycle event test |
| Refresh rotation could mint for a disabled tenant or strand a client on create failure | Tenant-state check and transactional revoke/replace | auth regression suite |

## P2 reliability and UX repairs

- Student coordinates must be supplied as a complete latitude/longitude pair on create and update.
- Socket location payloads include client timestamps and reject implausibly stale/future events.
- The driver client resumes location sharing when reopening an active trip and stops sharing on completion.
- The student tracking client subscribes to authorized live location/completion events and displays data freshness.
- Visible contact and account-deletion actions that had no implementation are now explicitly disabled with honest “unavailable” behavior.
- Concurrent mobile `401` responses share one refresh operation, preventing refresh-token rotation races from revoking a valid session.
- All 73 routes are captured in an executable source-of-truth inventory.
- Added independent OUTBOUND/RETURN attendance sessions, immutable attendance audit records, driver-assisted registration, and atomic driver closure without changing trip completion state.
- Attendance Socket.IO changes now go only to the affected student's user room and authorized staff-only trip rooms; closure notifications remain available to the affected trip room.

## Toolchain hardening

- Upgraded vulnerable proxy, upload, IP parsing, Vitest/Vite, source-map and brace-expansion dependencies.
- Pinned patched `deepmerge-ts` 8.0.2 transitively; verified Prisma client generation and schema validation afterward.
- Final `npm audit` result: zero known vulnerabilities.

## Files intentionally not changed

- The existing visual language and architecture were preserved.
- No production configuration, deployment target, external service, or database data was changed.
- The pre-existing modification to `backend/.gitignore` was left untouched.
- Missing incident/reporting/settings domains were not invented without business rules.
