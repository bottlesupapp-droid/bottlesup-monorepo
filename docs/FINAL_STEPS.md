# FINAL STEPS: what is left for you (everything else is built, tested and pushed)

Written 19 Oct 2026. This is the one list to work through, top to bottom, when you are ready. Everything that could be done without you is done: code, database
migrations with their tests, rollbacks, read-only audit scripts, documentation. **Nothing below has been done to production, and nothing in production was touched
while preparing it.** Each step says what it does, how to check it, and how to undo it.

Rule for Claude sessions reading this: do none of these without the user's explicit yes for that step.

## 0. Two answers I still need from you (2 minutes)

1. **Test login `bottlesupapp@gmail.com`: access to both apps.** I cannot create accounts or set passwords. Tell me which role(s) you want that
   account to have (owner / manager / server / door / several), and for which club (the demo club "Active Lounge" is the only one set up for a walk-through), and say
   "yes, grant it". I will then run one read-only look and one targeted write through your Supabase CLI login, as on 16 and 18 Oct. Alternative: send that one person an invitation from
   More > Team in the app (owner) and accept it with that e-mail: no database work at all.
2. **XNO's booking window.** The club XNO accepts bookings only until 26 Sep 2026 (`booking_end_date`). Extending it to 31 Dec 2026 is a production write; say "extend XNO" and I will do exactly
   that one change. Until then guests cannot book XNO tables online.

## 1. Merge the pull requests (about 15 minutes)

Each repo is a **stack**: every pull request sits on top of the one below it. Merge from the bottom, and **tick "Delete branch"** each time, so GitHub moves the next
pull request onto `main` by itself. Before you click Merge, look at the line under the title: it must say `into main`. If it still names another branch, wait a minute
and reload, or stop and tell me.

`docs/merge_stack.sh` does exactly this for you with the GitHub CLI (it prints the plan first, asks you to type `merge`, checks the base of each pull request, and stops at
the first problem): `bash docs/merge_stack.sh website` then `bash docs/merge_stack.sh vendor`. You can also click through by hand:

| Repo | Order |
|---|---|
| **website** (`KDR9MGR/bottles-up-website`) | #2, #3, #4, #5, #6, then #7, #8, #9, then #10 |
| **vendor app** (`bottlesupapp-droid/bottles-up-vendor`) | #16 (CI), #13, #14, #15, #17, #18, #19, #20, then #21 |

Before the website merges I checked on a scratch merge that #9 (e-mail wording) and #10 (everything else) combine without conflicts and that the unit tests pass together.
Merging changes nothing in production by itself: the website `main` redeploys on Vercel (see 3), the database is untouched until step 2.

Then tell me, and I will move the monorepo's pointers for `apps/bottles-up-vendor` and `apps/bottles-up-website-main` (they are deliberately not committed while the
branches are unmerged) and merge the monorepo branch `chore/audit-and-staging` if you want it.

## 2. Apply the database changes to production (30 to 45 minutes, at a quiet time)

