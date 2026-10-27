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

### 1c. Four more migrations for the vendor app's table service (server desk, orders, payments, Tonight)

Needed by the vendor app's **My Tables, Orders, Requests, Review and Tonight** tabs and **Record a payment**. Until they are applied those tabs say
"not set up on this server yet". They are **additive and nothing on the website or in the older apps calls them**, so applying them changes nothing
for anyone who is not using the new app. They create 2 tables, 23 functions and 2 storage policies on the private receipt bucket; they do not alter or
replace any existing table, function or policy. They are on the website branch `feat/server-desk-foundation` (not merged; the SQL files are all you
need), in `apps/bottles-up-website-main/supabase/migrations/`.

1. Section 1 and 1b are done and `05_check_client_feedback_fixes.sql` says OK.
2. Run `supabase/audit/08_preflight_table_service.sql` (read only). The first row must say `OK`. A `STOP` names what is missing or already taken: send me the grid.
3. Apply, in this order, the same way as above (copy, paste, Run, wait for success):
   - `20261014100000_table_servers.sql`
   - `20261014110000_service_requests.sql`
   - `20261014120000_desk_orders.sql`
   - `20261014130000_desk_payments.sql`

   The last two stop with a message, changing nothing, if a production-only money column is missing.
4. Run `supabase/audit/09_postflight_table_service.sql` (read only). The first row must say `OK`: 23 functions, none callable by anonymous visitors, the 5
   internal helpers not callable by signed-in people, the two new tables closed to direct access.
