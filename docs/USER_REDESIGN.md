# BottlesUp customer app ("user app"): redesign to the prototype's look

Started 14 Nov 2026 on the user's "start working on user app ui". Same way of working as the vendor app's redesign (`docs/VENDOR_REDESIGN.md`).
Design source: the branch `prototype-web` of the customer repo (`bottlesupapp-droid/bottles-up-user`), folder `prototype/` (a React/Vite web demo, 42 files, made-up data). It was read as data and never run. It has dark and light looks, a five-tab shell (Home, Explore, Create, Inbox, Profile) and 16 screens' worth of layouts (`prototype/src/screens/*.tsx`: Booking, Camera, Dj, Explore, Feed, Home, Launch, Night, Organizer, Posts, Profile, Reels, Sign, Social, Venue, VenuePhotos) and the stylesheet `prototype/src/index.css`, which is where the tokens below come from.

## How it is being done (the same rules as the vendor redesign)

1. **Restyle what exists; do not change behaviour, data, routes, keys or sentences.** The existing tests pin them and still pass.
2. **Local branches, stacked, one pull request each, nothing pushed until the user says so.** The first branch is based on `fix/password-reset` (customer pull request #4, the top of the unmerged stack: #3 holds everything, #4 sits on it), because the redesign has to cover the screens that stack adds. Merge order when the time comes: #3, then #4, then these.
3. **Dark only for now.** The light tokens exist and the light theme is built, but nothing switches to it (see the questions).
4. **Looked at as images** (rendered from tests with the real fonts), not on a phone. Nothing has run on a phone.

## Tokens (the prototype's own values, `lib/core/theme/app_tokens.dart`)

| | Dark | Light |
|---|---|---|
| page (`--canvas`) | `#090909` | `#f7f7f5` |
| panel (`--surface`) / step up / raised | `#131313` / `#1c1c1c` / `#262626` | `#ffffff` / `#f0f0ed` / `#e7e7e3` |
| line (`--line`, also a card's edge) | `#2a2a2a` | `#deded9` |
| text: ink / soft / muted | `#f7f7f5` / `#d7d7d7` / `#959595` | `#161616` / `#424242` / `#626262` |
| brand orange / soft / 14% wash | `#ff6a00` / `#ff8a33` / `#ff6a00` at 14% | same |
| text on the orange | `#080808` (near-black) | same |
| success / danger | `#47c987` / `#ff5151` | same |
| amber | `#ffb258` (the design has none: the vendor app's) | `#b86a00` (mine) |
| bars | the canvas at 94% | white at 94% |

Corners: buttons and inputs 13, cards 16, hero card 20, icon tiles 12, sheets 23, pills 99. Side margin 18. Type: Inter (bundled), headings 700 to 800 with tight tracking, display title 29 / 800, top-bar title 17 / 700, body 14 / 1.55, eyebrow 12 / 800 orange capitals.

## Phases

| Phase | What | State |
|---|---|---|
| 1 | **Foundation and first-run:** tokens (dark + light), the theme rebuilt from them (`lib/theme/app_theme.dart`; text sizes unchanged so no layout moves), the component kit (`lib/core/ui/bu_kit.dart`: eyebrow, page and section headers, card, icon tile, list row and card, status pill, count badge, hero card, backdrop, wordmark), the bottom bar in the prototype's look (flat, current page orange, Create as a small orange tile; class name and keys kept), the splash, sign in, sign up, phone sign in, forgot / enter-the-code / reset password (official wordmark replaces the Syne text that was downloaded at run time; message, spinner and muted colours are tokens) | **BUILT 14 Nov**, local branch `design/phase1-foundation` (commits `b8a4a5e`, `799642d`, on `fix/password-reset` `7fa9eb8`). Analyzer clean; full suite 2102 passed (2046 before, 56 new), 0 failed. **Not pushed, no pull request, not run on a phone, no mutation check yet** |
| 2 | **The booking side:** Events, event page, Tables, floor plan, table booking and checkout, payment screens, confirmation, My bookings / tickets / My Night, split bill, billing | not started |
| 3 | **The social side:** Home feed and stories, Explore, Create, Inbox and chats, Profile and its settings, hire and jobs | not started |
| 4 | **The long tail:** the colours still written in screens (about 100 left: social 37, profile 9, tables 5, tickets 4, discover 2, shared 2, bookings 1, split 1, glass kit's own constants), icons (Iconsax in 11 files, Material in 96, Ionicons in the shell), headings on the rest | not started |
| 5 | **Gap check against the prototype** (propose, do not build unasked): what the prototype has that the app does not (the launch animation, the DJ booking, the organizer screens, the camera editor, venue photos) as sample screens, the way the vendor app's phase 5 did | to propose |

## Done in phase 1: what changed

- **Plain Material widgets already look like the design** because the theme says so: buttons are orange with near-black text (the design's choice; white on that orange would be 2.9 : 1), outlined secondary buttons, inputs with a line edge and an orange focus, chips as outlined pills with the selected one filled orange, 23-point sheets with a handle, switches orange when on, a toast-like snackbar. About 400 places in the app use `Theme.of(context)` and moved with it.
- **The bottom bar** (`GlassBottomNavBar`, still that name and still the keys `nav-home`, `nav-explore`, `nav-create`, `nav-inbox`, `nav-profile`, `nav-badge-*`): no longer a floating glass pill; flat, full width, the canvas at 94% over a blur with a one-pixel line on top, an icon over a 12-point label, the current page orange, Create a 42 by 32 orange tile, the unread badge orange.
- **First-run screens:** the wordmark is the prototype's own artwork, bundled (`assets/brand/wordmark_dark.png`, `wordmark_light.png`, copied from `prototype/public/`). The "BottlesUp" text in the Syne font (fetched from the internet at run time) is gone from every screen; the headings use the theme.
- **A guard:** `test/design/no_old_hues_test.dart` fails if a screen in a "moved" folder writes a Material hue or asks for a downloaded font. The folders it covers grow with each phase (now: auth, splash, the loading indicator, the kit, the theme).
- **Tests:** `test/design/` has 56 (tokens pinned one by one, contrast of text on every surface in both looks, the theme, every kit widget, the bar, the first-run screens).
- **Not changed:** behaviour, routes, keys, sentences; the social and classic shells' structure; every screen not named above (they pick up the theme but not the kit yet).
- **Found, not fixed:** the files `forgot_password_screen.dart`, `phone_login_screen.dart`, `splash_screen.dart` and `loading_indicator.dart` have Windows line endings (CRLF); they were kept so the diff stays small. Mixed icon sets (see phase 4).

## Questions saved for the user (nothing waits on them)

1. **Light or System appearance?** The prototype has Light / Dark / System in Settings. The light tokens and theme are built and tested, but about 100 colours are still written inside screens, so switching on would look wrong in places until phase 4 is done. In the prototype's own light look the orange is used for text too, and orange on the white page is about 2.5 : 1 (below the 4.5 : 1 for small text); the light theme keeps the designer's value. Say if you want a darker orange for text in light.
2. **Amber for warnings:** the design has no amber (it has green, red and orange). I used the vendor app's amber so both apps warn in the same colour. Say if you want something else.
3. **Text on the orange:** the design puts near-black on its orange; the app had white. I followed the design (it is also the one that passes contrast).
4. **Launch screen:** only the wordmark on the backdrop for now. The prototype animates a bottle and an eye (`prototype/public/launch/*.svg`, `src/screens/Launch.tsx`); say if you want that built.
5. **Icons:** one set (Ionicons, which the shell and the vendor app use) instead of three?
6. **Merge order:** this stack sits on customer #4, which sits on #3 (313 files, no CI on the customer repo). The redesign cannot be merged before them.

## To continue

The work is on the local branch `design/phase1-foundation` of the customer repo. Its scratch checkout was made under the session's scratchpad; if that is gone, make a new one from the branch: `git -C apps/bottles-up-user worktree prune`, then `git -C apps/bottles-up-user worktree add <somewhere>/apps/bottles-up-user design/phase1-foundation`, with `<somewhere>/packages` linking to the monorepo's `packages` and a sibling `bottles-up-website-main` (the pubspec has a path dependency `../../packages/shared`, and some tests read the website checkout). `~/.pub-cache` is root-owned (see `docs/VENDOR_APP_PENDING.md`), so use `PUB_CACHE=<scratch>/pubcache`. The branch has NO upstream on purpose: push it by name (`git push origin design/phase1-foundation`) and only when told.
