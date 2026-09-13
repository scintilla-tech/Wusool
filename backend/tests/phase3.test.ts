import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { StructureService } from '../src/modules/structure/structure.service';
import { AssignmentsService } from '../src/modules/assignments/assignments.service';
import { EmployeesService } from '../src/modules/employees/employees.service';
import { requireTenant } from '../src/middlewares/requireTenant';
import { AppError } from '../src/utils/appError';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('tenant isolation', () => {
  it('lists branches scoped to the caller tenantId', async () => {
    const findMany = vi.fn().mockResolvedValue([]);
    const count = vi.fn().mockResolvedValue(0);
    const service = new StructureService(prisma({ branch: { findMany, count } }));
    await service.listBranches('tenant-A', { page: 1, limit: 20 });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { tenantId: 'tenant-A' } }),
    );
  });

  it('rejects updating a branch from another tenant', async () => {
    const findFirst = vi.fn().mockResolvedValue(null);
    const service = new StructureService(prisma({ branch: { findFirst } }));
    await expect(service.updateBranch('tenant-A', 'other-id', { name: 'X' })).rejects.toThrow(
      'Branch not found',
    );
  });

  it('rejects creating a route pointing at another tenant branch', async () => {
    const findFirst = vi.fn().mockResolvedValue(null);
    const service = new StructureService(
      prisma({ branch: { findFirst }, route: { create: vi.fn() } }),
    );
    await expect(
      service.createRoute('tenant-A', { name: 'R1', branchId: 'tenant-B-branch' }),
    ).rejects.toThrow('Branch not found');
  });

  it('rejects duplicate stops in a route', async () => {
    const service = new StructureService(
      prisma({
        route: { findFirst: vi.fn().mockResolvedValue({ id: 'r1' }) },
        neighborhood: { count: vi.fn().mockResolvedValue(1) },
      }),
    );
    await expect(
      service.setRouteStops('t1', 'r1', [
        { neighborhoodId: 'n1', sequenceOrder: 0 },
        { neighborhoodId: 'n1', sequenceOrder: 1 },
      ]),
    ).rejects.toThrow('duplicate');
  });
});

describe('active assignment uniqueness', () => {
  it('deactivates the existing active student assignment before creating a new one', async () => {
    const updateMany = vi.fn().mockResolvedValue({ count: 1 });
    const create = vi.fn().mockResolvedValue({ id: 'a2' });
    const tx = { studentAssignment: { updateMany, create } };
    const service = new AssignmentsService(
      prisma({
        studentProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'sp1' }) },
        route: { findFirst: vi.fn().mockResolvedValue(null) },
        branch: { findFirst: vi.fn().mockResolvedValue(null) },
        $transaction: vi.fn(async (fn: (c: unknown) => unknown) => fn(tx)),
      }),
    );
    await service.assignStudent('t1', { studentProfileId: 'sp1' });
    expect(updateMany).toHaveBeenCalledWith({
      where: { tenantId: 't1', studentProfileId: 'sp1', isActive: true },
      data: { isActive: false },
    });
    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({ tenantId: 't1', studentProfileId: 'sp1', isActive: true }),
    });
  });

  it('rejects assigning a student profile that belongs to another tenant', async () => {
    const service = new AssignmentsService(
      prisma({ studentProfile: { findFirst: vi.fn().mockResolvedValue(null) } }),
    );
    await expect(service.assignStudent('t1', { studentProfileId: 'sp-other' })).rejects.toThrow(
      'Student profile not found',
    );
  });
});

describe('sensitive-field DTO hygiene', () => {
  it('employee DTO never includes nationalIdOrIqama or passwordHash', async () => {
    const user = {
      id: 'u1',
      role: 'DRIVER',
      firstName: 'A',
      lastName: 'B',
      email: null,
      phone: '+966501234567',
      isActive: true,
      driverProfile: {
        employeeId: 'E1',
        nationalIdOrIqama: '1098765432',
        nationality: 'SA',
        joinDate: null,
        iqamaExpiry: null,
        employmentStatus: 'ACTIVE',
        licenseNumber: 'L1',
      },
      supervisorProfile: null,
      fieldSupervisorProfile: null,
    };
    const service = new EmployeesService(
      prisma({ user: { findFirst: vi.fn().mockResolvedValue(user) } }),
    );
    const dto = await service.get('t1', 'u1');
    expect(dto.employeeId).toBe('E1');
    expect(dto.licenseNumber).toBe('L1');
    expect(dto).not.toHaveProperty('nationalIdOrIqama');
    expect(dto).not.toHaveProperty('passwordHash');
    expect(JSON.stringify(dto)).not.toContain('1098765432');
  });
});

describe('requireTenant middleware', () => {
  it('rejects a platform-level principal without a tenant scope', () => {
    const next = vi.fn();
    requireTenant({ auth: { tenantId: null } } as never, {} as never, next);
    const err = next.mock.calls[0][0] as AppError;
    expect(err.code).toBe('TENANT_REQUIRED');
  });

  it('allows a tenant-scoped principal', () => {
    const next = vi.fn();
    requireTenant({ auth: { tenantId: 't1' } } as never, {} as never, next);
    expect(next).toHaveBeenCalledWith();
  });
});
