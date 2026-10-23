# FINAL STEPS: what is left for you (everything else is built, tested and pushed)

Written 19 Oct 2026. This is the one list to work through, top to bottom, when you are ready. Everything that could be done without you is done: code, database
migrations with their tests, rollbacks, read-only audit scripts, documentation. **Nothing below has been done to production, and nothing in production was touched
while preparing it.** Each step says what it does, how to check it, and how to undo it.

Rule for Claude sessions reading this: do none of these without the user's explicit yes for that step.

## Where things stand (19 Oct, night): steps 1, 2 and 3 are DONE and validated

* **Merged (by you, 13:34 to 13:42 UTC) and checked by Claude:** vendor `main` contains the whole stack (its only file difference from the stack head is the CI workflow it keeps), version 1.3.0+8; website `main` contains #2, the whole stack (#11), the e-mail wording (#9) and the September record (#12), and all nine migration files. Left over and harmless: website #7 (old stacked piece, contained in #11), website #3 (closed), website #4 to #6, #8, #10 show as merged.
* **Migrations applied to production (by you) and validated read-only by Claude through the Supabase connector:** post-flight 17 all 12 rows true; **all 29 functions (the 20 new ones, `outbox_claim`/`outbox_finish`, `invite_member`, and neighbours) are byte-for-byte identical to the committed files** (fingerprint of the normalized body, security flags, search_path and return type compared with a replay on the scratch database), grants exactly as designed (visitors none; signed-in people yes, except `event_door_allowed`, `outbox_claim`, `outbox_finish`); the live `door_scan_ticket`, `door_verify_ticket_code` and `desk_set_service_status` are unchanged and equal the repository; `site_order_admissions` has row level security, no policies, no access for signed-in people or visitors, 0 rows; `delivered_quantity` is `integer not null default 0` with a non-negative check and no line has a non-zero count; `organizer_door_staff` is `boolean not null default false` and no club has it on; `site_outbox.claimed_at` exists and the outbox is empty; the `scan_attempts` result constraint is untouched; the Phase 2 post-flight (audit 13: 83 functions, 22 tables, RLS, grants, search_path) still passes; the Supabase security advisor mentions the new objects only as "RLS enabled, no policy" on the closed admissions table and "signed-in users can execute a security definer function" on the new functions, both by design (each checks the caller inside, and the tests prove it). Pre-existing advisor items (exposed `auth.users` view, a security-definer view, leaked-password protection off, a Postgres version notice, functions in `public`) are not from this work.
* **Functions deployed (step 3) by Claude through the CLI once you had logged in to the right account:** `add-table-booking-bottles` v9 (JWT check kept off as it was; first confirmed that the live version was just an older revision of the repository code with no hand edits), `send-team-invitation` v4, `process-outbox` v1 (new, **not scheduled**). Smoke-tested without credentials: the first two answer 401 "Unauthorized" from their own code (so the new code boots), `process-outbox` answers 401 and sends nothing.
* **Still blocked for Claude (permission layer):** merging into `main` and every write to production, so the remaining steps below are yours, or add permission rules for `gh pr merge` and the Supabase connector's `execute_sql` / `deploy_edge_function`.
* **Not wanted:** extending XNO's booking window (you said no need).

## 3. Functions and website: DONE (nothing left except the optional guest e-mails)

Deployed on 19 Oct (see "Where things stand"); the website redeployed on Vercel when #11 and #9 merged.

* **Switching on the guest e-mails** (optional, your call, deliberately NOT done): the client reads the wording in `supabase/functions/_shared/outbox.ts`, then add a 5-minute schedule that calls `process-outbox` with the service role key as the bearer (`supabase/go-live/README.md` 1f step 4). Until then every guest message stays "Queued, not sent yet" in the app, which is honest, and `process-outbox` does nothing when called by anyone else.

## 3b. Let staff delete their own account (new 22 Oct, written and tested, NOT applied; needed for the App Store)

Today "Delete account" in the vendor app fails ("Failed to delete account") for anyone who accepted an invitation, scanned a ticket, handled cash or created a business. The fix is one website migration on branch `fix/account-deletion-actor-fks` (merged as website PR #13). Records stay; only the person is removed from them. No app rebuild and no function redeploy.

1. ~~Merge the website branch~~ DONE: you merged website PR #13 on 22 Oct (`main` = `951c069`).
2. DONE 23 Oct: audit 18 on production showed 71 rows (66 covered by the migration, 5 production-only legacy columns it does not cover).
3. DONE 23 Oct: applied `20261029100000_account_deletion_actor_fks` with `apply_one.sh` (one transaction, no error).
4. DONE 23 Oct: audit 18 again: 5 rows left, all production-only: `admin_audit_log.admin_id` (an admin with audit rows still cannot be deleted), `conversations.created_by`, `event_rsvps.verified_by`, `vendor_onboarding_data.referrer_id`, `venues.manager_id`. They need a second small migration (say the word). The brief-3 tables are already in production and were fixed too, so no re-run is needed.
4b. **The 5 leftover columns (written and tested, NOT applied):** website branch `fix/account-deletion-legacy-columns` (pull request open for you to merge). After merging: (a) run the read-only `supabase/audit/19_preflight_legacy_account_columns.sql` on production: no rows = it will go through, "would stop" rows = send them to me (the tables are not defined in the repository, so the migration refuses, changing nothing, rather than guess); (b) apply it with `apply_one.sh 20261030100000_account_deletion_legacy_columns`; (c) run audit 18: it must now return no rows. Only on your explicit yes for each production step.
5. Try it: delete a test door/manager account from the vendor app; the person's scans, payments and audit rows must still be there with no name on them.
Undo: none needed (the change only lets deletions through). Tell the client: the audit log keeps the e-mail of whoever acted, and accepted invitations keep the invited e-mail address; the privacy policy should say so.

## 4. Upload the vendor app (the builds are made)

Built on 19 Oct from the stack head (`bc810e1`, byte-for-byte the code that lands on `main` with #23), version **1.3.0 (build 8)**, pointing at production:

| | File (under `apps/bottles-up-vendor/`) | Checked |
|---|---|---|
| Android bundle (Play Console, internal testing) | `build/app/outputs/bundle/release/app-release.aab` (61.2 MB) | `com.bottlesup.vendor`, same upload key as before (SHA-256 `32:CE:D8:0E:...:08:F4`), jar verified |
| Android APK (install directly on a phone) | `build/app/outputs/flutter-apk/app-release.apk` (89.1 MB) | versionCode 8, versionName 1.3.0, target SDK 36 |
| iOS (Transporter, then TestFlight) | `build/ios/ipa/BottlesUp Business.ipa` (26.3 MB; ignore the old `Vendor.ipa` of 17 Oct) | `com..bottlesUp.ORG`, 1.3.0 build 8, Apple Distribution team `4T453RG45S`, App Store profile (get-task-allow false) |

Uploading needs your accounts: drag the `.ipa` into Transporter and deliver, then add testers in TestFlight; upload the `.aab` in Play Console > internal testing. If you merge #23 first and want builds made from `main` instead, say so and I will rebuild (same commands: `flutter build appbundle --release`, `flutter build apk --release`, `flutter build ipa --release`). The app copes with any of the new database functions being absent, so it can go out before or after step 2.

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
