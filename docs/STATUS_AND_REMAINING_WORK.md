# BottlesUp: recent work and what is left (website, vendor app, user app)

Written 23 Oct 2026 by Claude. Read from the git history, the pull requests, the repository docs (`HANDOFF.md`, `docs/FINAL_STEPS.md`, `docs/BRIEF_15OCT_GAP_ANALYSIS.md`) and read-only checks on production made on 22 to 23 Oct.
**Not verified:** nothing built here has been run on a real phone, and most of it was never run against a real database before it was applied; the tests use fake backends and a scratch Postgres.
`docs/FINAL_STEPS.md` stays the step-by-step list of what only you can do; this file is the overview.

Legend: **Done** = merged and (for database changes) applied to production. **Built** = written and tested, not merged or not applied. **You** = needs you (an account, a click, a decision). **Client** = needs an answer from the client.

## 1. The short version

| Part | Where it stands | What comes next |
|---|---|---|
| **Website + database** (the source of truth for all three apps) | Everything up to the 15 Oct brief's second batch is merged and in production. The third batch (floor map, refunds, discounts, payouts, door sales, time zones) is **built**, not merged; production already has several of its tables. Account deletion is fixed in production for all staff; the last 5 columns are in PR 14. | Merge PR 14 and apply it. Open and merge the third-batch pull request. Settle exactly what production has (post-flight audit). |
| **Vendor app (BottlesUp Business)** | `main` is 1.3.1+9. The third batch is **built** on `feat/business-brief-3` (same version number). The 1.3.0 (build 8) store builds exist and have not been uploaded. Never tried on a phone. | Merge the third batch, build 1.3.1, upload, real-phone test. Then the parts that wait on the client. |
| **User app (customer app)** | Not started. Untouched since the archive cut. Not production-ready. | Starts after the website and vendor app items above. Plan in section 4. |

## 2. Website and database

