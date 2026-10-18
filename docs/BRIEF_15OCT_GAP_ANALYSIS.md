# BottlesUp Business: gap analysis of the 15 Oct developer brief against the vendor app (19 Oct 2026)

Source: `BottlesUp_Business_Full_Plan_and_App_Fixes.pdf` (14 pages, 35 sections, dated 15 Oct 2026; it replaces the earlier brief whose section numbers the first
Phase 2 migrations quote). Checked against the code on vendor `feat/ops-modules` + PR #19, and website `feat/vendor-ops-modules` + PRs #7, #8.
Status words follow the brief's own (section 34): **Not built / In progress / Ready to test / Passed**. Nothing is "Passed": no real-device or real-database
acceptance run (section 35) has happened, so the best any module can be is **Ready to test**. "Needs decision" is an item the brief itself lists as unsettled
(section 34, last paragraph) or that needs a business rule the brief does not give.

## What is new in this brief
Rename to **BottlesUp Business**; a seventh role, **Event Lead**, and the **ambassador program** (sections 28); owner bottom navigation changed (Overview, Venues,
**Tonight**, Reports, More); **organizer-provided door staff** (25); **deposit and bottle payment configuration** (15); **direct deposit / payouts** (20); **earnings and
settlements** (31); **public organizer profiles** (30); explicit **interface states** and a **15-step acceptance demonstration** (33, 35); and a **failed workspace request must
not look like a new account** (3).

## Section by section

