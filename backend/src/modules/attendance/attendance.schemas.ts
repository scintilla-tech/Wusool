import { z } from 'zod';

export const setAttendanceIntentSchema = z
  .object({
    intent: z.enum(['ATTENDING', 'ABSENT']),
    note: z.string().trim().min(1).max(500).optional(),
  })
  .strict();

export type SetAttendanceIntentInput = z.infer<typeof setAttendanceIntentSchema>;
