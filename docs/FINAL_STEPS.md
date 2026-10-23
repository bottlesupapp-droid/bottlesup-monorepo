# FINAL STEPS: what is left for you (everything else is built, tested and pushed)

Written 19 Oct 2026, extended 21 Oct 2026 with section 2b (the third batch of the brief: floor plan and tables, refunds, discounts, payouts). This is the one list to work through, top to bottom, when you are ready. Everything that could be done without you is done: code, database
migrations with their tests, rollbacks, read-only audit scripts, documentation. **Nothing below has been done to production, and nothing in production was touched
while preparing it.** Each step says what it does, how to check it, and how to undo it.

Rule for Claude sessions reading this: do none of these without the user's explicit yes for that step.

## Where things stand (19 Oct, night): steps 1, 2 and 3 are DONE and validated

* **Merged (by you, 13:34 to 13:42 UTC) and checked by Claude:** vendor `main` contains the whole stack (its only file difference from the stack head is the CI workflow it keeps), version 1.3.0+8; website `main` contains #2, the whole stack (#11), the e-mail wording (#9) and the September record (#12), and all nine migration files. Left over and harmless: website #7 (old stacked piece, contained in #11), website #3 (closed), website #4 to #6, #8, #10 show as merged.
* **Migrations applied to production (by you) and validated read-only by Claude through the Supabase connector:** post-flight 17 all 12 rows true; **all 29 functions (the 20 new ones, `outbox_claim`/`outbox_finish`, `invite_member`, and neighbours) are byte-for-byte identical to the committed files** (fingerprint of the normalized body, security flags, search_path and return type compared with a replay on the scratch database), grants exactly as designed (visitors none; signed-in people yes, except `event_door_allowed`, `outbox_claim`, `outbox_finish`); the live `door_scan_ticket`, `door_verify_ticket_code` and `desk_set_service_status` are unchanged and equal the repository; `site_order_admissions` has row level security, no policies, no access for signed-in people or visitors, 0 rows; `delivered_quantity` is `integer not null default 0` with a non-negative check and no line has a non-zero count; `organizer_door_staff` is `boolean not null default false` and no club has it on; `site_outbox.claimed_at` exists and the outbox is empty; the `scan_attempts` result constraint is untouched; the Phase 2 post-flight (audit 13: 83 functions, 22 tables, RLS, grants, search_path) still passes; the Supabase security advisor mentions the new objects only as "RLS enabled, no policy" on the closed admissions table and "signed-in users can execute a security definer function" on the new functions, both by design (each checks the caller inside, and the tests prove it). Pre-existing advisor items (exposed `auth.users` view, a security-definer view, leaked-password protection off, a Postgres version notice, functions in `public`) are not from this work.
* **Functions deployed (step 3) by Claude through the CLI once you had logged in to the right account:** `add-table-booking-bottles` v9 (JWT check kept off as it was; first confirmed that the live version was just an older revision of the repository code with no hand edits), `send-team-invitation` v4, `process-outbox` v1 (new, **not scheduled**). Smoke-tested without credentials: the first two answer 401 "Unauthorized" from their own code (so the new code boots), `process-outbox` answers 401 and sends nothing.
* **Still blocked for Claude (permission layer):** merging into `main` and every write to production, so the remaining steps below are yours, or add permission rules for `gh pr merge` and the Supabase connector's `execute_sql` / `deploy_edge_function`.
* **Not wanted:** extending XNO's booking window (you said no need).

## 2b. The third batch: database DONE in production (24 Oct); one correction, the functions and the pull requests still to do

Everything the client answered on 20 Oct and the owner decided afterwards (payouts, BottlesUp's percentage and weekday set in the CMS; refund deadlines and amounts set by each venue and watched in the CMS; discount limits set by the owner; floor map, included admissions and deposit terms "similar to the website"; selling tickets at the door with cash or the club's own card machine, the door person's shift summary, and each venue's own time zone) is built on both sides and tested. **The seven migrations are live in production** (see step 4). **Nothing is merged or deployed yet, and no new app was built.** What is left, in order:

