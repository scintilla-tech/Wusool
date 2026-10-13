import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { attendanceOpensAt, addBusinessDays, dateOnly } from '../src/utils/date';
import { StudentSelfService } from '../src/modules/students/students.self.service';
import { OtpService } from '../src/modules/otp/otp.service';
import { MockOtpProvider } from '../src/providers/otp';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('attendance intent', () => {
  it('opens outbound at 18:00 Riyadh on the previous day', () => {
    const operationalDate = dateOnly(new Date('2026-10-12T12:00:00Z'));
    expect(attendanceOpensAt('OUTBOUND', operationalDate).toISOString()).toBe(
      '2026-10-11T15:00:00.000Z',
    );
  });

  it('opens return at 11:00 Riyadh on the operational day', () => {
    const operationalDate = addBusinessDays(new Date('2026-10-11T12:00:00Z'), 1);
    expect(attendanceOpensAt('RETURN', operationalDate).toISOString()).toBe(
      '2026-10-12T08:00:00.000Z',
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
