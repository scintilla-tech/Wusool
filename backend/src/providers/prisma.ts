import { PrismaClient } from '@prisma/client';

let prismaClient: PrismaClient | undefined;

export function createPrismaClient(): PrismaClient {
  return new PrismaClient();
}

/**
 * One reusable PrismaClient per process. Never instantiate per request.
 */
export function getPrismaClient(): PrismaClient {
  if (!prismaClient) {
    prismaClient = new PrismaClient();
  }
  return prismaClient;
}

export async function disconnectPrisma(): Promise<void> {
  if (prismaClient) {
    await prismaClient.$disconnect();
    prismaClient = undefined;
  }
}
