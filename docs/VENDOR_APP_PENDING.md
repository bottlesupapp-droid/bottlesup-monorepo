# Vendor ("Business") app, `bottles-up-vendor`: everything still pending

Written 10 Nov 2026 by Claude, on the user's "get UI from this repo and start working on vendor app UI, any feature missing add to the pending list and make UI skeleton for now; do what all you can without my input, any query save it for later".
This is the vendor app's one list, the same way `docs/USER_APP_PENDING.md` is the customer app's. Keep it current: tick a line when it is done and say where.
Other vendor notes: `docs/VENDOR_REDESIGN.md` (the look), `docs/FINAL_STEPS.md` (what is yours to do), `docs/VENDOR_APP_100_PERCENT_AUDIT.md` and `docs/BRIEF_15OCT_GAP_ANALYSIS.md` (the brief, point by point).

Bundle ID: Android `com.bottlesup.vendor`. Repo: `bottlesupapp-droid/bottles-up-vendor` (the old `KDR9MGR/bottles-up-vendor` address redirects to it; same branches, same commits).

## 0. Where it stands (10 Nov)

- **The design source is in the repo.** Branch `prototype-web` (one commit, 8 Nov, "Add BottlesUp web prototype (React/Vite demo) in /prototype") holds the whole Business-app design as a working web demo: `prototype/src/*.tsx` (about 600 KB), with eight roles. It is a demo with made-up data, so it is a guide to look and behaviour, not a spec. Nothing in it is wired to a backend.
- **Redesign phases 1 to 4 (the look of every screen that exists): built, tested, PUSHED on 8 Nov, no pull request open.** Branches `design/phase1-foundation` (on PR #39) → `design/phase2-owner-tabs` → `design/phase3-other-roles` → `design/phase4-long-tail`.
- **Phase 5 (this list's first part): sample screens for the features the design has and the app does not.** Branch `design/phase5-skeletons` (commits `2efd8ca`, `fc3957f`, on phase 4), **local only, nothing pushed**. 20 screens, each a layout with made-up data that saves and sends nothing (section 2).
- **Nothing here has been run on a phone.** The pictures were rendered from tests.
- Still open from before: pull requests #39, #40, #41, #42 (vendor) are unmerged; see `docs/FINAL_STEPS.md`.

## 1. How the sample screens work (so nobody mistakes them for features)

- They live in `lib/features/preview/`. Every screen says "Sample screen: the layout is real, the names and numbers are made up. Nothing here is saved or sent." and every button answers the same.
- **They exist only in debug builds** by default (`kPreviewsEnabled`, `lib/features/preview/preview_config.dart`). To see them in a release or TestFlight build: build with `--dart-define=BU_PREVIEWS=true`. With `false` they disappear from a debug build too. This follows the app's own rule for unbuilt parts (`showUnbuiltMoreEntries = false` in `more_screen.dart`: nobody opening the app meets a row that goes nowhere).
- Where to find them: **More** (last row, "Sample screens") and the "no business yet" page, then the list `/preview`; each has its own address `/preview/{id}`.
- No sample touches the database, the real roles, the workspace list or the routing rules of real roles. The only change outside `features/preview/` is a flag-guarded route pair, one rule in `decideWorkspaceRedirect` (`previewsEnabled`) and the two entry rows.
- To add one: a screen under `features/preview/screens/`, an entry in `preview_catalog.dart`, a line in section 2 here. The tests (`test/preview/`) open every catalog entry by themselves.

## 2. In the design, NOT in the app: sample screen built, the real feature still to do

"Needs" is what making it real takes, as far as I can tell from the prototype and the app; each is a proposal until you say go. Layouts came from the prototype file named in the last column.

### 2a. Three roles the app does not have

| # | Feature | Sample id | Needs to be real | Prototype |
|---|---|---|---|---|
| 1 | **DJ / Artist role**: booking requests (new / awaiting client / confirmed / past) with a price breakdown (package + extra hours + add-ons + travel, 13% tax, 30% deposit, payout after a 10% fee), accept / counter-offer / decline, calendar with blocked dates and date-conflict warning, packages and add-ons editor, earnings and payout status, public profile and its editor, visitor's booking-request form, rider, analytics, accepting-bookings switch | `dj` | A new role value (`site_memberships.role` and `WorkspaceRole`, `fromDb` already ignores unknown values), tables for artist profile, packages, add-ons, booking requests, blocked dates, quotes; deposit held by BottlesUp until the gig; payout 2 business days after; the customer app's request flow must write the same requests (its prices must match) | `Dj.tsx`, `DjStudio.tsx` |
| 2 | **Ambassador role**: performance, assigned events, referral code + link + QR, earnings by status (pending / confirmed / reversed / paid) | `ambassador` | New role; referral codes and links; attribution of ticket and table sales to a code; commission rules and statuses; reversal on refund; payouts; who may assign an ambassador to an event | `Roles.tsx` |
| 3 | **Event Lead role**: team overview, leaderboard, inactive ambassadors with "nudge", pending invitations with resend, invite with ticket target, personal earnings apart from the permitted team total | `event-lead` | Everything in 2, plus teams per event, targets, invitations, nudges (a notification), a rule for what a lead may see of the team's money | `Roles.tsx` |

### 2b. Organizer tools

| # | Feature | Sample id | Needs to be real | Prototype |
|---|---|---|---|---|
| 4 | **Overview with a branded banner** (what guests see at the top of the organizer's page), shortcuts, "needs attention" with four kinds of item | `organizer-overview` | The banner image / colours stored per organizer and shown in the customer app; the attention list needs the agreement, door-team, venue and application states (the first three exist) | `OrgTools.tsx` |
| 5 | **Organizer analytics**: ticket sales by day / week, views → checkout → booked, referral sales, gross → refunds → fees → net | `organizer-analytics` | Event-view and checkout-start tracking (not collected today); sales and refunds exist | `OrgTools.tsx` |
| 6 | **Opportunities**: post a role (DJ, photographer, host, ambassador...), applicants, shortlist / decline | `organizer-opportunities` | Tables for roles and applications; where the roles are shown (the customer app?); privacy of applicants | `OrgTools.tsx` |
| 7 | **Public profile** (guest's view and the editor: about, links, what to show) | `organizer-profile` | Organizer profile fields and visibility switches; may be the same profile as the customer app's social side (unmerged), see question 7 | `OrgProfile.tsx` |
| 8 | **Posts and highlights** with comment moderation | `organizer-content` | Posts, stories, comments and reporting exist only in the customer app's unmerged social branches | `OrgProfile.tsx` |
| 9 | **Flyer tool**: templates, text, picture, export 1080 × 1350 | `organizer-flyer` | Drawing to an image on the phone; saving / sharing the file; where the flyer is kept | `OrgTools.tsx` |
| 10 | **Repeating events and promo codes**: weekly schedule, end after N events; codes with amount, limit, end date, tables or not | `organizer-repeat-promos` | Series and dates in the event model (each date its own tickets, guests, tables, staff, report); promo codes at checkout in the customer app and the website. **Ticket tiers already exist in the app** (`manage_ticket_tiers_screen`), so they were not drawn again | `EventParts.tsx`, `OrgTools.tsx` |
| 11 | **Messages: Inquiries and Team** (guests and clients; staff, venues, DJs; event group chats) | `organizer-messages` | A guest-facing "message the organizer" in the customer app (its messaging is on the unmerged social branches); threads, members, unread counts, notifications. The app's staff Chat exists and is not this | `Inbox.tsx`, `Messages.tsx` |

### 2c. Venue owner and manager tools

| # | Feature | Sample id | Needs to be real | Prototype |
|---|---|---|---|---|
| 12 | **What is behind the Overview numbers** (Expected, Arrived by hour, Sales gross → earnings, Payouts) | `owner-numbers` | Tap targets on the existing tiles and a breakdown query per number (the numbers exist; the breakdown does not) | `OwnerStats.tsx` |
| 13 | **A payout that failed**: what happened, "your money is safe", fix the bank details, contact support | `owner-payout-issue` | A payout-failure event from the payment provider, and a way to update the account (probably the provider's hosted page, not a form in the app); the existing Payouts screen is read only by design | `Owner.tsx` |
| 14 | **Messages centre**: Customers (enquiries, bookings), Team, Requests (help, bottle signs, refunds) | `venue-messages` | A guest-to-venue thread; the Requests list could read what the app already has (signs, refunds) | `Messages.tsx` |
| 15 | **A booking's passes, pre-orders and refund**: who claimed a pass, what was ordered ahead, the sign, cancel with refund | `booking-details` | The app has no booking detail screen for staff (`features/booking_detail` has logic only); passes and pre-orders exist in the customer app's My Night; refunds exist as a policy and a request list | `Guests.tsx` |
| 16 | **The venue's own events** (one-time and weekly), each date with its tickets, guest list, tables, staff, report | `venue-events` | A venue creating events itself in the workspace shell (today only organizers do; the owner sees organizer events under Agreements); series model as in 10 | `VenueOps.tsx` |

### 2d. Whole app

| # | Feature | Sample id | Needs to be real | Prototype |
|---|---|---|---|---|
| 17 | **Settings with appearance** (Dark / Light / match the phone) and notification switches | `settings` | The **light theme** (phase 3 and 4 code uses `BuTokens.dark` directly and about 550 colours are hard-coded white or black; see `docs/VENDOR_REDESIGN.md`); notification preferences storage | `shared.tsx` |
| 18 | **Launch screen** (logo, name, "Business", a turning cue) | `launch` | The bottle "pop and splash" animation is a drawing from the design file (`BottlePop.tsx` is generated from it); needs the artwork exported; native splash is separate from this | `Launch.tsx` |
| 19 | **Invitation, expired and pending** states | `access-states` | The app has the accept-invitation screen; the expired and "waiting for an administrator" states and a "request a new invite" action need backend support | `Access.tsx` |
| 20 | **Role chooser (demo)**: "How are you working tonight?" | `role-chooser` | **Not a feature to build**: the real app knows the role from the workspace. Kept as a sample so the client can see all eight roles together. See question 4 | `Access.tsx` |

## 3. In the design, in the app in some form: not re-drawn, to be checked against the prototype later

I did not make sample screens for these, because the app has a screen for the thing. Whether the app's version matches the design's is for a later look.
- Venue editing: venue profile, floors, tables, bottle menu, booking times, payment settings (`owner/screens/setup/`). The prototype's guest-page editor also has a **photo and video picker with reorder and cover** and an **opening-hours editor**; check whether the app's editor covers them.
- Team, invitations, shifts (`team/`); agreements and terms (`agreements/`); inventory (`inventory/`); VIP guests (`vip/`: the prototype adds hosts and private notes); reports and the nightly report (`night/`); the door's guest list and door sales; server desk, orders, bottle signs; incidents and security; chat; refunds, discounts, payouts (read only).
- Offline: the prototype's "offline demo" is the app's connection banner.
- The three things the 7 Nov Figma list could not place (see `docs/VENDOR_REDESIGN.md`): the **booking-link QR page** is the Ambassador's Share page in the prototype (sample built, item 2); the **venue setup progress checklist** is the app's setup list on the venue page (green when complete since phase 2); the **nightly closing report** is the app's night report (`night/report_screen.dart`), which the prototype draws again as a detail page.
- **Not in the app and not drawn**: a **Support** sheet and **Shift details** sheet on every role's More (the samples have them inside the three new roles); the **Messages button with an unread badge** on operational screens; the manager's **Today** tab with a preparation checklist and a **Bookings** tab with a month calendar (the app's manager has Tonight, Floor, Orders, Team, More); a server **Team** tab; the venue tools for a **manager** (the prototype gives managers the owner's venue page, tables and menu; the app's setup editors are the owner's).

## 4. Questions saved for later (nothing is blocked on these; I used the prototype's numbers in the samples)

1. **DJ / Artist**: one more role inside the Business app (a membership), or a separate artist account? Are the prototype's money rules the client's: 30% deposit held by BottlesUp, 10% BottlesUp fee off the artist's subtotal, 13% tax added for the client, payout 2 business days after the gig, balance due 7 days before? (The prototype is set in Toronto, in Canadian dollars.)
2. **Ambassador / Event Lead**: the commission (the prototype's Opportunities screen says "10% of referred sales", and its earnings samples work out at about $8 a ticket; they do not agree, so neither is a rule), who pays it, when it becomes confirmed (after the event), reversal on refund, payout schedule, who may invite an ambassador (organizer, or event lead), what an event lead may see of the team's money.
3. **Should the sample screens ever ship in a store build?** I made them debug-only (`BU_PREVIEWS`). Showing them to the client on a phone needs a build made with the switch on.
4. **Role chooser**: keep as a demo sample only (my recommendation: do not build it).
5. **Light theme**: when? It needs an audit of the colours hard-coded in screens before it is a switch.
6. **Launch animation**: can the client's designer export the bottle artwork so the pop and splash can be drawn natively?
7. **Organizer public profile, posts, highlights, messages**: the customer app already has a social side (profiles, posts, stories, comments, messages) on unmerged branches. One profile for both apps, or a separate organizer profile? This decides the backend for items 7, 8 and 11.
8. **Opportunities**: shown to everyone in the customer app, or only on the organizer's profile? Who sees applicants?
9. **Failed payouts / bank account**: update the bank account inside the app, or send the owner to the payment provider's page?
10. **Flyer tool**: export on the phone only, or also keep the flyer with the event?
11. **Venue-created events**: should an owner or manager create events in the Business app (the website may already allow it)?
12. **Analytics**: OK to start collecting event views and checkout starts (needed for "views to bookings")?

## 5. Yours to do (not mine): see `docs/FINAL_STEPS.md`

- Decide whether to open the four redesign pull requests (and later the phase 5 one), and in what order.
- A phone pass of the redesign and the samples (nothing has run on a device).
- **Your Mac's Dart package cache is broken**: `~/.pub-cache` is owned by root and holds only a README (it was created Nov 9 06:58), so `flutter pub get`, `flutter test` and a build of any app in this monorepo fail with "Permission denied" until it is yours again. Fix, in a terminal: `sudo chown -R "$(whoami)" ~/.pub-cache` and then `flutter pub get` in each app. (I worked around it with a private cache in my scratch folder and changed nothing of yours.)

- **Every tracked file became executable on 9 Nov (08:31 to 08:33).** A recursive `chmod` over the monorepo folder (not from Claude: nothing of mine touches it) changed 644 to 755, so `git status` in the monorepo and in all three app repos lists about 2,700 "modified" files that are only mode changes (content untouched). A careless `git add -A` would commit them. To hide them: `git config core.fileMode false` in each repo (the monorepo, `apps/bottles-up-vendor`, `apps/bottles-up-user`, `apps/bottles-up-website-main`); to undo them, chmod the files back to 644. Say if you want me to do either. (The same hour as the root-owned `~/.pub-cache` above, so possibly one command run with `sudo`.) Claude sessions: stage by name and use `git -c core.fileMode=false add <files>`.

## 6. Small things found and left alone

- "Recorded just now ago": the payment line adds " ago" to a label that already says "just now" (`waitedLabel` in the table-service code). A wording fix.
- The Android release bundle has never been built from the redesign branches.
