# WASL — Demo Accounts

> ## ⚠️ DEVELOPMENT / DEMO ONLY — NEVER USE IN PRODUCTION
>
> These are **fictional test identities**. Their passwords are kept only in the ignored
> `backend/.env.demo.local` file and must never be reused for real accounts.

## Seeding

```powershell
Set-Location backend
Get-Content .env.local.e2e | ForEach-Object { if ($_ -match '^[A-Z_]+=') { $name, $value = $_ -split '=', 2; Set-Item -Path "Env:$name" -Value $value } }
npm run prisma:seed
```

The seed is **idempotent** (deterministic ids + upserts): re-running it never creates
duplicates. The script refuses staging/production, requires an explicit local-development
opt-in, and refuses non-loopback database hosts. Passwords are loaded from the ignored local
file and persisted only as Argon2id hashes.

## Accounts

Use `DEMO_PASSWORD` from `backend/.env.demo.local` for these accounts.

| # | Role | Name | Phone (login) | Tenant | Profile / IDs |
| - | ---- | ---- | ------------- | ------ | ------------- |
| 1 | `STUDENT` | Nejood Demo | `+966500000101` | KSU | StudentProfile `440000001`, active StudentAssignment → route **R1** / branch **MAIN** |
| 2 | `DRIVER` | Nejood Demo | `+966500000102` | KSU | DriverProfile `DRV-NEJOOD-01`, active DriverAssignment → bus **KSU-1003** |
| 3 | `SUPERVISOR` | Nejood Demo | `+966500000103` | KSU | SupervisorProfile `SUP-NEJOOD-01`, active SupervisorBusAssignment → bus **KSU-1003** |
| 4 | `FIELD_SUPERVISOR` | Nejood Demo | `+966500000104` | KSU | FieldSupervisorProfile `FSUP-NEJOOD-01` (tenant-wide access) |
| 5 | `UNIVERSITY_ADMIN` | Nejood Demo | `+966500000105` | KSU | employee label `ADMIN-NEJOOD-01` * |
| 6 | `PLATFORM_SUPER_ADMIN` | Nejood Demo | `+966500000106` | **none** (`tenantId = null`) | platform-level |

\* There is no admin profile model in the schema, so the university admin's employee label
is recorded here only (not persisted). Driver/supervisor/field-supervisor employee ids are
persisted on their profiles.

Tenant code for the five university-scoped accounts: **`KSU`**.

## Logging in from the Flutter app

1. Start the backend: `cd backend; npm run dev` (http://localhost:3100).
2. Run the app: `cd mobile; ..\tools\flutter.ps1 run -d chrome`.
3. On the login screen:
   - **University roles:** enter `رمز الجامعة` = `KSU`, the phone, and `DEMO_PASSWORD` from the ignored file.
   - **Platform super admin:** leave `رمز الجامعة` **blank**, enter `+966500000106` and the password.

The app routes each role to its own experience: student shell, driver screen, supervisor
dashboard, university admin shell, or platform screen.

## RBAC / tenant-scope expectations (verified)

| Check | Result |
| --- | --- |
| Each account authenticates via `POST /api/v1/auth/login` and gets its own role | ✅ |
| Student → `/driver/today`, `/admin/dashboard` | **403** |
| Driver → `/admin/dashboard` | **403** |
| Driver → `/driver/today` (own trip) | **200** |
| Supervisor / Field supervisor → `/supervisor/buses` | **200** |
| University admin → `/admin/dashboard` | **200** |
| University admin (KSU) → another tenant's bus (`PATCH /structure/buses/:id`) | **404** |
| University admin (KSU) bus list | **4 buses** (KSU only; not other tenants') |
| Platform super admin → `/platform/tenants` | **200** |
| Platform super admin → `/admin/dashboard` (tenant-scoped) | **403** |
| Platform super admin `tenantId` | **null** (platform-level) |

## End-to-end demo flow

The seed also creates a **today** `DailyTrip` (route **R1**, bus **KSU-1003**, driver
`+966500000102`) with the ATTENDING students on route R1 as `WAITING` pickup rows, so the
driver/student/supervisor flows can be exercised immediately:

- Student `+966500000101` → set attendance → tracking shows the trip for route R1.
- Driver `+966500000102` → sees the trip + pickup list → start trip → mark students.
- Supervisor `+966500000103` → sees bus KSU-1003 with attending/boarded/missed counts.
- Field supervisor `+966500000104` → sees tenant buses.
- University admin `+966500000105` → dashboard + management.
- Platform super admin `+966500000106` → tenant list.

## Notes

- Rate limiting still applies (login is limited per `tenantCode:phone`); the shared demo
  password does not disable any security control.
- To reset demo data, re-run `npm run prisma:seed` (idempotent) — it does not delete other data.
