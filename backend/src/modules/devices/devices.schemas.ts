import { z } from 'zod';

export const registerDeviceSchema = z
  .object({
    token: z.string().trim().min(16).max(512),
    platform: z.enum(['IOS', 'ANDROID', 'HUAWEI', 'WEB']),
    deviceId: z.string().trim().min(1).max(128).optional(),
  })
  .strict();

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;