1. **Open and merge two pull requests.** Both branches are pushed (`feat/business-brief-3` in the website and the vendor repo). Claude could not open the pull requests (the permission layer refused `gh pr create`), so open them from the links in `docs/pr_descriptions_batch3.md`, which also has the text to paste. Merge the website one first, then the vendor one. Neither needs anything else first (`main` already has the earlier batches). Do not delete the branches on merge.
2. ~~Check the generated files~~ (not needed any more).
3. ~~Pre-flight~~ DONE on 24 Oct: it listed the first five migrations as already existing, i.e. you had already pasted the bundle earlier. Every one of their 75 functions in production is byte-for-byte what the repository had on 21 Oct (checked by fingerprint).
4. ~~Apply~~ **DONE on 24 Oct.** The first five (floor plan, order stage Accepted, refunds, discounts, payouts) were already in; on your instruction I applied the other two, `20261026100000_door_sales` and `20261027100000_venue_time_zone`, one at a time through your Supabase CLI login (`supabase/go-live/apply_one.sh`, each in its own transaction). **The bundle `apply_business_brief_3.sql` must NOT be pasted again** (it would stop at its first file; it is kept as the record).
5. ~~Post-flight~~ **DONE on 24 Oct: `19_postflight_business_brief_3.sql` returned 19 of 19 ok.** Nothing was rewritten: all 138 existing orders are still online orders, no venue has chosen a time zone, nobody can call the new door functions without signing in.
5b. **ONE correction is waiting for your OK:** `20261028100000_refund_receipt_evidence` (apply with `WORKDIR=<linked scratch dir> supabase/go-live/apply_one.sh 20261028100000_refund_receipt_evidence`). Production has the first version of two refund functions; this makes a receipt photo for a refund paid back at the club have to belong to that booking, and makes the refund list return the reference and the photo (the app already reads them and works without them). It is guarded: it only replaces each function if it is exactly the version in production now, otherwise it stops and changes nothing. Tested, including that guard; not applied.
6. **Deploy the functions** (commands in `supabase/go-live/README.md` section 1h): `create-table-booking-checkout`, `create-walkin-table-booking`, `cancel-table-booking`, `refund-table-booking-payment` (changed code), and `add-table-booking-bottles`, `cancel-bottle-line`, `confirm-bottle-addon`, `order-bottles-by-code`, `respond-bottle-substitution`, `site-booking-status`, `site-stripe-webhook` (they share the total calculation, which now subtracts a staff discount). Database first (done), functions second. **They are not deployed yet**: production still runs the versions from 19 to 25 Sep (checked 24 Oct), which do not know the shared table count or the staff discount; nothing uses those yet because the new app is not out, so there is no hurry, but deploy them before the new app and the merged website go out.
7. **In the CMS (Payouts > Settings):** choose the payout weekday, how many days money waits, and **BottlesUp's percentage**. Nothing is invented: until you choose, venues are told it is not set. Then set each business's payout account status once you have checked its bank details yourself (the app collects none).
8. **Undo, if ever needed:** `supabase/go-live/rollback_business_brief_3.sql`. It refuses while any bottle line is "accepted", a refund is approved or paid back, a payout is being sent or paid, or any ticket was sold at the door (records of money). After it, redeploy the earlier function versions (README 1h step 8).

The vendor app also behaves safely with a database that is missing any of this (each new screen says "not set up on this server yet").

## 3. Functions and website: DONE (nothing left except the optional guest e-mails)

Deployed on 19 Oct (see "Where things stand"); the website redeployed on Vercel when #11 and #9 merged.

* **Switching on the guest e-mails** (optional, your call, deliberately NOT done): the client reads the wording in `supabase/functions/_shared/outbox.ts`, then add a 5-minute schedule that calls `process-outbox` with the service role key as the bearer (`supabase/go-live/README.md` 1f step 4). Until then every guest message stays "Queued, not sent yet" in the app, which is honest, and `process-outbox` does nothing when called by anyone else.

## 4. Upload the vendor app (the builds are made)

