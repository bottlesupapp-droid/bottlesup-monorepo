# BottlesUp Business (vendor app): redesign to the Figma concept

Started 7 Nov 2026 on the user's "we need to redo the UI/UX of the vendor in this concept and tone ... without breaking any existing features and functions".
Design source: the Figma Make file "BottlesUp Business App" (https://www.figma.com/make/3uNiwVYsaUhbic9tdIWE2z/BottlesUp-Buisness-App). View-only for us.
Since 8 Nov the same design also exists as a working web demo in the vendor repo, branch `prototype-web`, folder `prototype/` (React/Vite; `src/*.tsx`, `src/index.css`). It has eight roles and far more screens than the Figma pages seen on 7 Nov, so it is the fuller source; it has made-up data and no backend.

## Decisions (the user's, 7 Nov)

1. **Dark only for now.** The Figma also has a Light theme (tokens below), but about 550 colours are hard-coded white/black inside screens, so light mode needs its own audit. A later step.
2. **Restyle only what exists.** Every current screen and function keeps working and gets the new look. What the Figma shows that the app lacks is listed below and NOT built.
3. **Phase by phase, one pull request each. Nothing was pushed until the user said so; on 8 Nov ("commit and push everything pending") the four branches were pushed to the vendor repo. **On 11 Nov ("push phase 5 and open the pull requests") phase 5 was pushed and five stacked pull requests were opened: #43 (phase 1, based on #39) to #47 (phase 5). Nothing was merged that day.** **12 Nov ("merge the vendor pull requests in order"): #39 to #42 and #43 to #47 are all MERGED into vendor `main`; #45 needed a one-file conflict fixed first (the Summary page's Closing reports button from #41), and #48 fixes one colour line in #42's reset-code screen that the redesign's no-old-hues test caught.**

## What the design is (read from the prototype's own stylesheet, not estimated)

How to read it again: open the Make link in the built-in browser (a wide emulated viewport, e.g. 1500x900), read the request `.../generic_cached_preview` (the browser's network log, via
`read_network_requests`) for a `*-figmacachedpreview.figma.site?__figma_cached_preview_token=...` address (the token lasts 60 seconds and belongs to the person who is signed in), open it, then read
`document.styleSheets` for `:root` and `.theme-light`.

| Token | Dark | Light (not used yet) |
|---|---|---|
| page `bg` | `#090909` | `#f4f1eb` |
| card `panel` | `#151514` | `#ffffff` |
| `panel-2` | `#1c1b1a` | `#f7f3ed` |
| edge `line` | `#292826` | `#e4ded5` |
| `muted` / `soft` / `ink` | `#999894` / `#c8c6c1` / `#f5f4f1` | `#716d67` / `#3e3a36` / `#171512` |
| `orange` / `orange-soft` | `#ff5a2f` / `#ff7a45` | `#f04f24` / `#df461f` |
| `green` / `amber` | `#59d7a2` / `#ffb258` | `#16835e` / `#a9650d` |
| radius | 20 (cards), 24 (hero card and bottom bar), 14 (inputs, buttons), 12 (icon tiles) | same |

Type: Inter; page heading 30 / weight 650 / tracking -0.045em; body 14 / line 1.55; small orange upper-case "eyebrow" labels (about 10.5 / +0.12em) over headings.
Shapes of the screens: glass top bar with the brand mark, a floating glass bottom bar (76 high, 5 tabs, orange wash and glow on the active tab), hero card with a gauge, stat tiles, "needs attention" lists,
segmented switchers, a primary orange action beside a secondary outlined one, thin progress bars, small status pills.

## How it is built in the app

`lib/core/theme/app_tokens.dart` (colours, radii, spacing; widgets read them with `context.bu`), `lib/core/theme/app_theme.dart` (the dark theme, an explicit style for every common control),
`lib/core/ui/bu_kit.dart` (brand mark, eyebrow, page header, section header, card, icon tile, list row, status pill, count badge with a tone, list card, backdrop, wordmark; and from phase 2 the hero card, the progress ring and the stat tile), `lib/core/ui/glass_kit.dart` (the floating bar).
Inter is bundled (`assets/fonts/Inter.ttf`); nothing in the app downloads a font any more. Tests that pin the design: `test/design/`.

## Phases

| Phase | What | State |
|---|---|---|
| 1 | Foundation (tokens, theme, kit, Inter), the shell (top bar, floating bottom bar), sign-in, the shared auth fields and buttons, the workspace list | **BUILT 7 Nov** on branch `design/phase1-foundation` (pushed 8 Nov) (off PR #39's head, so it keeps the "page ends where the bar begins" fix); full suite passes; 103 new tests; 64 deliberate breakages, 63 caught, 1 equivalent. pushed, **pull request [#43](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/43)** (opened 11 Nov, not merged), not run on a phone |
| 2 | The owner's five tabs: Overview, Venues, Tonight, Reports, More (hero card, stat tiles, needs-attention list, segmented switchers) | **BUILT 7 Nov** on branch `design/phase2-owner-tabs` (pushed 8 Nov) (off phase 1's `51a231c`). pushed, **pull request [#44](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/44)** (opened 11 Nov, not merged), not run on a phone. Details below |
| 3 | The other roles' tabs (manager, organizer, door, server, security, verifier) | **BUILT 7 Nov** on branch `design/phase3-other-roles` (pushed 8 Nov) (`ab3e634`, on phase 2). pushed, **pull request [#45](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/45)** (opened 11 Nov, not merged), not run on a phone. Details below |
| 4 | The long tail: the remaining screens (123 screens in all) | **BUILT (first pass) 7 Nov** on branch `design/phase4-long-tail` (pushed 8 Nov) (on phase 3). pushed, **pull request [#46](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/46)** (opened 11 Nov, not merged), not run on a phone. Details below |
| 5 | **Sample screens** for what the design has and the app does not (DJ / Artist, Ambassador and Event Lead roles, organizer tools, venue tools, whole-app screens): 20 layouts with made-up data | **BUILT 10 Nov** on branch `design/phase5-skeletons` (`fc3957f`, on phase 4). pushed 11 Nov, **pull request [#47](https://github.com/bottlesupapp-droid/bottles-up-vendor/pull/47)** (not merged), not run on a phone. Debug builds only unless built with `--dart-define=BU_PREVIEWS=true`. The list and what each needs: `docs/VENDOR_APP_PENDING.md` |

### Phase 2: what changed (owner's tabs; the shared parts reach the other roles too)

- **Overview**: heading with an eyebrow, the ready-made ranges without a tick (the chosen one is the orange-washed chip), two compact date buttons, then the **hero card**: "12 guests expected" with a ring of the share of bookings that have arrived. The card appears only when every venue has been read in full (a headline built on a short total would look more sure than it is); otherwise the tiles and the old warning show, as before. Four stat tiles (Awaiting payment turns amber when something waits, Arrived turns green), venue cards with a green Live / grey Draft pill.
- **Venues**: venue cards with the setup bar (orange; **green once every required step is done**), a full-width orange "Add a venue".
- **Tonight** (the manager's screen too): the date bar in a panel, the five shortcuts in a grid ("Add walk-in" is the filled orange one, "Send alert" is amber because it interrupts the team), "Prepare and close the night" as the highlighted card, then **Needs attention** and **The night** as two grouped lists with the count in a badge (amber when it is not zero and needs a person). The counts line up whether or not a row opens something.
- **Reports**: a highlighted "All venues together" card with the orange Combined report button, a card per venue with its two buttons stacked.
- **More**: one grouped card of rows, each with an icon tile; a part that is not built is dimmed, says so, and has no chevron.
- **Shared pieces that now look new everywhere they appear:** the date bar (10 screens), the report button (5), the business status card, the failure / empty states of `OpsAsyncView` (41 screens).
- **Screen readers:** the hero card and each stat tile are one item each ("12, Guests expected"); before, a whole screen body read as one blob.
- **Kept exactly:** every key and every text the existing tests look for. One test constant changed on purpose: the amber in `test/table_service/tonight_screen_test.dart` is now the design's amber (`BuTokens.dark.amber`, `#FFB258`) instead of Material's `#FFB300`.
- **Not changed:** behaviour, data, routes, the sentences. Forgot / reset screens untouched (PR #42).

### Phase 3: what changed (the other roles' tabs)

Manager and server (Orders, Floor, My Tables, Requests, the server's Scan), verifier (Review, Cash, Exceptions, Summary), door (Scan, Guests, Door Sales), security (Alerts, Tasks), organizer (Events, Guests), Chat and Team are on the kit: a Service / Your shift / Payments / Door / Security / Organizer / Messages / People eyebrow over each title, cards and grouped lists, the shared date bar, stat tiles (the Floor's have a small line under the label), and one orange action per screen.
- **One palette for status.** Order, payment, booking, request, event and team states, the door's verdict and the signs notice use the design's amber, green, red, orange, soft and muted. The old Material hues are gone. States that used to be blue, teal and purple are now orange, soft and ink: the word on the pill carries the meaning, never the colour alone.
- **The door's verdict** is the design's green, amber and red, with a tinted panel and edge; only "Admit" is green.
- **An urgent alert is lit red** (`BuCard` gained an `accent` colour); a resolved one is not.
- Shared pieces: `DeskChip` is the kit's pill (with an icon if wanted), `TeamBadge` uses it, the order, payment, booking, table, request and event cards are kit cards, and the "bottle signs could not be loaded" notice is an amber card.
- **Old test pins changed on purpose:** the request-status colours (`server_desk_rules_test.dart`) and the amber of the Tonight test.
- **Found, not fixed:** the payment line reads "Recorded just now ago" when a payment is under a minute old (`waitedLabel` says "just now" and the screen adds " ago"). Not a design matter; a wording fix for a later pass.

### Phase 4: what changed (the long tail), first pass

The Material widgets (Card, ListTile, Chip, AppBar, sheets, dialogs, inputs) were already themed in phase 1, so what was left on the other ~150 screens was what the theme cannot reach:
- **Colours:** Material's own green, red, orange, amber, blue, grey (and the old hexes and the old brand orange) are replaced by the design's tokens on every role screen and on the classic dashboard, events, analytics, clubs, venues, profile and onboarding screens. `test/design/no_old_hues_test.dart` fails if one comes back. The one exception is the floor map's five table states (`table_map/widgets/floor_canvas.dart`), which need five hues that read over any floor-plan picture.
- **Icons:** Material icons become Ionicons wherever there is a clear equivalent (a few without one stay Material).
- **Inputs:** the heavy empty outlined border is gone from every input (the theme draws them).
- **Headings:** the nine More pages (Agreements, Bottle signs, Inventory, Money, Report e-mails, Incidents, Sales, Your venue access, VIP guests) have the kit's page header; the screens before a workspace ("Set up your business", "We could not load your workspace") sit on the warm backdrop in cards; a tab with no screen yet is a card under a header.
- **Not done, by choice:** the classic screens keep their own layouts (only their colours and icons moved). Their widgets draw on `BuTokens.dark` directly, so a later light theme needs a pass over every `BuTokens.dark` use (phase 3 and 4 code) as well as the screens that still hard-code white and black.
- **Old test pins changed on purpose:** the picker's tick (`Ionicons.checkmark`) and the assign-server warning (the design's amber).

Order against open pull requests: phase 1 is built on #39. Forgot-password / reset screens belong to #42 and were NOT touched (they pick up the new fields and buttons through the shared widgets once #42 is merged).

## In the design, not in the app: sample screens (phase 5) and the pending list

On 7 Nov the decision was "restyle only what exists" and the Figma-only parts were listed here, not built. On 10 Nov ("any feature missing add to the pending list and make UI skeleton for now") they were built as **sample screens**: layouts with made-up data that save and send nothing, so the client can see the whole design. The full list, what each needs to become real, and the questions saved for later are in `docs/VENDOR_APP_PENDING.md`. In short:

- **Roles the app does not have**: DJ / Artist, Ambassador, Event Lead (each a small app with its own tabs).
- **Organizer tools**: overview with a branded banner, analytics, opportunities, public profile, posts and highlights, flyer tool, repeating events and promo codes, messages (inquiries and team).
- **Owner and manager tools**: what is behind the Overview numbers, a failed payout, a messages centre, a booking's passes / pre-orders / refund, the venue's own events.
- **Whole app**: settings with Dark / Light / System, the launch screen, invitation / expired / pending states, the role chooser (a demo screen, not meant to be built).

How they work: `lib/features/preview/` (kit in `widgets/pv_kit.dart`, a role frame in `widgets/pv_mini_app.dart`, one list in `preview_catalog.dart`, the gallery at `/preview`). Reached from More ("Sample screens") and the "no business yet" page. **Debug builds only by default**; `--dart-define=BU_PREVIEWS=true` shows them in a release or TestFlight build. The real roles, the routing of real roles and the database are not touched. Tests: `test/preview/` (64; they open every catalog entry, pin the DJ's price maths and the flows that change what is shown). Full suite on the final state: 3583 passed, 0 failed, 32 skipped. 36 deliberate breakages: 34 caught first time, the 2 misses were test gaps (now closed), all 36 caught. Commits on the branch: `2efd8ca`, `fc3957f`.
- **Changed outside `features/preview/`**: two routes (`/preview`, `/preview/:id`) in `app_router.dart` behind the flag; one rule in `decideWorkspaceRedirect` (`previewsEnabled`, a signed-in person may open the samples whatever workspaces they have); two entry rows (More and the no-workspace page). The More tab's own structure is unchanged (the row is a plain card, so the tests that pin "one grouped card" still hold).

## Classic screens in the prototype's look (15 Nov, on the user's "does not look and feel same as prototype ... make it look like apple to apple, anything missing add with coming soon")

**What they saw:** the vendor app in the iPhone 17 simulator, signed in with a classic account (a `vendors` row, no workspace). That account gets the *classic* screens, which phases 1 to 5 had only recoloured (phase 4: "classic screens keep their own layouts"), so they looked nothing like the prototype: glass cards in four tints, a "Dashboard" bar, and "BOTTOM OVERFLOWED BY 9 PIXELS" banners. The workspace screens (the owner's five tabs) already matched; this account never reaches them.

**Built on local branch `design/match-prototype` of the vendor repo (off `main` `4b7ce68`; commits `a029df6`, `ac508f0`, `ef37b30`; NOT pushed, no pull request):**
- **The frame** (`lib/shared/widgets/main_shell.dart`, `classic_top_bar.dart`): the design's top bar (brand mark, "BottlesUp", business and role, profile button) and five tabs in the design's order: Overview, Venues, Tonight, Reports, More. **Events moved under More** (the design has no Events tab; the routes are unchanged and More stays lit on `/events`, `/bookings`, `/inventory`). The round Messages button of the design is on the five tabs (Coming soon).
- **Overview** (`dashboard_screen.dart`): date eyebrow and a greeting for the time of day with "Create event"; a hero card with a ring of confirmed bookings; four figures (Bookings, Events, Sales, Payouts); Needs attention (bookings to confirm, items low on stock, venue profile to finish, or "All clear"); Your venues; Shortcuts; What happened last (only dates the account really has). **The old screen's made-up activity lines ("Payout processed", "Promo code used SUMMER2024") are gone.**
- **Venues** (`clubs_list_screen.dart`): heading with a round add button, a strip (venues, open, setup complete) and a card per venue with its photo, status pill and a five-step setup bar (photos, details, description, address, capacity).
- **More** (`profile_screen.dart`): profile card, then Operations (Team, Inventory, VIP clients), Business (Payments, Events, Bookings, Agreements), Account (Settings, Terms, Privacy, About), then Delete Account and Sign Out as before.
- **Reports** and **Events**: the design's heading and a segmented control in place of the app bar and tab bar; same side margin as every tab.
- **Tonight** is a designed Coming soon page (`features/tonight`).
- **Kit additions** (`bu_kit.dart`): `BuStatTile`, `BuMiniVenue`; `bu_coming_soon.dart`: `BuComingSoonPill`, `showComingSoon`, `BuComingSoonPage`.

**Coming soon (placed where the design has them, each with its sheet or page):** Tonight, Team, VIP clients, Payments, Agreements, Broadcast, Messages. Not shown at all: the design's Light / Dark switch (the app is dark only).

**A real bug found and fixed on the way (not a look change):** every Reports tab said "We could not load your analytics". Cause, read from the app's own log: `PostgrestException ... Could not find a relationship between 'inquiries' and 'events' (PGRST200)`. The providers embedded `events!inner(...)` and the production database has no foreign key for that. They now read the account's own event ids and filter with `inFilter` (`analytics_provider.dart`), and `test/analytics/analytics_queries_test.dart` keeps an embedded form from coming back. Checked live: Reports now shows this account's real figures. **No database change was made or is needed.** (Reads only, through the app.)

**Checks:** analyzer: no new issue; full suite 3807 passed, 0 failed (37 skipped, as before); 32 new tests (`test/design/classic_screens_design_test.dart` 29, the guard 3); **24 deliberate breakages, 24 caught** (separate copy); the old classic-frame test (`test/core/shell_overlap_test.dart`) was updated on purpose (a provider scope for the top bar; its route is a non-tab page because a page with a button of its own is not a tab). Looked at on the real simulator, hot-reloaded, with the real account's data.

**Not done (as of the first pass; see the next section for what changed after):** the screens behind these tabs (venue details, edit venue, create event, edit profile, settings, bookings list, inventory) were as before (themed, not rebuilt); no phone; the Reports charts kept their old drawing; no light theme.

## Screens behind the classic tabs (15 Nov, on the user's "lets complete vendor app 100%", after the scheduling)

**Branch:** `design/match-prototype` of the vendor repo, now 7 commits past `main` `4b7ce68` (the 3 of the earlier section plus `2a236fa`, `fd50145`, `b8efba7`, `c68af2f`); **local only, not pushed, no pull request, nothing built or uploaded.** The user's iPhone 17 simulator runs a debug build of it (hot reload; `flutter run` from the scratch worktree), signed in with the classic account.

**What changed (seen on the simulator with the account's real data, and in test pictures):**
- **One header for every page opened from a tab** (`BuDetailHeader`, `BuDetailAppBar` in `bu_kit.dart`): the design's rounded back button, a small orange eyebrow and the title, actions at the right. It replaced the old `AppBar` on **22 screens**: venue page, edit venue, create venue, create / edit event, event details, tiers, lineup, tables, guest list, scheduled releases, bookings, inventory, edit profile, business details, security, notifications, settings, help, contact, terms, privacy, about. The back button hides when there is nowhere to go back to.
- **The brand top bar (BottlesUp / business / role / profile) shows on the five tabs only**, as in the design; a page opened from a tab has its own header. To make the back button work, More now **pushes** Events and Inventory instead of replacing the page.
- **Venue page rebuilt** (`club_details_screen.dart`) as the prototype's "Manage venue": name over "Manage venue", Open / Approved / Pending / Suspended pill, pill tabs **Setup** (progress "5 of 5 complete", the five steps done / to do, each opens the form; the design's other five steps shown with Coming soon), **Page** (location, about, facts, music, amenities, contact, from the venue), **Photos** (grid, first is the cover; reorder and video are Coming soon), and **Tables, Menu & signs, Booking link as Coming soon** (a classic account has no tables or booking link data). Edit and Delete (with its confirm) are kept.
- **Bookings rebuilt** (`bookings_screen.dart`): three figures (bookings, to confirm, sales = confirmed money only), filter pills All / Pending / Confirmed / Completed / Cancelled, design cards with a status pill; Confirm, Cancel and Mark Completed behave as before.
- **Inventory rebuilt** (`inventory_screen.dart`): figures (items, running low, out), filters All / Low / Out, design cards with how many are left. **Add, Edit and Remove were silent TODO buttons that did nothing; they now say Coming soon.**
- **Settings rebuilt** (`settings_screen.dart`): it was a "Settings Coming Soon" placeholder with made-up feature tiles. It is now the design's hub: a Display card (Dark chosen; Light and Auto are Coming soon), then Account (Edit profile, Business details, Security, Notifications, each opens its existing page; Billing and payouts is Coming soon), Help (Help Center, Contact Support) and About (Terms, Privacy, About).
- **A real bug fixed (not a look change): the Reports "Booking Trends" line was made-up data** (`_generateSampleSpots`: a fixed rising line, shown as if it were the vendor's bookings). It is now the account's real last seven days (`bookingsPerDay`, zero for a day with none), with small weekday labels and whole-number counts, and says "No bookings in the last 7 days." when there are none. The data was already fetched and ignored.

**Checks:** analyzer: no error or warning; full suite 3,838 passed, 1 failed on the first run (a repo guard, `bar_clearance_test`: my four new screens padded their bottom by 120; fixed to 32) and re-run green on the affected files; one timing flake (`live_refresh_test`, passes alone) under load. New tests: `test/design/classic_detail_screens_test.dart` (27: venue page 13, Bookings 5, Inventory 4, Settings 3, the frame 2) and `test/analytics/analytics_chart_test.dart` (7). Deliberate breakages: see the result line in HANDOFF (17 tried in a separate copy). Pictures were also rendered from the tests (icons show as boxes there because the test renderer has no icon font; the simulator shows them).

**Second pass, the same day, on "continue with the remaining screen bodies" (the branch is now 12 commits past `main`; 42 files, still local, not pushed):**
- **Account pages rebuilt from what the account has** (`business_details`, `notifications`, `security`, `edit_profile`, `help_center`, `settings`): several of them **showed made-up or false things, now fixed**:
  - **Business details** showed a hard-coded business name and **made-up opening hours** (Mon to Fri 9 to 5, Sunday closed). It now shows the account's own business name, e-mail and phone ("Not added yet" when missing), its venues, and opening hours as Coming soon.
  - **Notifications**: "Save Preferences" said "Notification preferences saved" while saving nothing (the app sends no push, SMS or e-mail). It now says plainly that notifications are coming, the switches are dimmed and cannot be changed, and there is no Save button.
  - **Security**: the two-step sign-in switch was fixed at "off" whatever the account had, and each row answered with a snackbar. It now has Coming soon rows (password, two-step, login activity, devices); **Delete Account is unchanged** (same confirm, same service call).
  - **Edit profile**: a "Full Name" field was validated and pre-filled with the business name but **never saved anywhere**; it is gone. Business name, phone and photo save as before; the e-mail is locked, with a line saying why.
  - **Help Center**: the answers quoted **a "10% service fee" (the fee schedule is an open client decision), push notifications (none exist), and tabs that moved**. They are rewritten for the app as it is, 12 questions, and the "Contact Support" button, which used a Navigator route the app does not have, now opens the contact page.
  - **Settings**: Notifications now carries the Coming soon pill.
- **Event details rebuilt** (`event_details_screen.dart`): picture, name and status pill, when and price, four figures (tickets sold, revenue, capacity, available; revenue says N/A when it cannot be loaded), grouped rows (scanner, guest list, tables, bookings; tiers, scheduled releases, team and lineup), and Share, Duplicate and Delete as Coming soon (Delete used to ask "are you sure?" and then say Coming Soon). View Bookings now pushes, so the back button works.
- **Venue forms** (`create_club_screen`, `edit_venue_screen`) and **event forms** (`simple_create_event_screen`, `edit_event_screen`): the design's capital section headings and the theme's inputs; "Club" wording became "Venue" in Create Venue; three number fields no longer cut their labels off; the categories now load after the first build (a failure used to try to show its message before the screen existed).
- **Reports**: the Quick Statistics card is in the design's style.
- **Checks:** full suite **3,866 passed, 0 failed** (37 skipped, as before); 59 new tests in all (`classic_detail_screens_test` 27, `account_pages_test` 16, `event_pages_test` 9, `analytics_chart_test` 7); **deliberate breakages in a separate copy (since removed): 18 tried on this pass, 18 caught** (two were first not matched because the source had been reformatted and were re-pointed, not missed). **Correction to the first pass: the analyzer is NOT free of warnings;** it reports a few unused-import warnings in files this work never touched (`promoter_onboarding_screen`, `dashboard_service`, `report_recipients_screen`, `organizer_sales_screen`, two test files); I removed the ones in screens I edited and left the rest. No new error.
- **Seen live** on the simulator with the real account (Business details, Settings, Reports, Venues, More, Events, Create Event); the other pages from test pictures.

**Still themed only (new header, old body):** ticket tiers, team and lineup, event tables, guest list and scheduled releases pages (they work on live data that this account has none of, and they build their own service objects, so they cannot be rendered with fakes without a refactor), the event create / edit forms' fields (headings and inputs follow the theme; the layout is the old one), About, Privacy (already plain facts) and **Terms of Service, whose text is placeholder legal text dated "January 2025" and needs the client's real text** (only its banner was restyled).

## Things to know

- **Contrast:** white text on the design's orange (`#ff5a2f`) is about 3.3 : 1: enough for large or bold text, below the 4.5 : 1 for small text. The primary button follows the design (white). Black text on the orange would be 6.4 : 1; say if you prefer it.
- **Touch targets:** the top bar's two buttons are 44 points (the design draws 38); list rows are at least 64.
- **Previews:** screens were rendered to images from tests (real theme, bundled Inter, the existing fake backends) and looked at. Nothing has run on a phone.
- The Figma Make prototype is a web mock-up with demo data; it is a guide to look and tone, not a pixel specification.
