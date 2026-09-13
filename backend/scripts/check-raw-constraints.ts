/**
 * Guard against Prisma migration drift silently dropping raw PostgreSQL
 * constraints that cannot be expressed in schema.prisma.
 *
 * Prisma cannot express partial unique indexes or CHECK constraints, so these
 * are created in raw SQL migrations. `prisma migrate dev` will therefore report
 * them as "drift" and may generate a migration that drops them. This script
 * asserts they still exist in the target database so CI can catch regressions.
 *
 * Usage: DATABASE_URL=... npm run db:check-constraints
 */
import { PrismaClient } from '@prisma/client';

const REQUIRED_PARTIAL_INDEXES = [
  'StudentAssignment_tenantId_studentProfileId_active_key',
  'DriverAssignment_tenantId_busId_active_key',
  'SupervisorBusAssignment_tenantId_busId_active_key',
];

const REQUIRED_CHECK_CONSTRAINTS = ['User_role_tenant_check'];

async function main(): Promise<void> {
  const prisma = new PrismaClient();
  try {
    const indexes = await prisma.$queryRaw<Array<{ indexname: string }>>`
      SELECT indexname FROM pg_indexes WHERE indexdef LIKE '%WHERE%'
    `;
    const indexNames = new Set(indexes.map((row) => row.indexname));
    for (const name of REQUIRED_PARTIAL_INDEXES) {
      if (!indexNames.has(name)) {
        throw new Error(`Missing partial unique index: ${name}`);
      }
    }

    const constraints = await prisma.$queryRaw<Array<{ conname: string }>>`
      SELECT conname FROM pg_constraint WHERE contype = 'c'
    `;
    const constraintNames = new Set(constraints.map((row) => row.conname));
    for (const name of REQUIRED_CHECK_CONSTRAINTS) {
      if (!constraintNames.has(name)) {
        throw new Error(`Missing CHECK constraint: ${name}`);
      }
    }

    console.log(
      `Verified ${REQUIRED_PARTIAL_INDEXES.length} partial indexes and ${REQUIRED_CHECK_CONSTRAINTS.length} CHECK constraint(s).`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