Never `supabase db push` (production's migration history stops at 20260925080444). Use the SQL editor, one file at a time, in the order below, exactly as in
`supabase/go-live/README.md` (sections 1f and 1g). Every file is in `apps/bottles-up-website-main/supabase/migrations/` after step 1. Or tell me "apply them" and I will do it
through your CLI login, one file per transaction, with a check after each (the method used on 16 and 18 Oct).

| # | File | Adds |
|---|---|---|
| 1 | `20261019100000_outbox_claim` | the claim/finish functions for the e-mail sender (optional; only needed with step 3's `process-outbox`) |
| 2 | `20261020100000_venue_payment_rules` | owner's bottle-payment setting |
| 3 | `20261020110000_booking_guests_and_activity` | a table page's Guests and Activity tabs |
| 4 | `20261020120000_org_event_states` | where each organizer event stands |
| 5 | `20261020130000_organizer_door_staff` | one column, six functions, and REPLACES `invite_member` (guarded: stops with nothing changed if the live function is not the expected one) |
| 6 | `20261020140000_desk_walkin` | walk-in booking |
| 7 | `20261020150000_add_bottles_checks` | who may add bottles to a table, and the bottle menu |
| 8 | `20261020160000_partial_delivery` | one column on the bottle lines and the partial-delivery functions |
| 9 | `20261020170000_group_admission` | one closed table and three functions for group admission at the door (the live scan functions are not touched) |

* **Before:** run `supabase/audit/16_preflight_business_brief_2.sql`. It must return **no rows**. (Rows mean a name is taken or something earlier is missing: send me the result.)
* **After each file:** it must say success. If one stops with a message, do not edit it: send me the message.
* **After all:** run `supabase/audit/17_postflight_business_brief_2.sql`: every row `ok = true`.
* **Undo:** `supabase/go-live/rollback_business_brief_2.sql` for files 2 to 9, `supabase/go-live/rollback_outbox_claim.sql` for file 1. Both tested on a scratch copy.
* The two September files (`20260923100000`, `20260925100000`) are **not** applied: they are already live (see 1e). Optional proof: `supabase/audit/15_check_september_changes.sql` returns no rows.

## 3. Deploy the functions and the website

From `apps/bottles-up-website-main` after step 1 (no Docker needed with `--use-api`):

```bash
supabase functions deploy add-table-booking-bottles --project-ref hwmynlghrmtoufyrcihp --use-api   # now lets a server or manager add bottles at the table
supabase functions deploy send-team-invitation        --project-ref hwmynlghrmtoufyrcihp --use-api   # invitation e-mail now says BottlesUp Business
supabase functions deploy process-outbox              --project-ref hwmynlghrmtoufyrcihp --use-api   # optional: sends the queued guest e-mails
```

* `add-table-booking-bottles` and `send-team-invitation` replace what is deployed with what is in the repository. If anyone ever edited either in the Supabase dashboard,
  tell me first so nothing is lost. `process-outbox` is new.
* **Switching on the guest e-mails** (optional, your call): the client reads the wording in `supabase/functions/_shared/outbox.ts`, then add a 5-minute schedule that calls
  `process-outbox` with the service role key as the bearer (README 1f). Until then every guest message stays "Queued, not sent yet" in the app, which is honest.
* **Website:** merging step 1 redeploys the site on Vercel (one team screen says BottlesUp Business now). Nothing else to do.

## 4. Build and upload the vendor app

The app is version **1.3.0 (build 8)** on `feat/business-brief-2` (it becomes `main` after step 1). Builds point at production by default.

```bash
cd apps/bottles-up-vendor
flutter pub get
flutter build appbundle --release      # Android: build/app/outputs/bundle/release/app-release.aab -> Play Console, internal testing
flutter build ipa --release            # iOS: build/ios/ipa/*.ipa -> Transporter -> App Store Connect / TestFlight
```

Signing is as before (upload key in `~/bottlesup-secrets/android/`, Apple team `4T453RG45S`). If you would rather I build them, say so after step 1 and I will build from `main`
and check the signatures and version numbers as on 18 Oct. Tell me about any build problem and I will fix it.

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

The older checklists in `HANDOFF.md` (TEST CHECKLIST and TEST CHECKLIST 2, items 1 to 67) still apply to everything built earlier.

## 6. Decisions only the client can make (they unblock the rest of the brief)

Payout timing and account structure (20); supported card devices and Door Sales (26); fee formulas; refund and commission windows (28, 31); how long a hold or an
invitation lasts (13, 24); how long ambassador chat is kept (28); discount stacking and approvals, complimentary bottle claim rules (21); the Event Lead role and the ambassador
program (28); settlements and who owes whom (31). `docs/BRIEF_15OCT_GAP_ANALYSIS.md` lists each, section by section, with what exists and what is missing.

## 7. If something goes wrong

* A database step fails: nothing from that file is applied (each runs in one transaction). Send me the message.
* The app misbehaves after step 2: the app copes with any of these functions being absent (each new screen says "not set up on this server yet" or "could not be loaded"). The undo scripts in step 2 take the database back.
* A merge shows conflicts: do not resolve in the browser; tell me which pull request.
