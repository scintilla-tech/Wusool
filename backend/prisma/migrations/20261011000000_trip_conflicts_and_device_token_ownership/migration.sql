-- Fail safely if historic duplicate device tokens require operator review.
-- This migration never deletes or rewrites production data automatically.
BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "DeviceToken" GROUP BY "token" HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate DeviceToken.token values exist; resolve ownership before migration';
  END IF;
  IF EXISTS (
    SELECT 1 FROM "DriverAssignment"
    WHERE "isActive" = true
    GROUP BY "tenantId", "driverProfileId" HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Conflicting active driver assignments exist; resolve them before migration';
  END IF;
  IF EXISTS (
    SELECT 1 FROM "DailyTrip"
    WHERE "status" IN ('SCHEDULED', 'IN_PROGRESS') AND "busId" IS NOT NULL
    GROUP BY "tenantId", "busId", "tripDate" HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Conflicting active bus trips exist; resolve them before migration';
  END IF;
  IF EXISTS (
    SELECT 1 FROM "DailyTrip"
    WHERE "status" IN ('SCHEDULED', 'IN_PROGRESS') AND "driverProfileId" IS NOT NULL
    GROUP BY "tenantId", "driverProfileId", "tripDate" HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Conflicting active driver trips exist; resolve them before migration';
  END IF;
END $$;

CREATE UNIQUE INDEX "DeviceToken_token_key" ON "DeviceToken"("token");
DROP INDEX "DeviceToken_userId_token_key";

CREATE UNIQUE INDEX "DriverAssignment_tenantId_driverProfileId_active_key"
  ON "DriverAssignment" ("tenantId", "driverProfileId")
  WHERE "isActive" = true;

-- Prevent concurrent scheduling from assigning one bus or driver to more than
-- one non-terminal trip on the same date. Prisma cannot express partial unique
-- indexes, so these constraints intentionally live in SQL.
CREATE UNIQUE INDEX "DailyTrip_tenantId_busId_tripDate_active_key"
  ON "DailyTrip" ("tenantId", "busId", "tripDate")
  WHERE "status" IN ('SCHEDULED', 'IN_PROGRESS') AND "busId" IS NOT NULL;

CREATE UNIQUE INDEX "DailyTrip_tenantId_driverProfileId_tripDate_active_key"
  ON "DailyTrip" ("tenantId", "driverProfileId", "tripDate")
  WHERE "status" IN ('SCHEDULED', 'IN_PROGRESS') AND "driverProfileId" IS NOT NULL;

COMMIT;
