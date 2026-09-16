# WASL — وَصــل

Multi-tenant university female transportation automation SaaS. WASL replaces fragmented
WhatsApp/paper workflows with structured student registration, attendance intent, bus
assignment, driver trip workflow, live tracking, supervision, and full auditability.

- **Backend:** Node.js · TypeScript · Express · PostgreSQL · Prisma · Socket.IO · Zod
- **Mobile:** Flutter · Riverpod (Arabic-first, RTL)
- **Architecture:** Modular monolith, shared PostgreSQL schema, strict application-layer
  tenant isolation (tenant context always comes from the authenticated server context).

## Features

- **Authentication & RBAC** — Argon2id passwords, short access JWT + rotating refresh
  sessions, six roles (`STUDENT`, `DRIVER`, `SUPERVISOR`, `FIELD_SUPERVISOR`,
  `UNIVERSITY_ADMIN`, `PLATFORM_SUPER_ADMIN`).
- **University structure** — branches, buses, employees, student/driver/supervisor
  assignments with partial unique indexes for active assignments.
- **Students** — registration, profile, and daily attendance intent (`ATTENDING` / `ABSENT`).
- **Trips** — driver trip lifecycle and per-student status (`WAITING`, `BOARDED`,
  `NOT_READY`, `MISSED`). Only `BOARDED` students become transport-confirmed.
- **Realtime tracking** — driver GPS shared only during active morning trips, secured over
  Socket.IO with resource authorization.
- **Geofencing** — local Haversine arrival detection with validated dwell/auto-completion
  (no external Maps API calls).
- **Notifications** — device management with a provider abstraction (FCM / Huawei Push /
  APNs ready).
- **Documents & storage** — private S3-compatible object storage abstraction.
- **Platform administration** — tenant management for platform super-admins.

## Repository layout

```
backend/    Express + Prisma API (src/, prisma/, tests/, scripts/)
mobile/     Flutter + Riverpod client (lib/, android/, ios/, web/, windows/)
docs/       Product, database, API, UI, realtime, security, testing, deployment specs
```

## Documentation

| Document | Description |
| --- | --- |
| [`docs/PRODUCT_REQUIREMENTS.md`](docs/PRODUCT_REQUIREMENTS.md) | Product scope and requirements |
| [`docs/USER_FLOWS.md`](docs/USER_FLOWS.md) | Role-based user journeys |
| [`docs/architecture/WASL_ARCHITECTURE.md`](docs/architecture/WASL_ARCHITECTURE.md) | System architecture |
| [`docs/DATABASE_SPEC.md`](docs/DATABASE_SPEC.md) | Schema and data model |
| [`docs/API_SPEC.md`](docs/API_SPEC.md) | REST API contract |
| [`docs/MOBILE_UI_SPEC.md`](docs/MOBILE_UI_SPEC.md) | Mobile UI specification |
| [`docs/REALTIME_SPEC.md`](docs/REALTIME_SPEC.md) | Socket.IO realtime contract |
| [`docs/NOTIFICATIONS_SPEC.md`](docs/NOTIFICATIONS_SPEC.md) | Notification provider design |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Security model and controls |
| [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md) | Testing approach |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Deployment guide |
| [`docs/DATABASE_PERFORMANCE_AUDIT.md`](docs/DATABASE_PERFORMANCE_AUDIT.md) | Measured performance evidence |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | 17-phase plan and status |
| [`docs/DEMO_ACCOUNTS.md`](docs/DEMO_ACCOUNTS.md) | Development demo accounts |

## Prerequisites

- Node.js >= 20 and npm
- PostgreSQL 14+
- Flutter SDK (stable) for the mobile client

## Backend quickstart

```bash
cd backend
npm install
cp .env.example .env          # fill in real values (local dev placeholders are fine)
npm run prisma:generate
npm run prisma:migrate        # development only
npm run prisma:seed           # optional demo data
npm run dev                   # http://localhost:3100
```

Quality checks:

```bash
npm run typecheck
npm run lint
npm run test
npm run build
npm run db:check-constraints
npm run test:integration      # requires RUN_DB_TESTS=1 and a reachable database
```

## Mobile quickstart

```bash
cd mobile
flutter pub get
flutter run -d chrome         # or -d windows / an attached device
```

The API base URL defaults to `http://localhost:3100/api/v1` and can be overridden:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3100/api/v1
```

Quality checks:

```bash
flutter analyze
flutter test
flutter build web --release
```

## Demo credentials (development only)

Seed with `cd backend && npm run prisma:seed`, then log in (tenant code `KSU`).
Full details in [`docs/DEMO_ACCOUNTS.md`](docs/DEMO_ACCOUNTS.md).

**Persistent per-role accounts (password `WaslDemo@2026`):**

| Role | Phone | Tenant |
| --- | --- | --- |
| STUDENT | +966500000101 | KSU |
| DRIVER | +966500000102 | KSU |
| SUPERVISOR | +966500000103 | KSU |
| FIELD_SUPERVISOR | +966500000104 | KSU |
| UNIVERSITY_ADMIN | +966500000105 | KSU |
| PLATFORM_SUPER_ADMIN | +966500000106 | (blank tenant code) |

> DEVELOPMENT / DEMO ONLY — never use these in production.

## Security & multi-tenancy

- Shared PostgreSQL database and schema with application-layer tenant isolation.
- `tenantId` is never trusted from the client — it is derived from the authenticated server
  context; cross-tenant relationships are forbidden.
- Argon2id password hashing, short-lived access tokens with rotating refresh sessions,
  role-based authorization, strict Zod validation, Helmet, CORS allowlist, endpoint rate
  limiting, and structured logging with redaction.
- Sensitive fields (`passwordHash`, national ID/Iqama, document keys, OTPs, student home
  coordinates) are never exposed in ordinary DTOs or logs.

## Status

All 17 planned phases are complete and verified. See [`docs/ROADMAP.md`](docs/ROADMAP.md).
