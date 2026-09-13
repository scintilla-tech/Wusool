# WASL — وَصــل

Multi-tenant university female transportation automation SaaS. Replaces fragmented
WhatsApp/paper workflows with structured registration, attendance intent, bus assignment,
driver trip workflow, tracking, supervision, and auditability.

## Repository layout

```
backend/    Node.js + TypeScript + Express + PostgreSQL + Prisma + Socket.IO
mobile/     Flutter + Riverpod client (Arabic-first, RTL)
docs/       Specifications, phase plans, roadmap, audits
tools/      Project-local Flutter wrapper (tools/flutter.ps1)
.opencode/  AI workflow: reviewer + security-reviewer subagents, /phase command
AGENTS.md   Engineering contract
```

## Documentation

- `AGENTS.md` — engineering contract (stack, architecture, security, process)
- `docs/PRODUCT_REQUIREMENTS.md`, `docs/USER_FLOWS.md`, `docs/DATABASE_SPEC.md`, `docs/API_SPEC.md`
- `docs/MOBILE_UI_SPEC.md`, `docs/REALTIME_SPEC.md`, `docs/NOTIFICATIONS_SPEC.md`, `docs/SECURITY.md`
- `docs/TESTING_STRATEGY.md`, `docs/DEPLOYMENT.md`
- `docs/ROADMAP.md` — 17-phase plan + status
- `docs/DATABASE_PERFORMANCE_AUDIT.md` — measured performance evidence

## Backend quickstart

```powershell
cd backend
npm install
copy .env.example .env          # fill in real values (dev placeholders are fine locally)
npm run prisma:generate
npm run prisma:migrate          # development only
npm run prisma:seed             # optional demo data
npm run dev                     # http://localhost:3100
```

Quality: `npm run typecheck`, `npm run lint`, `npm run test`, `npm run build`,
`npm run db:check-constraints`, `npm run test:integration` (needs `RUN_DB_TESTS=1`).

## Mobile quickstart

```powershell
cd mobile
..\tools\flutter.ps1 pub get
..\tools\flutter.ps1 run -d chrome      # or -d windows
```

Quality: `..\tools\flutter.ps1 analyze`, `..\tools\flutter.ps1 test`, `..\tools\flutter.ps1 build web --release`.

The Flutter wrapper resolves the existing SDK/JDK/Android SDK/pub cache; see `mobile/README.md`.

## Demo credentials (development only)

Seed with `cd backend; npm run prisma:seed`, then log in (tenant code `KSU`).

**Persistent per-role demo accounts (password `WaslDemo@2026`)** — one account per role so
RBAC/tenant isolation can be tested. Full details in [`docs/DEMO_ACCOUNTS.md`](docs/DEMO_ACCOUNTS.md):

| Role | Phone | Tenant |
| --- | --- | --- |
| STUDENT | +966500000101 | KSU |
| DRIVER | +966500000102 | KSU |
| SUPERVISOR | +966500000103 | KSU |
| FIELD_SUPERVISOR | +966500000104 | KSU |
| UNIVERSITY_ADMIN | +966500000105 | KSU |
| PLATFORM_SUPER_ADMIN | +966500000106 | (blank tenant code) |

Legacy demo accounts (also seeded):

| Role | Phone | Password |
| --- | --- | --- |
| University Admin | +966501111111 | AdminPass#1 |
| Driver 1 | +966550000001 | DriverPass#1 |
| Driver 2 | +966550000002 | DriverPass#2 |
| Supervisor | +966550000003 | SuperPass#1 |
| Student | +966551000001 | Student#123 |

> DEVELOPMENT / DEMO ONLY — never use these in production.

## Status

Backend Phases 1–7 and the database performance audit are complete and verified. Flutter
Phases 8–13 (foundation, student, driver, supervisor, admin, platform) are implemented and
verified. Phases 14–16 (storage, security audit, load testing) are complete. Phase 17
(deployment readiness) is in progress. See `docs/ROADMAP.md`.

## Multi-tenancy & security

- Shared PostgreSQL, shared schema, application-layer tenant isolation (`tenantId` from
  authenticated server context only; RLS deferred).
- Argon2id passwords, short access JWT + rotating refresh sessions, role-based authorization,
  strict Zod validation, Helmet, CORS allowlist, rate limiting, structured logging with
  redaction.
- Never expose `passwordHash`, `nationalIdOrIqama`, document keys, OTPs, or student home
  coordinates in ordinary DTOs.
