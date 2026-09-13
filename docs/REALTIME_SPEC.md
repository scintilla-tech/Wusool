# WASL — Realtime Specification (Socket.IO)

## Architecture

Driver GPS → WASL backend → authorized Socket.IO rooms → student/supervisor clients.

## Rooms (server-controlled)

- `tenant:{tenantId}:trip:{tripId}` — trip broadcast (status, arrival)
- `tenant:{tenantId}:bus:{busId}` — bus location during active trip
- `tenant:{tenantId}:user:{userId}` — personal notifications/events

Client must NOT join arbitrary rooms; the server joins sockets to rooms on authentication + authorization.

## Handshake & Authorization

- Socket handshake authenticates via access JWT (or query token).
- Each sensitive event re-validates: authenticated user, role, tenant, active trip, assigned driver/bus.
- Driver may only publish location for their own active trip (driver+bus+tenant match).

## Events

- Client → Server: `trip:location` (driver, `{ lat, lng, timestamp }`)
- Server → room: `trip:started`, `trip:location`, `trip:arrived`, `trip:completed`, `student:status`, `alert`

## Location Validation

- DRIVER role, authenticated, tenant match, active trip, assigned driver, assigned bus.
- Valid coordinates, reasonable timestamp, throttled (~3 min during ACTIVE trip only).
- No permanent high-frequency GPS history; transient latest-location is the default (Redis optional later).

## Reconnect / Lifecycle

- Room membership rebuilt on reconnect from server state.
- On trip completion: stop location publishing, notify room, close/leave trip room.