| § | Topic | Status | Evidence / what is missing |
|---|---|---|---|
| 1 | Rename to BottlesUp Business | **Ready to test** (vendor PR #20, website PR #9) | Phone labels, titles, About, Terms, Help, web page, staff invitation e-mails; guard test. Left: the legal wording of Terms/Privacy still uses "Vendor" as a defined term (client's lawyer). |
| 2 | Remove / replace current elements | In progress | Done for workspace users: role-specific workspaces, invite-only roles (vendors role guard), organizer without a venue (agreements: ask a club to host). Left: the classic dashboard (15 classic accounts) still has the long Create Club form, Min/Max Price, raw errors, unexplained metrics; gradients and spacing, safe areas and keyboard handling need a device look. |
| 3 | Website/app connection | **Ready to test** (vendor PR #20) | One Supabase project, shared accounts and records. A failed workspace request now shows "We could not load your workspace" with Retry (never the setup screen); the reason goes to the log. |
| 4 | App-opening flow | In progress | One workspace opens; several show the selector with the **last choice remembered** ("Last used", PR #20). Still missing: "incomplete setup / awaiting verification / pending invitation / awaiting assignment" screens (they need the verification and setup status from the website tables); top bar shows role, business, scope, access end (no night/event). |
| 5 | Three onboarding routes | Partly by design | Accounts and business onboarding are on the website (decided 16 Oct); invited staff accept in the app. Resume of saved setup and verification status are not shown in the app. |
| 6 | Role navigation | In progress | Owner (Overview/Venues/Tonight/Reports/More), Organizer, Door (More added), Security (More) now match; Manager and Server already did (PR #20). **Event Lead** role does not exist (no database role; program rules first). |
| 7 | Owner overview | In progress | Tonight across venues from bookings. Missing: stock issues, staff alerts, settlements and payouts, date filter, sales vs collections split beyond bookings. |
| 8 | Manager Tonight | Ready to test | Needs-attention queue, floor, orders, payments to check, close night. Missing: Add Walk-In, Message Team shortcut. |
| 9 | Organizer overview | In progress | Events and guests read-only. Missing: sales, deposit allocation, commissions, earnings, settlements; Share Event, Invite Team, Public Profile actions. |
| 10 | Event creation | In progress | Draft create/edit/remove with cover photo (organizer cannot publish). Missing: venue selection, tickets and VIP, tables, team, preview, publish, the statuses (Awaiting Venue Approval, Ready to Publish, Live, Ended, Cancelled). |
| 11 | Venue connection and agreement | Ready to test | Request, versioned terms, accept by both sides, sample calculation. Missing terms to add: deposit rules/recipient, organizer door staff yes/no, collection responsibilities; accepted-version history is stored. |
| 12 | Tickets, VIP and room access | Not built (app) | Ticket tiers are made in the website CMS; no app screens; no group admission allowance; no room capacity sharing. |
| 13 | Floor plans and tables | In progress | Tables and floors editors (name, capacity, min spend, deposit). Missing: map position by owner (BottlesUp team does it), included admissions, statuses Held/Occupied/Unavailable, timed checkout holds, moving a booking with a record of who moved it. |
| 14 | Booking details | In progress | Table page: money, orders, payments. Missing tabs Guests and Activity, guest allowance, payment terms shown as accepted. |
| 15 | Deposit and bottle configuration | **Not built (app)** | Database has `bottle_payment_mode` and `deposit_is_credit` on `site_venues`; the app has no screen for either, no deposit recipient or purpose, no "venue / approved organizer / split". Website checkout reads them. |
| 16 | Server workflow | In progress | Orders with the five stages, deliver, record payment. Missing: Accept stage, add bottles, apply codes, sign text, ETA, partial delivery, multiple tables as one shift. |
| 17 | Walk-in table booking | Not built (app) | Website edge function `create-walkin-table-booking` exists; no app flow, no timed hold. |
| 18 | Customer requests | Ready to test | Open, acknowledge, complete, escalate. Missing: assign. |
| 19 | Collect payment and evidence | Ready to test | Record payment, receipt photo, verifier queue, cash handover and discrepancies, corrections keep history. |
| 20 | Direct deposit / payouts | **Needs decision** | Brief says confirm payout structure and timing first (section 34 lists it). Nothing built. |
| 21 | Discounts and complimentary | **Needs decision** | Stacking, approval, claim rules not given. Shown as "Not available yet". |
| 22 | VIP guests | Ready to test | List, tiers, perks, invite (queued; e-mail sender built, not live), door lookup (PR #19). |
| 23 | Inventory | Ready to test | Receive, wastage, adjust, count, low stock. Missing: reserved vs issued, package components, best sellers. |
| 24 | Staff invitations | Ready to test | Invite, resend, revoke, shift, change role. |
| 25 | Organizer-provided door staff | Not built | Needs the agreement setting (11) and an organizer Team screen. |
| 26 | Door operations | In progress | Scan, manual admit, entry code, duplicate refusal. Missing: group admission with remaining allowance, Door Sales (needs payment decision), shift summary, promo codes. |
| 27 | Security workspace | Ready to test | Alerts, tasks, chat, incidents. |
| 28 | Ambassadors and Event Lead | Not built | New role, program rules, commissions, earnings states, customer-app Ambassador Hub. Needs the rules in section 34 (commission windows) first. |
| 29 | Chat and notifications | In progress | Chat built (event chats purge after 7 days; scheduling is in website PR #8). Notifications: e-mail sender built, not live; push/SMS and preferences not built; deep links not built. |
| 30 | Public organizer profiles, booking links | In progress | Venue booking link, slug, QR, preview built. Organizer public profile is website work. |
| 31 | Earnings and settlements | Not built | Depends on 15, 20, 28. |
| 32 | End-of-night PDF | Ready to test | Preliminary and final by role. Missing: ambassador, expenses, earnings, who-owes-whom; multi-venue owner report. |
| 33 | Interface states | In progress | Workspace screens, and now the classic screens: ~45 raw `$e` messages and the analytics query errors are plain sentences with Retry and a logged reason; a guard test fails on any new one (PR #20). Still to do: "connection lost / pending sync" banner, "permission removed" explanation on every screen, saved-record confirmations. The analytics relationship error's cause (legacy tables) needs a look at the production schema. |
| 34 | Development order | | Followed below. |
| 35 | Acceptance demonstration | Not run | Needs a shared test venue, organizer, event and booking, a real device, and a staging or production run the user agrees to. |

## Build plan (the brief's own order, section 34)

**Tranche 1: no decisions needed, vendor app only (DONE 19 Oct: vendor PR #20, website PR #9).**
1. Failed workspace request: "We could not load your workspace" with Retry, never the setup screen (3, 4, 33).
2. Rename to BottlesUp Business everywhere a person can read it, plus a test that stops "Vendor" coming back (1).
3. Navigation per section 6 for owner, organizer, door and security (6).
4. Plain-language errors and Retry in the screens that print raw text (33).
5. Remember the last authorized workspace (4).

**Tranche 2: needs small database and website additions, no new business rules.** Deposit and bottle payment settings screens (15), walk-in booking (17), booking Guests/Activity tabs (14), server: accept stage, add bottles, partial delivery (16), organizer door staff setting and team (25), event statuses and venue selection (10), group admission allowance (26), owner Tonight and date filter (7), awaiting-verification and awaiting-assignment screens (4).

**Tranche 3: blocked on the client (section 34's own list).** Payout timing and account structure (20), supported card devices (26 Door Sales), fee formulas, refund and commission windows (28, 31), hold and invitation expiry (13, 24), ambassador chat retention (28/29), discounts and complimentary rules (21), Event Lead and the ambassador program (28), settlements (31).

**Last: the 15-step demonstration (35)** on a real device against a database the user chooses.
