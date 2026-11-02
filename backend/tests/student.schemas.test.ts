import { describe, expect, it } from 'vitest';
import { studentCreateSchema, studentUpdateSchema } from '../src/modules/students/students.schemas';
import { profileUpdateSchema, registerSchema } from '../src/modules/students/students.self.schemas';

describe('student home location validation', () => {
  it.each([
    [
      'admin create',
      studentCreateSchema,
      {
        firstName: 'Noor',
        lastName: 'Ali',
        phone: '0551234567',
        password: 'Password#1',
        studentId: 'S1',
        homeLatitude: 24.7,
      },
    ],
    ['admin update', studentUpdateSchema, { homeLongitude: 46.6 }],
    [
      'self register',
      registerSchema,
      {
        tenantCode: 'KKU',
        firstName: 'Noor',
        lastName: 'Ali',
        phone: '0551234567',
        password: 'Password#1',
        studentId: 'S1',
        homeLatitude: 24.7,
      },
    ],
    ['self update', profileUpdateSchema, { homeLongitude: 46.6 }],
  ])('rejects incomplete coordinate pairs for %s', (_name, schema, payload) => {
    expect(schema.safeParse(payload).success).toBe(false);
  });
});
