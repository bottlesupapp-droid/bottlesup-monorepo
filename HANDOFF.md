# HANDOFF: read this first

Last updated: 2026-10-09 by Claude (Sonnet 5.5). **If you are a Claude session picking this up:** read this file, then verify any fact you are about to
rely on with git (branch heads, whether a PR merged) because it can be stale. **When you finish a chunk of work, update this file**: replace
stale lines, do not append history, keep it readable in a few minutes, commit it on the monorepo branch `chore/audit-and-staging` and push that
branch (never push `main`). No secrets in this file.

> **Other Claude sessions push to this repo too** (same git user). `git fetch` before you push, and read `git log origin/<branch>` for work you did not do. Never force-push.

## The project in one paragraph

BottlesUp: a nightlife booking platform. One Supabase project (`hwmynlghrmtoufyrcihp`) is **production** and is shared by three apps. The client
(brief PDFs: Phase 2 **Vendor App**, 31 sections; **Website Onboarding and Dashboards**, 6 sections) wants one shared set of records across the
website, the customer app and the vendor app, with roles (owner, manager, organizer, server, door, security, verifier) enforced in the database. The
decision taken: **the website's `site_*` schema and functions are the source of truth**; the apps must move onto them.

| Repo (path under `apps/`) | Remote | Default branch | Role |
|---|---|---|---|
| `bottles-up-website-main` | github.com/KDR9MGR/bottles-up-website | `main` | React/Vite site + Supabase migrations + edge functions. Source of truth. |
| `bottles-up-vendor` | github.com/KDR9MGR/bottles-up-vendor | `main` | Flutter app for owners, managers, staff. |
| `bottles-up-user` | github.com/KDR9MGR/bottles-up-user | **`master`** (but real work is on `main`) | Flutter customer app. |
| monorepo root | github.com/bottlesupapp-droid/bottlesup-monorepo | `main` | Submodules + audit SQL + staging runbook + this file. |

## Rules learned the hard way (follow them)

- **Production is off limits to me.** The harness blocks reading the production database (even with the user logged in to the Supabase CLI) and blocks
  `gh pr merge`. Do not look for a way around either; ask the user to do it, or to add a permission rule. The user merged website PR #1 themselves.
- **There is no staging.** (The go-live runbook goes straight to production, with the user running every step.) Never apply a migration "to staging" by running it against `hwmynlghrmtoufyrcihp`. The runbook is `supabase/staging/README.md`
  (never run). The org has only two Supabase projects (production and an unrelated `habitpro`); a third may need a paid plan (unconfirmed).
- Push **branches only**, never `main`, never force. Merges to `main` are the user's click (or an explicit rule they add).
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Never use bare `git stash`. `.DS_Store` stays uncommitted. Do not use other people's signing identities found on this Mac.
- Say what is **not verified** plainly (no real database was ever used; the camera was never tested on a phone; QR codes drawn but not scanned).
- Migrations: plain `CREATE FUNCTION` (never `CREATE OR REPLACE`) so a collision in the shared DB fails loudly; replacing a live function uses a
  compare-and-swap guard; `SECURITY DEFINER` + `set search_path`; whitelisted fields; row ids looked up *inside* the venue given.
- New code is **mutation-checked**: break it on purpose, confirm the tests fail, fix test gaps (two kinds of survivor are fine: redundant guards the UI makes unreachable).
- Pure rule modules + drift-guard tests that read the website repo's files (skipped if the repo is not beside the app) keep apps and website identical.
- Honest placeholders: a section that is not built says so; "booked" is never called "collected"; an unknown status is never shown as confirmed.
- Environment traps: see memory `local-db-tests-postgres` (Postgres needs `LC_ALL=en_US.UTF-8` and TCP only). zsh does not word-split `$VAR` (use `bash -c`), and `$R:t` is a
  modifier (write `${R}:t`). The Claude scratchpad is wiped between sessions: keep nothing important there.

## Website (`bottles-up-website-main`): merged, not live

