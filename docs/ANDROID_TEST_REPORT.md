# Android APK verification report

Date: 2026-11-03 (Asia/Riyadh)

## Artifact

- APK: `dist/android/wusool-demo-release.apk`
- Size: 59,796,175 bytes (57.0 MB)
- SHA-256: `3FC8F95AC991A5BE079BA364B21C09238A8AAD2EA458756CCF1D5BEAD2CC69C0`
- Package/version: `com.wasl.wasl_mobile`, `1.0.0+1`
- Android range: minimum API 24, target API 36
- Architectures: ARMv7, ARM64, x86_64
- Signing: Android debug certificate, APK Signature Scheme v2; not production signing
- Compiled API base: `http://172.20.10.3:3100/api/v1` with `APP_ENV=demo`

## Build and static verification

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | PASS, no issues |
| `flutter test --no-pub` | PASS, 11 tests |
| `flutter build apk --release ...` | PASS |
| APK signature verification | PASS (v2, Android Debug certificate) |
| APK install via `adb install -r` | PASS |
| Backend `/health/live` via LAN address | PASS |
| Existing backend suite | 333 tests were already passing; backend was not changed in this task |

The merged APK manifest requests `INTERNET`, `ACCESS_COARSE_LOCATION`, and
`ACCESS_FINE_LOCATION`. AndroidX also generates its signature-level
`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. No background location, notification, storage,
camera, or microphone permission is requested.

## Device/emulator verification

Test device: Android AOSP API 35 x86_64 emulator without Google Play Services or a Google
APIs system image. This provides a useful no-GMS compatibility check but is not a substitute
for a physical Huawei/EMUI/HarmonyOS device.

| Flow | Result |
| --- | --- |
| Cold install and launch | PASS |
| Real login through LAN backend | PASS (student and driver synthetic accounts) |
| Student home and today's trip | PASS |
| Driver trip and attendance roster | PASS |
| Start trip | PASS; backend reported `IN_PROGRESS` |
| Foreground location permission | PASS; precise/approximate Android dialog shown |
| Location without GMS | PASS using Android `LocationManager` |
| Socket.IO location publish | PASS; first sample reached backend after handshake fix |
| Student tracking | PASS; backend returned the injected bus coordinates |
| Map | PASS; OpenStreetMap tiles loaded over HTTPS with the bus marker |
| Attendance UI/data | PARTIAL; attendance states and driver controls loaded from backend, but a final manual attendance mutation was not submitted on the emulator |
| Fatal Android/Flutter errors | None observed during final flow |

The injected location was `18.2465, 42.5117`; the student tracking endpoint returned that
location for the active trip and the final map rendered the marker. During testing, a race
was found where the first location could be emitted before Socket.IO connected. The client
now queues the newest bounded sample and flushes it on connect/reconnect.

## Huawei assessment

- The app uses `flutter_map` and HTTPS OpenStreetMap tiles, not Google Maps SDK.
- Android location is forced through the platform `LocationManager`; the tested flow works on
  an AOSP image with no Google Play Services.
- The current Flutter client has no FCM, Huawei Push Kit, or local notification integration.
  Push delivery therefore was not testable and is not a current client capability.
- Socket.IO, REST, secure token storage, attendance, and map rendering worked on no-GMS AOSP.
- A physical Huawei device was not attached. EMUI/HarmonyOS battery management, vendor
  permission screens, background process killing, and AppGallery policy compliance remain
  unverified. The app intentionally publishes location only while active and does not ask for
  background location.

## Network and release limitations

- The demo APK permits cleartext HTTP to support a trusted LAN backend. It will work only
  while `172.20.10.3:3100` is reachable from the phone. Rebuild if the computer's LAN address
  changes.
- A remote/production-like build must use `APP_ENV=production` and an HTTPS URL. The Dart
  configuration rejects loopback in demo/production and rejects HTTP in production.
- Cleartext traffic should be disabled in the Android manifest before any store release.
- No store publication, production keystore, production backend, or production database was
  used or changed.

