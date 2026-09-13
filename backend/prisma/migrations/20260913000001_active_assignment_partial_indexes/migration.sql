-- Active assignment constraints: PostgreSQL partial unique indexes.
-- Prisma cannot express partial unique indexes, so these are created via raw SQL.
-- These enforce:
--   - one active StudentAssignment per student (tenantId + studentProfileId)
--   - one active DriverAssignment per bus (tenantId + busId)
--   - one active SupervisorBusAssignment per bus (tenantId + busId)

CREATE UNIQUE INDEX "StudentAssignment_tenantId_studentProfileId_active_key"
  ON "StudentAssignment" ("tenantId", "studentProfileId")
  WHERE "isActive" = true;

CREATE UNIQUE INDEX "DriverAssignment_tenantId_busId_active_key"
  ON "DriverAssignment" ("tenantId", "busId")
  WHERE "isActive" = true;

CREATE UNIQUE INDEX "SupervisorBusAssignment_tenantId_busId_active_key"
  ON "SupervisorBusAssignment" ("tenantId", "busId")
  WHERE "isActive" = true;