- `main` = `b765da8` (PR #1, merged by the user 2026-10-07) contains everything: CI, tenancy, account onboarding, team invitations, scoped door scanner,
  venue setup, booking link, owner bookings, and the two guarded scanner fixes. Production deploys only on `main`; the new screens are **off** behind
  `VITE_ENABLE_ACCOUNT_ONBOARDING` (unset). Only other branch: `claude/blissful-elbakyan-e0a880` (not mine: header/gallery/date-field fixes, 1 unmerged commit, 63 behind).
- **Go-live runbook (written by another session on 2026-10-07, branch `chore/audit-and-staging`): `supabase/go-live/README.md`. Follow it, not older notes.** It records that the
  user's production preflight (7 Oct) found no collisions and nothing missing; production is Postgres 17.4. Two findings: production's `checkin_ticket()` was rewritten and has
  **no** fall-through bug, so `20260830120000_fix_checkin_ticket_early_returns.sql` must **NOT be applied**; production's `verify_ticket_otp()` is the old one, so
  `20260830130000_fix_verify_ticket_otp_expiry.sql` **does** apply. Apply 7 files by hand in the SQL editor, in this order: `20260830130000`, `20261006120000`, `20261007100000`,
  `20261008100000`, `20261009100000`, `20261010100000`, `20261011100000`. **Do not use `supabase db push`.** Then run the read-only `supabase/audit/04_postflight_website_migrations.sql`
  (first row must say OK), deploy `send-team-invitation` (`--use-api`), add `https://www.bottlesupapp.com/home` to Auth redirect URLs, set `VITE_ENABLE_ACCOUNT_ONBOARDING=true` on the
  Vercel project that serves bottlesupapp.com (two projects deploy this repo: `bottles-up-website`, `bottles-up-website1`) and redeploy, then smoke-test. Rollback for the entry-code fix:
  `supabase/go-live/rollback_verify_ticket_otp_fix.sql`; the feature is switched off by unsetting the flag.
- **Whether the user has executed the runbook is UNKNOWN to me.** Nothing auto-applies on merge. Do not assume either way: ask the user, or have them run the postflight and send the result.
  The runbook goes straight to production (no staging project exists). The older preflight/audit scripts (`01`, `02`, `03` in `supabase/audit/`) are still there; `03` is the preflight that produced the findings above.
- Checks on `main`: 801 database assertions (+ concurrency and two migration-guard scripts), 753 unit tests, build, type check at its 127-error baseline
  (`tsc-baseline.json`), lint within 8 warnings. GitHub CI runs the same (Postgres 17).
- Owner screens built: Overview, My Venues (profile + editors for floor plans, tables, bottle menu, booking times), Tables & Bookings (read-only, a manager's Floor too),
  Booking Link + QR, Team. Door staff: Scan, Guests. Everything else in the workspace shell is a placeholder.
- **Blocked until `supabase db pull`:** bottle orders, money actually collected, cancellations, anything server/table-service (production has columns/functions no
  committed migration defines: `profiles`, `promo_codes`, 17 of 24 RPCs, per-line bottle service/payment state, `table_view`/`privacy_level`/`seating_type`/`amenities`/`policy_note`).

## DETOUR (2026-10-10): client-reported website problems (vendor-app work paused)

The client reported two things (a screen recording of the onboarding page was attached; frames were extracted and read). Both are fixed on
**two stacked website branches with PRs open, merge in this order** (PR [#2](https://github.com/KDR9MGR/bottles-up-website/pull/2) first, then [#3](https://github.com/KDR9MGR/bottles-up-website/pull/3), whose base is #2's branch; retarget #3 to `main` after #2 merges if GitHub does not): `fix/leave-onboarding-and-cancel-business` `0ceed72`, then
`feat/organizer-create-event` `3e5f96c` (which contains the first). Website `main` is still `b765da8`.
1. **"Eonics Lounge was a mistake but I can't exit the onboarding screen and cancel it."** Cause: Back pointed at `/home`, and `decideLanding`
   sends a person with exactly one unfinished business straight back to its onboarding page (a loop); no function let a person delete a business.
   Fix: Back goes to `/workspaces`; new `cancel_business(p_org)` (migration `20261012100000`): the owner/organizer of an UNVERIFIED business (not_submitted or
   more_information_needed) can delete it with its drafts; refuses under review / verified, other active team members, a live venue or published event, and
   anything with bookings or orders; audit-logged; "Cancel this business" section with a confirmation; sign-up intent reset to personal after cancelling.
2. **"Event organizer page needs a create event."** The organizer's Home/Events were "coming soon" and `site_events` is CMS-admin-only. Fix: new
   `list_org_events` / `save_org_event` / `remove_org_event` (migration `20261013100000`); organizers create DRAFTS only (cannot publish; no status/org_id/slug
   field), can edit/remove their drafts, published events are out of reach, 200 per business, audit-logged; list + Create event form on the organizer's Home and Events.
   **Not built (open client decisions):** ticket tiers, linking an event to a venue + agreement, publishing by the organizer. Drafts stay private until the BottlesUp
   team publishes them in the CMS (which also adds tickets).
- **Neither migration is applied anywhere.** Apply 8 and 9 in the SQL editor (runbook section 1b in `supabase/go-live/README.md`) and run
  `supabase/audit/05_check_client_feedback_fixes.sql` (read-only; checks prerequisites such as `site_events.organizer_name`, exposure and search_path). Until then the
  new buttons show an error; nothing else changes.
- **CI status (13 Oct): GREEN on both PRs** (#2 and #3: all 5 checks each, mergeable, state CLEAN). "Migrations replay and database tests" first failed only on a Docker Hub rate limit (the runner could not pull `postgres:17`); the re-run on 13 Oct passed, so both migrations (`20261012100000`, `20261013100000`) now have a passing run on Postgres 17, which is production's major version (production is 17.4; local runs used 15). Nothing is merged or applied yet.
- Checks on the stacked branch: DB suite 957 assertions, unit 890, typecheck/lint(8)/build clean; SQL and TypeScript mutation passes (every real survivor became a test;
  left: a redundant organization-kind check, a defensive double-save guard). Both screens were looked at on a throwaway Vite page (deleted).
- The client is already using the onboarding pages, so the go-live runbook (or enough of it) must have been run and the flag turned on somewhere; not confirmed with the user.
- Tell the client: events they create are private drafts until BottlesUp publishes them.

## Vendor app (`bottles-up-vendor`): ten stacked branches, none merged

`main` `1e7cb72` (1 Jul) → `chore/archive-unused-features` `09f3038` → `feat/workspaces` `7ac43fe` → `feat/door-on-website-functions` `9b8dd32` →
`feat/manager-floor` `8af0d05` → `feat/owner-venues` `4ab7b3c` → `feat/owner-setup-editors` `34e1dd1` → `feat/owner-team` `bc6c5ad` → `feat/organizer-events` `d85d03f` → `feat/owner-profile-floors` `9f44763` → `feat/photos-tables-bottles-events` `d467087` (all pushed). **PRs open, stacked: each PR's base is the previous branch; merge #1 first, oldest to newest** ([#1](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/1) archive, [#2](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/2) workspaces, [#3](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/3) door, [#4](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/4) manager Floor, [#5](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/5) owner Home/Venues, [#6](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/6) setup editors, [#7](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/7) Team, [#8](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/8) organizer Events, [#9](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/9) profile + floors, [#10](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/10) photos). After each merge GitHub should retarget the next PR to `main`; if not, change its base by hand. The repo has no CI.

- Built on the website's functions: workspaces (`my_workspaces`, `accept_invitation`), door **Scan + Guests** (door role only), manager **Floor** (bookings by night,
  `list_venue_bookings`), owner **Home** (tonight across venues) and **Venues** (list, add venue, per-venue Bookings / Setup / Link tabs with QR), and the owner's
  **setup editors**: tables, bottle menu, booking times (the Setup tab's `tables`/`bottles`/`booking_rules` steps open them; `save_venue_table_type`, `save_venue_bottle`,
  `add_venue_time_slot` and the `list_/remove_` pairs).
  The owner's and manager's **Team** tab (`lib/features/team/`): list, invite (role from `invitable_roles`, optional temporary window and shift), send a new link, cancel, remove
  (`list_team`, `list_team_invitations`, `list_shifts`, `invite_member`, `resend_invitation`, `revoke_invitation`, `revoke_membership`; email via the `send-team-invitation` edge function, link shown once with Copy / mailto fallback). Not yet: creating a shift, changing a member's role or window.
  The organizer's **Home and Events** tabs (`lib/features/organizer_events/`): list (drafts / upcoming / past), create, edit and remove drafts on `list_org_events` / `save_org_event` /
  `remove_org_event` (website PR #3; **needs that migration applied**). An organizer cannot publish; cover photo supported; no ticket tiers / venue link yet.
  The owner's **venue profile** (name, description, address, cover photo: `update_venue_profile`) and **floor plans** (`list_/save_/remove_venue_floor`, name + image) editors on the venue's Setup tab, with
  **photo upload** (`PhotoField` + `MediaService` + `media_rules.dart`: gallery picker, real-type sniff, JPEG/PNG/WebP <= 5 MB, into `<org id>/<uuid>.<ext>` of the public `business-media` bucket).
  **Photos for tables (`image_url`), bottles (`image_url`) and event covers (`cover_image_url`)** use the same `PhotoField` (thumbnails on the list cards; Remove sends none; Save waits for the upload).
  **Not tried with the real picker or real storage** (no staging, needs a phone); old photo files are never deleted.
  Rules are Dart ports of the website's rule modules. All screens say "not set up on this server yet" until the website migrations are applied.
- Still placeholders: server screens (Scan/My Tables/Orders/Requests: prod-only functions), Door Sales, manager Tonight/Orders/Team/More, owner Money/Reports/More, organizer, security, verifier.
- Checks: 670 tests, analyzer 0 errors, 142 infos and 14 old unused-import warnings in unrelated files (none in owner code). Run once under a DST zone: `TZ=America/Toronto flutter test`. Look at screens with a throwaway
  Flutter **web** build served locally and the built-in browser (click `flt-semantics-placeholder` to enable accessibility; delete the demo file and `build/web` after).
- Release blockers (user actions): Android `key.properties`/keystore (build fails without it on purpose); Apple team `4T453RG45S` has no signing identity and both
  iPhones were offline; register App ID `com.bottlesup.vendor`; real privacy-policy text; crash reporting; no iOS privacy manifest; camera never tested on a phone.
- Reads/writes legacy tables (`events`, `clubs`, `events_bookings`, `table_bookings`...) everywhere else: the classic dashboard and the old scanner are untouched.
  `CLAUDE.md` in that repo is accurate; the many `*_SUMMARY.md` / `PRODUCTION_READY*.md` files are stale, ignore them.

### Vendor app: production readiness (14 Oct) - what is done and what is left

**Verdict:** not production-ready as the full Phase 2 product. A narrow first release (owner setup + team + door + manager Floor + organizer drafts) is one set of user actions away
(merge, apply migrations, signing, real-device test). Money, table service and most of the 31-section brief are not built.

**Done (built, tested with fakes, pushed, unmerged):** workspaces + role navigation + accept-invitation screen; door Scan + Guests; manager Floor; owner Home (tonight across venues), Venues (add venue, per-venue
Bookings / Setup / Link + QR); owner/manager setup editors: venue profile + cover, floor plans + images, tables + photos, bottle menu + photos, booking times; owner/manager Team (invite, links, cancel, remove);
organizer Home/Events (create / edit / remove drafts, cover photo). 670 tests incl. drift guards against the website's SQL/TypeScript, a DST-zone run, and mutation testing of every slice.

**Left, user actions (blockers):** merge the ten vendor branches and website PRs #2/#3; apply website migrations 1-9 and run the post-flight + `supabase/audit/05_...`; deploy `send-team-invitation`;
decide on a staging Supabase project (nothing has ever run against a real database); Android keystore (`android/key.properties`); Apple signing identity + App ID `com.bottlesup.vendor` (team `4T453RG45S`);
real privacy-policy text and store listing; a real-device pass (door camera, photo picker + upload incl. an iPhone HEIC, invitation email -> accept, poor connectivity).

**Left, code in this app:** crash reporting (none: no Sentry/Crashlytics); iOS `PrivacyInfo.xcprivacy` for the Runner target (only pods have one); deep/universal links so an invitation link opens the app (today it opens the
website page; Android has no app-link intent filter, iOS no associated domains); CI for the vendor repo (none); decide the fate of the classic vendor dashboard + old scanner (legacy tables, untouched, not on `site_*`);
shift creation, change a member's role/window, claim an existing venue, venue gallery; analyzer clean-up (156 old issues, 14 warnings); an accessibility / offline / error-state pass; push notifications (none).

**Left, brief features not built in the app:** server dashboard (My Tables, Orders, Scan, Requests), bottle orders and delivery states, payment evidence + verifier queue, cash handover, walk-ins, service requests, door sales / VIP /
exit-occupancy / override, promo codes, complimentary bottles + claim link, venue VIP list, inventory ledger, chat + notifications, sales-source / POS, organizer ticket tiers / venue linking / agreements / settlement / payouts,
refunds + settlement adjustments, close night + PDF reports, manager Tonight / Orders / More, owner Money / Reports / More, security and verifier workspaces, organizer Guests / chat / team, business onboarding + verification (website only).
Most of the money and table-service items are blocked on `supabase db pull` (production-only functions) and on the client decisions listed above.

## User app (`bottles-up-user`): not production-ready, untouched since the archive cut

- My branch `chore/archive-unused-features` `1f00eb9` (pushed) sits on `main`'s `242b05f` and **lacks** `main`'s newest commit `edabdc2` ("Update bundle ID/package name to com.btlup.pop").
  The GitHub default branch is `master` (`97d53ea`, 5 commits behind `main`). Bundle IDs disagree: iOS `com.bottlesUpUser`, Android `com.bottlesupuser`, `main` tip `com.btlup.pop`.
  **Decision needed from the user: the real App Store/Play identity.** Then rebase the archive branch onto `main`.
- 1 analyzer error (untouched Flutter template test `MyApp`), effectively no tests, no secrets found, payments via its own edge functions (`create-checkout-session`,
  `create-payment-intent`, `stripe-webhook`, `stripe-webhook-updated`, `verify-checkout-session`, `generate-wallet-pass`) on the legacy tables. No iOS privacy manifest.
- Moving it onto `site_*` is the largest remaining job (a booking made in this app does not appear on the website's owner screens today).

## Monorepo

Branch `chore/audit-and-staging` (`594ecdd`, pushed, not merged to `main`): audit SQL (01, 02, 03 preflight), staging runbook, this file. Recorded submodule pointers:
website `b765da8` (bumped), vendor `1e7cb72` and user `242b05f` (deliberately not bumped: their feature branches are unmerged). `git status` shows vendor/user as modified because
they are checked out on feature branches; do not commit those pointers until their branches merge.

## The client documents and the tracker

- Alignment analysis (read-only, 2026-10-06): `/Users/abdulrazak/.claude/plans/users-abdulrazak-downloads-bottlesup-ph-peaceful-stardust.md`: 27 Phase 2 sections: 4 aligned, 14 partial, 9 not started; 23 demo scenarios.
- Shareable tracker (a Claude Docs doc, edit only through the Docs connector, tool `mcp__1a59c906-...`): https://claude.ai/code/artifact/6c0d2d03-3496-4477-8002-ab17577c2c64 . Tabs: main report,
  **Progress since 6 Oct** (website state; not yet updated for the vendor-app work), Section tracker. Update it when a section's status changes.
- Not started anywhere: organizer events and venue agreements, chat and notifications, nightly PDF reports, complimentary/VIP, service requests, sales source, organizer payouts.
- **Open client decisions** (block parts of the build): cashier role vs manager as reviewer; Stripe in-person and devices; whether Phase 2 executes organizer payouts or only records them;
  POS providers; final fee rates and who bears them; default timer durations; whether existing partner accounts migrate.

## ROADMAP: everything pending, in order (14 Oct)

Legend: **You** = needs the user (access, accounts, decisions); **Me** = Claude can do it once its input exists. A step waits on the steps named after "needs". Update this as steps complete.

### Phase 1: ship the two client fixes (website)
1. **You:** confirm which of the first seven website migrations are live: run `supabase/audit/04_postflight_website_migrations.sql`. If any are missing, apply them first (runbook `supabase/go-live/README.md`, sections 1-5). *(State unknown; the client is already using the onboarding pages, so some are applied.)*
2. **You** (needs 1): apply `20261012100000_cancel_business.sql`, then `20261013100000_organizer_events.sql` in the SQL editor.
3. **You** (needs 2): run `supabase/audit/05_check_client_feedback_fixes.sql` and send me the result; its first row must say OK.
4. **You** (needs 2): merge website PR [#2](https://github.com/KDR9MGR/bottles-up-website/pull/2), then [#3](https://github.com/KDR9MGR/bottles-up-website/pull/3) (CI is green on both). Merging redeploys the site.
5. **You** (needs 4): smoke test as the client would (cancel the "Eonics Lounge" business; create an event as an organizer) and reply to them. Tell them events stay private drafts until BottlesUp publishes them.

### Phase 2: a safe place to test
6. **You:** decide on a staging Supabase project and create it if yes (nothing in the vendor app has ever run against a real database).
7. **Me** (needs 6): replay all migrations on staging first (rehearsal), and write a short "point the app at staging" note (`--dart-define=SUPABASE_URL=... SUPABASE_ANON_KEY=...`).

### Phase 3: merge the vendor app
8. **You or Me:** merge the ten vendor PRs in order (links in the vendor section above). The repo has no CI.
9. **Me** (needs 8): re-run all tests on `main`, then update the monorepo's submodule pointer for the vendor app (kept unbumped while branches are unmerged).

### Phase 4: release plumbing (needs 8; items are independent)
10. **You:** Android keystore and `android/key.properties` (the release build refuses to run without it, on purpose).
11. **You:** Apple signing identity, and register App ID `com.bottlesup.vendor` (team `4T453RG45S`).
12. **You or the client:** the real privacy-policy text (the in-app screen is placeholder boilerplate) and the store listing.
13. **You:** choose a crash-reporting service (suggested: Sentry). 14. **Me** (needs 13): wire it up (none exists today).
15. **Me:** add the iOS privacy manifest `PrivacyInfo.xcprivacy` for the Runner target (only the pods have one).
16. **Me:** add CI to the vendor repo (tests + analyze on every PR).
17. **Me** (if wanted): deep/universal links so an invitation link opens the app (Android app links, iOS associated domains, the website's verification file). Today it opens the website page.

### Phase 5: real-device pass and release (needs 2-3, plus 10/11 for iOS)
18. **You, with Me fixing:** test on real phones against staging or production: the door camera on a real ticket; the photo picker and upload (incl. an iPhone HEIC photo); invite by email through to accepting; poor connectivity.
19. **Me** (needs 18): fix what it finds.
20. **You:** TestFlight and Play internal testing with the client, then store submission. **First realistic release: owner setup + team + door + manager Floor + organizer drafts.**

### Phase 6: money and table service (can start now, in parallel with phases 1-5)
21. **You:** run `supabase db pull` against production so its own functions and columns are committed to the website repo. Biggest blocker for the server screens, bottle orders and payment evidence.
22. **Client decisions:** cashier role vs manager as reviewer; Stripe in-person and devices; whether Phase 2 executes organizer payouts or only records them; POS providers; final fees and who bears them; default timers (holds, invitations, reminders, escalation); whether existing partner accounts migrate; whether a verified organizer may publish its own events; who sets up ticket tiers.
23. **Me** (needs 21), in this order: server dashboard (My Tables / Orders / Scan / Requests) -> bottle orders and delivery states -> payment evidence and the verifier queue -> manager Tonight and Orders -> walk-ins and service requests -> door sales / VIP / overrides -> owner Money and Reports.
24. **Me** (needs the matching decisions in 22): organizer ticket tiers, venue linking and agreements, settlement and payouts; refunds; close night with PDF reports; chat and push notifications; inventory, promo codes, complimentary bottles, venue VIP list; security and verifier workspaces.

### Smaller items, any time (Me)
25. Shift creation in Team, change a member's role or window, claim an existing venue, the venue gallery.
26. Decide with the user whether to archive the classic vendor dashboard + old scanner (legacy tables) or move them onto `site_*`.
27. Clean up the 156 old analyzer issues (14 warnings); accessibility and offline / error-state pass.
28. User app (`bottles-up-user`): after the bundle-ID decision (`com.btlup.pop` / `com.bottlesUpUser` / `com.bottlesupuser`), rebase the archive branch onto `main`, fix the template test, then move it onto `site_*`.
29. Refresh the shareable tracker doc with the recent work; keep this file current after each step.

**Critical path to a first release:** 1-5 (client fixes live), then 6, 8, 10-16, 18-20. Phase 6 runs alongside and decides how soon the full product exists.

## Phase 6 step 23 in progress (14 Oct): server dashboard, bottle orders, payments, Tonight

The user ran `supabase/audit/06_server_desk_definitions.sql` on production (14 Oct) and sent the result, which unblocked the money side. Findings that shaped the build
(and that the user should know about; none was changed in production):

- Production's staff functions (`record_club_payment`, `update_bottle_service_status`, `list_my_*`, `manager_verify_club_payment`, ...) authorize through the global
  `door_staff` / `cms_admins` tables. An invited `server`, `verifier` or club `manager` (a `site_memberships` role) is in neither, so they are refused.
- They also: let **any** `door_staff` row record a payment for **any** club's booking (no venue check; `door_staff.can_record_payments` is never read); show a door-staff row with
  no event assigned **every club's** tables, bottle orders and alerts (`v_venue_id is null or ...`); never look at `door_staff.access_start_at/access_end_at`
  (`is_door_staff()` is just "a row exists", so an expired temporary staff member is still authorized unless something else deletes the row); let the person who recorded a payment verify it
  and a second verification overwrite the first; and the `club-payment-receipts` bucket lets any door staff / CMS admin read any club's receipts.
- **To check, not confirmed (run `supabase/audit/07_check_access_findings.sql`, read only, counts only, and send the grid):** `profiles` has an UPDATE policy `auth.uid() = id` with no WITH CHECK and `authenticated` holds UPDATE on the whole table, and the policy
  "profiles: admin full access" is `is_admin()`. If `is_admin()` reads `profiles.is_admin` or `role`, any signed-in user can make themselves admin of the legacy tables. The definition of
  `is_admin()` was not in the report: run `select pg_get_functiondef('public.is_admin()'::regprocedure)`. Same shape on `event_table_bookings` (a customer can update their own booking's
  `status`/`payment_status`), and any signed-in user can overwrite any object in the `bottles` bucket.
- Fresh databases do not have the money tables/columns (`site_table_booking_club_payments`, `amount_paid_cents`, `service_status`, ...): they exist only in production. The new migrations stop with
  a message naming what is missing (answer: `supabase db pull`); the DB tests build the minimum shape from `tests/db/prod_shapes/` right before the migration that needs it.

**Website** branch `feat/server-desk-foundation` (stacked on `feat/organizer-create-event`, **no PR opened yet**): `df421e8`, `f65752d`, and `3a69a51` (new):
`20261014120000_desk_orders.sql` (who stands where towards a booking, a night's orders, one table's orders, moving an order) and `20261014130000_desk_payments.sql`
(a table's money, recording a payment with receipt evidence, the verifier's queue and verifying, per-table status, Tonight's numbers, receipt storage policies). DB tests `140`, `150`, four new races in `concurrency.sh`,
1498 assertions; `tests/db/tools/mutate_migrations.py`: 137 of 140 mutants killed (3 equivalent/defensive). Docs: `ACCOUNT_ONBOARDING.md` (new section), `tests/README.md`.

**Vendor** branch `feat/server-desk` (stacked on `feat/photos-tables-bottles-events`, **no PR opened yet**): My Tables/Requests/assignment (`dd629cc`) plus the table service (uncommitted until the mutation check below finishes):
server and manager **Orders**, a table's page (money, orders, payments), **Record a payment** with the receipt photo, verifier **Review**, manager **Tonight**, "next action" on each server card,
"Orders and payments" on the Floor. 1033+ tests, analyzer at 156 (the old baseline). See `apps/bottles-up-vendor/CLAUDE.md` "Table service".

- **Not run against a real database or a real phone.** Try the camera + private-bucket upload on a real phone, and apply the migrations on staging first.
- **Apply order if/when going live:** the earlier website migrations, then `20261014100000`, `110000`, `120000`, `130000`. The last two need the production tables above.
- **Client decisions still blocking parts of step 23/24:** brief states "Submitted > Accepted > Preparing > On the way > Delivered" vs the database's five (`awaiting_prep`, `preparing`, `ready`,
  `picked_up`, `served`; no "accepted", an extra "ready"); partial delivery needs a delivered quantity column; how long an order may wait before it "needs attention"; cashier role vs manager as reviewer;
  flagging a payment and settling a dispute; cash handover between server and cashier; individual tables (assignment is per booking).
- **Not built:** flag/resolve a payment, cash handover, corrections and refunds, partial delivery, a service estimate and "mark seated" (server Scan), manager checklist to prepare/close the night, slow-order and low-stock alerts, owner Money and Reports, walk-ins, door sales/VIP/overrides.

## Waiting on the user

1. Execute (or confirm you have executed) `supabase/go-live/README.md`, then run the postflight and send the result. 2. Decide whether a staging project is still wanted. 3. Merge the vendor PRs in order (open them first) and the monorepo branch if wanted.
4. User-app bundle ID. 5. Android keystore, Apple signing, privacy-policy text. 6. Apply migrations (staging first once it exists), deploy `send-team-invitation`, set the flag.
7. Run `supabase/audit/07_check_access_findings.sql` in the SQL editor and send the grid (whether any signed-in user can make themselves an admin of the legacy tables; how many staff rows see every club or have an expired window).

## Next steps for Claude, in order

0. After the detour: the two website PRs are green; merge #2 then #3 (user), apply migrations 8 and 9 (user), fix whatever the user reports from applying migrations 8 and 9, and decide with the client whether verified organizers may publish, plus ticket tiers for organizer events (brief section 7). Then resume the vendor app at item 1 below.
1. Open PRs for the five vendor branches (stacked; describe the order) if the user wants them; update the tracker doc's "Progress since 6 Oct" tab with the vendor-app work.
2. Vendor owner editors still missing: the venue gallery, placing tables on a floor plan (website CMS only), claiming an existing venue. Tables, bottles and times are done (branch `feat/owner-setup-editors`); the rule port is `lib/features/owner/logic/setup_forms.dart`.
3. (done: owner/manager Team tab on `feat/owner-team`; organizer Home/Events on `feat/organizer-events`.) Next vendor options: shift creation, deep links for invitations, release plumbing (see the readiness section), door staff for an organizer's events, the organizer's ticket tiers once the client decides (brief section 7).
4. After the user answers the preflight: fix anything it finds (a name collision, a differing live function).
5. (done 14 Oct: bottle orders, payments, verifier queue, Tonight. Left in step 23: walk-ins, door sales/VIP/overrides, owner Money and Reports; they need client decisions in step 22 for some parts.)
6. User app: after the bundle-ID decision, rebase, fix the template test, then begin moving bookings/payments onto `site_*`.

## Where things are

- Website tests: `tests/README.md`; DB suite `tests/db/run.sh` (needs a scratch Postgres, recipe in memory `local-db-tests-postgres`); unit `npm test`; `npm run typecheck`, `npm run lint:ci`, `npm run build`.
- Vendor/user: `flutter pub get` then `flutter test`, `flutter analyze` (pub get needs network; `--offline` fails on a clean cache).
- Website rollout and rules: `apps/bottles-up-website-main/ACCOUNT_ONBOARDING.md`. Vendor architecture: `apps/bottles-up-vendor/CLAUDE.md`. Staging runbook: `supabase/staging/README.md`.
- Memory (one profile only): `/Users/abdulrazak/.claude/projects/-Users-abdulrazak-Documents-bottlesup-monorepo-main/memory/`. This file is the portable copy of what matters.

## Session log (newest first)

- 2026-10-13: website CI re-run: both PRs (#2, #3) are green, including the database job on Postgres 17. Still to do (user): merge #2 then #3, apply migrations 8 and 9, run `supabase/audit/05_check_client_feedback_fixes.sql`, redeploy.
- 2026-10-14 (latest): ten stacked vendor PRs opened ([#1](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/1) .. [#10](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/10)); the full ROADMAP (phases 1-6, steps 1-29) added to this file.
- 2026-10-14 (later): **photos for tables, bottles and event covers** built and pushed as `feat/photos-tables-bottles-events` `d467087` (22 more tests; 42 mutants, all caught; a new test that failed on clean code was caught by re-running the baseline).
- 2026-10-14: **venue profile + floor plans + photo upload** built and pushed as `feat/owner-profile-floors` `9f44763` (65 new tests; mutation results redone after a killed run left a stray line the residue check could not see; remaining survivors are two defensive duplicates).
  Lesson: a mutation run killed mid-way can leave a *superset* edit that a "does the original text still exist" check cannot detect; always re-run the unmutated baseline before trusting results, and run mutants in foreground chunks with a process-group timeout.
- 2026-10-10 (latest): organizer **Home/Events** screens built, tested (69 new tests; 69 mutants, real survivors fixed) and pushed as `feat/organizer-events` `d85d03f`; vendor CLAUDE.md updated.
- 2026-10-10 (later): back on the vendor app: owner/manager **Team** tab built, tested (89 new tests; 92 mutants, real survivors fixed) and pushed as `feat/owner-team` `bc6c5ad`; vendor CLAUDE.md updated.
- 2026-10-10 (detour): client reported two website problems; fixed on `fix/leave-onboarding-and-cancel-business` and `feat/organizer-create-event` (see the DETOUR section); runbook 1b and `supabase/audit/05_check_client_feedback_fixes.sql` added.
- 2026-10-10: vendor owner setup editors (tables, bottle menu, booking times) built, tested (100 new tests incl. drift guards against the website migration; 125 mutants, all real survivors fixed), looked at on a throwaway web build, pushed as `feat/owner-setup-editors` `34e1dd1`; vendor CLAUDE.md updated.
- 2026-10-09 (later): merged the other session's go-live commit `b4ea58d` into this branch; corrected this file (check-in fix must not be applied; verify-code fix does).
- 2026-10-09: vendor app moved onto website functions: door scanner, manager Floor, owner Home/Venues (branches above); user/vendor readiness assessed; HANDOFF.md created.
- 2026-10-07: website branches merged via PR #1 (the user clicked merge); merged branches deleted; monorepo pointer bumped; preflight SQL written; production read and `gh pr merge` blocked by the harness.
- 2026-10-06/07: website onboarding, workspaces, team, door scanner, venue setup, booking link, owner bookings built and tested; scanner fixes written; tracker doc created.
