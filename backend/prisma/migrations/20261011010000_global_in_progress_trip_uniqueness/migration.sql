-- A stale IN_PROGRESS trip must never compete with today's trip for GPS routing.
-- Fail for operator review rather than rewriting historical data.
BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "DailyTrip"
    WHERE "status" = 'IN_PROGRESS' AND "busId" IS NOT NULL
    GROUP BY "tenantId", "busId" HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Multiple IN_PROGRESS trips exist for one bus; resolve before migration';
  END IF;
  IF EXISTS (
    SELECT 1 FROM "DailyTrip"
    WHERE "status" = 'IN_PROGRESS' AND "driverProfileId" IS NOT NULL
    GROUP BY "tenantId", "driverProfileId" HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Multiple IN_PROGRESS trips exist for one driver; resolve before migration';
  END IF;
END $$;

CREATE UNIQUE INDEX "DailyTrip_tenantId_busId_in_progress_key"
  ON "DailyTrip" ("tenantId", "busId")
  WHERE "status" = 'IN_PROGRESS' AND "busId" IS NOT NULL;

CREATE UNIQUE INDEX "DailyTrip_tenantId_driverProfileId_in_progress_key"
  ON "DailyTrip" ("tenantId", "driverProfileId")
  WHERE "status" = 'IN_PROGRESS' AND "driverProfileId" IS NOT NULL;

COMMIT;
