# WASL Backend

Multi-tenant university female transportation automation SaaS — backend foundation (Phase 1).

## Stack

- Node.js + TypeScript
- Express
- PostgreSQL + Prisma
- Zod
- Helmet, CORS allowlist
- pino (structured logging with request IDs)

## Requirements

- Node.js >= 20
- PostgreSQL (for migrations and `/health/ready`)

## Setup

```bash
npm install
cp .env.example .env   # fill in real values
npm run prisma:generate
npm run prisma:migrate   # development only
```

## Scripts

| Command                        | Description                                                   |
| ------------------------------ | ------------------------------------------------------------- |
| `npm run dev`                  | Run in watch mode                                             |
| `npm run build`                | Compile to `dist/`                                            |
| `npm start`                    | Run compiled output                                           |
| `npm run typecheck`            | TypeScript typecheck                                          |
| `npm run lint`                 | ESLint                                                        |
| `npm run test`                 | Vitest test suite                                             |
| `npm run prisma:generate`      | Generate Prisma client                                        |
| `npm run prisma:validate`      | Validate schema                                               |
| `npm run prisma:migrate`       | Create/apply dev migrations                                   |
| `npm run db:check-constraints` | Assert raw partial indexes + CHECK constraint exist in the DB |

## Health

- `GET /health/live` — process liveness
- `GET /health/ready` — database readiness

## Conventions

- IDs and phone numbers are Strings.
- Tenant isolation is application-layer (RLS is not active); cross-tenant FK integrity is enforced by tenant-aware queries/service validation.
- National ID/Iqama and student home coordinates are sensitive and never exposed in DTOs.
- Active-assignment uniqueness is enforced by PostgreSQL partial unique indexes (see `prisma/migrations/`).
- Historical data (assignments/trips/attendance) uses `RESTRICT` referential actions so records are never cascade-deleted.

### Migration drift guardrail

`prisma/schema.prisma` cannot express partial unique indexes or the `User` role/tenant
`CHECK` constraint, so these are created in raw SQL migrations. `prisma migrate dev`
will therefore report them as "drift" and may generate a migration that DROPS them.
**Never auto-accept a migration that drops these constraints** — the partial indexes
(`StudentAssignment`, `DriverAssignment`, `SupervisorBusAssignment`) and the
`User_role_tenant_check` constraint are intentional.

Enforce this with `npm run db:check-constraints` (asserts the raw constraints exist in
the database), and prefer `prisma migrate dev --create-only` plus manual review before
applying any generated migration.

### Phase 2 preconditions (before write endpoints)

Tenant isolation is enforced at the application layer today (RLS is deferred). Before
any Phase 2 that introduces write endpoints, the following must be in place:

- Every tenant-scoped write must resolve `tenantId` from authenticated server context
  (never from the client) and filter/scope by it.
- A shared `assertSameTenant(...)` guard must verify that any child row's `tenantId`
  equals its referenced parent's `tenantId` (cross-tenant references are forbidden).
- Composite `(tenantId, id)` foreign keys should be evaluated for the highest-risk
  links (`StudentAssignment`, `DriverAssignment`, `SupervisorBusAssignment`,
  `AttendanceIntent`, `DailyTrip`, `TripStudent`, `RouteNeighborhood`) as defense in depth.
- Denormalized `tenantId` on `DeviceToken`, `Notification`, `UserDocument`, and
  `AuditLog` must be derived from the referenced `user.tenantId` (or equality-enforced),
  so these rows can never be persisted under a mismatched tenant.

See `AGENTS.md` and `docs/architecture/WASL_ARCHITECTURE.md` for the full contract.
