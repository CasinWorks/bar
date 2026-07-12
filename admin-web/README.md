# Blind Tiger Admin Console

Cash-first operations console for **The Blind Tiger** pilot. GCash and digital payments are deferred — time is loaded at the desk via cash (or card / complimentary).

## Stack

| Layer | Tech |
|-------|------|
| Client | React 19 + Vite (port **5173**) |
| API | Node.js + Express (port **4000**) |
| Auth & data | Supabase |

## Features

- **Dashboard** — members, active sessions, cash collected today, time loaded
- **Load Time (Cash)** — POS bills (₱1,000 / ₱2,000 / ₱3,000 / ₱5,000 / ₱10,000) auto-credit club time; **Void** mistaken loads from recent history
- **Members & Access** — search, ban/unban, whitelist (admin only)
- **Calendar & Events** — create and manage club events
- **Guest List** — per-event guests, check-in status
- **HR & Employment** — roster, departments, hire/terminate

## Prerequisites

1. Supabase project with migrations **001–008** applied (especially `008_admin_platform.sql`).
2. Node.js 18+.

## One-time setup

### 1. Run migration 008

In Supabase **SQL Editor**, run:

```
supabase/migrations/008_admin_platform.sql
```

### 2. Create your first admin user

Sign up in the mobile app (or Supabase Auth), then promote in SQL Editor:

```sql
-- Replace with your admin email
update public.profiles
set role = 'admin'
where email = 'you@example.com';
```

For HR-only access, use `role = 'hr'` instead.

### 3. Environment files

**Server** — copy `server/.env.example` → `server/.env`:

```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
CLIENT_ORIGIN=http://localhost:5173
PORT=4000
```

**Client** — copy `client/.env.example` → `client/.env`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key
VITE_API_URL=http://localhost:4000
```

Never commit `.env` files or the service role key.

### 4. Install & run

```bash
# Terminal 1 — API
cd admin-web/server && npm install && npm run dev

# Terminal 2 — UI
cd admin-web/client && npm install && npm run dev
```

Open **http://localhost:5173** and sign in with your admin account.

## Investor demo script

1. **Member** signs up on the Flutter app and logs in (wallet shows 0 time).
2. **Admin** opens Load Time → searches member → loads e.g. 60 min for ₱500 cash.
3. **Member** phone updates in real time (wallet balance animates up).
4. **Member** buys entry pass / enters lounge — time deducts live.
5. **Admin** shows Dashboard cash totals and optional event + guest list for a themed night.

## Roles

| Role | Mobile app | Admin web |
|------|------------|-----------|
| `member` | Yes | No |
| `staff` | Yes (door / bar) | No |
| `hr` | No | Yes (no ban/whitelist edits) |
| `admin` | No | Full access |

Banned members cannot log in to the mobile app.

## Deploy to Vercel

The admin console (React UI + Express API) deploys as **one Vercel project** from the `admin-web/` folder.

### 1. Import the repo

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import **CasinWorks/bar**
3. Set **Root Directory** to `admin-web`
4. Framework Preset: **Other** (vercel.json is already configured)

### 2. Environment variables

In **Project Settings → Environment Variables**, add for Production (and Preview if you want):

| Name | Value |
|------|--------|
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase **service role** key (server only) |
| `CLIENT_ORIGIN` | your Vercel URL, e.g. `https://bar-xxx.vercel.app` |
| `VITE_SUPABASE_URL` | same as `SUPABASE_URL` |
| `VITE_SUPABASE_ANON_KEY` | same as `SUPABASE_ANON_KEY` |

Do **not** set `VITE_API_URL` on Vercel — the UI calls `/api` on the same domain.

### 3. Supabase Auth allowlist

In Supabase → **Authentication → URL Configuration**:

- **Site URL**: your Vercel URL
- **Redirect URLs**: add `https://YOUR_PROJECT.vercel.app/**`

### 4. Deploy

Click **Deploy**. After it finishes:

- Admin UI: `https://YOUR_PROJECT.vercel.app`
- Health: `https://YOUR_PROJECT.vercel.app/api/health`

### CLI alternative

```bash
cd admin-web
npx vercel login
npx vercel          # preview
npx vercel --prod   # production
```

Paste the same env vars when prompted (or set them in the dashboard first).

## Production notes

- Never expose `SUPABASE_SERVICE_ROLE_KEY` to the browser — it stays in Vercel server env only.
- Restrict who has admin/hr roles in Supabase.
- For a tighter pilot lock-down, put the Vercel URL behind password protection (Vercel Deployment Protection) or VPN.
