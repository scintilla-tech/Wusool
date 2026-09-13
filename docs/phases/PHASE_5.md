# PHASE 5 — Trip Lifecycle + Driver Workflow + TripStudent

## Scope
- DailyTrip lifecycle: SCHEDULED → IN_PROGRESS → COMPLETED (CANCELLED).
- Driver "بدء الرحلة" (start trip), pre-trip student list (ATTENDING only for the day).
- TripStudent status transitions: WAITING → BOARDED / NOT_READY / MISSED.
- Manual trip completion (authorized, audited).
- Transport-attendance confirmation: only BOARDED students become confirmed on completion.

## Key Points
- Driver sees only their assigned bus/trip; per-student actions scoped to the active trip.
- Student home locations become pickup stops.
- Attendance intent ≠ transportation; ATTENDING-never-BOARDED never confirmed.
- Audit events: TRIP_STARTED, TRIP_COMPLETED, TRIP_MANUALLY_COMPLETED.

## Acceptance
- Driver endpoints (`/driver/today`, `POST /trips/:id/start`, `PATCH /trips/:id/students/:studentId`, `POST /trips/:id/complete`).
- Tests: status transitions, ATTENDING-not-BOARDED not confirmed, driver scoping, idempotency.
