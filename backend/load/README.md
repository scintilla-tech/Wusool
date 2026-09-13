# WASL Load Tests (k6)

k6 scenarios for the WASL backend. The k6 binary is **not installed** in this environment,
so these scripts are prepared and committed but must be run where k6 is available.

## Install k6

- Windows: `winget install k6` (or `choco install k6`, or download from k6.io)
- macOS: `brew install k6`
- Linux: see https://grafana.com/docs/k6/latest/set-up/install-k6/

## Prerequisites

1. Start the backend against a development database and seed demo data:
   - `cd backend && npm run prisma:seed`
   - `npm run dev` (listens on port 3100)
2. For the burst scenario, optionally seed the realistic dataset:
   - `npx tsx scripts/perf-seed.ts`

## Run

```bash
# Smoke (liveness, readiness, per-role login)
k6 run backend/load/smoke.js

# Morning burst (~400 active users, mixed roles)
k6 run backend/load/burst.js
```

Override the target/credentials via env vars:

```bash
k6 run -e API_BASE_URL=http://localhost:3100/api/v1 \
       -e WASL_TENANT=KSU \
       -e WASL_STUDENT_PHONE=+966551000001 backend/load/burst.js
```

## Thresholds

- `http_req_failed < 1%`
- reads `p(95) < 500ms`
- writes `p(95) < 800ms`

## Scenarios covered

| Script     | Scenario                                                                                                  |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| `smoke.js` | health + auth for all roles                                                                               |
| `burst.js` | ~400-user morning burst: attendance (read+write), driver trip/pickup list, admin dashboard + student list |

## Notes

- Never run these against production.
- Socket.IO tracking load (driver GPS broadcast) is not covered by k6; validate it with a
  dedicated Socket.IO client harness in the realtime phase.
- Local dev benchmarks for read paths are recorded in `docs/DATABASE_PERFORMANCE_AUDIT.md`.
