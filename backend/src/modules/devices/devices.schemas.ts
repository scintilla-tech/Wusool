import { z } from 'zod';

export const registerDeviceSchema = z
  .object({
    token: z.string().trim().min(16).max(512),
    platform: z.enum(['IOS', 'ANDROID', 'HUAWEI', 'WEB']),
    deviceId: z.string().trim().min(1).max(128),
  })
  .strict();

export const deactivateDeviceSchema = z
  .object({
    deviceId: z.string().trim().min(1).max(128),
  })
  .strict();

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;
