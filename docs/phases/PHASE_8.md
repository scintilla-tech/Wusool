# PHASE 8 — Flutter Foundation + Design System + Authentication

## Scope
- Flutter project with Riverpod; role-aware navigation scaffold.
- Design system: tokens (deep navy, emerald/teal, off-white), components (cards/buttons/form/status chips), RTL.
- Authentication screens (login) wired to backend; secure token storage (access + refresh) with auto-refresh.

## Key Points
- Arabic-first RTL. Professional institutional style.
- API client with tenant context, error handling, token refresh interceptor.
- Env-configurable backend base URL (dev localhost).

## Acceptance
- `flutter analyze` clean; app builds for a local target; login flow works against local backend.
