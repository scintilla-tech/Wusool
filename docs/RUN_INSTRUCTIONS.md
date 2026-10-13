# WUSOOL Run and Verification Instructions

## Prerequisites

- Node.js 22.12+ required (the verified host used Node 24).
- PostgreSQL reachable through `DATABASE_URL`.
- Flutter SDK compatible with the repository SDK constraint; Android/iOS toolchains as needed.
- Copy environment keys from `backend/.env.example`. Never commit real secrets.

## Complete local demonstration (Windows PowerShell)

The repository includes an idempotent PostgreSQL container and ignored local credentials. From the repository root:

```powershell
docker compose -f docker-compose.local.yml up -d postgres
Set-Location backend
Get-Content .env.local.e2e | ForEach-Object { if ($_ -match '^[A-Z_]+=') { $name, $value = $_ -split '=', 2; Set-Item -Path "Env:$name" -Value $value } }
npm ci
npm run prisma:generate
npm run prisma:migrate:deploy
npm run db:check-constraints
npm run prisma:seed
npm run build
$env:CORS_ALLOWED_ORIGINS = 'http://127.0.0.1:8080,http://localhost:8080'
npm start
```

Keep that terminal open. In a second PowerShell terminal:

```powershell
Set-Location mobile
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:3100/api/v1
```

Open `http://127.0.0.1:8080/?role-test=1`. Synthetic role metadata is in ignored file `backend/.env.demo.local`; the active shared password is in ignored file `backend/.env.attendance-demo.local`. The seed automatically reads both files. To emit one coordinate for a trip already started by the demo driver, run from `backend`:

```powershell
npm run simulate:location
```

For an Android emulator, use `http://10.0.2.2:3100/api/v1` and accept the outstanding Android SDK licenses first. A physical device must use the host's authorized LAN address and firewall configuration; do not use `127.0.0.1` from the device.

## Backend

From `backend`:

```powershell
npm ci
npm run prisma:generate
npm run prisma:validate
npm run prisma:migrate:deploy
npm run db:check-constraints
npm run typecheck
npm run lint
npm run format:check
npm test
npm run build
npm start
```

For local development use `npm run dev`. Health endpoints are `/health/live` and `/health/ready`; readiness should not be considered healthy until PostgreSQL responds.

Before applying the new migration outside a disposable database, back up the database and inspect duplicate device tokens and conflicting active driver/bus assignments/trips. The migration deliberately aborts on duplicate device tokens and does not delete records.

To run DB-gated integration tests on Windows after creating an isolated test database:

```powershell
$env:RUN_DB_TESTS = '1'
npm run test:integration
Remove-Item Env:RUN_DB_TESTS
```

Do not point those tests at production.

To run the complete test suite, including the two real-database lifecycle E2E tests, load `.env.local.e2e`, set both gates, and run Vitest. E2E files are serialized because they deliberately reuse the same synthetic trip IDs:

```powershell
$env:RUN_DB_TESTS = '1'
$env:RUN_E2E_TESTS = '1'
npm test
Remove-Item Env:RUN_DB_TESTS
Remove-Item Env:RUN_E2E_TESTS
```

## Flutter client

From `mobile`, with the API origin appropriate for the target:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://localhost:3100/api/v1
```

For an Android emulator, the host API is commonly `http://10.0.2.2:3100/api/v1`; for a physical device use an authorized LAN/TLS endpoint. Build web with:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://your-authorized-api.example/api/v1
```

The repository includes `tools/flutter.ps1` to discover the local managed SDK on Windows. If it hangs even on `--version`, resolve the SDK/toolchain process/lock issue before accepting analysis, tests or build as executed.

## External services

Current OTP and push providers are mocks and document storage is local. Do not deploy these implementations as production services. Configure real providers, private durable storage, retention, observability and failure handling first.

## Post-start smoke checklist

1. Confirm live and ready health separately.
2. Login each role with synthetic test accounts.
3. Verify a Student cannot access admin, driver, supervisor or platform routes.
4. Create assignments and a trip in a disposable tenant.
5. Start the trip as its assigned Driver, connect an assigned Student and Supervisor socket, and confirm an unrelated user receives no GPS event.
6. Interrupt and restore the driver network; verify freshness and resume behavior.
7. Complete the trip; verify location publishing stops and only one completion/audit record exists.
8. Revoke all sessions and verify old refresh tokens fail.