Built on 19 Oct from the stack head (`bc810e1`, byte-for-byte the code that lands on `main` with #23), version **1.3.0 (build 8)**, pointing at production:

| | File (under `apps/bottles-up-vendor/`) | Checked |
|---|---|---|
| Android bundle (Play Console, internal testing) | `build/app/outputs/bundle/release/app-release.aab` (61.2 MB) | `com.bottlesup.vendor`, same upload key as before (SHA-256 `32:CE:D8:0E:...:08:F4`), jar verified |
| Android APK (install directly on a phone) | `build/app/outputs/flutter-apk/app-release.apk` (89.1 MB) | versionCode 8, versionName 1.3.0, target SDK 36 |
| iOS (Transporter, then TestFlight) | `build/ios/ipa/BottlesUp Business.ipa` (26.3 MB; ignore the old `Vendor.ipa` of 17 Oct) | `com..bottlesUp.ORG`, 1.3.0 build 8, Apple Distribution team `4T453RG45S`, App Store profile (get-task-allow false) |

**These builds do NOT contain the third batch (section 2b)**: no new build was made, as you asked. When you want one with it, say so (it will be version 1.4.0, build 10, from `feat/business-brief-3` after it is merged). Uploading needs your accounts: drag the `.ipa` into Transporter and deliver, then add testers in TestFlight; upload the `.aab` in Play Console > internal testing. If you merge #23 first and want builds made from `main` instead, say so and I will rebuild (same commands: `flutter build appbundle --release`, `flutter build apk --release`, `flutter build ipa --release`). The app copes with any of the new database functions being absent, so it can go out before or after step 2.

## 4b. Give the test login its roles (one paste, 1 minute)

`bottlesupapp@gmail.com` exists and has signed in, but has **no role**, so the app would show "You do not have a workspace yet". Paste `supabase/go-live/test_login_roles.sql` into the production SQL editor: it makes that login **owner of Active Lounge** (the club that already holds the test staff) plus **door** and **server** at that venue, so the workspace picker lets one login try all three sides. The last query lists what it gave; running it twice adds nothing; the undo block at the bottom revokes the three roles. No organizer role is included (the organizer businesses are other people's); ask for a separate test organizer if you want that side. Claude could not run it itself (the permission layer blocks granting access in production).

## 5. Check it on a real phone (the brief's acceptance demonstration, section 35)

Use the demo club and a test booking (the demo night can be loaded with `supabase/go-live/demo_night.sql`; remove it afterwards with `demo_night_cleanup.sql`; both only on your say-so). What the app can show today, step by step:

| # | Brief step | In the app today |
|---|---|---|
| 1 | Create and verify the venue on the website | Website (unchanged). |
| 2 | Log in to BottlesUp Business, same venue and verification state | Yes: the status card on Overview. |
| 3 | Organizer creates an event and asks the club to connect | Yes: Events (draft) and More > Venue agreements > Ask a club. Venue selection on the event itself is website work. |
| 4 | Approve the connection, table allocation and deposit terms | Connection and terms yes. **Table allocation is not built** (needs the client's rules). |
| 5 | Invite a new door staff member for that event | Yes: organizer More > Team, once the club has switched on "organizer door staff" (club More > Organizer door staff). |
| 6 | The person registers, accepts and sees only the assigned dashboard | Yes (invitation link; one workspace opens straight in). |
| 7 | Test table booking with clear payment terms | Yes on the website; and in the app: Tonight > Add walk-in (terms read out, deposit due at the club). |
| 8 | The booking appears on the website and in the app | Yes: Floor, Tonight, the table page. |
| 9 | Scan admission and reject a duplicate scan | Yes (door Scan; "already checked in"). A ticket for several guests asks how many come in now and shows how many may still come (group admission). |
| 10 | Add a bottle order and record/confirm its payment | Yes: the table page > Orders > Add bottles; then Record a payment; a second person verifies it. |
| 11 | Mark partial or full delivery | Yes: Orders > Deliver some (part way) or Delivered. |
| 12 | Stock, order and financial totals update once | Yes: the menu shows what is left, the table total goes up once, a repeated tap changes nothing. |
| 13 | Review the organizer allocation and remaining settlement | **Not built** (settlements wait for the client, see 6). |
| 14 | Preliminary and final end-of-night report with matching figures | Yes: Tonight > Prepare and close the night; the PDF. |
| 15 | Unauthorized staff cannot reach another venue's records | Yes: checked by the database tests (a server sees only their tables, one club never sees another's). |
| 16 | (batch 3) Place the club's tables on its floor plan | Yes: Setup > Rooms and floor plan > Place tables (drag, resize, Save); the same percentages the website's editor uses, so guests see them in the right place. |
| 17 | (batch 3) See the night's tables as Available, Held, Booked, Occupied, Unavailable; hold one; take one out of use; reopen it | Yes: Tonight > Tables. A booked table can never be blocked; a held or blocked table cannot be bought on the website or at the door (one shared count). |
| 18 | (batch 3) Move a booking to another table and see who moved it | Yes: the table's page > Terms > Move to another table; it shows in Activity too. The guest's amounts do not change. |
| 19 | (batch 3) Set the refund policy, then ask for and decide a refund | Yes: Payment settings or More > Refunds > Refund policy; a booking's page > Cancel booking / Ask for a refund; More > Refunds > Decide. A card refund is returned by BottlesUp in the CMS (Refunds > Return through Stripe); one at the club is recorded with a terminal or receipt reference, a photo of the receipt, or both. |
| 20 | (batch 3) Staff give a discount and a free bottle; the owner's limits decide who approves | Yes: More > Discounts and free bottles (owner sets limits); the table's Orders tab (give); More > Discounts > Waiting (approve). Totals and stock follow. |
| 21 | (batch 3) The owner sees payouts | Yes, read only: More > Settlements and payouts; the CMS page Payouts creates the items and records the transfer with its reference. |
| 22 | (batch 3) Door staff sell a ticket at the door and the guest is checked in once | Yes: the door's **Door Sales** tab. Pick the ticket type and how many, the guest's name (email and phone optional), cash or the club's card machine (with its receipt number), confirm. The ticket code is shown; scanning it afterwards says already checked in. Try the last tickets from two phones at once: only one sale gets them. |
| 23 | (batch 3) A door person's own shift at the end of the night | Yes: the door's **More > Shift summary**: guests let in by scanning, tickets sold, cash and card machine kept apart. Another door person's figures never appear. |
| 24 | (batch 3) A club outside Toronto sets its own time zone | Yes: Setup > Venue profile > Time zone (owner or manager). It is what the refund policy counts the hours before arrival in. Every club reads as Toronto until it chooses. |

The older checklists in `HANDOFF.md` (TEST CHECKLIST and TEST CHECKLIST 2, items 1 to 67) still apply to everything built earlier.

## 6. Decisions only the client can make (what is still open after the 20 Oct answers)

Answered on 20 Oct and now built: payouts, refunds, discounts and free bottles, order stage Accepted, floor map, deposit terms, the 10-minute checkout hold, one booking system. Still waiting on the client: the **Event Lead** role and the ambassador program (including how Event Leads are paid); **Door Sales** extras: approved discounts or promo codes at the door (they need ticket discounts first), e-mailing the ticket to a guest sold at the door, a card reader built into the app, a manager's report of every door person's sales; how a **free bottle is claimed by someone who is not at a table**; **ticket discounts** for organizers; **settlements** of ticket earnings (who owes whom); the wording of the **guest e-mails** about a refund decision, and the rest of the e-mail sheet; the **legal text** (Terms, Privacy); push and SMS providers; a Sentry DSN or Firebase account if crash reporting is wanted; and a decision on the 15 old accounts to convert. `docs/BRIEF_15OCT_GAP_ANALYSIS.md` lists each, section by section, with what exists and what is missing.

## 7. If something goes wrong

* A database step fails: nothing from that file is applied (each runs in one transaction). Send me the message.
* The app misbehaves after step 2: the app copes with any of these functions being absent (each new screen says "not set up on this server yet" or "could not be loaded"). The undo scripts in step 2 take the database back.
* A merge shows conflicts: do not resolve in the browser; tell me which pull request.
