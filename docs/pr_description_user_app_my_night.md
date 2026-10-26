# Pull request for `bottles-up-user`: `feat/site-schema` into `master` (27 Oct 2026)

Open it at: https://github.com/bottlesupapp-droid/bottles-up-user/pull/new/feat/site-schema (base `master`). Pull requests #1 (archive cut) and #2 (site-schema work through My bookings) were already merged on 25 Oct; this one is what came after: three commits plus a merge of `master`, 78 files, about +4,600 / -1,100 lines. 496 tests pass; `flutter analyze` shows 6 issues (the hidden Google/Apple sign-in buttons, decision A7). **Nothing in it has been built or run on a phone or simulator.**

Title: `Customer app: My Night, store readiness, honest Settings, password-reset fix`

## What it does

**My Night (a table booking's own page)**
- Sections: Entry (QR), Reservation, Guests, Payments, Orders, Getting there; plus share and "Book again".
- Guests are invited by name and e-mail through the website's `manage-guest-tickets`; each guest gets their own QR ticket and can be sent it again. The host is one of the table's seats.
- Bottles show whether they are paid and, separately, where the venue has got to with them (`service_status`). More bottles can be ordered (paid on Stripe's page or at the club, as the venue allows); a bottle replacement can be approved or declined; a payment the club recorded can be confirmed or reported.
- A guest asks for a refund (`guest_request_refund`): the website's `cancel-table-booking` is staff-only, so there is no cancel button, by design.
- Plan items that fit the existing backend: Tonight / This weekend filters, "Book a table" from an event (opens the venue on the event's night), minimum-spend and deposit-credit wording and included passes before paying, directions and share on the ticket page, a paid table opens its own page.

**Store readiness (nothing built; owner steps listed below)**
- iOS privacy manifest in the Runner target, kept in step with an in-app list (Profile > What this app collects) and `docs/DATA_COLLECTED_USER_APP.md` by a test; export-compliance key.
- Android: the version comes from `pubspec.yaml` (it was hard-coded 1.0.0 (1)); a release build with no `key.properties` fails with a message instead of silently using the debug key; `key.properties.example`.

**Bugs found and fixed on the way**
- The password-reset e-mail sent people to `bottlesupapp://auth-callback/reset-password`, a scheme neither phone registers: the link could never open the app. Now `bottlesup://reset-password` (registered on both). The web-address filters (a host the website redirects away from, no page the app handles) and the old payment filter are gone.
- The Settings screen was switches that did nothing (push, analytics, location, dark mode, currency, clear cache) and invented e-mail addresses. Replaced by "Help and settings": account, how notifications work, BottlesUp's real contact details from the CMS (`site_content`), what the app collects, privacy policy, a data-copy request.
- The privacy screen's invented text is replaced by the website's privacy page; "Bottles Up" is "BottlesUp" everywhere (app name on both stores, headings, text).
- Log lines that printed a person's e-mail at sign-up are gone; a dead second password-reset path is gone.

**Docs**: `docs/USER_APP_PLAN_STATUS.md` maps the client's 15 Oct plan (a social-first app) to what exists: production has no social tables. `docs/production_snapshot/` is a read-only copy of what production holds (policies, columns, statuses), with a test that compares the app against it.

## Before or when you merge

1. **Supabase dashboard, one click:** Authentication > URL Configuration > Redirect URLs: add `bottlesup://reset-password`. Also check Authentication > Providers > Email > "Confirm email" is ON (the customer read policies compare e-mail addresses and never look at confirmation).
2. Nothing else is needed to merge: no migration, no function deploy, no change to the website or the vendor app.
3. After merging, the monorepo's submodule pointer for `apps/bottles-up-user` can move to the new `master` head (it was deliberately left alone until the branch merged).

## Owner steps before a store build (not done, not mine to do)

- Apple Developer: the App ID `com.btlup.pop` and signing for team `4T453RG45S`. Google Play: create the release keystore and `android/key.properties`, and back the keystore up.
- Answer Apple's App Privacy and Google's Data safety forms from `docs/DATA_COLLECTED_USER_APP.md`.
- Decide the first version number (`pubspec.yaml` says `2.0.1+3`), the Terms text (the app still shows text nobody at the client wrote), and whether profile pictures (stored in a public bucket) should become private.
- Say go for a real-device run with Stripe test cards (ticket, table with bottles, invite a guest, scan, order a bottle, ask for a refund, delete a test account). Gradle and Xcode were not run for the build-file edits: the Android edit is copied from the vendor app's working file; `xcodebuild -list` still opens the project.

## Test plan

- [x] `flutter test`: 496 pass (services against a pretend website through the real Supabase client; drift tests that read the website's SQL and functions and the production snapshot, mutation-checked; widget tests for every screen and route; platform-file tests).
- [x] `flutter analyze`: 6 issues left, all the hidden social sign-in buttons.
- [ ] Real device: not run.
