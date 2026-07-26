# Club District time economy

Canonical entry packages (mobile + admin + migration `020_time_packages_economy.sql`):

| Package | Price | Duration | Drinks |
|---------|-------|----------|--------|
| Quick Escape | ₱699 | 90 min | 2 |
| Standard Night | ₱999 | 180 min | 4 |
| After Hours | ₱1,299 | 240 min | 5 |
| Unlimited | ₱1,799 | Until closing (~480 min soft) | Soft cap 12 |

## Apply migration

Run in Supabase SQL editor (or CLI):

`supabase/migrations/020_time_packages_economy.sql`

This adds `admin_load_package` and `admin_award_bonus_time` RPCs. Until applied, admin package loads fall back to legacy `admin_load_time` (minutes only, no drink allowance).

## Staff runbook (cash desk)

1. Guest picks a package at the desk.
2. Admin → **Load Package** → select account + package → Credit.
3. Guest phone wallet updates live (pull to refresh on pricing).
4. Guest shows entry QR (or VIP allowlist auto-enters).
5. Standard drinks use package allowance; premium can burn minutes or pay at bar.
6. Experiences (VIP Lounge, etc.) spend minutes from the wallet.
7. Bonus time (birthday, bring-a-friend, games) via **Award bonus time** on the same page.
8. Exit QR → visit summary shows package, drinks, experiences, bonuses.

## Battery time psychology

- Green: 180–121 minutes remaining  
- Yellow: 120–31  
- Red: ≤30 (soft “Extend your time” cue)

## Source of truth files

- Flutter: `lib/models/club_packages.dart`
- Admin client: `admin-web/client/src/lib/timePricing.js`
- Admin server: `admin-web/server/src/lib/timePricing.js`
