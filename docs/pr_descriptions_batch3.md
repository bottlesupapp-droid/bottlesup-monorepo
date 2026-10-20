# Pull request texts for batch 3 (paste when opening the two pull requests)

Both branches are pushed (`feat/business-brief-3` in each repo, based on `main`). Open them from:

- website: https://github.com/KDR9MGR/bottles-up-website/pull/new/feat/business-brief-3
- vendor: https://github.com/KDR9MGR/bottles-up-vendor/pull/new/feat/business-brief-3

Merge the website one first. Do not delete the branches on merge.

---

## Website pull request

Title: Batch 3 of the 15 Oct brief: floor plan, order stage Accepted, refunds, staff discounts, payouts (five migrations)

## What this is
The database side of the remaining Phase 2 vendor-app modules: **11 new migrations**, all additive (new tables and functions only; nothing existing is altered). **None are applied to production yet** (that needs the owner's go-ahead). Stacked on #5.

| Migration | Adds |
|---|---|
| `20261018100000_cash_handover_and_flags` | cash held / hand in / count with shortages kept; flag a payment, manager resolves; a correction replaces the payment it corrects |
| `20261018110000_seating_and_outbox` | seat a guest once, estimate, undo; `site_outbox` (messages only queued) |
| `20261018120000_chat` | club / event / direct chats, unread, rate limit, pin, event chats expire 7 days after the event |
| `20261018130000_security` | alerts, tasks, retained incident reports; no finance access |
| `20261018140000_close_night_and_reports` | checklist, close with exceptions, owner-only reopen, preliminary / final report by role |
| `20261018150000_inventory_ledger` | stock movements with before/after, double-tap-safe, low-stock levels |
| `20261018160000_vip_guests` | VIP members, perks with limits, role-filtered lookup, redemptions |
| `20261018170000_change_member_role` | change a club role in one step |
| `20261018180000_event_agreements` | venue/organizer agreements: versioned terms, both sides accept the same latest version |
| `20261018190000_organizer_guests` | read-only ticket buyers + check-in counts for the event's own business |
| `20261018200000_owner_money` | per-club totals for a range of nights, owner only |

Also `supabase/go-live/rollback_phase2_modules.sql` (in the monorepo): drops exactly the 83 functions and 22 tables these add; checked on a scratch copy, and the migrations re-apply cleanly afterwards.

## Test plan
- [x] `tests/db/run.sh`: **2337 assertions + 14 concurrency races** pass (a double tap / two people at once is one result for: cash hand-in, seating, alert taking, closing a night, stock receipts, once-a-night VIP perks, ticket scans, payments).
- [x] Each migration applies on a scratch Postgres 15 with the production-only table shapes.
- [ ] Before applying to production: confirm that production's `correct_club_payment` makes a correction REPLACE the payment it corrects (the cash, report and money figures assume it).
- [ ] Apply one migration per transaction, in order, and check the objects exist (the `apply_one.sh` method used on 16 Oct).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

---

## Vendor pull request

Title: BottlesUp Business: floor and tables, refunds, discounts and free bottles, payouts, order stage Accepted

## What this is

The BottlesUp Business app side of batch 3 of the client's 15 Oct brief. It needs the website's five migrations `20261021100000` .. `20261025100000` (website branch `feat/business-brief-3`); where they are missing each new screen says "not set up on this server yet" or "could not be loaded" with Try again, and the rest of the app keeps working.

- **Order stage Accepted**: Submitted, Accepted, Preparing, Ready to collect, On the way, Delivered.
- **Floor and tables**: Tonight > Tables (Available / Held / Booked / Occupied / Unavailable, holds, reopen), Place tables (drag and resize on the floor picture), a booking's Terms card and Move to another table (with who, from, to and why), included admissions, deposit recipient / purpose / split.
- **Refunds and cancellation**: the venue's own refund policy, More > Refunds (approve an amount or decline; a refund paid at the club is recorded with a reference; a card refund is returned by BottlesUp, so the app never moves money), cancel a booking, ask for a refund, the walk-in terms read out the policy.
- **Discounts and free bottles**: the owner's limits, give on the table's Orders tab (applied within your own limit, waiting above it, nobody approves their own), More > Discounts and free bottles for approvals and limits.
- **Settlements and payouts**, read only: the payout account status (masked), how and when BottlesUp pays out, what is waiting, every payout with its reference.

Details: `CLAUDE.md`, "tranche 3".

## Checked

- Complete `flutter test`: 2,544 tests passing. `flutter analyze` at its baseline of 154.
- New code has rules, service, screen, wiring and drift tests; the drift tests read the website's SQL, and the fake backends copy the database's checks and sentences.

## Not verified

Not run against a real database or on a phone. No build was made.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
