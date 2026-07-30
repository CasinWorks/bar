# Guest install guide (pilot)

Guests need the **Blind Tiger** app on a **real phone**. During the pilot, distribution is **invite-only** via the website — not the public App Store / Play Store yet.

---

## Website unlock (recommended for guests)

1. Open the Blind Tiger site → **Download for free** (`/download`)
2. Enter the invite code from staff (format `BT-XXXXXXXX`)
3. Scan the **iOS** or **Android** QR code (or tap the open/download button)

Admins mint and revoke codes in the admin console: **App Downloads** (`/app/download-invites`).

| Platform | What unlocks |
|----------|----------------|
| **iOS** | [TestFlight public link](https://testflight.apple.com/join/9yKpM4rz) |
| **Android** | Short-lived signed APK URL from private Supabase Storage (`app-releases/app-arm64-v8a-release.apk`) |

---

## Option A — TestFlight (iOS)

**One-time (you / dev team)**

1. Apple Developer account with app record **com.intime.inTimeBartender**
2. Build release IPA from the repo:
   ```bash
   cd "/path/to/Bar"
   flutter build ipa --release
   ```
3. Upload with **Xcode → Organizer** or **Transporter**
4. App Store Connect → **TestFlight** → External testing group with public link  
   Current public link: https://testflight.apple.com/join/9yKpM4rz

**Guest steps**

1. Install **TestFlight** from the App Store
2. Scan the iOS QR from `/download` (or open the TestFlight link)
3. Accept → Install **Blind Tiger**
4. Sign up or sign in · age 21+ · accept privacy & terms

---

## Option B — Android APK

**One-time (you / dev team)**

The universal APK is ~90 MB, which exceeds the **50 MB per-file limit on the Supabase free plan**. Build **per-ABI splits** instead — each one fits, and guests download less:

1. Build split APKs:
   ```bash
   flutter build apk --release --split-per-abi
   ```
   Output sizes (current build):

   | File | Size | Covers |
   |------|------|--------|
   | `app-arm64-v8a-release.apk` | ~44 MB | Virtually all Android phones from ~2017 on |
   | `app-armeabi-v7a-release.apk` | ~40 MB | Older 32-bit devices |
   | `app-x86_64-release.apk` | ~46 MB | Emulators, x86 tablets |

2. Upload from `build/app/outputs/flutter-apk/` to Supabase Storage:
   - Bucket: **`app-releases`** (private; created by migration `039_app_download_invites.sql`)
   - Upload **`app-arm64-v8a-release.apk`** at minimum; add the other splits for wider coverage

   The unlock endpoint tries `arm64-v8a` → `armeabi-v7a` → `x86_64` → universal and serves the first one present, so uploading only arm64 is enough to go live.

3. Optional server env (defaults match above):
   - `APP_IOS_DOWNLOAD_URL`
   - `APP_ANDROID_STORAGE_BUCKET` / `APP_ANDROID_STORAGE_OBJECT` (object pins one exact file)
   - Temporary override only: `APP_ANDROID_DOWNLOAD_URL` (avoid Google Drive for production)

**If a single APK ever must exceed 50 MB**, either upgrade the Supabase plan (Pro raises the per-file cap well past this) or publish that file as a **GitHub Release asset** (free, 2 GB per file) and point `APP_ANDROID_DOWNLOAD_URL` at it — the invite gate still lives on `/download`.

**Guest steps**

1. Unlock downloads with an invite code on `/download`
2. Scan the Android QR or tap **Download APK**
3. Allow install from this source if Android prompts
4. Open the app · sign up or sign in · age 21+

Do **not** rely on Google Drive share links for guest install — they often force a preview/login step and break clean QR → install.

---

## Option C — Staff pre-loaded phones (fastest pilot)

- Venue provides loaner phones with the app already installed
- Guest signs in with their account or creates one at the desk
- Same Wi‑Fi as staff devices recommended

---

## Option D — Developer install (dev team only)

Used for internal QA — not for general guests:

```bash
flutter build ios --release
# Install via Xcode or devicectl to registered devices

flutter build apk --release
# adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Guests may need to **Trust Developer** under Settings → General → VPN & Device Management (iOS ad-hoc).

---

## After install

1. **Create account** or sign in
2. Go to the club — **do not expect in-app payment**; time is loaded at the **cash desk**
3. Show **entry QR** at the door when prompted

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Invalid invite code” | Ask desk for a fresh code; check it wasn’t revoked/exhausted |
| Unlock says Android unavailable | Confirm APK uploaded to `app-releases/app-release.apk` |
| “Untrusted developer” | Settings → trust developer profile |
| Balance zero after paying cash | Reopen app; confirm desk loaded correct email |
| Can’t scan QR | Brightness up; allow camera |
| Social features empty | Both users inside same branch, Open to Meet on, migrations 013–015 applied |
