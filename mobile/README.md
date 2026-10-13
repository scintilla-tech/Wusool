# WASL Mobile (Flutter)

Flutter client for WASL — Arabic-first (RTL) multi-role university transportation app.

## Requirements

Flutter SDK (stable) with a configured toolchain (JDK + Android SDK for Android builds).

```bash
flutter --version
flutter devices
```

## Run

```bash
cd mobile
flutter pub get
flutter run -d chrome      # or -d windows / an attached device
```

The backend base URL defaults to `http://localhost:3100/api/v1` and can be overridden:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3100/api/v1
```

## Verify

```bash
flutter analyze
flutter test
flutter build web --release
```

## Demo credentials (development)

Start the backend and seed demo data as described in `docs/RUN_INSTRUCTIONS.md`. Current
synthetic credentials and all role phone numbers are stored in ignored
`backend/.env.demo.local`; tracked documentation intentionally does not contain passwords.

Use tenant `KSU` for university roles; the platform administrator leaves the tenant blank.

## Structure

```
lib/
  main.dart                 entry (ProviderScope + secure-token migration)
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
