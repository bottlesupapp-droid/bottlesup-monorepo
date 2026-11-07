# BottlesUp Business (vendor app): redesign to the Figma concept

Started 7 Nov 2026 on the user's "we need to redo the UI/UX of the vendor in this concept and tone ... without breaking any existing features and functions".
Design source: the Figma Make file "BottlesUp Business App" (https://www.figma.com/make/3uNiwVYsaUhbic9tdIWE2z/BottlesUp-Buisness-App). View-only for us.

## Decisions (the user's, 7 Nov)

1. **Dark only for now.** The Figma also has a Light theme (tokens below), but about 550 colours are hard-coded white/black inside screens, so light mode needs its own audit. A later step.
2. **Restyle only what exists.** Every current screen and function keeps working and gets the new look. What the Figma shows that the app lacks is listed below and NOT built.
3. **Phase by phase, one pull request each. Nothing is pushed until the user says so.**

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
| 1 | Foundation (tokens, theme, kit, Inter), the shell (top bar, floating bottom bar), sign-in, the shared auth fields and buttons, the workspace list | **BUILT 7 Nov** on local branch `design/phase1-foundation` (off PR #39's head, so it keeps the "page ends where the bar begins" fix); full suite passes; 103 new tests; 64 deliberate breakages, 63 caught, 1 equivalent. NOT pushed, no pull request, not run on a phone |
| 2 | The owner's five tabs: Overview, Venues, Tonight, Reports, More (hero card, stat tiles, needs-attention list, segmented switchers) | **BUILT 7 Nov** on local branch `design/phase2-owner-tabs` (off phase 1's `51a231c`). NOT pushed, no pull request, not run on a phone. Details below |
| 3 | The other roles' tabs (manager, organizer, door, server, security, verifier) | **BUILT 7 Nov** on local branch `design/phase3-other-roles` (`ab3e634`, on phase 2). NOT pushed, no pull request, not run on a phone. Details below |
| 4 | The long tail: the remaining screens (123 screens in all) | **BUILT (first pass) 7 Nov** on local branch `design/phase4-long-tail` (on phase 3). NOT pushed, no pull request, not run on a phone. Details below |

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

## In the Figma, not in the app (NOT built; each needs a decision)

- A **role chooser** ("How are you working tonight?") marked DEMO MODE. The real app already knows each person's role from their workspace; a chooser would be a demo feature.
- **Ambassador** and **Event lead** roles. The app's roles are owner, manager, organizer, server, door, security, verifier.
- A **booking-link QR page**, a **venue setup progress checklist** screen and a **nightly closing report** flow as drawn. (Parts of these may exist in the app in other forms; each would be checked before anything is added.)
- A **Dark / Light / System** setting (see decision 1).

## Things to know

- **Contrast:** white text on the design's orange (`#ff5a2f`) is about 3.3 : 1: enough for large or bold text, below the 4.5 : 1 for small text. The primary button follows the design (white). Black text on the orange would be 6.4 : 1; say if you prefer it.
- **Touch targets:** the top bar's two buttons are 44 points (the design draws 38); list rows are at least 64.
- **Previews:** screens were rendered to images from tests (real theme, bundled Inter, the existing fake backends) and looked at. Nothing has run on a phone.
- The Figma Make prototype is a web mock-up with demo data; it is a guide to look and tone, not a pixel specification.
