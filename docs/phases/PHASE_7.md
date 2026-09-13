# PHASE 7 — Notifications + Device Management

## Scope
- NotificationService abstraction (FCM / Huawei Push / APNs / mock).
- DeviceToken registration/management (per-user, platform, active).
- Persisted `Notification` inbox; push delivery for trip events.

## Key Points
- Provider by platform; Huawei handled without GMS assumption; mock provider in dev.
- Tokens never exposed cross-user.
- Events: morning reminder, trip started, pickup, arrival, missed student, alerts.

## Acceptance
- `POST /devices` register; `GET /notifications` inbox.
- Mock provider records notifications; tests for cross-user token isolation.