### Done recently
- **7 Oct** accounts, onboarding, workspaces, team invitations, the scoped door scanner, venue setup and owner tools (behind a flag), PR 1.
- **9 to 10 Oct** a person can leave onboarding and cancel a business added by mistake; organizers can create event drafts.
- **14 to 18 Oct** server desk and table service migrations; guard on the classic vendors table (only an administrator can make an administrator); the 11 Phase 2 module migrations (cash handover, seating, chat, security, close night and reports, inventory, VIP guests, agreements, guests, owner money), applied to production on 18 Oct.
- **19 Oct** the second batch of the 15 Oct brief landed (PR 11): venue payment rules, booking guests and activity, organizer event states, organizer-provided door staff, walk-in bookings, add-bottles checks, partial delivery, group admission; the guest e-mail sender (built, **not switched on**); staff invitation e-mails say "BottlesUp Business"; the September production-only changes recorded as guarded migrations. You applied the migrations; Claude deployed three functions and checked that all 29 functions in production match the repository byte for byte.
- **22 to 23 Oct, account deletion** (needed for the App Store): every deletion path ends in `DELETE FROM auth.users` (the website's `delete-account` function; the customer app's `delete_user()`; the vendor app's `delete_account()` through a trigger on `vendors`), and that failed for anyone who had ever scanned, invited, paid, chatted or created a business, and for every invited staff member. PR 13 (merged) made 66 columns nullable with `ON DELETE SET NULL` and relaxed 10 rules that tied a person to a state; **applied to production on 23 Oct** (blockers 71 to 5). Tested with a database test, a guard script and mutation checks. Read-only audits 18 and 19 are in `supabase/audit/`.
- **Trigger checks on production (read-only):** deleting a guest-list verifier or a referring vendor sends no e-mail and leaves counts correct.

### Built, waiting on you
1. **PR 14, the last 5 account-deletion columns** (`admin_audit_log.admin_id`, `conversations.created_by`, `event_rsvps.verified_by`, `vendor_onboarding_data.referrer_id`, `venues.manager_id`): merge, then your yes to apply (`apply_one.sh 20261030100000_account_deletion_legacy_columns`), then re-run audit 18: it must show nothing.
2. **The third batch** (website branch `feat/business-brief-3`, 7 migrations and 11 functions): floor plan placement and table states, moving a booking, deposit terms, refund policy and requests, staff discounts and free bottles with the owner's limits, payout settings and ledger (set in the CMS), the "Accepted" order stage, door sales with the shift summary, per-venue time zones, and CMS pages for refunds, discounts and payouts. Its pull request was never opened (an earlier session was refused). Merge order: website first, then vendor.
   **Check first:** my audit of 23 Oct showed the batch's refund, payout, discount and table-block tables already exist in production, so part of it was applied. Which migrations, and whether the 11 functions were deployed, is not confirmed. The post-flight audit `supabase/audit/19_postflight_business_brief_3.sql` (on the monorepo branch `chore/audit-and-staging`, with the pre-flight `18_preflight_business_brief_3.sql` and the pull request texts in `docs/pr_descriptions_batch3.md`) settles it. **Numbering clash:** my two read-only audits are `18_account_deletion_blockers.sql` and `19_preflight_legacy_account_columns.sql`; use the full file names when you say "audit 18/19".
3. **In the CMS (Payouts > Settings):** payout weekday, how many days money waits, BottlesUp's percentage, and each business's payout account status. Nothing is invented: until you choose, venues are told it is not set.

### Left (code and housekeeping)
- Run `supabase db pull` so production-only SQL (17 functions, `profiles`, `promo_codes`, the legacy tables) is committed; reconcile production's migration history table **before** anyone runs `supabase db push` (it stops at 25 Sep).
- Switch on guest e-mails (`process-outbox` on a 5-minute schedule) once the client has read the wording.
- Remove the demo night from production after the walk-through (`supabase/go-live/demo_night_cleanup.sql`); the test login account.
- 43 accounts have no `profiles` row: decide whether that matters.
- CI: the database job once stopped without a message in the second pass (`concurrency_outbox.sh`) and passed on the next run; cause not found. The script now says what went wrong if it happens again.
- Type check baseline is 127 old errors; the generated types file is out of date.
- **Security (not caused by this work):** `trigger_rsvp_approval_email()` in production has a bearer token and an `apikey` written into its body. Check in the Supabase dashboard (Settings > API) which role they carry; if either is the service key, rotate it and move the call to a stored secret.

## 3. Vendor app (BottlesUp Business)

### Done recently (all merged to `main`, 1.3.1+9)
- **Rename and flows (15 Oct brief, batch 1):** BottlesUp Business everywhere a person reads it; a failed workspace request shows "We could not load your workspace" with Retry; navigation per role; plain errors with Retry; last workspace remembered.
- **Batch 2:** venue status on Overview, payment settings (bottle payment mode), booking tabs (Guests, Activity), organizer event states, organizer-provided door staff, walk-in bookings, add bottles, partial delivery, group admission at the door, connection-lost banner, Message team, Copy event link, Invite door staff.
- **Earlier:** workspaces and accept-invitation, door Scan and Guests, manager Floor, owner Home/Venues/Setup editors (venue profile, rooms and floors, tables, bottle menu, booking times, photos), Team, organizer events, server desk and table service, and the Phase 2 modules (chat, security, close night and PDF reports, inventory, VIP, cash handover, seating, agreements, guests, money, door VIP lookup).
- **Builds made 19 Oct, version 1.3.0 (8), not uploaded:** Android bundle and APK, iOS IPA (App Store signing under team `4T453RG45S`). 1.3.1 (9) is **not built** (builds only on your say-so).
- **Account deletion, CORRECTION (23 Oct):** I earlier said the app's button calls the function that is now fixed. It does not: the vendor app calls the database function `delete_account()` (`supabase_auth_service.dart`), which in the repo's own migration (`apps/bottles-up-vendor/supabase/migrations/006_delete_account_function.sql`) only deletes the caller's row in the classic `vendors` table; a trigger on that table then deletes the sign-in. So (a) for an account that HAS a `vendors` row, the final delete is the one the database fix unblocks; (b) for an account that has NO `vendors` row (the web-first accounts made since 16 Oct, which is most invited staff) it would delete nothing and still sign the person out, so the account would stay. Production's real `delete_account()` body and trigger have not been read (that needs a read-only query with your yes). The simplest fix is to make the app call the website's `delete-account` function, which deletes any account.

### Built, not merged (`feat/business-brief-3`, same version number)
Floor map, placement editor, holds and moving a booking, included admissions and the Terms card; refunds and cancellations (the venue's refund policy, requests to decide, refund paid back at the club with a receipt photo); discounts and free bottles with approvals; read-only settlements and payouts; the "Accepted" order stage; Door Sales and the door's shift summary; venue time zone; an Android app link for invitation links; Contact Support and About now say only what is true; the Privacy screen lists what the app collects.
These screens say "not set up on this server yet" until the matching database parts are in production.

### Left
- **You:** merge the batch-3 pull requests, build 1.3.1, upload to TestFlight and Play, test on real phones (door camera, photo picker and upload, invitation e-mail through to accepting, poor connectivity, a staff account deletion).
- **You / client:** the legal Terms of Service text; real support contact details in the CMS; a Sentry account if crash reporting is wanted (it is off); the Apple bundle ID `com..bottlesUp.ORG` has a double dot and Apple may object; for Android invitation links the website must serve `assetlinks.json`; iOS invitation links need the Associated Domains capability and a final bundle ID.
- **Not built, waits on the client:** ambassadors and the Event Lead role; the claim link for a free bottle given to someone not at a table; ticket discounts for organizers and settlements of ticket earnings; push and SMS; guest e-mails about refund decisions (wording needs approval); table allocation by the owner; organizer overview figures (sales, deposit allocation, earnings), ticket tiers, venue selection on an event and publishing by the organizer; multi-venue owner report.
- **Fix the vendor app's Delete account** (see the correction above): read production's `delete_account()` and its trigger, then point the app at the website's `delete-account` function (or fix the database function), with a test. Needed for the App Store.
- **Smaller, mine to do when asked:** a "pending invitation" screen, "assign" on customer requests, analyzer clean-up (about 150 old issues), the classic vendor dashboard (15 accounts) and the old scanner on legacy tables.

## 4. User app (customer app): starts after sections 2 and 3

State today (read from the repo, nothing changed): version 2.0.1+3. The GitHub default branch is `master`; the real work is on `main`, which is 5 commits ahead of `master`; the archive branch `chore/archive-unused-features` is 2 commits off `main`. The bundle identity disagrees: iOS `com.bottlesUpUser`, Android `com.bottlesupuser`, and the newest `main` commit says `com.btlup.pop`. One template test, no real tests. No iOS privacy manifest.
It reads **old tables** (`events`, `events_bookings`, `event_rsvps`, `table_bookings`, `event_table_bookings`, `wallet_passes`, `payment_transactions`, `venue_inquiries`, `profiles`...) and **none** of the website's `site_*` tables, so a booking made in this app does not appear on the website's owner screens. Payments use its own edge functions.
**Account deletion here is a third path:** the app deletes the profile row, then calls the database function `delete_user()`. In the repo (`apps/bottles-up-user/supabase/migrations/create_delete_user_function.sql`) it runs `DELETE FROM auth.users` for the caller, so it benefits from the foreign-key fix directly; the production copy has not been read, and its extra tables (`event_rsvps`, `venues.manager_id`...) are in PR 14.

Proposed order (nothing started; I begin only when you say):
1. **Decide:** the real App Store and Play identity (bundle ID), and that customers should book through the website's `site_*` records (the decision already taken for the other two).
2. **Housekeeping:** rebase the archive branch onto `main`, fix the template test, read and fix `delete_user` and test account deletion on a scratch database, add the iOS privacy manifest, privacy policy and store data answers.
3. **The big job:** move bookings and payments onto the website's `site_*` tables and functions, with tests, so one record is shared by the website, vendor app and customer app.
4. **After that:** guest-facing refund flow (the website already has "ask for a refund" on a booking page), push notifications, deep links, ambassador hub (client rules first), and a build and phone test.

## 5. Needs the client (they block parts of the above)
Payout timing and account structure; card reader and POS provider for door sales beyond the club's own machine; fee formulas; discount stacking and approvals beyond what was answered on 20 Oct; free-bottle claim rules; refund and commission windows; how long a hold or an invitation lasts; ambassador program, Event Lead role and chat retention; the legal Terms and Privacy text; whether existing partner accounts migrate. `docs/BRIEF_15OCT_GAP_ANALYSIS.md` lists each, section by section (its tables are from 19 Oct and out of date for batch 3).

## 6. Suggested order
1. Merge PR 14, then apply it (your yes), then `18_account_deletion_blockers.sql` shows nothing.
   Read production's `delete_account()` (your yes) and fix the vendor app's Delete account; then try deleting a test staff account in the vendor app.
2. Run the batch-3 post-flight audit to learn what production really has; open and merge the two batch-3 pull requests (website first); deploy any missing functions.
3. Build 1.3.1, upload both vendor builds, and do the real-phone pass; fix what it finds.
4. Check the hard-coded tokens in the e-mail trigger.
5. Start the user app (section 4) once the first four are moving.
