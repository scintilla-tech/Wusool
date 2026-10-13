# WUSOOL Role-by-Role UI Test Record

**Execution date:** 2026-10-12
**Environment:** Local Windows host, Flutter Web at `http://127.0.0.1:8080`, backend/API and Socket.IO at `http://127.0.0.1:3100`, PostgreSQL 16 in Docker
**Data classification:** Synthetic demo data only

## Scope and evidence

This record covers an interactive browser session through every seeded WUSOOL role. Actions were performed through the rendered Flutter application. API request logs and direct read-only PostgreSQL queries were used to verify critical persistence. Representative screenshots were captured and displayed in the Codex session for the student tracking map, supervisor views, university administration views, platform tenant view, and completed driver-trip state.

A full-screen video walkthrough is stored at `docs/evidence/WUSOOL_ROLE_WALKTHROUGH_2026-10-12.mp4`. It is a silent 1920×1080 H.264 recording with a duration of 14 minutes 25 seconds. The recording shows the student, driver, supervisor, field-supervisor, university-administrator, and platform-administrator interfaces, including the complete trip lifecycle. Password fields remain visually masked. SHA-256: `8DA1B724D6DF48AE6D8F7DDF78581A9C115D4D86EBEE2E3693F0DD58E1239D49`.

The temporary automation-only password used while driving the UI was removed after testing. The database was reseeded from the existing ignored `backend/.env.demo.local` file, and no password is reproduced in this report. All six restored accounts were then authenticated against the live local API and returned HTTP 200 with the expected role.

## Result summary

| Role | Login | Main capabilities exercised | Result |
|---|---:|---|---|
| Student | PASS | Assignment/trip view, attendance state, absence action, live tracking before and during a trip, profile, logout | PASS with one UI error-handling defect |
| Driver | PASS | Assigned trip, trip start, student pickup states, real Socket.IO location publication using the simulator, trip completion, logout | PASS |
| Supervisor | PASS | Assigned-bus active trip, attendance totals, refresh, logout | PASS |
| Field supervisor | PASS | Fleet-wide bus/trip visibility, active-trip totals, refresh, logout | PASS |
| University administrator | PASS | Dashboard metrics, student inventory, bus inventory, manual refresh, logout | PASS with one initial-loading defect |
| Platform super administrator | PASS | Platform-scope login without tenant code, tenant inventory, refresh, logout | PASS |

## Student journey

Account suffix: `101`; tenant code: `KSU`.

- Authentication succeeded and opened the student shell.
- The assigned North Loop route, KSU-1003 bus, and current trip information were visible.
- Attendance showed the seeded state for the current day.
- Selecting absence after the configured cutoff correctly produced backend HTTP 422, but the UI did not display the server error and left the action looking available. This is a confirmed presentation/interaction defect, not a backend acceptance failure.
- Before trip start, tracking showed the waiting state.
- After the driver started the trip and a real Socket.IO location event was published through the local backend, the student tracking screen displayed the OpenStreetMap view, the active North Loop/KSU-1003 label, and the bus marker.
- Profile data rendered successfully. Driver/supervisor contact actions and account deletion were visibly unavailable in this implementation rather than pretending to work.
- Logout succeeded.

## Driver journey

Account suffix: `102`; tenant code: `KSU`.

- Authentication succeeded and showed the scheduled North Loop trip with bus KSU-1003 and five students.
- Starting the trip succeeded and changed the trip to `IN_PROGRESS`.
- Pickup status updates were exercised through `NOT_READY`, `MISSED`, and `BOARDED`; the final state rendered correctly.
- Two students were left in `BOARDED` state and three in `WAITING` for persistence verification.
- A simulated GPS point (`24.75`, `46.6`) was sent through the real backend and Socket.IO path. The backend reported a successful broadcast, and the student UI received/rendered the active bus location. This was simulator validation, not a physical-device GPS test.
- Ending the trip succeeded. The UI transitioned to `لا توجد رحلة مجدولة اليوم`.
- PostgreSQL verification immediately after completion showed:
  - trip `demo-trip-nejood`: `COMPLETED`;
  - `startedAt` and `completedAt` populated;
  - two `BOARDED` and three `WAITING` trip-student records.
- Logout succeeded.

## Supervisor journey

Account suffix: `103`; tenant code: `KSU`.

- Authentication succeeded.
- The supervisor saw only the assigned KSU-1003 active trip.
- The view showed five students, two boarded, zero delayed/not-ready, and zero missed at the time of observation.
- Refresh and logout succeeded.

## Field supervisor journey

Account suffix: `104`; tenant code: `KSU`.

- Authentication succeeded.
- The view listed all four buses in the operational scope.
- KSU-1003 showed the active trip and the other three buses showed no current trip.
- Fleet totals reflected five students and two boarded students.
- Refresh and logout succeeded.

## University administrator journey

Account suffix: `105`; tenant code: `KSU`.

- Authentication succeeded.
- Dashboard refresh returned and displayed four buses, two routes, nine students, three drivers, two supervisors, and one trip for the day.
- Student inventory refresh returned nine student rows.
- Bus inventory refresh returned four bus rows.
- Logout succeeded.

Observed defect: the first concurrent preload of the dashboard, student list, and bus list was aborted by the client lifecycle, leaving the panes on loading indicators. Manual refresh recovered every pane and the backend returned HTTP 200. The initial loading state needs a client-side retry/lifecycle fix.

## Platform super administrator journey

Account suffix: `106`; tenant code intentionally blank.

- Authentication succeeded only when the university code was cleared, as required for the platform-scoped account.
- The platform view displayed King Saud University (`KSU`) with 17 users and four buses.
- Tenant-list refresh and logout succeeded.
- The login form defaults the tenant field to `KSU`; platform administrators must explicitly clear it. This is functional but easy to miss.

## Confirmed defects and limitations

| Severity | Finding | Evidence | Current workaround |
|---|---|---|---|
| Medium | Attendance cutoff failure is silent in the student UI | Backend returned HTTP 422 while the screen showed no error | Disable the action after cutoff or render the backend message |
| Medium | Initial university-admin preloads can be aborted and remain in loading state | First requests were aborted; all three manual refreshes returned HTTP 200 | Use the refresh action |
| Low | Platform login defaults to tenant `KSU` although the platform account requires no tenant | Login with `KSU` returned 401; clearing it returned 200 | Clear the university-code field |
| Limitation | Physical-device GPS permission and native background location were not exercised | Browser session used the real API/Socket.IO path with simulated coordinates | Validate separately on an Android/iOS device |
| Limitation | Push delivery, OTP, and document storage providers were not externally verified | External production credentials were intentionally not used | Keep local providers separated from production configuration |

## Cleanup and final state

After recording the completed-trip database state, the synthetic seed was restored using the original ignored local credential file.

Final PostgreSQL state:

- PostgreSQL container: healthy.
- `demo-trip-nejood`: `SCHEDULED`.
- `startedAt` and `completedAt`: unset.
- Trip students: five `WAITING`.
- Original synthetic credentials: HTTP 200 for all six expected roles.
- Browser: logged out at the WUSOOL login screen.
- Local Flutter web server, backend API, Socket.IO server, and PostgreSQL were left running for personal testing.
