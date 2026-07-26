# Firebase Cloud Messaging setup (Blind Tiger)

App code registers **FCM** and **APNs** device tokens and enqueues social pushes
into `push_dispatch_queue`. Delivery only happens when a drain path runs with
valid secrets.

## Architecture

```
member_notifications INSERT
  → enqueue_social_push trigger
  → push_dispatch_queue
  → drain via:
       A) Admin POST /api/push/drain  (FCM HTTP v1)   ← preferred
       B) Edge Function send-social-push (FCM and/or APNs)
  → iOS Notification Center (app backgrounded or killed)
```

Foreground / soft-background alerts can also appear as **local** banners from
in-app inbox polling. Those do **not** work when the app is force-quit — remote
APNs/FCM is required for Notification Center in that case.

## 1. Firebase Console

1. Open https://console.firebase.google.com/
2. Create project (or open existing) — Analytics optional
3. Add **iOS** app
   - Bundle ID: `com.intime.inTimeBartender`
   - Download `GoogleService-Info.plist`
4. (Optional later) Add **Android** app
   - Package name: `com.intime.in_time_bartender`
   - Download `google-services.json`

## 2. Apple APNs → Firebase (required for iPhone push)

1. Apple Developer → Keys → create key with **Apple Push Notifications service (APNs)**
2. Download `.p8`, note Key ID + Team ID
3. Firebase → Project settings → Cloud Messaging → Apple app
   - Upload APNs Authentication Key (`.p8` + Key ID + Team ID)

Without this step, Android can work but **iOS will not receive pushes**.

## 3. Drop config files into the repo

```text
ios/Runner/GoogleService-Info.plist
android/app/google-services.json   # only if you added Android
```

Then open `ios/Runner.xcworkspace` in Xcode once and confirm
`GoogleService-Info.plist` is in the Runner target (Copy Bundle Resources).

## 4. Service account (server send)

1. Firebase → Project settings → Service accounts
2. Generate new private key → JSON file
3. On **Vercel / admin** `.env`:

```bash
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...entire json...}
FIREBASE_PROJECT_ID=blindtigerclub-4894e
PUSH_WEBHOOK_SECRET=pick-a-long-random-string
CRON_SECRET=optional-if-using-vercel-cron-auth
```

4. Optional — same JSON on **Supabase Edge Function** secrets if you drain via
   `send-social-push` instead of (or in addition to) the admin route:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
supabase secrets set FIREBASE_PROJECT_ID=blindtigerclub-4894e
```

Direct APNs (for `kind=apns` / Live Activity tokens) also needs:

```bash
supabase secrets set APNS_KEY_ID=...
supabase secrets set APNS_TEAM_ID=...
supabase secrets set APNS_BUNDLE_ID=com.intime.inTimeBartender
supabase secrets set APNS_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----'
supabase secrets set APNS_ENVIRONMENT=sandbox   # or production for TestFlight/App Store
```

Do **not** invent credentials — use your Apple `.p8` and Firebase service account.

## 5. Supabase SQL

Run in SQL Editor (if not already):

- `018_push_notifications.sql`
- `019_fcm_token_kind.sql`

## 6. Drain the push queue (critical)

Jobs sit in `push_dispatch_queue` until drained. A once-a-day cron is **not**
enough.

### Preferred: Database Webhook (near-instant)

Supabase → Database → Webhooks → insert on `public.push_dispatch_queue`:

```http
POST https://blind-tiger-admin.vercel.app/api/push/drain
x-push-secret: <PUSH_WEBHOOK_SECRET>
```

Or point the webhook at the Edge Function URL with body `{ "drain": true }` /
the inserted `record`.

### Also: Vercel Cron

`admin-web/vercel.json` schedules `GET/POST /api/push/drain` every minute
(`* * * * *`). Requires a Vercel plan that allows sub-daily crons. Hobby may
only run daily — use the Database Webhook if so.

Manual test:

```http
POST https://blind-tiger-admin.vercel.app/api/push/drain
x-push-secret: <PUSH_WEBHOOK_SECRET>
```

## 7. iOS build notes

- Debug builds use `aps-environment = development` (sandbox APNs).
- Release/Profile builds use `RunnerRelease.entitlements` with
  `aps-environment = production`.
- Token registration stores `environment` as `sandbox` in debug and
  `production` in release (`kDebugMode`).
- Match Firebase APNs key + drain `APNS_ENVIRONMENT` / FCM APNs config to the
  build you installed (dev install ≠ TestFlight).

## 8. Rebuild phones + user settings

1. Delete Blind Tiger from the phone (clears stale tokens).
2. Install a fresh debug or release build; open the app; **Allow** notifications.
3. Confirm Settings → Blind Tiger → Notifications:
   - Allow Notifications **On**
   - Lock Screen / Notification Center / Banners **On**
   - Sounds **On**
4. Settings → General → Background App Refresh → Blind Tiger **On** (helps soft
   background; killed app still needs remote push).
5. Sign in as a member so FCM + APNs tokens register in `device_push_tokens`.

## 9. Verify background / killed delivery

1. In Supabase SQL, confirm the receiver has tokens:

```sql
select user_id, kind, left(token, 16) as token_prefix, environment, updated_at
from device_push_tokens
order by updated_at desc
limit 20;
```

   Expect `fcm` (and usually `apns`) for that user.

2. On the **receiver** phone: open Blind Tiger once, then swipe it away (force
   quit) or lock the phone with the app not in foreground.

3. From another account, send a friend ping / chat.

4. Within a few seconds (webhook) or ≤1 minute (cron), check:
   - iOS Notification Center shows “Message from …” / “Ping from …”
   - `push_dispatch_queue.dispatched_at` is set
   - Admin drain response `{ ok: true, sent: ≥1 }`

5. If `sent: 0` but rows dispatch: tokens missing or wrong `kind`.
   If drain returns 503: `FIREBASE_SERVICE_ACCOUNT_JSON` missing on admin / edge.
   If FCM errors mention APNs: upload the APNs key in Firebase (step 2).
   If APNs `BadEnvironment`: sandbox vs production mismatch (step 7).
