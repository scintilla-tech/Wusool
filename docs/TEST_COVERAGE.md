# WUSOOL Test Coverage and Verification

Audit date: 2026-10-12

## Executed checks

| Layer | Command/check | Result |
| --- | --- | --- |
| Backend unit/HTTP/service/integration/E2E | `RUN_DB_TESTS=1`, `RUN_E2E_TESTS=1`, `npm test` | 325 passed, 0 failed, 0 skipped; 25 files passed |
| Endpoint inventory | included in backend suite | 192 assertions passed across all 73 source-discovered endpoints |
| Backend type safety | `npm run typecheck` | PASS |
| Backend lint | `npm run lint` | PASS |
| Backend format | `npm run format:check` | PASS |
| Backend production build | `npm run build` | PASS |
| Prisma client | `npm run prisma:generate` | PASS |
| Prisma schema | `npm run prisma:validate` | PASS |
| Dependency audit | `npm audit --omit=dev` | PASS, 0 known production vulnerabilities |
| Flutter static analysis | `flutter analyze` | PASS; no issues |
| Flutter widget tests | `flutter test` | PASS — 7/7 after dual-attendance mobile changes |
| Flutter release web build | `flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:3100/api/v1` | PASS; optional Wasm dry-run warning only |
| PostgreSQL integration | guarded tests | PASS — 4/4 against local PostgreSQL 16 |
| Browser/device E2E | interactive Flutter web plus executable real-DB E2E | PASS on web with simulated GPS; physical device not run |
| Bounded load test | k6 scripts exist | NOT RUN; outside the critical local journey scope |

Flutter commands initially hung because the managed SDK cache was outside the restricted workspace. With the required local SDK access, doctor, analysis, widget tests, and the release web build completed successfully.

## Coverage by critical workflow

| Workflow | Automated evidence | Classification |
| --- | --- | --- |
| Student login | HTTP valid/wrong/unknown credentials, DTO secrecy | Implemented and verified at API layer |
| Refresh/logout/reuse/logout-all | rotation, revocation, reuse detection tests | Implemented and verified at API/service layer |
| Student attendance | separate OUTBOUND/RETURN windows, finish time, closure denial, audit and persistence | PASS in real DB E2E |
| Driver-assisted attendance/closure | membership, assigned-driver authorization, serializable close/register race and socket events | PASS in real DB E2E and interactive Flutter web |
| Student registration/OTP | service and invalid-input tests | Partial; mock/in-memory OTP only |
| Driver trip initialization | assignment check, atomic transition, persistence, wrong-driver denial | PASS in real DB E2E |
| Driver location update | role/room authorization, real Socket.IO server, Flutter-web receipt | PASS with simulated coordinate; real device not run |
| Student live tracking | authenticated Socket.IO update received by Flutter map | PASS on web with simulated coordinate |
| Supervisor monitoring | server room-scope tests, real REST service, active-trip UI | PASS for implemented bus monitoring screen |
| Admin assignments | service/tenant tests, applied constraints, real students/buses UI | Partial UI; verified existing lists and backend constraints |
| Trip completion | transactional/duplicate/concurrent completion and real persistence assertion | PASS |
| Unauthorized access | all protected routes missing/expired JWT; privileged routes as Student | Verified at outer boundary |
| Cross-tenant/object access | focused service/document/notification tests plus wrong-driver and unrelated-student socket checks | PASS for covered critical objects; broader CRUD remains partial |
| Emergency reporting | no entity/API/UI | Missing |
| Network failure/recovery | client reconnect configuration and active-trip resume | Partial; physical-device interruption test not run |

## What the numbers do not prove

- The 325 passing backend tests do not imply 325 independent features; 192 are systematic route-inventory/boundary cases.
- The local migration and real-DB lifecycle test prove the covered constraints and transactions, not every possible query plan or production load profile.
- The Flutter web demonstration does not prove native GPS permission prompts, background execution, or OS secure-storage behavior.
- No unexecuted physical-device, k6, or production-provider scenario is marked passed.

## Recommended next coverage

1. Add Android/iOS integration tests for secure token storage, GPS permission denied/limited/granted, offline buffering, reconnection, and trip-end shutdown.
2. Add Playwright automation for the already verified Flutter web role/navigation flows.
3. Add bounded query-plan/load measurements using a larger isolated dataset.
4. Add multipart document tests for allowed signatures, disguised files, truncation, cross-user reads, aborted uploads and cleanup.
