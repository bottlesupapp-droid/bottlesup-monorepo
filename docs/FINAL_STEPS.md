# FINAL STEPS: what is left for you (everything else is built, tested and pushed)

Written 19 Oct 2026. This is the one list to work through, top to bottom, when you are ready. Everything that could be done without you is done: code, database
migrations with their tests, rollbacks, read-only audit scripts, documentation. **Nothing below has been done to production, and nothing in production was touched
while preparing it.** Each step says what it does, how to check it, and how to undo it.

Rule for Claude sessions reading this: do none of these without the user's explicit yes for that step.

## Where things stand (19 Oct, evening)

* **Done by Claude:** all code, tests and documents; the **production pre-flight audit was run read-only through the Supabase connector and came back with no rows** (no new name exists, every prerequisite is there, `invite_member` is exactly the expected version), so the migrations are safe to apply as they are.
* **Blocked for Claude, so they are yours:** merging into `main` (the permission layer refuses "Merge Without Review") and every write to production (refused as "Production Deploy"), through the connector too. The Supabase CLI on this Mac is signed in to a different Supabase account (it lists only the `sabalive` projects), so it cannot reach production either. Two ways forward: do steps 1 and 2 yourself (about 20 minutes), or add permission rules for `gh pr merge` and for the Supabase connector's `execute_sql` / `deploy_edge_function` in the Claude Code settings and tell me to continue.
* **Already merged by someone before this list was finished:** the vendor stack was merged bottom-up into its intermediate branches, so vendor `main` only got #13, #16 and #22; website #2 is merged and #3 was closed by a branch deletion. That is why step 1 is now three single pull requests (the whole stack already sits, in order, on the top branches).
* **Not wanted:** extending XNO's booking window (you said no need).

## 1. Merge three pull requests (2 minutes)

Each is one pull request from the top of a stack, with every piece already in it, CI passing, and a clean trial merge into `main`:

| Repo | Pull request | Merge when |
|---|---|---|
| vendor app | [#23](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/23) `feat/business-brief-1` into `main` (the whole stack, version 1.3.0+8) | first |
| website | [#11](https://github.com/KDR9MGR/bottles-up-website/pull/11) `feat/business-brief-2` into `main` (organizer events, server desk, Phase 2 modules, September record, outbox sender, tranche 2) | second |
| website | [#9](https://github.com/KDR9MGR/bottles-up-website/pull/9) `feat/business-naming` into `main` (e-mails say BottlesUp Business) | after #11 |

In the browser: Merge pull request, **Create a merge commit**, and do NOT tick "Delete branch". Or in a terminal: `bash docs/merge_landing_prs.sh` (shows the plan, asks you to type `merge`). Afterwards close website #4, #5, #6, #7, #8 and #10: they are the old stacked pieces and are fully contained in #11 (#3 is already closed).

Merging the website redeploys it on Vercel (the new organizer and cancel-business screens, one team screen wording) and changes nothing in production's database.

Then tell me, and I will move the monorepo's pointers for `apps/bottles-up-vendor` and `apps/bottles-up-website-main` and open the monorepo pull request for `chore/audit-and-staging` (it only holds documents, audits and scripts).

## 2. Apply the database changes to production (about 10 minutes)

**One paste:** `supabase/go-live/apply_pending_migrations.sql` holds all nine pending migrations (the outbox claim plus the eight tranche-2 ones), byte-identical to the migration files, each in its own begin/commit, in the right order; an error rolls back that migration and stops the rest. Tested on the scratch database: after the undo scripts it applied cleanly and the post-flight was all true.

1. Supabase dashboard > the production project > SQL editor. (Optional but done already on 19 Oct: run `supabase/audit/16_preflight_business_brief_2.sql`, it must return no rows.)
2. `pbcopy < supabase/go-live/apply_pending_migrations.sql` (macOS), paste, Run. It must finish with no error.
3. Run `supabase/audit/17_postflight_business_brief_2.sql`: every row `ok = true`.
4. Undo, if ever needed: `supabase/go-live/rollback_business_brief_2.sql` (the eight tranche-2 files), `supabase/go-live/rollback_outbox_claim.sql` (the outbox file). Both tested.

If a file stops with a message, do not edit it: send me the message. Never `supabase db push` (production's migration history stops at 20260925080444). The two September files (`20260923100000`, `20260925100000`) are **not** applied: they are already live (`supabase/audit/15_check_september_changes.sql` returns no rows). The old per-file list is in `supabase/go-live/README.md` sections 1f and 1g.

## 3. Deploy the functions and the website

From `apps/bottles-up-website-main` after step 1 (no Docker needed with `--use-api`). **The Supabase CLI on this Mac is currently signed in to another Supabase account**: run `supabase login` with the account that owns the production project first (`supabase projects list` must show `hwmynlghrmtoufyrcihp`):

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
