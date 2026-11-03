# WUSOOL — وصول

WUSOOL is a university transportation management MVP for students, drivers, field
supervisors, university administrators, and platform administrators. It combines an
Arabic-first Flutter client with a tenant-aware Express API, PostgreSQL persistence, and
authenticated Socket.IO updates.

> **Release status:** this repository is suitable for local development and MVP evaluation.
> It is **not production-ready**. Production OTP, push notifications, durable document
> storage, multi-instance realtime delivery, native-device validation, and operational
> hardening remain outstanding.

## Current MVP capabilities

- Authentication with Argon2id password hashes, short-lived access JWTs, rotating refresh
  sessions, logout/revocation, RBAC, and tenant isolation.
- Student profile, assigned bus/route/trip views, independent outbound and return attendance,
  optional outbound finish time, and live active-trip tracking.
- Driver trip lifecycle, assigned student roster, assisted attendance, direction-specific
  attendance closure, and simulated or device-provided GPS updates.
- Supervisor active-trip monitoring and separate outbound/return attendance statistics.
- University administration views for implemented student, bus, and assignment operations.
- Platform tenant administration for the platform super-administrator role.
- Transactional trip/attendance integrity, audit records, PostgreSQL constraints, and
  authorized realtime events.

The supported roles are `STUDENT`, `DRIVER`, `SUPERVISOR`, `FIELD_SUPERVISOR`,
`UNIVERSITY_ADMIN`, and `PLATFORM_SUPER_ADMIN`.

## Technology stack

| Layer | Technology |
| --- | --- |
| Client | Flutter, Dart, Riverpod, Dio, GoRouter, Flutter Secure Storage |
| API | Node.js 22+, TypeScript, Express, Zod, Prisma |
| Database | PostgreSQL 16 (14+ supported by the application design) |
| Realtime | Socket.IO with authenticated, resource-scoped rooms |
| Security | Argon2id, JWT access tokens, rotating refresh sessions, Helmet, CORS allowlist, rate limits |
| Tests | Vitest, Supertest, real-PostgreSQL integration/E2E tests, Flutter widget tests |

## Repository layout

```text
backend/                   Express, Prisma, migrations, seed, and automated tests
mobile/                    Flutter application and widget tests
docs/                      Architecture, audit, API, security, and verification reports
docker-compose.local.yml   Local PostgreSQL service with a persistent named volume
```

## Prerequisites

- Git
- Node.js 22.12 or newer and npm
- Docker Desktop (recommended) or PostgreSQL 14+
- Flutter stable compatible with Dart `^3.13.1`
- Chrome for the quickest local Flutter web run; native targets require their platform SDKs

## Environment configuration

`backend/.env.example` is the public variable template. Never put real credentials in that
file. Copy it to an ignored local file and replace every placeholder with a locally generated
value:

```powershell
Copy-Item backend/.env.example backend/.env.local.e2e
```

For `docker-compose.local.yml`, add `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`
to `backend/.env.local.e2e`, then make `DATABASE_URL` use the same values. Generate unique
JWT secrets of at least 32 characters. The local file is ignored by Git; verify with:

```powershell
git check-ignore -v backend/.env.local.e2e
```

Important variables include:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_ACCESS_SECRET` | Access-token signing secret (32+ characters) |
| `JWT_REFRESH_SECRET` | Reserved refresh-token secret (32+ characters) |
| `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL` | Token lifetimes |
| `CORS_ALLOWED_ORIGINS` | Explicit client-origin allowlist |
| `TRUST_PROXY` | Number of trusted reverse-proxy hops |
| `LOGIN_RATE_LIMIT` | Per-identifier login attempt limit |
| `LOG_LEVEL` | Pino log level |

Do not reuse local secrets, synthetic account passwords, or test database credentials in any
shared or production environment.

## PostgreSQL and migrations

Start the included non-destructive local PostgreSQL service from the repository root:

```powershell
docker compose -f docker-compose.local.yml up -d postgres
docker compose -f docker-compose.local.yml ps
```

The named volume `wasl_postgres_data` preserves data across container restarts. Do not use
`docker compose down -v` unless you intentionally want to remove that local data.

Load the ignored environment into the current PowerShell session, then generate the Prisma
client and apply committed migrations:

```powershell
Set-Location backend
Get-Content .env.local.e2e | ForEach-Object {
  if ($_ -match '^[A-Z_]+=') {
    $name, $value = $_ -split '=', 2
    Set-Item -Path "Env:$name" -Value $value
  }
}
npm ci
npm run prisma:generate
npm run prisma:validate
npm run prisma:migrate:deploy
npm run db:check-constraints
```

`prisma:migrate:deploy` applies existing migrations and does not create a destructive reset.
Review and back up any non-disposable database before applying migrations.

## Start the backend

From `backend`, after loading the environment and applying migrations:

```powershell
npm run prisma:seed   # optional synthetic local data
npm run dev
```

The API listens on `http://127.0.0.1:3100` by default. Check both endpoints:

