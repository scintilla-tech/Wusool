import { z } from 'zod';

export const attendanceDirectionSchema = z.enum(['OUTBOUND', 'RETURN']);

export const setAttendanceIntentSchema = z
  .object({
    direction: attendanceDirectionSchema.optional(),
    intent: z.enum(['ATTENDING', 'ABSENT']),
    note: z.string().trim().min(1).max(500).nullable().optional(),
    expectedFinishTime: z
      .string()
      .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'expectedFinishTime must be HH:mm')
      .nullable()
      .optional(),
  })
  .strict();

export const driverAttendanceSchema = setAttendanceIntentSchema.omit({ direction: true });

export const closeAttendanceSchema = z.object({ confirm: z.literal(true) }).strict();

export type AttendanceDirection = z.infer<typeof attendanceDirectionSchema>;
export type SetAttendanceIntentInput = z.infer<typeof setAttendanceIntentSchema>;
