# WASL — Database + Backend Performance Audit

Scope: the completed backend (Phases 1–7). Method: direct inspection of the actual
implementation, PostgreSQL index inventory, `EXPLAIN (ANALYZE, BUFFERS)` on a realistic
seeded dataset (1 tenant, 150 buses, 2,250 students, 150 drivers, 150 routes, 150 daily
trips, 2,250 TripStudents), automated N+1 query-count regression tests, and a latency
benchmark. No numbers below are fabricated; commands and outputs are reproducible via
`scripts/perf-seed.ts`, `scripts/bench.ts`, and `tests/integration/n_plus_one.int.test.ts`.

## 1. Summary

| Severity | Issue | Status |
| --- | --- | --- |
| MEDIUM | `StudentAssignment` lookup by `(tenantId, routeId)` performed a sequential scan | Fixed (index) |
| MEDIUM | `DailyTrip` driver/active-trip lookup had no supporting index | Fixed (index) |
| MEDIUM | Employee list/get retrieved `nationalIdOrIqama` (sensitive) unnecessarily | Fixed (select) |
| MEDIUM | Student list retrieved home coordinates (sensitive) unnecessarily | Fixed (select) |
| MEDIUM | Assignment list endpoints were unbounded (could return ~2,250 rows) | Fixed (pagination) |
| LOW | `setRouteStops` issued N individual INSERTs | Fixed (`createMany`) |
| LOW | Route list over-fetched full neighborhood rows | Fixed (select) |

No CRITICAL/HIGH performance defects found. No N+1 query patterns were found in the
existing code (no Prisma calls inside loops).

## 2. N+1 Audit

Inspection of every service/route: no `for`/`forEach`/`.map` loop contains a Prisma call,
and no `Promise.all(list.map(prisma…))` pattern exists. All list endpoints use a bounded
`findMany` (with `select`/`include`) plus `count`, so query count is constant.

| Endpoint / service | Query pattern | Query count | N+1 risk |
| --- | --- | --- | --- |
| `GET /students` (`StudentsService.list`) | `findMany(select)` + `count` in `Promise.all` | 2 | None |
| `GET /employees?role=` (`EmployeesService.list`) | `findMany(select)` + `count` | 2 | None |
| `GET /assignments/students` | `findMany(select)` + `count` | 2 | None |
| `GET /structure/routes` (nested stops) | `findMany(include→select)` + `count` | 2 | None |
| `GET /driver/today` (`TripService.getDriverToday`) | `driverProfile.findFirst` + `dailyTrip.findFirst(include)` | 2 | None |
| `POST /trips` (`TripService.createTrip`) | 3 asserts + 2 list queries + 1 transaction (create + `createMany`) | ~7 bounded | None |
| `POST /trips/:id/complete` | assert + transaction (update + `updateMany`) | ~4 | None |
| Location processing (`LocationService.processLocation`) | `driverProfile.findFirst` + `dailyTrip.findFirst` (+ completion) | 2–4 | None |

### Regression tests

`tests/integration/n_plus_one.int.test.ts` measures the query count for a small page vs a
large page and asserts they are equal and small:

- student list: limit 5 == limit 100, ≤ 4 queries
- employee list: limit 5 == limit 100, ≤ 4 queries
- student assignment list: limit 5 == limit 100, ≤ 4 queries
- route list (nested stops): limit 5 == limit 50, ≤ 4 queries

Run: `RUN_DB_TESTS=1 DATABASE_URL=… npx vitest run tests/integration/n_plus_one.int.test.ts`
Result: **4 passed**.

## 3. Index Audit

Existing indexes were reviewed against actual query patterns (tenant-scoped filters,
`userId`/`studentId`/`busId`/`routeId`/`tripId`/`date`/`status`). Existing coverage is good:
`User(tenantId, phone|email|role)`, `StudentProfile(tenantId, studentId)`, profile
`(tenantId, employeeId)`, `Bus(tenantId, plateNumber)`, `Route(tenantId, code)`,
`RouteNeighborhood(routeId, neighborhoodId)`, `AttendanceIntent(studentProfileId, tripDate)`
and `(tenantId, tripDate)`, `DailyTrip(tenantId, tripDate)`,
`TripStudent(dailyTripId, studentProfileId)`, `Notification(userId, isRead)`,
`AuditLog(tenantId, createdAt)`, `RefreshSession(tokenHash)`.

