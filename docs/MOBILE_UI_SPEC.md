# WASL — Mobile UI Specification (Flutter + Riverpod)

## Stack

Flutter + Riverpod. Single codebase with role-aware navigation. Arabic-first, RTL.

## Design System

- Visual direction: deep navy, emerald/teal, white/off-white, subtle gradients, clean cards, clear typography, generous spacing.
- Reusable design tokens (colors, spacing, typography) and components (cards, buttons, form fields, status chips).
- Professional Saudi institutional style; no childish/generic demo appearance.

## Navigation (Student)

الحضور (Attendance), التتبع (Tracking), الملف الشخصي (Profile).

- Attendance: current day (e.g., "الاثنين 8 سبتمبر"), "نعم، سأحضر" / "لن أحضر", confirmation state, changeable before cutoff.
- Tracking: pre-trip waiting state; on active trip: map + latest bus location + last-updated timestamp + trip status + prominent "اتصال بالسائق" + secondary contact-supervisor/emergency.
- Profile: view/update phone, home location, branch (where allowed), logout, delete-account request.

## Driver

- Assigned bus/route/trip; pre-trip student list (ATTENDING only); "بدء الرحلة".
- Per-student status: waiting / boarded / not-ready / missed (clear Arabic wording).
- Location sharing only during active trip.

## Supervisor / Field Supervisor

- Supervisor: assigned buses dashboard (trip states, attending/boarded/missed counts, alerts); missed-student escalation.
- Field supervisor: today's buses/trips, arrival/status visibility, stop confirmation, incident recording, escalation.

## University Admin

- Mobile-appropriate management screens (structure, employees, students, assignments) + dashboard statistics from real DB values.
- Full desktop admin, if more appropriate, may be a web application; mobile roles remain as specified.

## Maps

- Map provider abstraction; Google Maps (GMS), Huawei Map Kit (no-GMS), iOS mapping. Business logic must not depend on a vendor.
