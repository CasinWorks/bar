# The Blind Tiger Social Club

Premium mobile companion for **The Blind Tiger Social Club & Speakeasy Entertainment Lounge** — ported from the `the-blind-tiger-social-club` reference app to Flutter.

## Quick Start

```bash
flutter pub get
flutter run
```

## Experience Flow

1. **Secret Entry** — Knock 3× or enter passcode `tiger` (or skip)
2. **Club Passport** — Customize avatar (hair, eyes, accessory, pin color, codename)
3. **Socialite Pass** — Choose 30/60/90 min tiers with 15% GCash referral discount
4. **Checkout** — Secure transaction loading screen
5. **Active Lounge** — Timer hub with 5 tabs:
   - **Challenge** — Socialite challenges with point rewards
   - **Play** — Mini-games (Spin the Vinyl, Mixology Secret, etc.)
   - **Feed** — Live lounge activity with reactions
   - **Menu** — Storytelling cocktails that deduct reservation time
   - **Rank** — Leaderboard sorted by reserved time
6. **Summary** — Checkout receipt, badges, referral code, extend or exit

## Design System (from reference)

| Token | Value |
|-------|-------|
| Crimson | `#8B0000` |
| Gold Brushed | `#C5A059` |
| Gold Bright | `#E5C180` |
| Dark Background | `#050200` |
| Tiger Orange | `#D97706` |

**Fonts:** Cinzel (display), Inter (body), Share Tech Mono (timer/data)

**Modes:** Speakeasy (before midnight) → Microclub (after midnight) — toggle via `currentHour` in AppState

## Project Structure

```
lib/
├── core/theme/          # Blind Tiger color palette & theme
├── core/widgets/        # Lattice background, luxury cards, tiger buttons
├── data/mock_data.dart  # Drinks, challenges, leaderboard, branches
├── models/              # Avatar, drinks, challenges, feed, etc.
├── providers/           # AppState (timer, points, social, menu)
├── screens/
│   ├── onboarding/      # Secret entry
│   ├── avatar/          # Passport identity
│   ├── purchase/        # Pricing + checkout
│   ├── lounge/          # Active hub + tabs
│   └── summary/         # Session receipt
└── router/
```

## Demo Tips

- Password hint: type **tiger** at the secret door
- **Freeze Pass** pauses your timer; **Activate Pass** opens branch check-in
- Order drinks from **Menu** tab — each deducts minutes from your reservation
- Play games to earn points; unlock **The Director's Safe** at 150+ pts

## Reference

Based on the React prototype in `the-blind-tiger-social-club/` (Google AI Studio mockup).
