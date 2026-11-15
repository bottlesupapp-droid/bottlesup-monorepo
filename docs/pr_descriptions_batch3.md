# Pull request texts for batch 3 (paste when opening the two pull requests)

Both branches are pushed (`feat/business-brief-3` in each repo, based on `main`). Open them from:

- website: https://github.com/KDR9MGR/bottles-up-website/pull/new/feat/business-brief-3
- vendor: https://github.com/KDR9MGR/bottles-up-vendor/pull/new/feat/business-brief-3

Merge the website one first. Do not delete the branches on merge.

---

## Website pull request

Title: Batch 3 of the 15 Oct brief: floor plan, order stage Accepted, refunds, staff discounts, payouts, door sales, venue time zone (seven migrations)

## What this is
The database and website side of batch 3 of the client's 15 Oct brief and the answers of 20 Oct: **seven migrations plus one guarded correction**, a few changed edge functions and three CMS pages. **The database part is already live in production** (the owner pasted the first five on their own; the last two were applied on 24 Oct with a pre-flight and a post-flight check). The edge functions were deployed on 24 Oct.

| Migration | Adds |
|---|---|
| `20261021100000_floor_plan_and_table_states` | table placement, included admissions per table, table holds and "unavailable", ONE shared count of taken tables (paid + checkouts in their 10-minute hold + blocks) used by the website picker, the walk-in and the checkout functions, move a booking to another table (with a record and `desk_booking_move_options`), deposit terms copied onto each new booking. Replaces 3 live functions, each behind a fingerprint guard. |
| `20261022100000_order_accepted_stage` | the order stage Accepted; replaces 4 live functions behind the same kind of guard. |
| `20261023100000_refund_policy_and_requests` | each venue's refund policy (up to 6 rules), refund requests (guest and staff), decide, a refund paid at the club recorded with a reference and/or a receipt photo, online refunds claimed for the Stripe function, the booking's terms, CMS views. |
| `20261028100000_refund_receipt_evidence` | a guarded correction of two functions of the one above (already live): a receipt photo must be filed under its own booking, and the refund list returns the reference and the photo. |
| `20261024100000_staff_discounts_and_complimentary` | the owner's discount limits, discounts and free bottles (within a limit at once, above it waiting for a manager, nobody approves their own), voiding, the checkout totals subtract an applied discount, CMS views. |
| `20261025100000_payout_settings_and_ledger` | payout settings, per-business overrides and accounts set in the CMS (masked account only), the estimate of what is waiting, payout items ("Paid" needs a reference), `my_payouts` (owner and organizer, read only). |
| `20261026100000_door_sales` | a door person sells a ticket (cash, or the club's own card machine with its receipt number): paid, issued with a normal ticket code and checked in once; the tier is locked while capacity is counted, so the last tickets cannot be sold twice; the same sale key twice is one sale; the door person's own shift summary. Adds five columns and one rule to `site_orders` (every existing order stays an online one). Nothing is charged or e-mailed. |
| `20261027100000_venue_time_zone` | each venue's own time zone (empty = Toronto, as every venue is read today), set by its owner or manager; the refund policy counts the hours before arrival in it. |

Edge functions changed: `create-table-booking-checkout`, `create-walkin-table-booking`, `cancel-table-booking`, `refund-table-booking-payment`, and the shared `bookingTotals` (eleven functions use it). CMS pages: Refunds, Discounts, Payouts. The refund policy is shown before payment and a guest can ask for a refund from their booking page.

## Test plan
- [x] `tests/db/run.sh`: **3,894 assertions + 7 race scripts + 7 migration-guard scripts** pass. Every new function has tests for who may call it, every refusal, and the happy path; the races cover the last tickets and the same sale arriving twice at once (checked by removing the lock and the second look: both make the script fail).
- [x] The go-live bundle was applied to a scratch database built as production is BEFORE it: pre-flight no rows, apply clean, post-flight 19 of 19, rollback complete (pre-flight no rows again), applied again.
- [x] Website unit tests 1,025 passing at the last run; no TypeScript has changed since.
- [x] Applied to production (24 Oct): the first five migrations were pasted by the owner earlier, the last two applied one at a time; post-flight `19_postflight_business_brief_3.sql` = 19 of 19 ok.
- [x] The guarded correction `20261028100000_refund_receipt_evidence` (a receipt photo must belong to its booking; the refund list returns the evidence) is applied (24 Oct); it has a guard script (`migration_guard_refund_receipt.sh`).
- [x] The changed edge functions are deployed (24 Oct); the Stripe webhook still answers without a login and refuses an unsigned request.

## Not verified
No real booking, Stripe payment or payout has been tried against it; no real Stripe refund or payout was made; nothing was run on a phone.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

---

## Vendor pull request

Title: BottlesUp Business: floor and tables, refunds, discounts and free bottles, payouts, door sales, order stage Accepted

## What this is

The BottlesUp Business app side of batch 3 of the client's 15 Oct brief. It needs the website's seven migrations `20261021100000` .. `20261027100000` (website branch `feat/business-brief-3`); where they are missing each new screen says "not set up on this server yet" or "could not be loaded" with Try again, and the rest of the app keeps working.

- **Order stage Accepted**: Submitted, Accepted, Preparing, Ready to collect, On the way, Delivered.
- **Floor and tables**: Tonight > Tables (Available / Held / Booked / Occupied / Unavailable, holds, reopen), Place tables (drag and resize on the floor picture), a booking's Terms card and Move to another table (with who, from, to and why), included admissions, deposit recipient / purpose / split.
- **Refunds and cancellation**: the venue's own refund policy, More > Refunds (approve an amount or decline; a refund paid at the club is recorded with a reference; a card refund is returned by BottlesUp, so the app never moves money), cancel a booking, ask for a refund, the walk-in terms read out the policy.
- **Discounts and free bottles**: the owner's limits, give on the table's Orders tab (applied within your own limit, waiting above it, nobody approves their own), More > Discounts and free bottles for approvals and limits.
- **Settlements and payouts**, read only: the payout account status (masked), how and when BottlesUp pays out, what is waiting, every payout with its reference.
- **Door Sales and Shift summary** (door role): sell a ticket at the door (ticket type, how many, guest name, cash or the club's card machine with its receipt number, confirm), issued and checked in once, never sold twice (a lost answer retried returns the sale already made); the door person's own night in More > Shift summary, cash and card machine apart. Nothing is charged or e-mailed from the app; approved discounts and promo codes are not part of it (ticket discounts are not built).
- **Smaller things**: the venue's time zone in the venue profile; a Tonight tile for the discounts and free bottles waiting for approval; a photo of the receipt for a refund paid back at the club; an in-app list of what the app collects; an Android app link so an invitation link can open the app (needs the website's `assetlinks.json`: `docs/APP_LINKS_SETUP.md`); Contact Support and About now show only what the BottlesUp team published in the CMS (the old ones invented a 24/7 line, a company and a fake "ticket submitted").

Details: `CLAUDE.md`, "tranche 3".

## Checked

- Complete `flutter test`: 2,705 tests passing. `flutter analyze` at its baseline of 154.
- New code has rules, service, screen, wiring and drift tests; the drift tests read the website's SQL, and the fake backends copy the database's checks and sentences.

## Not verified

Not run against a real database or on a phone. No build was made.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
