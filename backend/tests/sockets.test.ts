import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { resolveAuthorizedSocketContext } from '../src/sockets';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('Socket.IO room authorization', () => {
  it('joins a student only to trips containing that student', async () => {
    const dailyTripFindMany = vi.fn().mockResolvedValue([{ id: 'trip1', busId: 'bus1' }]);
    const client = prisma({
      user: {
        findUnique: vi.fn().mockResolvedValue({
          id: 'student-user',
          role: 'STUDENT',
          tenantId: 'tenant1',
          isActive: true,
          tenant: { isActive: true },
        }),
      },
      studentProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'student1' }) },
      dailyTrip: { findMany: dailyTripFindMany },
    });

    const context = await resolveAuthorizedSocketContext(client, 'student-user');
    expect(context?.rooms).toEqual(['user:student-user', 'tenant:tenant1:trip:trip1']);
    expect(context?.rooms).not.toContain('tenant:tenant1:trip:trip1:staff');
    expect(dailyTripFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: 'tenant1',
          tripStudents: { some: { studentProfileId: 'student1', tenantId: 'tenant1' } },
        }),
      }),
    );
  });

  it('limits a supervisor to buses from active assignments', async () => {
    const dailyTripFindMany = vi.fn().mockResolvedValue([{ id: 'trip2', busId: 'bus2' }]);
    const context = await resolveAuthorizedSocketContext(
      prisma({
        user: {
          findUnique: vi.fn().mockResolvedValue({
            id: 'supervisor-user',
            role: 'SUPERVISOR',
            tenantId: 'tenant1',
            isActive: true,
            tenant: { isActive: true },
          }),
        },
        supervisorProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'supervisor1' }) },
        supervisorBusAssignment: {
          findMany: vi.fn().mockResolvedValue([{ busId: 'bus2' }]),
        },
        dailyTrip: { findMany: dailyTripFindMany },
      }),
      'supervisor-user',
    );

    expect(context?.rooms).toContain('tenant:tenant1:trip:trip2');
    expect(context?.rooms).toContain('tenant:tenant1:trip:trip2:staff');
    expect(context?.rooms).not.toContain('tenant:tenant1:bus:bus2');
    expect(dailyTripFindMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ busId: { in: ['bus2'] } }) }),
    );
  });

  it('rejects inactive users before any room is joined', async () => {
    const context = await resolveAuthorizedSocketContext(
      prisma({
        user: {
          findUnique: vi.fn().mockResolvedValue({
            id: 'u1',
            role: 'DRIVER',
            tenantId: 'tenant1',
            isActive: false,
            tenant: { isActive: true },
          }),
        },
      }),
      'u1',
    );
    expect(context).toBeNull();
  });
});