Added (migration `20260913000007_perf_indexes`):

| Index | Real query that benefits |
| --- | --- |
| `StudentAssignment(tenantId, routeId)` | `TripService.createTrip` student lookup: `findMany({ where: { tenantId, routeId, isActive } })` — previously a Seq Scan over all tenant assignments |
| `DailyTrip(tenantId, driverProfileId, tripDate)` | `TripService.getDriverToday` and `LocationService.processLocation` driver/active-trip lookups (hot path during trips) |

No indexes were added blindly; both map to measured access patterns. Redundant indexes were
avoided (the existing `(tenantId, tripDate)` and `(tenantId, busId)` indexes remain useful).
Tenant-scoped uniques and the three **partial unique active-assignment indexes** were
verified intact (`npm run db:check-constraints` → 3 partial indexes + 1 CHECK constraint).

## 4. EXPLAIN ANALYZE Findings

- **`StudentAssignment` by `(tenantId, routeId, isActive)`**
  - Before: `Seq Scan on "StudentAssignment" … Rows Removed by Filter: 2244` (0.292 ms at 2,259 rows; cost grows linearly with total assignments).
  - After: `Index Scan using "StudentAssignment_tenantId_routeId_idx" … rows=15` (0.075 ms).
- **`DailyTrip` by `(tenantId, driverProfileId, status)` / `(…, tripDate)`**
  - Before/after at 150 rows: planner keeps a `Seq Scan` (cost ≈ 6.6) because the table is tiny — this is the correct plan for a small table, not a defect. The new index makes the lookup O(1) as the table grows (multiple days/tenants).
- **`TripStudent` by `dailyTripId`**: `Index Scan using TripStudent_dailyTripId_studentProfileId_key` (15 rows) — good.
- **`AttendanceIntent` by `(tenantId, tripDate)`**: `Index Scan using AttendanceIntent_tenantId_tripDate_idx` — good.
- **`User` by `(tenantId, role)`**: `Bitmap Index Scan` for DRIVER (150 rows); `Seq Scan` for STUDENT because students are ~93% of a single-tenant table (planner selectivity choice). At multi-tenant scale the index is used; the residual cost is the `ORDER BY createdAt` sort (see remaining risks).

## 5. Over-fetching / Sensitive Data

- `EmployeesService` now uses an explicit `select` that excludes `nationalIdOrIqama` from the
  database result (previously retrieved into memory even though the DTO excluded it).
- `StudentsService.list` uses a `select` that excludes `homeLatitude`/`homeLongitude`; the
  detail path keeps them (authorized admin detail only).
- Route lists select only `{ id, name }` for neighborhoods instead of full rows.
- No list endpoint retrieves `passwordHash`, `tokenHash`, `documentKey`, or OTP values.
- Driver trip responses project a `select` for student `user` (`id, firstName, lastName, phone`)
  — never `passwordHash`/`email`.

## 6. Pagination / Bounded Queries

Paginated with validated `page`/`limit` (max 100): students, employees, assignments
(students/drivers/supervisors), notifications, structure lists. `GET /trips` is bounded
(`take: 100`). No public list endpoint performs an unbounded `findMany`.

Offset pagination is retained for admin tables (low churn). Cursor pagination is a future
option for high-churn collections (audit logs, notifications) — see remaining risks.

## 7. Aggregations

No dashboard/statistics endpoints exist yet (planned Phase 11/12). When added they must use
`count`/`groupBy`/`aggregate` rather than loading rows into Node. No premature raw SQL is used.

## 8. Transactions + Connection Management

- Exactly one shared `PrismaClient` per process (`src/providers/prisma.ts`); `new PrismaClient()`
  appears only in the provider (and test helpers). `server.ts` uses `getPrismaClient()`.
