# WASL — Deployment & Operations

## Environments

Separate development / staging / production configuration (env-driven, Zod-validated).

## Backend

- Stateless where practical (JWT + rotating refresh; DB is source of truth).
- One PrismaClient per process; DB connection pooling.
- Run behind a reverse proxy with `TRUST_PROXY` set to the controlled hop count.

## PostgreSQL

- Production: automated backups + PITR/WAL-based recovery where supported.
- RPO <= 15 minutes, RTO <= 1 hour.
- Retention: 14–30 days operational; longer monthly if policy requires.
- Restore testing required.

## Realtime / Redis

- Single-instance MVP: no Redis. Redis introduced only for multi-instance (Socket.IO adapter, distributed rate limiting, transient distributed latest-location).

## Observability

- Structured logs + request IDs. Never log passwords/JWTs/refresh tokens/OTP/national IDs/document keys/long-term GPS.
- Monitor: API latency, 4xx/5xx, DB latency/pool, CPU/memory, Socket.IO connections, event loop, auth abuse, storage, backup failures.

## Safety

- Do NOT deploy to paid production infrastructure without explicit authorization.
- Never run destructive production DB operations.
