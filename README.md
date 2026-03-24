# 😴 Baby Sleep Tracker v2 — Multi-User Edition

A free, self-hosted baby sleep tracker for families. Track naps, predict schedules, and sync across devices — all for $0.

Built as a single-file PWA with Supabase for auth and data. Deploy to Cloudflare Pages in minutes.

---

## ✨ Features

- **👨‍👩‍👧 Multi-user** — Each family gets their own account and isolated data
- **⏱️ One-tap timer** — Track naps and night sleep with a single tap
- **🔮 Smart nap predictions** — Based on your baby's actual patterns (weighted 7-day half-life)
- **⏰ Wake window tracking** — Schedule pressure indicator shows when the next nap is due
- **🔄 Nap transition detection** — Detects 3→2 nap transitions automatically
- **🌅 Morning plan** — Start each day with 2-nap and 3-nap scenario projections
- **⭐ Day rating & trends** — Rate each day and view weekly trends over time
- **📅 Calendar history** — Browse past sleep data in a calendar view
- **🌐 Bilingual** — English + Chinese (中文)
- **📱 PWA** — Installable on any device, works offline
- **🔑 Invite codes** — Control who can sign up with an invite code system
- **🔄 Real-time sync** — Changes sync instantly across devices via Supabase

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Single HTML file PWA (vanilla JS, no framework) |
| Backend | Supabase (Auth + Postgres + Row Level Security) |
| Hosting | Cloudflare Pages (recommended, free) |
| **Cost** | **$0** — handles hundreds of users on free tiers |

---

## 🚀 Setup Guide

### 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a free account
2. Create a new project (pick any region close to you)
3. Go to **SQL Editor**, paste the contents of `supabase-schema.sql`, and run it
4. Go to **Authentication → Settings** and make sure email auth is enabled
5. Note your **Project URL** and **anon key** from **Settings → API**

### 2. Configure the App

1. Open `index.html`
2. Find `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the top of the file
3. Replace the placeholder values with your Supabase project credentials:

```js
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-key-here';
```

### 3. Deploy to Cloudflare Pages

1. Push this repo to GitHub
2. Go to [Cloudflare Pages](https://pages.cloudflare.com) and create a new project
3. Connect your GitHub repo
4. Configure the build:
   - **Build command:** _(leave empty — it's a static site)_
   - **Output directory:** `/` or `.`
5. Hit **Deploy** 🎉

Your app will be live at `https://your-project.pages.dev`.

### 4. Generate Invite Codes (Optional)

To restrict sign-ups, generate invite codes in the Supabase SQL Editor:

```sql
INSERT INTO invites (code) VALUES ('family-smith-2024');
INSERT INTO invites (code) VALUES ('grandma-access');
```

Share these codes with the people you want to invite.

---

## 💻 Local Development

No build tools needed. Just open the file:

```bash
# Option 1: Open directly
open index.html

# Option 2: Local server (recommended for PWA features)
python3 -m http.server 8000
# Then visit http://localhost:8000
```

---

## 📦 Migration from v1

If you're coming from the single-user v1:

1. In v1, go to **Settings → Export** to download your data
2. Sign up / log in to v2
3. Use **Settings → Import** to load your exported data _(planned feature)_

---

## 💰 Free Tier Limits

Everything runs on free tiers. Here's how the numbers look with ~50 families:

| Resource | Free Tier Limit | Est. Usage (50 families) |
|---|---|---|
| Supabase Database | 500 MB | ~5 MB |
| Supabase Auth | 50,000 MAU | 50 |
| Supabase API Calls | 500k/month | ~150k |
| Cloudflare Pages | Unlimited bandwidth | ✅ |

> **Bottom line:** You'd need thousands of users before hitting any limits. For a family sleep tracker, free tier is more than enough.

---

## 📄 License

MIT — do whatever you want with it.
