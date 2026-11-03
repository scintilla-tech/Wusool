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

The backend base URL defaults to `http://localhost:3100/api/v1` on web/desktop and
`http://10.0.2.2:3100/api/v1` on an Android emulator. It can be overridden:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3100/api/v1
```

For a physical Android phone, compile a reachable LAN address or an HTTPS endpoint; never
use `localhost` or `127.0.0.1`. See [`../docs/ANDROID_BUILD.md`](../docs/ANDROID_BUILD.md)
for APK build, installation, Huawei compatibility, and device test instructions.

## Verify

```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --release `
  --dart-define=APP_ENV=demo `
  --dart-define=API_BASE_URL=http://YOUR-LAN-IP:3100/api/v1
```

## Demo credentials (development)

Start the backend and seed demo data as described in `docs/RUN_INSTRUCTIONS.md`. Current
synthetic credentials and all role phone numbers are stored in ignored
`backend/.env.demo.local`; tracked documentation intentionally does not contain passwords.

Use tenant `KKU` for university roles; the platform administrator leaves the tenant blank.

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
