# Guest install guide (pilot)

Guests need the **Blind Tiger** iOS app on a **real iPhone** (iOS 16+ recommended). During the pilot, distribution is via **TestFlight** or **pre-installed devices** — not the public App Store yet.

---

## Option A — TestFlight (recommended)

**One-time (you / dev team)**

1. Apple Developer account with app record **com.intime.inTimeBartender**  
2. Build release IPA from the repo:
   ```bash
   cd "/path/to/Bar"
   flutter build ipa --release
   ```
3. Upload with **Xcode → Organizer** or **Transporter**  
4. App Store Connect → **TestFlight** → Internal or External testing group  
5. Add testers by Apple ID email; they receive the TestFlight invite  

**Guest steps**

1. Install **TestFlight** from the App Store  
2. Open the invite link / email from Blind Tiger  
3. Install **Blind Tiger Social Club**  
4. Sign up or sign in · age 21+ · accept privacy & terms  

---

## Option B — Staff pre-loaded phones (fastest pilot)

- Venue provides loaner iPhones with the app already installed (developer/ad-hoc build)  
- Guest signs in with their account or creates one at the desk  
- Same Wi‑Fi as staff devices recommended  

---

## Option C — Developer install (dev team only)

Used for internal QA — not for general guests:

```bash
flutter build ios --release
# Install via Xcode or devicectl to registered devices
```

Guests may need to **Trust Developer** under Settings → General → VPN & Device Management.

---

## After install

1. **Create account** or sign in  
2. Go to the club — **do not expect in-app payment**; time is loaded at the **cash desk**  
3. Show **entry QR** at the door when prompted  

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Untrusted developer” | Settings → trust developer profile |
| Balance zero after paying cash | Reopen app; confirm desk loaded correct email |
| Can’t scan QR | Brightness up; allow camera |
| Social features empty | Both users inside same branch, Open to Meet on, migrations 013–015 applied |

---

*Replace TestFlight link here when available:*  
`TestFlight public link: ___________________________`
