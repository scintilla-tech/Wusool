# PHASE 3 — University Structure + Users + Employee Management + Assignments

## Scope
- University Admin manages own tenant: branches, neighborhoods, routes (with ordered stops), buses.
- Employee management: drivers, supervisors, field supervisors (create/list/update/deactivate).
- Student management (admin-side create/list/update/deactivate).
- Assignments: student→route/bus, driver→bus, supervisor→bus (active-unique, transactional).

## Key Points
- All queries tenant-scoped by `req.auth.tenantId`; UNIVERSITY_ADMIN only.
- Employee records: firstName, lastName, phone, employeeId, nationalIdOrIqama, nationality, joinDate, iqamaExpiry, employmentStatus. `nationalIdOrIqama` never in lists/responses.
- Partial-index assignment constraints enforced transactionally (deactivate-old → activate-new).
- Admin dashboard statistics from real DB values only.

## Acceptance
- CRUD endpoints for structure/employees/students under `/api/v1`, all tenant-isolated.
- Assignment service enforces one-active-per-student/bus.
- Tests: tenant isolation (A can't touch B), assignment uniqueness, sensitive-field DTO exclusion.
