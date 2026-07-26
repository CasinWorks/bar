# Observability (pilot)

Crash and error visibility for soft launch. **One pilot night** can run with manual reporting; production scale needs a service.

---

## Built in (app)

- `AppObservability.install()` in `main.dart` logs uncaught Flutter errors to the console in debug builds.  
- For release builds on guest phones, console logs are not visible — use TestFlight crash reports or add Sentry below.

---

## Recommended: Sentry (optional, ~30 min setup)

1. Create project at [sentry.io](https://sentry.io)  
2. Add dependency (when ready):
   ```yaml
   dependencies:
     sentry_flutter: ^8.0.0
   ```
3. Wrap `runApp` with `SentryFlutter.init` and pass DSN via `--dart-define=SENTRY_DSN=...`  
4. Never commit the DSN to git; set in CI / local build flags  

**Pilot minimum:** enable Sentry for **release** TestFlight builds only.

---

## Supabase

- Dashboard → **Logs** → API / Postgres errors during the event  
- Watch failed RPCs (`send_friend_request`, `list_whos_inside`, etc.)

---

## Admin API (Vercel)

- Vercel project → **Logs** for `/api/safety-social/*` and `/api/time-loads/*`  
- Failed loads often show as 500 with Supabase error text  

---

## Night-of checklist

- [ ] One person monitoring Supabase + Vercel logs for first 30 minutes  
- [ ] Staff channel (group chat) for “app broken” screenshots  
- [ ] Note member email + time + action for any failure  
