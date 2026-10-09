# Going live: website accounts, workspaces and owner tools

What goes live: sign-up and log-in for personal and business accounts, business verification, owner and staff workspaces, team
invitations, the scoped door scanner, venue setup (floor plans, tables, bottle menu, booking times), bookings view and booking
links. All of it is already on the website's `main` and deployed, **switched off**. Going live is: database, email function, auth
setting, then the switch.

The production preflight (7 Oct) found no collisions and nothing missing. Production is Postgres 17.4. Two findings shape the steps:

- Production's `checkin_ticket()` was rewritten (it also checks in table bookings and guest tickets) and has **no** fall-through bug.
  So `20260830120000_fix_checkin_ticket_early_returns.sql` is **not applied**: it would be stopped by its guard, and forcing it would
  replace the better live function with an older one.
- Production's `verify_ticket_otp()` is the old version, so `20260830130000_fix_verify_ticket_otp_expiry.sql` **does** apply.

Do not use `supabase db push`: the skipped check-in migration has the earliest filename and would stop it, and production's
migration history is not known to match the repo's.

Take 30 to 45 minutes at a quiet time. Everything is additive except the entry-code fix and one constraint (`scan_attempts_result_check`,
which gains `wrong_event`; the preflight confirmed no existing row would be rejected).

## 1. Apply the seven migrations (Supabase dashboard > SQL editor, production project)

For each file, in this order: copy it, paste it into a new SQL editor tab, Run, and check it says success before the next one.
On a Mac, `pbcopy < <file>` copies a file without opening it. The files are in
`apps/bottles-up-website-main/supabase/migrations/` (website `main`):

1. `20260830130000_fix_verify_ticket_otp_expiry.sql` (entry-code fix; guarded, says "fixed" or "already fixed")
2. `20261006120000_tenancy_foundation.sql`
3. `20261007100000_accounts_onboarding.sql`
4. `20261008100000_team_invitations.sql`
5. `20261009100000_door_scanner.sql`
6. `20261010100000_venue_setup.sql`
7. `20261011100000_venue_bookings.sql`

### 1b. Two follow-up migrations (client feedback of 10 Oct), once their website branches are merged to `main`

The client found two problems on the live onboarding pages: a business added by mistake could not be left or cancelled, and the
organizer's Events page had no way to create an event. The fixes are two more migrations. They are on the website branches
`fix/leave-onboarding-and-cancel-business` and `feat/organizer-create-event` (stacked: merge the first, then the second), and they only
work after the seven above. **Until they are applied, the "Cancel this business" button and the organizer's "Create event" button show an
error** (the rest of the site is unaffected). Apply them the same way, in this order:

8. `20261012100000_cancel_business.sql` (one new function: cancel a business that has not been verified)
9. `20261013100000_organizer_events.sql` (the organizer's own draft events: three new functions and helpers; it needs `site_events.organizer_name`)

Then run `supabase/audit/05_check_client_feedback_fixes.sql` (read only; it can also be run before, to check the prerequisites). The first
row must say `OK`.

If one fails, **stop and send me the error text**. A failed run should leave nothing half-applied (each file stops at its first problem
and a multi-statement run is normally all-or-nothing), but do not run later files until it is understood.

## 2. Check it (read only)

Run `supabase/audit/04_postflight_website_migrations.sql` in the same SQL editor. The first row must say `OK`. Anything marked `STOP`
means something is missing or exposed: send me the result before going on. (`INFO` rows about three harmless helper functions are normal.)

## 3. Deploy the invitation email function

From `apps/bottles-up-website-main` (no Docker needed with `--use-api`):

```bash
supabase functions deploy send-team-invitation --project-ref hwmynlghrmtoufyrcihp --use-api
supabase secrets list --project-ref hwmynlghrmtoufyrcihp
```

The list must show `RESEND_API_KEY` and `TICKETS_FROM_EMAIL` (the other emails already use them). `ALLOWED_ORIGIN` should include
`https://www.bottlesupapp.com`. `SITE_URL` is optional (it defaults to `https://www.bottlesupapp.com`). Without this function the Team
screen still works and shows each invitation link to copy.

## 4. Supabase Auth setting (Dashboard > Authentication > URL Configuration)

Add `https://www.bottlesupapp.com/home` to the Redirect URLs (and the non-www address if the site is also served there). Leave the existing
ones. Leave "Confirm email" as it is: the code handles both settings.

## 5. Turn it on (Vercel)

Two Vercel projects deploy this repo (`bottles-up-website` and `bottles-up-website1`). Open each project's Settings > Domains and find
the one that serves `bottlesupapp.com`. In that project: Settings > Environment Variables, add
`VITE_ENABLE_ACCOUNT_ONBOARDING` = `true` for **Production**, then Deployments > the latest production deployment > Redeploy. It is a
build-time setting, so it only takes effect after the rebuild.

## 6. Smoke test (use your own email addresses: this creates real accounts)

1. Home page: the account prompt appears (personal / business / log in).
2. `/signup/business`: sign up as a venue owner, fill the business details, add or claim a venue, submit for verification.
3. As an admin, `/cms/verifications`: approve the business and the venue claim.
4. `/home`: open the workspace, then My Venues: add a table, a bottle and a booking time; check Booking Link and Tables & Bookings.
5. Team: invite a second email as door staff. Open the emailed link in another browser, accept, and open Scan.
6. Existing flows still fine: buy a ticket, book a table, the existing staff pages (`/staff`, `/door`).

Door staff see an event only when it is linked to a venue in the CMS event form. An existing venue has no owner until a business claims
it and an admin approves the claim.

## Rollback

- **Switch the feature off:** set `VITE_ENABLE_ACCOUNT_ONBOARDING` to `false` (or delete it) and redeploy. The site is as before. The
  database additions are harmless with the flag off and can stay.
- **Undo the entry-code fix only:** run `supabase/go-live/rollback_verify_ticket_otp_fix.sql` (restores the 20260821 definition exactly;
  checked by fingerprint).

## Not part of this release

Organizer events, venue agreements, chat and notifications, nightly PDF reports, complimentary bottles, VIP lists, service requests,
sales-source reporting, organizer payouts, bottle orders and amounts collected (these need production-only definitions: run
`supabase db pull` first), table check-in for scoped door staff, and screens for manager (other than Floor), server, security,
verifier and organizer.