- `disconnectPrisma()` is called on graceful shutdown (with a force-exit timeout).
- Transactions are used for atomic operations: assignment deactivate+activate, trip
  completion (update + confirm), registration (user + profile), `setRouteStops`.
- Transactions are short and contain no external/network calls.
- Connection pooling is Prisma's default; fine for the single-instance MVP.

## 9. Tenant-Safe Access

Every tenant-owned query is scoped by `tenantId` from `req.auth` (server context). All
optimizations use tenant-scoped `where` clauses or `select`/`include` on tenant-scoped
parents. Negative cross-tenant tests exist (`tests/phase3.test.ts`) for structure and
assignments; the N+1 integration tests use a single tenant and do not weaken isolation.

## 10. API Request Efficiency

Current endpoints are purpose-shaped (e.g. `GET /driver/today` returns the trip + pickup
list in one call; `GET /attendance/today` returns today's intent). No client-side request
waterfalls are required for the implemented screens. Dashboard endpoints (Phase 11/12) should
follow the same rule: one coherent endpoint per screen, not N per entity.

## 11. Benchmark Results

Local dev machine, PostgreSQL 16 (Docker), 60 iterations, perf dataset. These are local
figures, not production claims.

| Operation | p50 | p95 | p99 |
| --- | --- | --- | --- |
| admin student list (20) | 3.25 ms | 7.34 ms | 8.85 ms |
| admin employee list (20) | 5.14 ms | 10.98 ms | 15.36 ms |
| admin bus list (20) | 1.30 ms | 1.68 ms | 4.03 ms |
| route list (20, nested stops) | 4.41 ms | 6.42 ms | 8.32 ms |
| student assignment list (20) | 4.12 ms | 5.43 ms | 7.00 ms |
| driver assigned trip (today, with pickup list) | 9.78 ms | 20.74 ms | 22.60 ms |
| student attendance (today) | 2.30 ms | 3.89 ms | 4.17 ms |
| student self profile | 1.88 ms | 3.02 ms | 4.17 ms |
| attendance set intent (write) | 3.82 ms | 7.08 ms | 10.98 ms |

DB query counts per call: student list = **2** (limit 20 and 100), route list = **2**,
driver trip = **2**. All p95 well under the 500 ms read target locally.

## 12. Remaining Risks

- **`ORDER BY createdAt` on list endpoints** has no covering index. At ~2,250 rows the sort
  is ~1 ms; monitor if a tenant exceeds ~10k students, then consider `(tenantId, role, createdAt)`.
- **Offset pagination** on high-churn collections could degrade at large offsets; migrate
  audit-log/notification lists to cursor pagination when they grow.
- **`DailyTrip` driver lookup** relies on a new index that the planner only prefers as the
  table grows; verify with a multi-day dataset before production.
- **Dashboard aggregations** (Phase 11/12) must use `count`/`groupBy`; not yet implemented.
- **In-memory state** (location throttling, arrival samples, OTP store) is single-instance
  only; Redis becomes required for multi-instance (documented).
- **Cross-tenant composite FKs** remain deferred (documented Phase 2+ precondition).
- **No load test yet** at ~1,000 concurrent connections (Phase 16, k6).

## 13. Verification Commands Run

- `npx prisma validate` → valid
- `npx prisma migrate deploy` → 7 migrations applied
- `npm run db:check-constraints` → 3 partial indexes + 1 CHECK constraint
- `npm run typecheck` → 0 errors
- `npm run lint` → 0 errors / 0 warnings
- `npm test` → 103 passed, 4 integration tests skipped (no `RUN_DB_TESTS`)
- `RUN_DB_TESTS=1 npx vitest run tests/integration` → 4 passed (N+1 regression)
- `npx tsx scripts/perf-seed.ts` → dataset seeded
- `npx tsx scripts/bench.ts` → results in §11
- `EXPLAIN (ANALYZE, BUFFERS)` → §4

**DATABASE + BACKEND PERFORMANCE AUDIT: VERIFIED**
