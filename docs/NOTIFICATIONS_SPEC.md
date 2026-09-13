# WASL — Notifications Specification

## NotificationService Abstraction

Provider interface with implementations for: FCM, Huawei Push (no-GMS), iOS/APNs. Do NOT assume FCM works on Huawei devices without GMS.

```ts
interface PushProvider {
  id: 'fcm' | 'huawei' | 'apns' | 'mock';
  send(device: DeviceToken, payload: PushPayload): Promise<void>;
}
```

If real credentials are unavailable, use a development/mock provider (logs and records the notification; no network). Provider selection by `DeviceToken.platform`.

## DeviceToken

`tenantId`, `userId`, `token`, `platform` (IOS/ANDROID/HUAWEI/WEB), `deviceId`, `isActive`, timestamps. Tokens are per-user and never exposed cross-user.

## Event Types

- morning reminder (attendance cutoff)
- trip started
- bus/pickup-relevant events
- arrival
- missed student
- operational alerts

## Delivery

- Notifications persisted to `Notification` (inbox) and pushed via provider.
- Never expose another user's tokens or inbox.
