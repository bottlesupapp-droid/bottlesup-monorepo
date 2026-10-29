# Vendor app (BottlesUp Business): what is left for 100% (audit of 30 Oct 2026)

Written by Claude on the user's "lets audit what all is left for vendor app for 100%". **Read-only: nothing was built, merged, applied or deployed, production was not touched.**

**What "100%" means here.** The client's own test, from the Phase 2 brief of 2 Oct (`docs/BottlesUp_Phase_2_Vendor_App_Developer_Brief.docx`, 31 sections), last line: *Phase 2 is complete when the agreed modules work together from venue setup through live operations, financial review and automatic role-specific reports, not only when the individual screens exist.* Its measure is the 23 completion scenarios of section 31. The 15 Oct brief (35 sections, the PDF is not in the repo; its section-by-section reading is `docs/BRIEF_15OCT_GAP_ANALYSIS.md`) adds the 15-step acceptance demonstration (`docs/FINAL_STEPS.md` section 5). Both are used below.

**How I checked.** I read `HANDOFF.md`, `docs/FINAL_STEPS.md`, `docs/STATUS_AND_REMAINING_WORK.md`, the gap analysis and the vendor `CLAUDE.md`, then checked their biggest claims against the code and GitHub: pull requests, CI, the More menu, the section-to-screen map, searches for each feature of the brief, the agreement terms, and the website's table checkout. Where the older notes were out of date I say so.

**Not verified.** I did not run the app, the tests or the analyzer myself (CI did, below). I did not read production today: "live in production" statements come from `HANDOFF.md` (24 Oct, 29 Oct). Nothing in this app has ever run on a real phone or against a real acceptance run, so **no scenario below is "Passed"**; the best status is "Ready to test".

## 1. Where it stands

