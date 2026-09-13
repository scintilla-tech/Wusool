import type { DevicePlatform } from '@prisma/client';

export interface PushPayload {
  type: string;
  title: string;
  body?: string;
  data?: Record<string, unknown>;
}

export interface PushProvider {
  id: 'fcm' | 'huawei' | 'apns' | 'mock';
  send(platform: DevicePlatform, token: string, payload: PushPayload): Promise<void>;
}

/**
 * Development/mock push provider. Does not send anything. Real FCM / Huawei
 * Push / APNs providers plug in here when credentials are available.
 */
export class MockPushProvider implements PushProvider {
  readonly id = 'mock' as const;
  async send(_platform: DevicePlatform, _token: string, _payload: PushPayload): Promise<void> {
    // no-op in development
  }
}