- `GET http://127.0.0.1:3100/health/live`
- `GET http://127.0.0.1:3100/health/ready`

Readiness requires a working database connection.

## Start Flutter

In a second terminal:

```powershell
Set-Location mobile
flutter pub get
flutter run -d chrome --web-port 8080 `
  --dart-define=API_BASE_URL=http://127.0.0.1:3100/api/v1
```

Open `http://127.0.0.1:8080/`. An Android emulator normally reaches the host API through
`http://10.0.2.2:3100/api/v1`; a physical device requires an explicitly authorized host/LAN
address and firewall rule. Do not point local tests at production resources.

Synthetic test identities can be generated with the seed, but their password belongs only in
an ignored local environment file. No reusable login password is published in this repository.

## Verification commands

Backend checks:

```powershell
Set-Location backend
npm ci
npm run prisma:generate
npm run prisma:validate
npm run typecheck
npm run lint
npm run format:check
npm test
npm run build
```

To include the real-database integration and lifecycle E2E suites, use only an isolated local
database and explicitly enable both test gates:

```powershell
$env:RUN_DB_TESTS = '1'
$env:RUN_E2E_TESTS = '1'
npm test
Remove-Item Env:RUN_DB_TESTS
Remove-Item Env:RUN_E2E_TESTS
```

Flutter checks:

```powershell
Set-Location mobile
flutter pub get
flutter analyze
flutter test
flutter build web --release `
  --dart-define=API_BASE_URL=http://127.0.0.1:3100/api/v1
```

## Documentation

- [`docs/SYSTEM_AUDIT.md`](docs/SYSTEM_AUDIT.md) — architecture and capability audit
- [`docs/API_TEST_REPORT.md`](docs/API_TEST_REPORT.md) — discovered endpoint inventory/results
- [`docs/SECURITY_AUDIT.md`](docs/SECURITY_AUDIT.md) — defensive security findings
- [`docs/DATABASE_AUDIT.md`](docs/DATABASE_AUDIT.md) — schema and integrity verification
- [`docs/TEST_COVERAGE.md`](docs/TEST_COVERAGE.md) — executed test evidence
- [`docs/DUAL_ATTENDANCE_IMPLEMENTATION.md`](docs/DUAL_ATTENDANCE_IMPLEMENTATION.md) — attendance implementation and screenshots
- [`docs/RUN_INSTRUCTIONS.md`](docs/RUN_INSTRUCTIONS.md) — complete local demonstration guide
- [`docs/ANDROID_BUILD.md`](docs/ANDROID_BUILD.md) — Android build, installation, network, and Huawei guidance
- [`docs/ANDROID_TEST_REPORT.md`](docs/ANDROID_TEST_REPORT.md) — APK build and no-GMS emulator verification
- [`docs/REMAINING_ISSUES.md`](docs/REMAINING_ISSUES.md) — unresolved gaps and blockers

## Known limitations

- OTP, push delivery, and durable document storage use development substitutes; no external
  provider is certified or configured for production.
- Native Android/iOS secure storage, GPS permissions, background tracking, and reconnection
  still require physical-device validation.
- Realtime fan-out and some OTP state are in-process; horizontal production deployment needs
  durable shared infrastructure.
- Emergency/incident reporting, durable GPS history, production ETA, recurring scheduling,
  and complete analytics/settings workflows are not implemented.
- The web demonstration uses simulated coordinates and does not prove real-device GPS.
- Operational monitoring, backups, retention, incident response, TLS termination, and a
  production secrets manager must be designed and verified before deployment.

For the evidence-based release state, read the audit and remaining-issues documents rather
than inferring support from the presence of source files.
