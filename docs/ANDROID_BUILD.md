# Android build and device setup

Wusool's Android client reads its environment and API endpoint from Dart compile-time
defines. The app never needs to be edited to switch between an emulator, a LAN demo, and
an HTTPS deployment.

## API environments

`APP_ENV` accepts `development`, `demo`, or `production`. `API_BASE_URL` must end in
`/api/v1`.

- Android emulator development defaults to `http://10.0.2.2:3100/api/v1`.
- A physical phone must use the backend computer's LAN address, for example
  `http://172.20.10.3:3100/api/v1`. The phone and computer must be on the same trusted
  network, the backend must listen on a non-loopback interface, and Windows Firewall must
  allow inbound TCP 3100 on the private network.
- A remote demo or production build should use an authorized HTTPS endpoint. Production
  builds reject HTTP and loopback URLs at startup.

Never use `127.0.0.1` or `localhost` in a build installed on a phone: both refer to the
phone itself.

## Build

From `mobile`:

```powershell
flutter pub get
flutter analyze
flutter test

# Emulator/local development
flutter build apk --release `
  --dart-define=APP_ENV=development `
  --dart-define=API_BASE_URL=http://10.0.2.2:3100/api/v1

# Physical-device LAN demo (replace the address)
flutter build apk --release `
  --dart-define=APP_ENV=demo `
  --dart-define=API_BASE_URL=http://172.20.10.3:3100/api/v1

# Remote HTTPS environment
flutter build apk --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://api.example.test/api/v1
```

The checked-in release configuration intentionally uses the Android debug key. It is
suitable only for local installation/testing and must be replaced with an approved,
privately managed production signing configuration before store distribution.

The demo manifest permits cleartext HTTP so a trusted-LAN backend can be reached. A store
release should disable cleartext traffic and use HTTPS only.

## Install

Enable developer options and USB debugging on the phone, connect it, accept the host key,
then run:

```powershell
adb devices
adb install -r dist/android/wusool-demo-release.apk
```

Alternatively, copy the APK to the phone and open it from Files. Android may ask to allow
the selected file manager to install unknown apps. Disable that permission again after
installation.

## Android and Huawei compatibility

- Maps use `flutter_map` and HTTPS OpenStreetMap raster tiles; no Google Maps SDK or Google
  API key is required.
- Android location is explicitly requested through the platform `LocationManager`, so the
  driver location flow does not require Google Play Services. Location is requested only
  after a driver starts a trip and only while the app is active.
- The app declares Internet, coarse location, and fine location. It does not declare
  background location, storage, camera, microphone, or notification permissions.
- Socket.IO tracking uses the configured backend origin and supports WebSocket/polling. A
  restrictive network, VPN, or firewall may still block it.
- Push notifications are not implemented by the current Flutter client. There is therefore
  no Firebase Cloud Messaging or Huawei Push Kit dependency to validate. Adding push later
  will require an HMS-compatible delivery path for Huawei devices without GMS.

For Huawei verification, test the APK on a Huawei device without GMS (or an AOSP emulator)
and cover driver GPS acquisition, map tile loading, socket reconnection, and battery-saving
behavior. A generic Android emulator cannot certify EMUI/HarmonyOS-specific behavior.

## Device smoke-test checklist

1. Confirm `/health/live` and `/health/ready` are reachable from the phone's browser using
   the same host and port compiled into the APK.
2. Sign in with a synthetic local/demo account; do not use production credentials.
3. Open trip lists for the relevant roles and confirm REST responses render.
4. Open a map and confirm OpenStreetMap tiles load.
5. Start a driver trip, grant location only while using the app, inject/move the device
   location, and confirm the tracking socket updates the observer view.
6. Record and close attendance, then refresh the related student/guardian view.
7. Deny location once and permanently, and confirm the rest of the app remains usable.

