# Soft launch readiness checklist

**Status:** Pilot at one venue · Cash-first · Supabase migrations through **015** applied

---

## Done (product + backend)

- [x] Core loop: desk load → wallet → QR in/out → lounge → summary  
- [x] Admin: dashboard, load time, void, members, events, guest list, HR  
- [x] Admin: Safety & Social desk  
- [x] Migrations **013** (friends/safety), **014** (auto badge-out), **015** (Who’s Inside accuracy)  
- [x] In-app **cash load only** messaging on pricing  
- [x] Signup **privacy & terms** acceptance  

---

## Done (documentation)

- [x] [Staff runbook](./SOFT_LAUNCH_STAFF_RUNBOOK.md) — brief floor team  
- [x] [Guest install](./PILOT_GUEST_INSTALL.md) — add TestFlight link before event  
- [x] [Observability](./OBSERVABILITY.md) — optional Sentry for release builds  

---

## Before first pilot night

- [ ] Two-phone smoke test: load → enter → Open to Meet → friend request → report in admin  
- [ ] TestFlight group created **or** loaner phones ready  
- [ ] Staff runbook walkthrough (15 min)  
- [ ] Privacy/terms reviewed by venue (not legal advice — pilot copy)  
- [ ] Manager name + escalation phone on runbook  

---

## Explicitly out of scope (pilot)

- In-app GCash/card checkout  
- SMS 2FA  
- Public App Store listing  
- Real Grab/insurance API integrations  

---

## Quick links

| Resource | URL |
|----------|-----|
| Admin | https://blind-tiger-admin.vercel.app |
| Demo script | [INVESTOR_DEMO_SCRIPT.md](./INVESTOR_DEMO_SCRIPT.md) |
