# Wusool hackathon cloud deployment

This runbook is deliberately scoped to a short-lived, synthetic-data demo. It
does not turn the current mock OTP, notification, or document-storage providers
into production services.

## Selected platform

Render is the lowest-friction option for the demo because one Blueprint creates
the Node/Socket.IO web service and a separate managed PostgreSQL database. Render
terminates TLS, so the public endpoints are HTTPS and WSS. The database password
is injected directly into the service and must never be copied into the app.

The checked-in `render.yaml` selects the free plans. Important limitations:

- the free web service sleeps after 15 minutes with no inbound HTTP request or
  WebSocket message; an active Socket.IO demo keeps it awake;
- waking can take about one minute, so open `/health/ready` before the judges arrive;
- Render may restart a free service; use the USD 7/month web-service plan for a
  higher-confidence always-on rehearsal only after explicit approval;
- a free Render PostgreSQL database expires 30 days after creation and has no
  backups. That is suitable only for this disposable demo database.

## Deploy

1. Push the prepared branch to the private GitHub repository.
2. In Render, choose **New > Blueprint**, connect the repository, and select the
   root `render.yaml`.
3. When prompted for `DEMO_PASSWORD`, enter a new strong demo-only password.
   Do not reuse any real user or production password.
4. Confirm that only `wusool-demo-api` and `wusool-demo-db` will be created, both
   on the free plan, before applying the Blueprint.
5. Wait for migrations, the idempotent synthetic seed, and the API startup.
6. Verify `https://<service>.onrender.com/health/ready` returns HTTP 200.

The seed refuses production and remote databases unless all three staging-only
guards are present. Public student registration is disabled because the current
OTP provider intentionally sends nothing.

## Demo accounts

Tenant code for all three accounts: `KKU`. Their password is the secret entered
as `DEMO_PASSWORD` in Render.

| Role | Phone |
| --- | --- |
| Student | `+966500000101` |
| Driver | `+966500000102` |
| Supervisor | `+966500000103` |

All names, identifiers, routes, buses, and attendance records are synthetic.

## Verify the cloud scenario

From `backend/`, set `API_BASE_URL` to the HTTPS origin (without `/api/v1`) and
set `DEMO_PASSWORD` only in the current shell. Then run:

```powershell
npm run smoke:cloud-demo
```

The test performs three logins, student attendance, trip start, a real Socket.IO
WebSocket location update, student REST location verification, boarding, the
supervisor view, and trip completion. It changes the disposable demo state; a
manual redeploy reruns the idempotent seed and resets today's demo trips.

## Build the Android artifacts

After Render provides the final URL:

```powershell
flutter build apk --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://<service>.onrender.com/api/v1
flutter build appbundle --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://<service>.onrender.com/api/v1
```

Copy the APK and AAB to `dist/android/`. Internal App Sharing accepts either APK
or AAB signed with any key and re-signs it with Google's internal-sharing key.
The direct APK is the fallback for Huawei phones without Google Play Services.
The Android application ID is `tech.scintilla.wusool`.

Use **Internal App Sharing**, not an Internal Testing track, for the hackathon
artifact while the release build still uses the local debug key. Google accepts
any signing key for Internal App Sharing and re-signs the upload. Do not establish
the debug certificate as the permanent upload key for a testing/production track.

## Rehearsal checklist

- Warm `/health/ready` and sign in on all demo phones 10 minutes before judging.
- Put the student and driver phones on separate cellular/Wi-Fi networks.
- Start the outbound trip on the driver phone and grant location only while the
  app is in use.
- Confirm the marker moves on the student phone and the supervisor count changes.
- Complete the trip and verify its status.
- Keep the direct APK available offline as the installation fallback.
- Never show the Render database URL, JWT secrets, or demo password on screen.
