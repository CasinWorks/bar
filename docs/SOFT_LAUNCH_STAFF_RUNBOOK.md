# Blind Tiger — Staff Runbook (Soft Launch Pilot)

**Audience:** Door, bar, cash desk, floor manager  
**Model:** Entry packages (minutes + drinks) · Mobile wallet · QR entry/exit  
**Economy detail:** [CLUB_DISTRICT_ECONOMY.md](./CLUB_DISTRICT_ECONOMY.md)

---

## Before doors open

- [ ] Admin logged in: https://blind-tiger-admin.vercel.app  
- [ ] **Load Package** page tested with a test member  
- [ ] Door phone on **Staff → Door scanner**  
- [ ] Bar phone on **Staff → Tip pad** (if tipping tonight)  
- [ ] Wi‑Fi stable; guest phones not in airplane mode  
- [ ] Know tonight’s **branch name** (must match member session)  
- [ ] Safety lead knows **Admin → Safety & Social** desk  
- [ ] Migration `020_time_packages_economy.sql` applied (for drink allowances + bonus awards)  

---

## Cash package load (guest messaging)

Tell every guest:

> “Time is your currency. Pick a package at the desk — minutes and drinks land on your phone.”

**Packages**

| Package | Price | Time | Drinks |
|---------|-------|------|--------|
| Quick Escape | ₱699 | 90 min | 2 |
| Standard Night | ₱999 | 180 min | 4 |
| After Hours | ₱1,299 | 240 min | 5 |
| Unlimited | ₱1,799 | Until closing | Soft cap |

**Desk steps**

1. Admin → **Load Package**  
2. Search member by name or email  
3. Select package → Credit  
4. Ask guest to **open the app** — balance should update within seconds  

**If balance doesn’t move**

- Guest pulls down / reopens app  
- Confirm correct member selected  
- Check admin load appeared in recent history  
- Retry a smaller test load if needed  

**Void a mistake**

- Admin → recent load → **Void** (requires migration 010 on Supabase)  

---

## Entry

1. Guest has **time on wallet** (or active pass from balance)  
2. Guest shows **entry QR** in app  
3. Door staff scans → confirm **entry**  
4. Guest lands in **lounge** with timer running  

---

## During the night

| Situation | Action |
|-----------|--------|
| Guest out of time but still inside | Time depleted overlay — load at desk or request exit |
| Guest wants to leave | App → request exit → **exit QR** → door scan |
| Safety / harassment | Guest uses **Report** in app; staff checks **Safety & Social** (reports are private) |
| Ride help | Guest **Get a Ride** — staff assists; record may appear in admin |
| Who’s Inside looks wrong | Both must be **inside**, **Open to Meet**, app open/recent (~90s heartbeat), same branch |

---

## Exit & end of night

- Exit scan completes visit; guest sees **summary/receipt**  
- Sessions left open **48+ hours** auto-complete (admin can **Run check** on Safety desk)  
- Review dashboard: active visits should trend to zero  

---

## Escalation

| Issue | Who |
|-------|-----|
| App crash / install | Floor tech / dev contact |
| Wrong load / refund policy | Manager + admin void |
| Serious safety incident | Manager + Safety desk + venue protocol |

---

*Pilot edition — update branch names and contacts before each event.*
