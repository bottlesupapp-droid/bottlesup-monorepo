# Bottles Up — Super-Admin Dashboard

React + Vite + TypeScript admin panel for the Bottles Up platform. Connects to the shared Supabase project used by the Flutter mobile apps and manages vendors, clubs, events, bookings, and inventory.

## Tech stack

| Layer | Choice |
|---|---|
| Frontend | React 18, Vite 5, TypeScript, Tailwind CSS, shadcn/ui |
| Auth & DB | Supabase (PostgreSQL + Auth) |
| Payments | Stripe — server-side only via Supabase Edge Function |
| Deployment | Vercel (static SPA + edge functions live in Supabase) |

---

## Local development

### Prerequisites

- Node.js ≥ 18
- npm ≥ 9
- A Supabase project with the schema already applied

### Setup

```bash
# 1. Clone and install
git clone https://github.com/KDR9MGR/bottles-up-dashboard-admin.git
cd bottles-up-dashboard-admin
npm install

# 2. Configure environment variables
cp .env.example .env
# Edit .env and fill in VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY

# 3. Start the dev server (http://localhost:8080)
npm run dev
```

---

## Environment variables

| Variable | Required | Where to find it |
|---|---|---|
| `VITE_SUPABASE_URL` | ✅ | Supabase Dashboard → Project Settings → API → Project URL |
| `VITE_SUPABASE_ANON_KEY` | ✅ | Supabase Dashboard → Project Settings → API → `anon` `public` key |

**Do not commit `.env`.** It is listed in `.gitignore`. Use `.env.example` as the canonical reference for all developers and CI pipelines.

> The anon key is safe to expose in the browser — it identifies the project but grants no privileges beyond what Supabase Row-Level Security policies allow. The real enforcement is in the database.

### Vercel environment variables

Set these in **Vercel Dashboard → Project → Settings → Environment Variables** (or with `vercel env add`):

```
VITE_SUPABASE_URL        = https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY   = eyJhbGci...
```

The Stripe secret key is used exclusively by the `process-refund` Supabase Edge Function and must **never** appear in Vercel's environment variables or the frontend build. Set it as a Supabase secret only:

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
```

---

## Database setup

Two migration files must be applied to the Supabase project before deploying:

```
supabase/migrations/20260614000000_admin_rls.sql    # RLS policies + is_admin() function
supabase/migrations/20260614000001_admin_actions.sql # vendors.status column + admin_audit_log table
```

**Apply in the Supabase SQL Editor** (Dashboard → SQL Editor → New query), running `_admin_rls.sql` first.

### Creating admin accounts

Self-registration is disabled. Admin accounts must be created manually:

1. **Invite the user** — Supabase Dashboard → Authentication → Users → Invite user
2. **Grant platform admin access** — run in SQL Editor:

```sql
INSERT INTO public.vendor_admins (id) VALUES ('<auth-uid-from-step-1>');
```

The user's uid must exist in `vendor_admins` or all protected API calls will be blocked by RLS. The `vendors.role` column stores vendor business roles (`staff`, `promoter`, `venue_owner`, `organizer`) and is unrelated to platform admin access.

---

## Supabase Edge Function

The `process-refund` edge function handles Stripe refunds server-side so the Stripe secret key never reaches the browser.

```bash
# Deploy (requires Supabase CLI)
supabase functions deploy process-refund

# Set the Stripe secret (once per environment)
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
```

---

## Deploying to Vercel

### First deployment

```bash
# Install Vercel CLI (if not already)
npm i -g vercel

# From the project root
vercel
```

Follow the prompts. Vercel auto-detects Vite and uses the settings from `vercel.json`:
- **Build command**: `npm run build`
- **Output directory**: `dist`
- **SPA rewrite**: all paths → `index.html` (so deep links like `/vendors` work)

### Subsequent deploys

Push to the `main` branch — Vercel deploys automatically if the GitHub integration is connected.

### Verify locally before pushing

```bash
npm run build   # must produce dist/ with no errors
npm run preview # serves dist/ at http://localhost:4173 — test deep links manually
```

---

## Security headers

`vercel.json` sets the following response headers on every route:

| Header | Value | Purpose |
|---|---|---|
| `X-Frame-Options` | `DENY` | Prevents clickjacking in older browsers |
| `X-Content-Type-Options` | `nosniff` | Prevents MIME-type sniffing |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referrer leakage |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Blocks unused browser APIs |
| `Content-Security-Policy` | see below | Restricts resource origins |

**CSP breakdown:**

```
default-src 'self'
script-src  'self'
style-src   'self' 'unsafe-inline'        ← Tailwind / shadcn inline styles
connect-src 'self' https://*.supabase.co wss://*.supabase.co
img-src     'self' data: https:           ← user avatars from Supabase Storage
font-src    'self'
object-src  'none'
base-uri    'self'
frame-ancestors 'none'
```

> **If you add Vercel Analytics**, add `https://vitals.vercel-insights.com` to `connect-src`.  
> **If you add Google Fonts**, add `https://fonts.googleapis.com https://fonts.gstatic.com` to `style-src` and `font-src`.

---

## Project structure

```
src/
├── contexts/AuthContext.tsx      # Supabase auth — enforces admin role on login
├── components/
│   ├── AppSidebar.tsx            # Navigation
│   ├── ConfirmDialog.tsx         # Reusable confirmation modal
│   ├── EventsChart.tsx           # Live 6-month events/ticket chart
│   └── UserBookingsDialog.tsx    # Per-user booking history modal
├── hooks/
│   ├── useAdminActions.ts        # Approve/suspend/unpublish/refund + audit log
│   └── useSupabase.ts            # All Supabase data hooks (with refetch)
├── pages/
│   ├── Index.tsx                 # Dashboard overview + charts
│   ├── Vendors.tsx               # Approve / Suspend vendors
│   ├── Events.tsx                # Unpublish / Remove events
│   ├── Users.tsx                 # View user booking history
│   └── Bookings.tsx              # Process / Flag refunds
└── types/supabase.ts             # TypeScript interfaces matching DB schema

supabase/
├── migrations/                   # Apply to Supabase before first deploy
└── functions/process-refund/     # Stripe refund edge function (server-side key)
```
