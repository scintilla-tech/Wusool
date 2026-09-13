# WASL Mobile (Flutter)

Flutter client for WASL — Arabic-first (RTL) multi-role university transportation app.

## Requirements

Flutter SDK (this machine has Flutter 3.47.1 under the SnapSortTools directory). Use the
project-local wrapper so the SDK + JDK 21 + Android SDK + pub cache are resolved:

```powershell
# from the repository root
.\tools\flutter.ps1 --version
.\tools\flutter.ps1 devices
```

## Run

```powershell
cd mobile
..\tools\flutter.ps1 pub get
..\tools\flutter.ps1 run -d chrome      # or -d windows
```

The backend base URL defaults to `http://localhost:3100/api/v1` and can be overridden:

```powershell
..\tools\flutter.ps1 run -d chrome --dart-define=API_BASE_URL=http://localhost:3100/api/v1
```

## Verify

```powershell
..\tools\flutter.ps1 analyze
..\tools\flutter.ps1 test
..\tools\flutter.ps1 build web --release
```

## Demo credentials (development)

Start the backend and seed demo data (`backend`: `npm run prisma:seed`), then log in with:

| Role | Tenant | Phone | Password |
| --- | --- | --- | --- |
| University Admin | KSU | +966501111111 | AdminPass#1 |
| Driver 1 | KSU | +966550000001 | DriverPass#1 |
| Driver 2 | KSU | +966550000002 | DriverPass#2 |
| Supervisor | KSU | +966550000003 | SuperPass#1 |
| Student | KSU | +966551000001 | Student#123 |

## Structure

```
lib/
  main.dart                 entry (ProviderScope + SharedPreferences)
  app.dart                  MaterialApp (RTL, theme, auth gate)
  core/
    config.dart             API base URL (dart-define)
    theme.dart              design tokens + ThemeData
    token_store.dart        access/refresh token persistence
    api_client.dart         Dio client + auth header + 401 refresh-retry
  features/
    auth/                   auth state + login screen
    home/                   role-aware home scaffold
```

Phase 8 delivers the foundation, design system, and authentication. Role-specific screens
follow in Phases 9–13.
