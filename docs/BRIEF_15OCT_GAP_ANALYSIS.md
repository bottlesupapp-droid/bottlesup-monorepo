# BottlesUp Business: gap analysis of the 15 Oct developer brief against the vendor app (19 Oct 2026)

Source: `BottlesUp_Business_Full_Plan_and_App_Fixes.pdf` (14 pages, 35 sections, dated 15 Oct 2026; it replaces the earlier brief whose section numbers the first
Phase 2 migrations quote). Checked against the code on vendor `feat/business-brief-2` (PR #21, on #20 and #19) and website `feat/business-brief-2` (PR #10, on #8; with #7 and #9). **Updated 19 Oct after tranche 2 was built** (nothing is merged or applied; see `docs/FINAL_STEPS.md`).
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
| 4 | App-opening flow | **Ready to test** | One workspace opens; several show the selector with the **last choice remembered** ("Last used", PR #20). Overview shows the business verification and setup status (PR #21); a staff member with no assignment yet gets a plain "awaiting assignment" sentence. Left: a dedicated "pending invitation" screen (the invitation flow itself works); the top bar shows role, business and scope but not the night or event. |
| 5 | Three onboarding routes | Partly by design | Accounts and business onboarding are on the website (decided 16 Oct); invited staff accept in the app. Resume of saved setup and verification status are not shown in the app. |
| 6 | Role navigation | In progress | Owner (Overview/Venues/Tonight/Reports/More), Organizer, Door (More added), Security (More) now match; Manager and Server already did (PR #20). **Event Lead** role does not exist (no database role; program rules first). |
| 7 | Owner overview | In progress | **Date filter built** (PR #21): the Floor's ranges and date pickers, up to 93 nights, with a venue that has more than 1000 bookings saying its totals are incomplete. Missing: stock issues, staff alerts, settlements and payouts, sales vs collections split beyond bookings. |
| 8 | Manager Tonight | **Ready to test** | Needs-attention queue, floor, orders, payments to check, close night, **Add walk-in** (17). Missing: Message Team shortcut. |
| 9 | Organizer overview | In progress | Events and guests read-only. Missing: sales, deposit allocation, commissions, earnings, settlements; Share Event, Invite Team, Public Profile actions. |
| 10 | Event creation | In progress | Draft create/edit/remove with cover photo (organizer cannot publish). **Event states built** (PR #21): draft, awaiting the club's approval, ready for BottlesUp to publish, live, ended, with what blocks publishing; there is no "cancelled" in the database, so none is shown. Missing: venue selection on the event, tickets and VIP, tables, team, preview, publish (BottlesUp's team publishes). |
| 11 | Venue connection and agreement | Ready to test | Request, versioned terms, accept by both sides, sample calculation; **organizer door staff yes/no is now the club's switch on the agreement** (25). Missing terms to add: deposit rules/recipient, collection responsibilities (need the client's rules); accepted-version history is stored. |
| 12 | Tickets, VIP and room access | Not built (app) | Ticket tiers are made in the website CMS; no app screens; no group admission allowance; no room capacity sharing. |
| 13 | Floor plans and tables | In progress | Tables and floors editors (name, capacity, min spend, deposit). Missing: map position by owner (BottlesUp team does it), included admissions, statuses Held/Occupied/Unavailable, timed checkout holds, moving a booking with a record of who moved it. |
| 14 | Booking details | **Ready to test** | Table page with the brief's tabs: Overview, Orders, Payments, **Guests, Activity** (PR #21). Missing: payment terms shown as accepted by the guest, a guest allowance per table (needs the client's rules). |
| 15 | Deposit and bottle configuration | In progress | **Bottle payment mode (pay ahead / at the club / both) is settable** in the venue Setup list (PR #21); it only affects NEW bookings. The deposit-credit switch is shown read-only (bookings read the venue's current value, so changing it would change existing bookings, which the brief forbids). Deposit amounts have their own table editor. Not built: deposit recipient and purpose, "venue / approved organizer / split" (need the client's rules). |
| 16 | Server workflow | In progress | Orders with the five stages, deliver, record payment, **add bottles** (one call to the website's existing function: priced, stock-checked, due at the club) and **partial delivery** ("Deliver some", safe against repeats), service ETA (seating). Missing: an Accept stage (production's check constraint allows five states; changing it is a production DDL change), apply codes, sign text, multiple tables as one shift. |
| 17 | Walk-in table booking | **Ready to test** | Tonight > Add walk-in: arrival time, a table that is really free, guest name and e-mail, terms read out, one call that cannot give the last table twice; the deposit is due at the club and recorded with Record a payment (cash and card stay separate). Not built: a timed hold (the booking is made at once, so nothing is held and lost), phone-tap payment. |
| 18 | Customer requests | Ready to test | Open, acknowledge, complete, escalate. Missing: assign. |
| 19 | Collect payment and evidence | Ready to test | Record payment, receipt photo, verifier queue, cash handover and discrepancies, corrections keep history. |
| 20 | Direct deposit / payouts | **Needs decision** | Brief says confirm payout structure and timing first (section 34 lists it). Nothing built. |
| 21 | Discounts and complimentary | **Needs decision** | Stacking, approval, claim rules not given. Shown as "Not available yet". |
| 22 | VIP guests | Ready to test | List, tiers, perks, invite (queued; e-mail sender built, not live), door lookup (PR #19). |
| 23 | Inventory | Ready to test | Receive, wastage, adjust, count, low stock. Missing: reserved vs issued, package components, best sellers. |
| 24 | Staff invitations | Ready to test | Invite, resend, revoke, shift, change role. |
| 25 | Organizer-provided door staff | **Ready to test** | The club's switch on each agreement; the organizer's Team screen invites door staff per event only where allowed (the rule is in the database); the club sees and removes the organizers' door staff. Door staff cannot change pricing, issue refunds or reach banking (their role has no such function). |
| 26 | Door operations | In progress | Scan, manual admit, entry code, duplicate refusal, **group admission with remaining allowance** (a ticket for several guests asks how many come in; shows how many are in and may still come; "Admit more"), **Refunded told apart from Not paid**, exact "guests in" counts. Missing: Door Sales (needs the payment decision), shift summary, promo codes. |
| 27 | Security workspace | Ready to test | Alerts, tasks, chat, incidents. |
| 28 | Ambassadors and Event Lead | Not built | New role, program rules, commissions, earnings states, customer-app Ambassador Hub. Needs the rules in section 34 (commission windows) first. |
| 29 | Chat and notifications | In progress | Chat built (event chats purge after 7 days; scheduling is in website PR #8). Notifications: e-mail sender built, not live; push/SMS and preferences not built; deep links not built. |
| 30 | Public organizer profiles, booking links | In progress | Venue booking link, slug, QR, preview built. Organizer public profile is website work. |
| 31 | Earnings and settlements | Not built | Depends on 15, 20, 28. |
| 32 | End-of-night PDF | Ready to test | Preliminary and final by role. Missing: ambassador, expenses, earnings, who-owes-whom; multi-venue owner report. |
| 33 | Interface states | In progress | Workspace screens, and now the classic screens: ~45 raw `$e` messages and the analytics query errors are plain sentences with Retry and a logged reason; a guard test fails on any new one (PR #20). Every new screen has loading, empty, failed (with Retry), "your access has ended" (no Retry), save-in-progress (double taps make one action, even two in one frame) and failure-keeps-input states. Still to do: a "connection lost / pending sync" banner (needs a connectivity package and a decision on offline behaviour). The analytics relationship error's cause (legacy tables) needs a look at the production schema. |
| 34 | Development order | | Followed below. |
| 35 | Acceptance demonstration | Not run | Needs a shared test venue, organizer, event and booking, a real device, and a production run the user agrees to. **Steps 1 to 12, 14 and 15 can be shown with what is built; 4 (table allocation) and 13 (organizer allocation and settlement) cannot until the client's rules arrive.** The step-by-step script is in `docs/FINAL_STEPS.md` section 5. |

## Build plan (the brief's own order, section 34)

**Tranche 1: no decisions needed, vendor app only (DONE 19 Oct: vendor PR #20, website PR #9).**
1. Failed workspace request: "We could not load your workspace" with Retry, never the setup screen (3, 4, 33).
2. Rename to BottlesUp Business everywhere a person can read it, plus a test that stops "Vendor" coming back (1).
3. Navigation per section 6 for owner, organizer, door and security (6).
4. Plain-language errors and Retry in the screens that print raw text (33).
5. Remember the last authorized workspace (4).

**Tranche 2: needs small database and website additions, no new business rules (BUILT 19 Oct: vendor PR #21, website PR #10; nothing applied).** Done: bottle payment settings (15), walk-in booking (17), booking Guests/Activity tabs (14), add bottles and partial delivery (16), organizer door staff setting and team (25), event states (10), group admission (26), owner date filter (7), verification status and awaiting-assignment (4). **Not done from this list, and why:** the server Accept stage (production's check constraint), event venue selection (website work), deposit recipient and purpose (client rules).

**Tranche 3: blocked on the client (section 34's own list).** Payout timing and account structure (20), supported card devices (26 Door Sales), fee formulas, refund and commission windows (28, 31), hold and invitation expiry (13, 24), ambassador chat retention (28/29), discounts and complimentary rules (21), Event Lead and the ambassador program (28), settlements (31).

**Last: the 15-step demonstration (35)** on a real device against a database the user chooses.