| Fact | Evidence (30 Oct) |
|---|---|
| The third batch (floor and tables, refunds, discounts and free bottles, payouts, door sales, Accepted stage, privacy manifest, delete account) is **not on `main`** | Vendor pull request [#26](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/26) is open, mergeable, and its CI check `analyze-and-test` passed on the head commit `78f6b47`. `origin/main` (`30dc0eb`) is 17 commits behind it. Website side is merged (PR #15). |
| Store builds | Only 1.3.0 (build 8) exists, made 19 Oct; the notes say it was never uploaded (I cannot see the stores), and it does not contain batch 3. 1.3.1+9 / next 1.4.0 is not built (builds only on the user's say-so). |
| Every tab of every role has a screen | Yes (`workspace_section_screen.dart`). |
| More menu entries with no page | **Four** show "Not available yet" in the app: Complimentary bottles (owner, manager), Promo codes (door), Settlement and Notifications (organizer). |
| Website database CI | `main` is **red** since 22 Oct (last run 29 Oct): job "Migrations replay and database tests" fails, "Types, lint, unit tests, build" passes. This is the safety net for the database all three apps share. |

## 2. The client's 23 completion scenarios (section 31): my reading

**13 ready to test, 7 partly built, 3 not built, 0 passed** (updated 30 Oct evening: scenario 6 moved up because both of its fixes are built, but only once website PRs #17 and #19 are merged and applied).

| # | Scenario | Status | Why |
|---|---|---|---|
| 1 | Owner adds two clubs | Partly | Add venue, separate setup/staff/stock, Home across venues, date filter: built. No consolidated multi-venue report or PDF. |
| 2 | Manager sees the assigned club only | Ready to test | Enforced in the database, tested. |
| 3 | Temporary staff invite expires or is revoked | Partly | Access window and revoke built, actions stay attributable. Not built: individual secure expiring link with identity check, and "request renewed access" on an expired link. |
| 4 | Organizer links a venue | Partly | Agreement built well: every section-8 term, versions, both sides accept the same version, sample calculation, "above the threshold" vs "all sales once reached". Missing: the "Your Venue Access" panel and per-event data grants. |
| 5 | Upfront charge alternatives | Partly | Reservation fee, credit toward minimum, admission, recipient, split: built. The explicit "combination" and per-event table rules are not. |
| 6 | Two users book the same table | Ready to test (after website #17 and #19 are merged and applied) | Staff walk-in and desk always locked the table type. The online checkout now does too (#17, race-tested). A payment that lands after its 10-minute hold is flagged for the manager and gets no confirmation (#19 + the vendor screen). Not run against a real database or a phone. |
| 7 | Prepaid order scanned | Ready to test | Payment and service kept independent. |
| 8 | Pay-at-venue order | Ready to test | Evidence, amount remaining, review state. |
| 9 | Cash table and handover | Ready to test | |
| 10 | Bottle with discount and sign | Partly | Discounts built. **Bottle signs: no code at all.** |
| 11 | Partial bottle delivery | Ready to test | |
| 12 | Duplicate payment callback | Ready to test | Idempotent, tested on the website side. |
| 13 | Complimentary location link | **Not built** | Free bottle at a table works; the claim link, map and customer claim page do not exist. |
| 14 | VIP at the door | Ready to test | |
| 15 | Booth guest pass reused | Ready to test | Per-guest passes and group admission with remaining allowance. |
| 16 | Door cash or card sale | Ready to test | Cash and the club's own card machine; one sale, one admission. No integrated card. |
| 17 | Private-room conflicts | **Not built** | No private-room concept in the app. |
| 18 | POS / upload overlap | **Not built** | No sales-source setting at all. |
| 19 | Overnight event | Ready to test | After-midnight logic, per-venue time zone, business night in reports. |
| 20 | Chat expires | Ready to test | Hourly purge is scheduled in production, first run confirmed 29 Oct. |
| 21 | Close with exceptions | Ready to test | Preliminary and final report. |
| 22 | Role-specific PDFs | Partly | Owner and manager reports exist. No organizer PDF, no automatic e-mail to recipients. |
| 23 | Refund after settlement | Partly | Refunds keep the original record. Settlement (and so a settlement adjustment) is not built. |

## 3. The 28 feature sections (2 to 29): my reading

**Built 5, partly built 20, not built 3.** "Built" means the section's described flow exists and is tested with fakes, not that it works on a phone.

- **Built:** 3 Permissions, 5 Owner dashboard, 11 Bookings and guest details, 13 Server dashboard and check-in, 21 Venue VIP list.
- **Not built:** 19 Internal promo codes (staff-applied; the limits-based discounts are a different, built mechanism), 24 Sales-source configuration, 25 Organizer share and payout recording (what exists is BottlesUp's payouts to venues, read only).
- **Partly built, with what is missing:**

| § | Section | Missing |
|---|---|---|
| 2 | Navigation and behavior | Last-sync time and a pending-actions list on screens; night/event in the context bar (it shows role, business, scope). |
| 4 | Venue-owner onboarding | Website-first by decision (16 Oct); not re-audited today. The app shows verification and setup status. |
| 6 | Manager dashboard | *Assign staff and Send alert: DONE 30 Oct (vendor #28).* Nothing else missing that was checked. |
| 7 | Organizer events | Tickets (name, price, quantity, sale window, room access, benefits), venue selection on the event, publishing, Sales and Settlement tabs. BottlesUp's team publishes today. |
| 8 | Venue linking | "Your Venue Access" panel and per-event data grants. |
| 9 | Table-payment configuration | Explicit combination purpose, per-event table rules and organizer pricing, versioned fee schedule. |
| 10 | Rooms, floor plan, availability | Private-room buyouts; availability is per table **type** (a count), not individual physical tables with their own stable IDs; late payment after a hold lapses: *flagged for the manager, DONE 30 Oct (#19).* |
| 12 | Team and shifts | Secure expiring links with identity check; request-renewal page. |
| 14 | Bottle orders | *The guest's sign from checkout is now shown to staff (website #20, vendor #28).* The rest of signs (owner marks eligible bottles, server types text per line, review) and applying a permitted code on an order are not built. |
| 15 | Payments, evidence, cash | Integrated (Stripe) payment from the app; the app records payments, it takes none. |
| 16 | Walk-in sales | Timed hold during checkout (the walk-in is booked at once); phone-tap payment. |
| 17 | Service requests | Automatic escalation after an interval (escalation is by hand, with a reason). *Assigning to a person: DONE 30 Oct (vendor branch `feat/vendor-remaining-ops`, not merged).* |
| 18 | Door | Filters (Tickets, Booth Guests, VIP, Invited, Special Guests); controlled override with reason (not found in the code); exit tracking; integrated card; ticket discounts at the door. |
| 20 | Complimentary bottles | Claim link and customer claim page. |
| 22 | Inventory | Reserved vs issued (available-to-sell vs physical), packages with components, most-sold by period. |
| 23 | Chat, security, notifications | Chat and security built. No push, no SMS, no notification preferences; guest e-mails are written but **switched off** (`process-outbox` is not scheduled). |
| 26 | Changes, refunds, exceptions | Event-cancellation payment queue; settlement adjustments. |
| 27 | Close night and PDFs | Organizer PDF, consolidated multi-venue owner PDF, automatic e-mail of the PDF, a new report version after a later correction (not checked). |
| 28 | Settings directory | Settings holds the account, the privacy list and Delete my account only: no Notification preferences, PDF recipients, Sales Tracking, Bottle Signs. |
| 29 | Shared records and sync | Live updates (none; screens refresh), stored business-night id was not checked. Idempotency and audit are done. |

## 4. What is left, in five groups

### A. Ship what is already built (your actions; nothing needs new code)
1. **Click "Merge pull request" on vendor #26** (checks passed, merges cleanly). Keep the branch.
2. **Say "build 1.4.0"** (iOS + Android from `main`; version 1.4.0 build 10). After the iOS build: `unzip -l "BottlesUp Business.ipa" | grep -i privacy` must list `PrivacyInfo.xcprivacy`; answer App Store Connect's privacy questions from `docs/DATA_COLLECTED_BUSINESS_APP.md`. Upload (Transporter, Play internal testing).
3. **The real-phone pass** (`docs/FINAL_STEPS.md` section 5, 24 rows) is the biggest unknown: door camera, photo picker and upload (including an iPhone HEIC), invitation e-mail through to accepting, poor connectivity, deleting a staff account, a Stripe test card on the website then the booking in the app.
4. Paste `supabase/go-live/test_login_roles.sql` (test login gets roles), remove the demo night afterwards (`demo_night_cleanup.sql`).
5. CMS: Payouts > Settings (BottlesUp's percentage, weekday, wait days), the support e-mail/phone/address on the Content page (Contact Support shows only what is published).
6. Invitation links: serve `/.well-known/assetlinks.json` (Android); Associated Domains and a final bundle ID (iOS). The bundle ID `com..bottlesUp.ORG` has a double dot and Apple may object (`docs/APP_LINKS_SETUP.md`).
7. Google/Apple sign-in for the vendor app: branch `feat/social-login` (1 commit past batch 3, not merged) needs the console steps in `docs/SOCIAL_LOGIN_SETUP.md` first.
8. The client's legal Terms and Privacy text (the classic Terms screen is placeholder text); a Sentry DSN if crash reporting is wanted (it is off).
9. Switch on guest e-mails when the client has read the wording (`process-outbox` schedule, README 1f step 4). Until then walk-in confirmations, refund decisions and VIP invitations stay "Queued, not sent yet".
10. Security, not from this app: `trigger_rsvp_approval_email()` in production has a bearer token and an apikey written into its body. If either is the service-role key, rotate it (HANDOFF, 23 Oct).

### B. Code I can build without waiting for the client (proposed, sizes rough: S = a screen and a function, M = a database module plus screens, L = several modules)
| Item | Brief § | Size |
|---|---|---|
| Fix the online checkout race (D1): **BUILT 30 Oct, not applied.** Still to do: reconcile a payment that lands after the hold lapsed | 10, 16, 31 #6 | M (migration + function deploy) |
| Bottle signs (owner picks eligible items, server types the text, it travels with the order, optional review) | 14, 28 | M |
| Inventory: reserved vs issued, package components, most-sold by period | 22 | M |
| Door: category filters, controlled override with reason, optional exit tracking | 18 | M |
| Service requests: assign to a person: **DONE 30 Oct** (the database already had it; app only) | 17 | S |
| Manager quick actions: Assign Staff, Send Alert | 6 | S |
| Temporary staff: individual expiring link, identity check, request-renewal page | 12 | M (the identity method needs a one-line decision) |
| Organizer: "Your Venue Access" panel, Sales tab (read only) | 7, 8 | M |
| Reports: organizer PDF, consolidated owner PDF, new version after a correction | 27 | M |
| Settings pages: notification preferences, PDF recipients (storage only until sending exists) | 28 | S each |
| Live updates and a last-sync line | 2, 29 | L |
| Event-cancellation payment queue | 26 | M |

### C. Waiting on the client (the brief's own "decisions still open" plus the 20 Oct list)
- **Stripe in-person payments, card reader, tap-to-pay** (15, 18): which integration and devices. Until then no card button that cannot transact.
- **Organizer settlement** (25): whether Phase 2 pays out. The brief says to build the records and statuses anyway; a **record-only** settlement (calculate from the agreement, Estimated to Paid with reference and evidence, labelled "recorded external payment") can start before this is answered.
- **Sales source** (24): "BottlesUp Entries" and "Closing Report Upload" need no provider; "Connected POS" needs the provider. Propose building the first two.
- **Complimentary claim link** (20): the brief describes the flow in detail; the 20 Oct list still marks "how a free bottle is claimed by someone not at a table" as open. Propose building to the brief and asking the client to confirm.
- **Ticket discounts and staff promo codes** (19): ticket discounts for organizers are an open item, and door promo codes depend on them.
- **Push and SMS providers** (23), **timers** (invitation expiry, reminders, escalation interval; the 10-minute hold is decided), **fee schedule** (final rates, who bears them), **verifier role** (separate cashier or the manager), **private-room conflict rule** (10), **Event Lead and ambassadors** (15 Oct brief), **organizer publishing and ticket tiers** (7), **what to do with the 15 classic vendor accounts**, whether existing partner accounts migrate.

### D. Problems found in this audit
1. **D1. The online table checkout is not airtight.** `supabase/functions/create-table-booking-checkout/index.ts` reads the count of taken tables, then inserts a pending booking, with no lock between the two; its own comment says "Not airtight under heavy concurrent checkouts". Two people paying for the last table in the same moment can both get through. Staff paths (walk-in, desk) lock the table type and are race-tested. Fix: do the count and the insert inside one database function that locks the table type, as the walk-in does, and reconcile a payment that is confirmed after its hold lapsed. This is a production change (migration plus function deploy): **the fix was written and tested on 30 Oct** (website branch `fix/atomic-table-checkout`: migration `20261111100000_atomic_table_checkout.sql`, 37 database assertions, a two-guests race script that fails without the lock, 29 new edge tests, all 34 SQL mutants caught, and the TypeScript mutants caught once two test gaps (promo code and discount reaching the reservation) were closed; the full database suite passes with 4,034 assertions) but it is NOT merged, applied or deployed. Still open: a payment that is confirmed after its hold has lapsed is marked paid without a capacity check, so a second paid booking is possible; that needs a rule from you (see `docs/FINAL_STEPS.md`, item 3).
2. **D2. FIXED 30 Oct (website #18, green): the website's database CI was red on `main`.** Original finding: the cause of the time-zone failure was not known; it is now: the newer time-zone data in CI makes British Columbia permanent UTC-07 from 1 Nov 2026, so the test's 3 hours became 2 (not a product bug); a second test matched random digits; see HANDOFF. Original text follows. Test `450_venue_time_zone.sql` ("8 pm in Vancouver is 3 hours later than 8 pm in Toronto": expected 3, got 2) failed in CI on 29 Oct; it passed in my local run on 29 Oct, and CI stops at the first failing file so later tests did not run. Toronto's clocks change this Sunday, 1 Nov. I have not shown whether this is only a date-dependent test or a real mistake in how the refund policy counts hours across a clock change. Worth a look before then.
3. **D3. Four "Not available yet" entries in the More menu** (Complimentary bottles, Promo codes, organizer Settlement, organizer Notifications): **DONE 30 Oct, hidden until built** (vendor #28; one constant brings them back for development).
4. **D4. The classic dashboard is still routed** for the 15 classic vendor accounts and still has about 18 "Coming Soon" messages and 8 TODOs (Delete Event, Share Event, Edit Business Details, Change Password, 2FA, Notifications...). It is not part of the workspace app. Decide: convert those accounts and archive the classic screens, or leave them.
5. **D5. Batch 3 is live in the database and functions (since 24 Oct) but not in `main`**, so anyone building the app from `main` today gets a build that lacks the screens for tables already in production. Merging #26 closes this.
6. **D6. Vendor working tree has two uncommitted generated-file changes** (`.flutter-plugins-dependencies`, `ios/Runner.xcodeproj/project.pbxproj`). I did not make them. Check before building.

### E. Housekeeping
Analyzer: 154 old issues (baseline, none in new code). Run `supabase db pull` to commit the production-only SQL (17 functions, `profiles`, `promo_codes`) and reconcile the migration history before anyone runs `supabase db push`. 43 accounts have no `profiles` row. Old `*_SUMMARY.md` files in the vendor repo root are stale; `CLAUDE.md` is accurate.

## 5. Suggested order
1. Merge #26 (your click). Then CI on `main` for the vendor repo.
2. Look at the red website CI before Sunday (D2), and decide on D1.
3. Build 1.4.0 and do the real-phone pass; fix what it finds. Nothing else gives as much certainty.
4. In parallel, group B in the order: D1 fix, bottle signs, inventory, door, then the smaller ones.
5. Send the client the group C questions in one message; build the record-only parts that do not need an answer.

Honest bottom line: the vendor app has the money and table-service core and most of the operations, but it is **not 100% of the client's brief**, and several of the missing parts are not code I can write alone (group C). The shortest honest path to something shippable is steps 1 to 3 above, which need no new features.