5. To undo all of it: `supabase/go-live/rollback_table_service.sql` (one transaction; it removes only these objects; payments already recorded
   stay, because they live in production's own table).

**Once the app is pointed at production, everything done in it is real**: moving an order, recording a payment (it adds a row to the club payments table,
which production never lets anyone delete), inviting staff (a real email). For a client walk-through use a test business and your own email addresses,
and do not record payments against a real guest's booking.

### 1d. Optional: a demo night for the walk-through

Without bookings and bottle orders the new tabs are empty. `supabase/go-live/demo_night.sql` adds three clearly-marked demo tables to a club of your
choice (customer e-mails end in `@demo.bottlesup.invalid`, codes start with `DEMO-`): one that owes money with three bottles, one paid up and arrived,
one with no server. Edit the three values at the top (club name, a server's e-mail, the night), run it in the SQL editor, and the server's phone shows it.
`supabase/go-live/demo_night_cleanup.sql` removes exactly those tables again, with anything recorded against them. Both were tested on a scratch
database (the server sees their two tables, the manager all three, a payment recorded in the app is removed by the cleanup, a real booking beside them
is untouched). They are real rows in production tables while they exist: they show in the CMS bookings list and may count in its totals.

### 1e. Two September files that are NOT applied (they are already live)

`20260923100000_guest_tickets_and_checkin_fix.sql` and `20260925100000_after_midnight_availability.sql` (website PR #7) record changes that were made by hand in
production on 23 and 25 Sep, which is why production's `checkin_ticket()` differs from the repository (see the findings above). Running them there prints "already applied"
and changes nothing, but there is no reason to run them: skip them, and run the read-only `supabase/audit/15_check_september_changes.sql` once if you want proof that production
matches them (no rows = it does). On any other database they build the same objects.

### 1f. Optional, when you decide: send the queued guest e-mails (website PR #8)

Until this is done every guest message in the vendor app (table seated, wait estimate, VIP invitation) says "Queued, not sent yet", and expired chats are never deleted.
Nothing here is automatic; each step is yours:

1. Have the client read the e-mail wording in `apps/bottles-up-website-main/supabase/functions/_shared/outbox.ts` (a first draft). Messages older than 12 hours are never sent.
2. Apply `20261019100000_outbox_claim.sql` (adds one column and two functions; undo: `supabase/go-live/rollback_outbox_claim.sql`), the same way as the other migrations (`supabase/go-live/apply_one.sh`).
3. Deploy the function: `supabase functions deploy process-outbox --use-api`. It uses the `RESEND_API_KEY` the other e-mail functions already use (and `OUTBOX_FROM_EMAIL` if you want a different sender than `tickets@bottlesupapp.com`). With no key it sends nothing and loses nothing.
4. Add a schedule that calls it every 5 minutes with the **service role key** as the bearer token (Supabase dashboard > Integrations > Cron, job type "Supabase Edge Function", or `pg_cron` + `pg_net` with the key kept in Vault). The function refuses any other caller. The key never goes in this repository.
5. Check: queue a test message by seating a demo booking (or `vip_invite` for a VIP with your own e-mail), wait for the schedule, and see the message turn "Sent" in the app and arrive in your inbox.

> **Shortcut (19 Oct):** `supabase/go-live/apply_pending_migrations.sql` is sections 1f step 2 and 1g steps 2 to 7 in ONE paste (the nine files, byte-identical, each in its own transaction, in order). Pre-flight 16 and post-flight 17 still apply.

### 1g. Eight more migrations for the 15 Oct brief (website PR #10, branch `feat/business-brief-2`; apply AFTER the outbox migration in 1f)

Everything here is additive except one replaced function (`invite_member`, see 4) and one added column on a busy table (`site_table_booking_bottles.delivered_quantity`, see 6). The door scan functions that are live today are NOT touched (see 7). None of them changes an existing row. Run them one at a time with `apply_one.sh`, in this order, and stop at the first failure (each file runs in its own transaction, so a failure leaves nothing half-done):

1. Read-only first: run `supabase/audit/16_preflight_business_brief_2.sql`. It must return **no rows**. A row says what is in the way (a name already taken, a missing earlier migration or production-only column, or an `invite_member` that is not the expected version).
2. `20261020100000_venue_payment_rules`: two functions, `venue_payment_rules` and `save_venue_payment_rules` (the owner's bottle payment setting; it changes only `site_venues.bottle_payment_mode`, which only affects NEW bookings). Stops with nothing changed if `site_venues.bottle_payment_mode` or `deposit_is_credit` is missing.
3. `20261020110000_booking_guests_and_activity`: two read-only functions for the table page's Guests and Activity tabs. `20261020120000_org_event_states`: one read-only function that says where each of an organizer's events stands and what blocks publishing.
4. `20261020130000_organizer_door_staff`: adds the column `site_agreements.organizer_door_staff` (false for every club until the club turns it on), six functions, and REPLACES `invite_member` with the same function plus one check (an organizer's event invitation for a club's event is refused unless the club allowed it). The replacement is guarded: it is replaced only if the live function is exactly the version in this repository; if it already has the rule nothing happens; if it is anything else the migration **stops and changes nothing** and prints the live fingerprint. If that happens, do not edit the file: send the output to Claude.
5. `20261020140000_desk_walkin`: two functions, `desk_walkin_options` and `desk_create_walkin` (a club manager or owner books a table for a guest who is at the club; the deposit is left DUE at the club and is recorded afterwards with "Record a payment"; a confirmation e-mail is only QUEUED). Needs the seating/outbox and close-night migrations that are already live.
6. `20261020150000_add_bottles_checks`: two read-only functions, `desk_may_add_bottles` (may this person add bottles to this table now?) and `desk_bottle_menu`. Then `20261020160000_partial_delivery`: adds `site_table_booking_bottles.delivered_quantity` (0 for every existing line, never negative; a plain `ADD COLUMN` with a constant default, so it is quick) and two functions, `desk_deliver_part` and `desk_booking_deliveries`. Neither changes an existing function or row. Both stop with nothing changed if a column they need is missing.
   **Then redeploy the edge function** `add-table-booking-bottles` (`supabase functions deploy add-table-booking-bottles --project-ref hwmynlghrmtoufyrcihp --use-api`, from `apps/bottles-up-website-main` once the branch is merged): it now also lets in a manager, an owner or the table's server by asking `desk_may_add_bottles` with the caller's own login. A person the database does not know is treated as a customer exactly as before, and the function behaves as before until step 6's first migration is applied, so the order does not matter for safety. Prices, stock, totals and the guest's e-mail are still done by that function, nothing new.
7. `20261020170000_group_admission`: one new closed table (`site_order_admissions`, one row per admission at the door) and three new functions: `door_admit_group` (the scan, with group admission and remaining allowance; also tells a refunded order from an unpaid one), `door_admission_counts` and `door_guest_admissions` (exact "guests in"). It does **not** replace `door_scan_ticket`, `door_verify_ticket_code` or the older check-in functions: those stay as they are. The first admission of a group also marks the order checked in, so every older scanner refuses the rest of that order (it can never be admitted twice); the older screens then count the whole order as in, and the vendor app uses the exact figures instead. The app falls back to the older scan by itself where this migration is not applied.
8. Check afterwards: `supabase/audit/17_postflight_business_brief_2.sql`, every row `ok = true` (20 functions, none callable by visitors, 19 callable by signed-in people, both columns, the admissions table closed, `invite_member` with the rule).
9. Undo, if ever needed: `supabase/go-live/rollback_business_brief_2.sql` (one transaction; drops the 20 functions, the two columns and the admissions table, puts the previous `invite_member` back only if it is the one these files wrote). It deletes the clubs' door-staff switches, the delivered counts (a line that is Delivered stays Delivered) and the record of how many of a group came in (an order stays checked in); walk-in bookings and bottles added at a table stay as ordinary records. Tested on a scratch copy: after the rollback the pre-flight returns no rows, and the eight files apply again cleanly. (The edge function change needs no undo: without the function it behaves as before.)

The vendor app (PR #21, `feat/business-brief-2`) copes with these functions not being there yet: each new screen or tab shows a plain sentence ("not set up on this server yet", or "could not be loaded" with Try again) and the rest of the app keeps working, so the app build may go out before or after the migrations.

### 1h. Seven more migrations (brief 3: floor plan, order stage Accepted, refunds, staff discounts, payouts, door sales, venue time zone) and the functions that go with them

**STATUS 24 Oct 2026: ALL SEVEN ARE LIVE IN PRODUCTION.** The first five were pasted by the owner before 24 Oct (pre-flight on 24 Oct listed all their names as already existing, and a fingerprint comparison showed all 75 of their functions identical to the repository's); the last two (`20261026100000_door_sales`, `20261027100000_venue_time_zone`) were applied on 24 Oct with `apply_one.sh`, one at a time, post-flight 19 = 19 of 19. **Do not paste `apply_business_brief_3.sql` again.** Also done on 24 Oct, on the owner's OK: the guarded correction `20261028100000_refund_receipt_evidence` (own transaction, own guard; `apply_one.sh`; post-flight still 19 of 19) and the deployment of the eleven changed edge functions plus the three wording-only ones (step 5). The text below is the original plan, kept for the record and for the undo.

These are the website branch `feat/business-brief-3` (stacked on `feat/business-brief-2`; merge that first, then this one). **Nothing in production changes until you paste the file below.**
Two of the seven migrations REPLACE live functions (the floor plan one 3, the Accepted one 4) and each replacement is guarded: it happens only if the live function is exactly the
version the repository has; anything else stops that migration before it changes anything.

1. Make sure the file is current (it is generated from the migrations): `python3 -I supabase/go-live/build_business_brief_3.py --check` (it must say "both files are current").
2. Run `supabase/audit/18_preflight_business_brief_3.sql` in the production SQL editor. **It must return no rows.** Any row is a reason to stop and send it to me (a name is taken, something
   it builds on is missing, or one of the seven live functions is not the version the change was written against).
3. Paste **`supabase/go-live/apply_business_brief_3.sql`** (about 3,330 lines; the seven migrations in order, each in its own begin/commit) into the SQL editor and Run. An error in one file rolls
   back that file and stops the rest; send me the error text, do not edit anything. (On a scratch copy of production's shape it applied cleanly in one run. The file is about 205 KB; if the editor refuses so large a paste, paste the seven migration files one after another instead, in the same order, each from `apps/bottles-up-website-main/supabase/migrations/`; they are the same bytes, and each one is all-or-nothing.)
4. Run `supabase/audit/19_postflight_business_brief_3.sql`: **all 19 rows must say ok = true.**
5. Then deploy the website functions that changed (from `apps/bottles-up-website-main`, logged in to the right Supabase account; the database must come first, because the new code calls the new
   functions; `bookingTotals` copes with the discount column being absent, `create-table-booking-checkout` and `create-walkin-table-booking` do not cope with the shared count being absent):

   ```bash
   for f in create-table-booking-checkout create-walkin-table-booking cancel-table-booking refund-table-booking-payment \
            add-table-booking-bottles cancel-bottle-line confirm-bottle-addon order-bottles-by-code respond-bottle-substitution site-booking-status site-stripe-webhook; do
     supabase functions deploy "$f" --project-ref hwmynlghrmtoufyrcihp --use-api
   done
   ```

   (`site-stripe-webhook` keeps its `verify_jwt = false` from `supabase/config.toml`, which the deploy reads; add no flags.) The wording-only functions `manage-door-staff`, `process-outbox` and `send-team-invitation` also changed (the name "BottlesUp Business" in the e-mails); deploy them too if they are not yet current.
6. The website (CMS pages Refunds, Discounts, Payouts; the refund policy before payment; asking for a refund from a booking page) deploys with the merge to `main`, like the rest of the site.
7. Then the BottlesUp team sets, in the CMS, the things only BottlesUp controls: **Payouts > Settings** (the weekday, how many days money waits, BottlesUp's percentage: nothing is invented, it stays "not set" until you choose),
   and each business's payout account status. Venue owners set their own refund policy and discount limits in the BottlesUp Business app.
8. **Undo:** `supabase/go-live/rollback_business_brief_3.sql` (one transaction; also generated). It puts the seven replaced functions and the five-value status constraint back exactly (checked on the scratch copy: after
   it, the pre-flight 18 returns no rows, so each restored function is byte-for-byte the previous version) and drops what the seven files created. It **refuses, and changes nothing,** while any bottle line is "accepted",
   a refund is approved or paid back, a payout is being sent or paid, or any ticket was sold at the door (those are records of money). It deletes: table holds and the record of moves, deposit terms, the terms each booking was sold under,
   refund policies and requests, discount limits and the record of discounts and free bottles, payout settings/accounts/items, and (door sales) the columns that say how an order was sold (the orders themselves stay), and the time zones venues chose (they read as Toronto again). Tables already discounted keep their lowered total; free bottles stay as ordinary lines.
   After a rollback redeploy the previous edge functions (`git checkout <previous commit> -- supabase/functions`, then the loop above): the new ones call functions the rollback removes.

The vendor app (branch `feat/business-brief-3`) copes with all of these functions being absent: each new screen says "not set up on this server yet" or "could not be loaded" with Try again, and the rest of the app keeps working.

### 1i. Going live: the social side (six migrations: feature switches, profiles, posts and stories, explore and reviews, inbox and notifications, safety and moderation)

**STATUS 27 Oct 2026: BUILT AND TESTED, NOT APPLIED ANYWHERE.** Website branch `feat/social-backend`, customer app branch `feat/social-app`. Everything is **additive** and **every feature starts switched OFF** (16 switches in the CMS under *Social settings*): applying the files changes nothing a customer can see. The apps ask the server which switches are on, so the database may go first and the app builds may go out before or after. It replaces no existing function; it adds 25 tables, the functions the apps call, one private storage bucket (`social-media`, three policies), seven nullable columns and two constraints on `site_venues`, and a few triggers and indexes (the exact lists are in the pre-flight and post-flight files, generated from the migrations).

1. The bundle is generated from the migrations: `python3 -I supabase/go-live/build_social.py --check` must say the files are current.
2. Run `supabase/audit/22_preflight_social.sql` in the production SQL editor. **It must return no rows.** A row says what is in the way (a name already taken, a bucket that exists, or an earlier table the files build on that is missing).
3. Paste **`supabase/go-live/apply_social.sql`** (about 4,000 lines, 200 KB: the six migrations in order, each in its own begin/commit) and Run. An error in one file rolls back that file and stops the rest: send me the error text, edit nothing. If the editor refuses so large a paste, paste the six files from `apps/bottles-up-website-main/supabase/migrations/` (`20261101100000` to `20261105100000`) one after another, in order.
4. Run `supabase/audit/23_postflight_social.sql`: **every row must say ok = true** (tables closed to direct access, nobody can call the helper functions, visitors cannot call the signed-in ones, the bucket is private, all 16 switches exist and are OFF).
5. Add the nightly clean-up: `supabase/go-live/schedule_social_cleanup.sql` (a `pg_cron` job at 03:15 UTC that runs `public.social_housekeeping()`: stories that ended more than 7 days ago, notifications read more than 90 days ago and caption-idea counts older than two days; it never touches posts, comments, messages or reports). Then `supabase/audit/24_postflight_social_cleanup.sql` (its last row stays "not run yet" until the first 03:15). Undo: `rollback_social_cleanup.sql`.
6. Deploy the edge functions (from `apps/bottles-up-website-main`, after the database): `suggest-caption` (new), `sweep-social-media` (new), `delete-account` (changed: it now also removes a deleted person's folders in the bucket).

   ```bash
   for f in suggest-caption sweep-social-media delete-account; do
     supabase functions deploy "$f" --project-ref hwmynlghrmtoufyrcihp --use-api
   done
   supabase secrets set ANTHROPIC_API_KEY=<the owner's key> --project-ref hwmynlghrmtoufyrcihp
   ```

   Caption ideas need the key (your Anthropic account: it is billed per request; the daily limit is 20 per person). Without it the function says "not set up yet" and nothing else is affected. The key never goes in this repository.
7. Schedule `sweep-social-media` once a day, the same way as the e-mail outbox in 1f step 4: Supabase dashboard > Integrations > Cron, job type "Supabase Edge Function", or `pg_cron` + `pg_net` with the **service role key** as the bearer token (the function refuses any other caller). It removes the pictures and videos no post uses any more (a story's files after the story is deleted, an upload whose post was never made); until it is scheduled the files only cost space.
8. In the CMS (*Social settings*): write and publish the community rules (the app shows them before a person's first post, comment or message; have them read by whoever answers for the legal side), and add the banned words if you want any. In *Moderation*, someone must look at the reports **every day** once the first feature is on: a report is never acted on by itself. Then turn the switches on one at a time, in this order, using a test account first: `social`, `stories`, `reels`, `inbox`, `reviews`, `ai_captions`, `members_only`. The other nine (`split_payments`, `marketplace`, `venue_hire`, `referrals`, `subscriptions`, `advertising`, `creator_earnings`, `ranks`, `jobs`) belong to later chapters of the plan and do nothing yet.
9. **Undo:** `supabase/go-live/rollback_social.sql` (one transaction). **It refuses, and changes nothing,** while any post, comment, message, review, report or follow exists, or the bucket holds a file: those are people's words and pictures. To stop the social side after launch, switch the features off in the CMS instead: that hides everything and deletes nothing. It is for a launch that never opened.

The customer app (branch `feat/social-app`) shows nothing social while the switches are off, and where the functions are missing it says so in a sentence and carries on with tickets and bookings.

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
