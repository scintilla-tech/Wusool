# WASL — User Flows

## 1. Student Registration

1. Student opens app, selects/enters university (tenant) context.
2. Enters first name, last name, university email, university ID, phone.
3. Selects branch and neighborhood; sets exact home location via map/device GPS.
4. Receives verification via OTP abstraction (phone/email depending on config; mock provider in dev).
5. Account activated; student may then set daily attendance intent.

Tenant is resolved server-side (never self-selected from raw client input).

## 2. Student Attendance

- Student sees current day (e.g., "الاثنين 8 سبتمبر").
- Chooses "نعم، سأحضر" (ATTENDING) or "لن أحضر" (ABSENT).
- May change intent before the configured daily cutoff.
- Confirmation state shown. ATTENDING ≠ transported.

## 3. Student Tracking

- Before active trip: waiting state.
- On trip start: notification received.
- Tracking screen: map, latest bus location, last-updated timestamp, trip status, prominent "اتصال بالسائق" action, secondary contact-supervisor/emergency action.
- No continuous Uber-style tracking; bus location updates ~3 min during ACTIVE trip only.

## 4. Driver Trip

1. Driver logs in, sees assigned bus/route/trip.
2. Pre-trip: sees only students whose intent is ATTENDING for that day and who belong to the active assignment/route.
3. Student home locations are pickup stops.
4. Driver taps "بدء الرحلة" → location sharing begins → students notified.
5. For each student: mark WAITING → BOARDED / NOT_READY / MISSED.
6. On arrival (geofence), trip auto-completes; BOARDED students become transport-attendance-confirmed; tracking stops; audit event created.

## 5. Supervisor

- Dashboard of assigned buses only: trip states, attending/boarded/missed counts, alerts.
- Handle/escalate missed students per authorized workflow.
- No cross-tenant visibility.

## 6. Field Supervisor

- Today's relevant buses/trips, arrival/status visibility, stop confirmation, incident recording, escalation. Mobile-friendly.

## 7. University Admin

- Manage only own tenant: branches, neighborhoods, routes, buses, drivers, supervisors, field supervisors, students, assignments.
- Assign students→routes/buses, drivers→buses, supervisors→buses (respect active-assignment uniqueness).
- Operational dashboard using real DB values only (no fabricated analytics).

## 8. Platform Super Admin

- Manage tenants/universities, tenant status, basic configuration. Remains outside university scope.

## 9. Authentication

- Argon2id password hashing; short access JWT; rotating refresh sessions; logout / logout-all; disabled-account and expiration handling; refresh reuse protection.
