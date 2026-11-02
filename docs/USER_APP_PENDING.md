# Customer app ("user app", `bottles-up-user`): everything still pending

Written 2 Nov 2026 by Claude, on the user's "list all user app related task" and "note it in user app pending or handoff". **Read-only: nothing was built, merged, applied, deployed or uploaded for this list.**
Keep it current: tick a line when it is done and say where. The app's own list is `apps/bottles-up-user/REMAINING_WORK.md` (written 24 Oct, in the app's own repo, not touched here); the plan for the social side is `docs/USER_APP_COMPLETION_PLAN.md`; the client's plan mapped to the code is `apps/bottles-up-user/docs/USER_APP_PLAN_STATUS.md`; the console steps are in `docs/FINAL_STEPS.md` sections 0 to 0d and 6b to 6d and `docs/SOCIAL_LOGIN_SETUP.md`.

Bundle IDs: iOS `com.btlup.pop`, Android `com.bottlesup.user`. Apple team `4T453RG45S`. Version on `master`: `2.0.1+3`.

## 0. Where it stands (checked against GitHub on 2 Nov; everything else is from the notes)

- **Nothing in the customer app has ever run on a phone.** Every test used a pretend website.
- **`master` is the 25 Oct state** (pull requests #1 and #2 merged 24 Oct). **There are no open pull requests.** (The text for a "#3" from 27 Oct, `docs/pr_description_user_app_my_night.md`, was never opened and is now out of date: the branches grew.)
- **The four unmerged branches are one stack; the top one contains all the others:** `feat/site-schema` (4 commits ahead of `master`) is inside `feat/social-app` (18), which is inside `feat/social-login` (19), which is inside `feat/complete-profile` (20). One pull request from `feat/complete-profile` lands everything.
- **The backend for it is on two unmerged website branches:** `feat/social-backend` (18 commits ahead of website `main`; migrations `20261101100000` to `20261110100000`, the functions and the CMS pages) and `feat/profile-date-of-birth` (2 ahead; migration `20261112100000`). **They are 33 and 31 commits behind `main`.** Git finds no conflicts when each is merged into `main`, but both need refreshing and the whole database and unit suites run again before anything is applied. **`feat/social-backend` also changes `site-stripe-webhook` and `delete-account`, and `main` has changed `site-stripe-webhook` since** (the deposit combination code, redeployed 2 Nov as version 29): test the merged result before redeploying either.
- **Production has none of the social tables.** `20261112100000_profile_date_of_birth` is not applied either. The Apple sign-up fix (`20261031100000_signup_without_email`) is applied and merged (29 Oct).
- **Builds:** the 28 Oct TestFlight upload (2.0.1 build 3) opens to a white screen: it was made without the Supabase settings. `env.json` now exists on the user's Mac (git-ignored) and the app shows a proper "could not start" page instead, but **no new iOS build has been made.** The Android bundle 2.0.1 (build 5) was built 28 Oct with the correct customer-app upload key (iCloud `Btlup/usr`, SHA-1 `85:DA:C5…`) and **not uploaded**.

## 1. Built and tested, waiting to be shipped (so these are "pending" in the sense of merge, apply, build, upload, try)

- Events and tickets on the website's data; buying a ticket through the website's Stripe page (no card entry in the app).
- VIP table booking (venues, nights, live availability, floor plan, bottles, promo code, payment, confirmation).
- My bookings (tickets and tables), and "My Night": guests (invite by e-mail, each gets a QR), extra bottles, bottle replacements, club payments to confirm, refund terms and request, directions, share.
- Delete account; Google and Apple sign-in; "Complete your profile" before the home screen (e-mail, phone, date of birth, under 18 refused); the password-reset link fixed (asks for `bottlesup://reset-password`).
- The social side, all hidden behind switches: feed, posts, reels, stories, comments, Members Only, Explore and reviews, messages and notifications, reporting and moderation, group payments, hiring professionals, venue hire and teams, subscriptions, referrals and tips, ranks and jobs, AI caption ideas.
- Store files: iOS privacy manifest, `docs/DATA_COLLECTED_USER_APP.md`, Android version and signing check.

## 2. Yours to do: accounts, consoles, builds

- [ ] **Archive and upload a build WITH its settings** (iOS, new build number: the white-screen build was 3, `2.0.1+4` was prepared; Android must be above Play's latest, which showed 4, so the 28 Oct bundle is build 5). Check it first with `scripts/check_build_has_settings.sh`. Needs the merges in section 5 first if the build is to have the new screens.
- [ ] **Apple Developer:** register the App ID `com.btlup.pop` (if Apple says it is taken, tell Claude and pick another before anything is built); switch on Sign In with Apple for `com.btlup.pop` and `com..bottlesUp.ORG`; signing and provisioning.
- [ ] **Supabase, Providers, Apple:** Client IDs `com.btlup.pop,com..bottlesUp.ORG`. **Providers, Google:** every web and iOS client ID of both apps.
- [ ] **Google Cloud:** an Android client for `com.bottlesup.user` (upload-key SHA-1 now, Play app-signing SHA-1 once on Play), an iOS client for the customer app, the consent screen published. **The customer app has NOT been switched to the shared web client** that the vendor app uses (`49598092873-m0ulktdo…`): say so and Claude will.
- [ ] **Supabase, Authentication, URL Configuration, Redirect URLs:** add `bottlesup://reset-password`. **Providers, Email:** check "Confirm email" is ON.
- [ ] **Retry "Continue with Apple" on a phone** (the production fix is live; nobody has tried it on a phone).
- [ ] **The Android release keystore and `android/key.properties`** (keystore backed up), and **the store forms** (App Privacy, Data safety) from `docs/DATA_COLLECTED_USER_APP.md`; screenshots and descriptions.
- [ ] **The real-phone pass**, on the user's go: sign in, open an event, buy one ticket with a Stripe test card, see it with its QR, scan it with the vendor door scanner, book a table (test card), see the confirmation and scan its code, invite a guest and see their e-mail, order a bottle (paid on Stripe, and paid at the club), approve a replacement, ask for a refund, delete a test account. The complete-profile checks: a brand-new Apple sign-in lands on the form, 17 is refused, an existing account is asked once, the back button does not leave the form, Edit Profile shows the date and the age.

## 3. Decisions only the user (or the client) can make

- [ ] **First store release: booking-only, or with the social side?** (The client's own plan treats booking-only as phase one.)
- [ ] **Payment approach:** Stripe's hosted page in the app, no card entry, no Apple Pay (built this way). **Buying needs sign-in** (built this way; guest checkout would be a different flow).
- [ ] **Which cut features come back:** location, favourites, loyalty, the old notifications screen (all in `_archive/`). **Push notifications in version 1?** (needs a Firebase account and the Apple push capability). **Should Android's ID match iOS?**
- [ ] **Legal texts** (Terms, Privacy) and a **real support contact**: the Privacy screen still has invented `@bottlesup.com` addresses and Terms shows text nobody at the client wrote.
- [ ] **People who signed up with a phone number only** (6 accounts have no e-mail) see no bookings or tickets: ask for an e-mail after a phone sign-in, or look bookings up by phone?
- [ ] **Profile pictures** go to a public bucket: leave it (the in-app text says so) or make it private?
- [ ] **The complete-profile form:** it has only "Not you? Sign out" (no account deletion from it; deletion is reachable after it, as App Review expects) and requires a phone number (Apple sometimes questions that). Keep, or make the phone optional with "Not now"?
- [ ] **The first version number** (`2.0.1+3` on `master`).
- [ ] **Before the social side goes live:** write the **community rules** (CMS, Social settings) and decide **who reads the Moderation page every day**; decide the numbers in `docs/USER_APP_COMPLETION_PLAN.md` (D18 to D21 splitting, D23 to D28 hiring, D35 to D38 billing, D39 to D44 ranks); **how professionals are paid** (by hand today); **whether BottlesUp takes the venue-hire deposit** (D31); advertising and "Book With Me" links are not built (D41); **Apple may require its own in-app purchase for the subscription** (D45); the privacy-policy lines (words typed for caption ideas go to Anthropic; deleting an account removes the person's profiles, posts, comments, messages and pictures; plaque address and job applications).

## 4. Production steps: only on the user's explicit "apply it" (none done)

- [ ] **Profile date of birth:** pre-flight, apply `20261112100000_profile_date_of_birth` (adds the column and a trigger that keeps the age in step; changes nothing else), post-flight `supabase/audit/27_postflight_profile_date_of_birth.sql` (8 rows, all true). Apply it BEFORE the app that asks for the date, or saving fails with a plain "could not save".
- [ ] **The social bundle (10 migrations):** `supabase/audit/22_preflight_social.sql` (must return no rows), `supabase/go-live/apply_social.sql`, `23_postflight_social.sql` (18 of 18 true); then `supabase/go-live/schedule_social_cleanup.sql` (nightly 03:15 UTC) and `24_postflight_social_cleanup.sql`. Undo: `rollback_social.sql`. Order and detail: `supabase/go-live/README.md` section 1i. **The migration numbers `20261101` to `20261110` are lower than ones already applied (`20261111` to `20261120`): apply with `apply_one.sh`/the bundle, never `supabase db push`.**
- [ ] **Functions to deploy:** `suggest-caption`, `sweep-social-media`, `create-split-checkout`, `confirm-split-share`, `cancel-split`, `process-split-refunds`, `create-pro-checkout`, `confirm-pro-payment`, `cancel-pro-booking`, `process-pro-bookings`, `create-subscription-checkout`, `create-billing-portal`, `create-tip-checkout`, and the changed `site-stripe-webhook` and `delete-account` (**redeploy these two only from a branch that has been merged with `main`**: see section 0). Secret `ANTHROPIC_API_KEY` for caption ideas.
- [ ] **Schedules** (service-role key, like the chat purge): `sweep-social-media` daily; `process-split-refunds` and `process-pro-bookings` every few minutes.
- [ ] **Stripe:** add the webhook events `customer.subscription.updated` and `customer.subscription.deleted` (`checkout.session.completed` is already received).
- [ ] **CMS:** Hiring professionals (commission 5%, free-cancellation days 7, days before a job confirms itself 3), Subscriptions and tips (prices CAD 29.99 / 299, referral credit CAD 5, tip share 5%, tip limits CAD 2 to 500), Ranks and plaques, Community rules; then switch `split_payments`, `marketplace`, `venue_hire`, `subscriptions`, `referrals`, `creator_earnings`, `ranks`, `jobs`, `ai_captions` on **one at a time**.
- [ ] **Retire the old payment functions** `create-checkout-session` and `create-payment-intent` (still deployed and callable).
- [ ] **Three customer "read your own rows" policies** (table bookings, booking bottles, bottle substitutions) exist only in production: the website repo needs a migration for them, or a database rebuilt from the repo shows customers none of their bookings.

## 5. Claude can do now, without a client answer (waits for the user's go for each)

- [ ] **Open the pull request for the customer-app stack** (from `feat/complete-profile` into `master`), with fresh text; run its test suite on the result. Do not merge (the user merges).
- [ ] **Refresh the two website branches against `main`** (`feat/social-backend`, `feat/profile-date-of-birth`), rerun the full database and unit suites, fix what the 33 commits of drift break, open pull requests. Pay particular attention to `site-stripe-webhook` and `delete-account`.
- [ ] **A ticket refund request:** the website has none (only `guest_request_refund` for table bookings), so this is a website function plus the app screen.
- [ ] **Edit profile and the avatar** still use the old `profiles` and `media` tables: move them to the site schema or keep deliberately.
- [ ] **In-app notifications** (push stays blocked on Firebase).
- [ ] **Phone sign-ups' bookings** (once the user decides in section 3).
- [ ] **The website change** so `site-create-checkout-session` (and the table checkout) also return `session_id` and `order_id` (needs a deploy).
- [ ] **Test both account-deletion paths** with a test account (needs a phone or a test login).
- [ ] **Table-booking leftovers (B1):** the hourly table has no upper limit on the website but the app offers up to 12 hours; `min_guests` is only where the stepper starts; bottle sign text is not carried; bottle service status in "My bookings" is not shown.
- [ ] **Move the monorepo's submodule pointer** for `apps/bottles-up-user` once its branches merge.
- [ ] **Optional later:** universal links so website pages for events and venues open the app (needs the entitlement, the website's association files and a handler per page).

## 6. Touchpoints from the vendor app (the client's brief limits customer-facing work to these; it is not a redesign)

The brief (section 1 and "Customer outputs from vendor actions"): booking and guest-pass confirmation and resend; service acknowledgment and estimate; order progress; complimentary claim; VIP invite; payment receipt and update; booking change and refund status. "Do not announce success before the corresponding operation succeeds."

- [ ] **Guest e-mails:** four written (seated, updated estimate, walk-in booking, VIP invitation), **switched off** (`process-outbox` is not scheduled). Text to read first: `docs/GUEST_EMAILS_FOR_REVIEW.md`. The user says "switch the guest e-mails on" (and any wording changes). The 3 old queued messages (20 to 22 Oct) would be marked failed, not sent (12-hour rule).
- [ ] **The complimentary claim page** (vendor scenario 13, not built): a small website page the recipient opens from a secure link, sees venue, event, item and expiry, chooses a table on the floor map, one claim only. It needs a design pass first (it touches stock and orders; it would reuse `desk_request_free_bottle`).
- [ ] **Check the deposit wording.** The customer app's table-booking screens and "My Night" were built (24 and 25 Oct) before the deposit combination existed (applied 2 Nov). The amounts come from the server, but **nobody has checked whether the customer app's wording matches a booking whose deposit is a combination** (reservation fee, credit toward the minimum spend, admission). Check before the first build.
- [ ] **A customer's view of a sign on a bottle, a complimentary offer and a refund after settlement** follow the vendor work; no customer screen exists for the sign beyond what the guest typed at checkout.

## 7. Not in the first store release unless the user says otherwise

Location and maps, loyalty, ticket transfer and resale, venue comparison, and anything in the client's 15 Oct plan that needs a backend that does not exist yet (see `USER_APP_PLAN_STATUS.md`).

## Suggested first steps (Claude's recommendation)

1. Open the pull request for the customer-app stack and refresh the two website branches against `main` (section 5, first two lines): nothing here touches production.
2. The user does the console steps in section 2 that block a build (Apple App ID, the Supabase and Google provider IDs, the redirect URL).
3. The user decides section 3, first four lines (first release scope, payment approach, cut features and push, legal text).
4. Then a build and the real-phone pass, which is the biggest unknown.
