import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { AttendanceService } from '../src/modules/attendance/attendance.service';
import { StudentSelfService } from '../src/modules/students/students.self.service';
import { OtpService } from '../src/modules/otp/otp.service';
import { MockOtpProvider } from '../src/providers/otp';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('attendance intent', () => {
  it('rejects setting intent after the cutoff', async () => {
    const service = new AttendanceService(
      prisma({
        studentProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'sp1', tenantId: 't1' }) },
      }),
      '00:00',
    );
    await expect(service.setIntentForUser('t1', 'u1', 'ATTENDING')).rejects.toThrow('cutoff');
  });

  it('upserts the intent before the cutoff', async () => {
    const upsert = vi.fn().mockResolvedValue({ id: 'ai1' });
    const findFirst = vi.fn().mockResolvedValue({ id: 'sp1', tenantId: 't1' });
    const service = new AttendanceService(
      prisma({ studentProfile: { findFirst }, attendanceIntent: { upsert } }),
      '23:59',
    );
    await service.setIntentForUser('t1', 'u1', 'ATTENDING');
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ tenantId: 't1', intent: 'ATTENDING' }),
      }),
    );
  });
});

describe('student registration + verification', () => {
  it('creates an inactive student and returns a dev OTP in development', async () => {
    const created = { id: 'u1', role: 'STUDENT' };
    const tx = {
      user: { create: vi.fn().mockResolvedValue(created) },
      studentProfile: { create: vi.fn().mockResolvedValue({ id: 'sp1' }) },
    };
    const service = new StudentSelfService(
      prisma({
        tenant: {
          findUnique: vi.fn().mockResolvedValue({ id: 't1', code: 'KSU', isActive: true }),
        },
        $transaction: vi.fn(async (fn: (c: unknown) => unknown) => fn(tx)),
      }),
      new OtpService(new MockOtpProvider()),
      true,
    );

    const result = await service.register({
      tenantCode: 'KSU',
      firstName: 'Noor',
      lastName: 'Ali',
      phone: '+966551234567',
      password: 'Password#1',
      studentId: 'S001',
    });

    expect(result.userId).toBe('u1');
    expect(result.devOtp).toMatch(/^\d{6}$/);
    expect(tx.studentProfile.create).toHaveBeenCalled();
  });

  it('verifies and activates the student', async () => {
    const otp = new OtpService(new MockOtpProvider());
    const code = await otp.generate('+966551234567');

    const update = vi.fn().mockResolvedValue({});
    const service = new StudentSelfService(
      prisma({
        user: {
          findFirst: vi.fn().mockResolvedValue({
            id: 'u1',
            role: 'STUDENT',
            phone: '+966551234567',
            isActive: false,
            studentProfile: null,
          }),
          update,
        },
      }),
      otp,
      false,
    );

    await service.verify('u1', code);
    expect(update).toHaveBeenCalledWith({
      where: { id: 'u1' },
      data: { isActive: true },
    });
  });
});
