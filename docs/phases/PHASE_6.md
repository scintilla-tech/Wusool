# PHASE 6 — Realtime Secure Tracking + Geofence

## Scope
- Socket.IO bootstrap (authenticated handshake, server-controlled rooms).
- Driver location publishing during ACTIVE trip only (~3 min), validated.
- Student/supervisor receive trip location/status via rooms.
- Branch geofence: local Haversine arrival; auto-completion on validated arrival samples/dwell.

## Key Points
- Rooms: `tenant:{id}:trip:{id}`, `tenant:{id}:bus:{id}`, `tenant:{id}:user:{id}`.
- Per-event authorization (role/tenant/active trip/assigned driver+bus/coords/timestamp).
- No permanent high-frequency GPS history.
- Auto-completion: two valid arrival samples or sample+dwell → TRIP_COMPLETED + TRIP_AUTO_COMPLETED_BY_GEOFENCE audit.

## Acceptance
- Driver location rejected for other drivers' trips / inactive trips.
- Geofence auto-complete test.
- Room isolation test (A can't receive B's events).
