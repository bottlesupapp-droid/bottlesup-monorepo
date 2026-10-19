# Staging environment

Today there is **one** Supabase project, `hwmynlghrmtoufyrcihp`, and it is production. The website, the user app, the vendor app and the admin dashboard all talk to it, and the apps' test builds write straight into it. Nothing below has been run for you: creating a project and setting secrets needs your Supabase and Stripe logins.

**Ground rules**

1. Staging uses **Stripe test keys only** and a **separate** Supabase project.
2. It is a copy of production's **schema, not its data**. No customer rows.
3. Never put a production key in a staging build, or the reverse.

> Do **not** build staging with `supabase db push` from the migration folders. There are six of them (website, user app, vendor app x2, admin, root) and they overlap. The website's migrations never create `profiles` or `promo_codes`, so they do not reproduce production. Clone production's real schema instead (step 3).

---

## 0. Run the audits on production first

Open `supabase/audit/01_live_db_audit.sql` and `02_money_users_overlap.sql` in the **production** SQL editor, run each, and export the CSV. They are read-only. Fix anything CRITICAL before you clone, otherwise you copy the hole into staging too. The second one also tells you whether real money ever went through the old app tables.

## 1. Create the project

Same region and Postgres major version as production (production is Postgres 17).

```bash
supabase login
supabase projects create bottlesup-staging \
  --org-id <ORG_ID> --db-password '<long random password>' --region <same region as prod>
```

Then note the new project ref and export these in your shell (not in a file that gets committed):

```bash
export STAGING_REF=<new ref>
export PROD_DB_URL='postgresql://postgres.<prod-ref>:<password>@<pooler-host>:5432/postgres'
export STAGING_DB_URL='postgresql://postgres.<staging-ref>:<password>@<pooler-host>:5432/postgres'
```

Use the **session pooler** connection strings from *Project Settings -> Database* (the direct host is IPv6-only on many networks).

## 2. (optional) Look before you copy

```bash
psql "$PROD_DB_URL" -c "select count(*) from pg_tables where schemaname='public'"
```

## 3. Copy production's schema, without data

`pg_dump` must be the same major version as the server. This machine has `pg_dump` 15 and production is 17, so either install 17 or use the Supabase CLI with Docker:

```bash
# option A: install a matching pg_dump
brew install postgresql@17
/opt/homebrew/opt/postgresql@17/bin/pg_dump "$PROD_DB_URL" \
  --schema-only --schema=public --no-owner -f prod_public_schema.sql

# option B: Supabase CLI (needs Docker Desktop running)
supabase db dump --db-url "$PROD_DB_URL" --schema public -f prod_public_schema.sql
```

Then load it into staging and stop at the first error:

```bash
psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f prod_public_schema.sql
```

This brings over tables, RLS policies, functions, triggers and grants. It does **not** bring storage buckets: recreate the ones the audit listed under "public storage bucket" in *Storage* (same names). `prod_public_schema.sql` can contain production object names; keep it out of git.

## 4. Auth settings (Dashboard -> Authentication)

- **URL Configuration:** Site URL = your staging website URL. Add to Redirect URLs: the staging website, `http://localhost:5173`, and the app deep link `bottlesup://`.
- **Email templates:** paste `apps/bottles-up-website-main/supabase/email-templates/magic-link.html` into the magic-link template.
- **Providers:** if the apps use Google/Apple sign-in, create separate OAuth clients for staging.

## 5. Edge functions and secrets

The website owns the functions the apps will keep using (checkout, booking status, staff RPC helpers).

```bash
cd apps/bottles-up-website-main
supabase functions deploy --use-api --project-ref "$STAGING_REF"

supabase secrets set --project-ref "$STAGING_REF" \
  STRIPE_SECRET_KEY=sk_test_... \
  STRIPE_WEBHOOK_SECRET=whsec_... \
  RESEND_API_KEY=re_... \
  TICKETS_FROM_EMAIL=tickets@<verified domain> \
  SITE_URL=https://<staging website url>
```

In the Stripe **test mode** dashboard add a webhook endpoint pointing at `https://<STAGING_REF>.supabase.co/functions/v1/site-stripe-webhook`, listening for `checkout.session.completed`, and use its signing secret above. `site-stripe-webhook` is already set to `verify_jwt = false` in the website's `supabase/config.toml`.

## 6. Seed one admin and one server

Create two users in *Authentication -> Users* (any emails you control), edit the two emails at the top of `supabase/staging/seed_staging.sql`, and run it in the **staging** SQL editor. It makes the first user a CMS admin, the second a server who can record club payments, and forces `payments_mode` to `test`.

## 7. Point each client at staging

**Website** (Vercel preview, or locally):

```bash
cd apps/bottles-up-website-main
printf 'VITE_SUPABASE_URL=https://%s.supabase.co\nVITE_SUPABASE_ANON_KEY=<staging anon key>\n' "$STAGING_REF" > .env.staging
npx vite --mode staging
```

`.env.*` files are gitignored there. For a hosted staging site set the same two variables in Vercel's Preview environment.

**User app** already reads `--dart-define` and refuses to start without it:

```bash
cd apps/bottles-up-user
flutter run \
  --dart-define=SUPABASE_URL=https://$STAGING_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging anon key> \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
```

**Vendor app** read production credentials from `packages/shared` with no way to override them. `packages/shared/lib/src/supabase/supabase_config.dart` now accepts the same two defines, and with no defines it still uses the production values, so existing builds are unchanged:

```bash
cd apps/bottles-up-vendor
flutter run \
  --dart-define=SUPABASE_URL=https://$STAGING_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging anon key>
```

A build made **without** the defines still talks to production. When you are ready, remove the `defaultValue`s so a forgotten define fails loudly instead.

## 8. Make staging catch mistakes

Once the apps are repointed at the website's tables, a stray call to an old table should fail loudly in staging, not quietly in production. In the **staging** project only:

```sql
revoke insert, update, delete on
  public.events_bookings, public.table_bookings, public.event_table_bookings,
  public.bookings, public.event_bookings, public.club_table_bookings,
  public.payment_transactions, public.stripe_customers
from anon, authenticated;
```

Also give staging builds their own identity so they never replace a real install: a different bundle id / application id suffix (for example `.staging`) and an app name like "BottlesUp (staging)".

---

## After you have read the audit: production clean-up (your call, nothing here has been run)

Use the exact function signature the audit printed. These change production, so run them yourself.

```sql
-- if audit 1 reported exec_sql (or similar) as CRITICAL/HIGH:
revoke execute on function public.exec_sql(text) from public, anon, authenticated;
-- then, once nothing legitimate uses it:
-- drop function public.exec_sql(text);
```

Archiving `run-migration` out of the user app's repo did **not** remove it from production. Check what is actually deployed:

```bash
supabase functions list --project-ref hwmynlghrmtoufyrcihp
# if run-migration is listed and you do not need it:
# supabase functions delete run-migration --project-ref hwmynlghrmtoufyrcihp
```

## Checklist

- [ ] Audit 1 and 2 run on production, CSVs saved, CRITICAL items handled
- [ ] Staging project created, schema loaded, buckets recreated
- [ ] Auth URLs and email template set
- [ ] Functions deployed, Stripe **test** secrets and webhook set
- [ ] Admin and server seeded, `payments_mode = 'test'`
- [ ] Website, user app and vendor app each run against staging
- [ ] Legacy-table writes revoked on staging
- [ ] Staging builds have a separate bundle id and app name
