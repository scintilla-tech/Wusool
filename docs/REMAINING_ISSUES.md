# WUSOOL Remaining Issues

Audit date: 2026-10-12

## Release blockers

| Priority | Issue | Why it remains |
| --- | --- | --- |
| P0 (production only) | OTP and push are mocks; document storage is local | Real provider contracts/credentials and production storage policy are absent. Local substitutes are intentionally retained for the demonstration. |
| P1 | Native secure-storage/device validation outstanding | Tokens use `flutter_secure_storage`, but only the web target was launched; validate native Keychain/Keystore/Credential Locker behavior before mobile release. |
| P1 | No physical-device GPS/background test | Real REST/Socket.IO and simulated GPS passed through Flutter web, but permission, background, and reconnection behavior needs an Android/iOS device. |
| P1 | Single-instance realtime/OTP state | In-memory state loses data on restart and does not scale horizontally |
| P1 | Android licenses not accepted | `flutter doctor -v` otherwise passed, but Android SDK licenses blocked emulator/device validation on this host. |
| P1 | Windows ATL build component missing | Native Windows build reaches `flutter_secure_storage_windows` but fails on missing `atlstr.h`; install the matching Visual Studio C++ ATL component. |

## Functional gaps

- Emergency/incident reporting: no model, endpoint or UI; severity, escalation, recipients and retention are undefined.
- Trip history and durable GPS history: not implemented.
- ETA: no stable ETA endpoint/provider; only transient arrival sampling exists.
- Transportation schedule management: trip creation exists, but no recurring scheduling domain.
- Supervisor experience: bus list exists; no complete fleet map, incident queue or operational reporting workflow.
- Admin UI: dashboard and limited lists exist; backend CRUD is not exposed as a complete management experience.
- Reports/analytics/system settings: only aggregate dashboard counts exist.
- Account deletion request and driver/supervisor contact: requirements and workflows absent; controls are disabled rather than misleading.

## Technical debt

- Most route `:id` values lack strict CUID validation.
- `GET /trips` is not paginated.
- Tenant-specific timezones are not modeled; the current Saudi deployment explicitly uses `Asia/Riyadh` for attendance and date boundaries.
- Field Supervisor realtime scope needs a formal business definition.
- Student pickup status transition rules need clarification (for example, whether a driver may reverse `MISSED` to `BOARDED`).
- OpenStreetMap tiles are called directly; a configurable maps-provider abstraction and usage policy are absent.
- Flutter errors are still handled inconsistently across some screens.
- Logout-all revokes refresh sessions; already-issued access tokens and sockets remain valid only until their short JWT expiry unless the user/tenant is deactivated.
- Existing product/roadmap/API documents contain historical claims that should be reconciled with these evidence reports.

## Environment/external verification still outstanding

- Real notification, OTP, durable object-storage, and contracted map integrations (credentials/providers are unavailable).
- Physical-device GPS permissions, background behavior, and network interruption/reconnection.
- Android emulator run until the SDK licenses are accepted.
- Safe load tests beyond the bounded functional/concurrency suite.

The earlier database, migration, constraint, Flutter-analysis, Flutter-widget-test, and release-web-build blockers are resolved in the local environment.
