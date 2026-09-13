# PHASE 4 — Student Registration + Profile + Attendance Intent

## Scope
- Public student registration with OTP verification (provider abstraction + mock).
- Student profile (view/update phone, home location, branch where allowed).
- Daily attendance intent (ATTENDING/ABSENT) with cutoff; changeable before cutoff.
- Delete-account request with confirmation.

## Key Points
- Tenant resolved server-side (never client-provided). Branch/neighborhood/home-location captured.
- OTP abstraction: phone/email per config; mock provider in dev.
- Attendance intent is an upsert (idempotent) per day; never conflated with transportation.
- Student home coordinates sensitive; returned only to the student and authorized trip context.

## Acceptance
- `POST /students/register` + verify; `GET/PATCH /students/me`; `PUT /attendance/today`.
- Tests: registration tenant scoping, OTP flow (mock), intent upsert, cutoff behavior.
