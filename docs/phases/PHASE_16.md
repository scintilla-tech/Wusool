# PHASE 16 — Performance + k6 Load Testing + Optimization

## Scope
- k6 scenarios (~400 users, dashboards, ~200 buses, 3-min location updates, 1000-connection headroom).
- Measure p95 latency, DB pool, CPU/memory, event loop, Socket.IO.
- Index real query patterns; bounded queries; DTO selects.

## Acceptance
- Load tests run locally; targets (p95 read <=500ms, write <=800ms excl. providers) verified or explicitly not-yet-achieved.
