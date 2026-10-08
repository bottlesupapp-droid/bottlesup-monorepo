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

## Vendor app (`bottles-up-vendor`): five stacked branches, none merged

`main` `1e7cb72` (1 Jul) → `chore/archive-unused-features` `09f3038` → `feat/workspaces` `7ac43fe` → `feat/door-on-website-functions` `9b8dd32` →
`feat/manager-floor` `8af0d05` → `feat/owner-venues` `4ab7b3c` (all pushed; no PRs opened yet). Merge in that order.

- Built on the website's functions: workspaces (`my_workspaces`, `accept_invitation`), door **Scan + Guests** (door role only), manager **Floor** (bookings by night,
  `list_venue_bookings`), owner **Home** (tonight across venues) and **Venues** (list, add venue, per-venue Bookings / Setup / Link tabs with QR).
  Rules are Dart ports of the website's rule modules. All screens say "not set up on this server yet" until the website migrations are applied.
- Still placeholders: server screens (Scan/My Tables/Orders/Requests: prod-only functions), Door Sales, manager Tonight/Orders/Team/More, owner Money/Reports/More, organizer, security, verifier.
- Checks: 315 tests, 0 analyzer errors/warnings (142 old infos). Run once under a DST zone: `TZ=America/Toronto flutter test`. Look at screens with a throwaway
  Flutter **web** build served locally and the built-in browser (click `flt-semantics-placeholder` to enable accessibility; delete the demo file and `build/web` after).
- Release blockers (user actions): Android `key.properties`/keystore (build fails without it on purpose); Apple team `4T453RG45S` has no signing identity and both
  iPhones were offline; register App ID `com.bottlesup.vendor`; real privacy-policy text; crash reporting; no iOS privacy manifest; camera never tested on a phone.
- Reads/writes legacy tables (`events`, `clubs`, `events_bookings`, `table_bookings`...) everywhere else: the classic dashboard and the old scanner are untouched.
  `CLAUDE.md` in that repo is accurate; the many `*_SUMMARY.md` / `PRODUCTION_READY*.md` files are stale, ignore them.

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

## Waiting on the user

1. Execute (or confirm you have executed) `supabase/go-live/README.md`, then run the postflight and send the result. 2. Decide whether a staging project is still wanted. 3. Merge the vendor PRs in order (open them first) and the monorepo branch if wanted.
4. User-app bundle ID. 5. Android keystore, Apple signing, privacy-policy text. 6. Apply migrations (staging first once it exists), deploy `send-team-invitation`, set the flag.

## Next steps for Claude, in order

1. Open PRs for the five vendor branches (stacked; describe the order) if the user wants them; update the tracker doc's "Progress since 6 Oct" tab with the vendor-app work.
2. Vendor owner editors on the website's tested functions (`save_venue_floor`, `save_venue_table_type`, `save_venue_bottle`, `add_venue_time_slot`, `update_venue_profile`, and the `remove_*`/`list_*` pairs): large forms; port the website's `venueSetupForms.ts` rules.
3. Vendor team screens (`list_team`, `invite_member`, `invitable_roles` exist and are tested on the website).
4. After the user answers the preflight: fix anything it finds (a name collision, a differing live function).
5. After `supabase db pull`: bottle orders, collected money, server/table-service screens (website and vendor).
6. User app: after the bundle-ID decision, rebase, fix the template test, then begin moving bookings/payments onto `site_*`.

## Where things are

- Website tests: `tests/README.md`; DB suite `tests/db/run.sh` (needs a scratch Postgres, recipe in memory `local-db-tests-postgres`); unit `npm test`; `npm run typecheck`, `npm run lint:ci`, `npm run build`.
- Vendor/user: `flutter pub get` then `flutter test`, `flutter analyze` (pub get needs network; `--offline` fails on a clean cache).
- Website rollout and rules: `apps/bottles-up-website-main/ACCOUNT_ONBOARDING.md`. Vendor architecture: `apps/bottles-up-vendor/CLAUDE.md`. Staging runbook: `supabase/staging/README.md`.
- Memory (one profile only): `/Users/abdulrazak/.claude/projects/-Users-abdulrazak-Documents-bottlesup-monorepo-main/memory/`. This file is the portable copy of what matters.

## Session log (newest first)

- 2026-10-09 (later): merged the other session's go-live commit `b4ea58d` into this branch; corrected this file (check-in fix must not be applied; verify-code fix does).
- 2026-10-09: vendor app moved onto website functions: door scanner, manager Floor, owner Home/Venues (branches above); user/vendor readiness assessed; HANDOFF.md created.
- 2026-10-07: website branches merged via PR #1 (the user clicked merge); merged branches deleted; monorepo pointer bumped; preflight SQL written; production read and `gh pr merge` blocked by the harness.
- 2026-10-06/07: website onboarding, workspaces, team, door scanner, venue setup, booking link, owner bookings built and tested; scanner fixes written; tracker doc created.
