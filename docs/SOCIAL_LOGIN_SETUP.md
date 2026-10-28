# Google and Apple sign-in: what is built, and what only you can do

Written 28 Oct 2026. The code for both apps is on a branch called `feat/social-login` in each app's repository (nothing merged, nothing built, nothing tried on a phone). The buttons only work once the steps in sections 2 to 4 are done in the Apple, Google and Supabase consoles; Claude has no access to those.

## 1. What changed in the apps

| | Customer app (`com.btlup.pop`, `com.bottlesup.user`) | Vendor / business app (`com..bottlesUp.ORG`, `com.bottlesup.vendor`) |
|---|---|---|
| Before | Google and Apple code was in the app, but the buttons had been hidden since March and the iPhone project had no Sign in with Apple entitlement | No Google or Apple sign-in at all |
| Now | "Continue with Google" on the login and sign-up pages; "Continue with Apple" under it on iPhone. Sign in with Apple entitlement added. Google's return address added to `Info.plist`. Apple sign-in now also checks a one-time value (nonce), keeps the name Apple gives the first time, and writes the profile row again. Closing the Google or Apple sheet is no longer shown as "Login failed". | "Continue with Google" (Android) and "Continue with Apple" (iPhone) under the e-mail and phone sign-in. Sign in with Apple entitlement added. **Sign-in only** (see below). |
| Terms | Both buttons need the "I accept the terms" tick first, like the e-mail button, because a first sign-in makes the account | not needed (no account is made) |

**The vendor app never makes accounts.** Business accounts are made on the website, and an old bug that made a vendor row for every sign-in turned customer accounts into vendors. Supabase makes an account for any Google or Apple identity it has not seen, and the app cannot stop that. So when a Google or Apple sign-in has just made a new account, the app signs it out on that phone again and says "No BottlesUp Business account was found for this Google sign-in. Accounts are created on our website...". The exception is a person who opened an invitation link (they may have no account yet; the invitation gives it a place). An account that already existed, including one reached because the Google e-mail matches an existing e-mail account, signs in normally.

- One thing the app cannot undo: Supabase keeps the empty sign-in it created for that unknown Google or Apple identity. It has no business access and does nothing, but it is there. If you want those blocked, the website would need a Supabase "before user created" hook. Say so and Claude will propose it; it is a production change, so it waits for your yes.
- Apple's "Hide My Email" gives the app a private address, not the person's real one. Someone who hides their e-mail will not match their existing business account and will be told there is none. They should choose "Share My Email", or sign in with e-mail and password.

## 2. Apple (both apps)

1. Apple Developer, Identifiers: open the App ID for each app (`com.btlup.pop` and `com..bottlesUp.ORG`, team `4T453RG45S`) and switch on **Sign In with Apple**. With automatic signing Xcode will then add it to the profile; with a manual App Store profile, make a new profile.
2. Supabase, Authentication, Providers, **Apple**: the **Client IDs** field must list both bundle ids, separated by a comma: `com.btlup.pop,com..bottlesUp.ORG`. (The provider already reports as enabled on the project.) The iPhone sign-in needs nothing else there; the Services ID and secret key are only for sign-in on a website.
3. Account deletion: Apple asks apps that offer Sign in with Apple to cancel that sign-in when a person deletes their account. Both apps already delete an account through the website's `delete-account` function (Profile in the customer app, Settings in the vendor app). That function does not tell Apple yet. Check this with Apple's review notes before the first submission; it is website work, not app work.

## 3. Google (both apps)

Google keeps client ids in a Google Cloud project; the two apps use two different projects today, so each has its own list.

**Customer app** (Google Cloud project number `386838494006`, ids already in the code):
- iOS client `386838494006-tqo6ags4qbr2onoertn9e716jvv4rdnk` for bundle id `com.btlup.pop`, and web client `386838494006-j472kn5eh58552cln304f0b9l4daf7gh`. Check that both exist and the iOS one has the right bundle id.
- **Android client needed:** package `com.bottlesup.user`, with the SHA-1 of the upload key `85:DA:C5:A6:4C:6D:DC:E4:6F:9A:8F:E7:7D:E2:C3:E9:AD:D0:C9:CE`, and a second one with the SHA-1 Google Play shows under App integrity (App signing key certificate) once the app is on Play. Without it Google sign-in fails on Android with "developer error".

**Vendor app** (Firebase project `bottles-up-2d907`, project number `49598092873`):
- The web client `49598092873-vvb9c9oqi02o1e94iodqv9t5c8oeghp9` exists (it is in `google-services.json`) and is in the code.
- **Android client needed:** package `com.bottlesup.vendor`, with the upload key SHA-1 `F1:C8:48:AD:18:C2:B7:C7:5D:8F:02:75:7E:D6:10:D5:33:44:0E:D7` and the Play app signing SHA-1.
- **iOS client needed:** bundle id `com..bottlesUp.ORG`. **Send Claude its client id** (it is not secret). Two small changes then switch Google on for iPhone: the id in `lib/core/config/google_sign_in_config.dart` and its reversed form as a URL scheme in `ios/Runner/Info.plist`. Until then the vendor app offers only Apple on iPhone (and Google on Android).

**Both:** the Google OAuth consent screen must be **published** (not "Testing"), or only listed test users can sign in. In Supabase, Authentication, Providers, **Google**: the **Client IDs** field must list every client id the apps use, separated by commas: both web clients, both iOS clients and, to be safe, the Android ones. If the vendor web client is not in that list, every vendor Google sign-in is refused ("Unacceptable audience"; the app shows "Google sign-in is not set up for this app yet").

## 4. What Claude could and could not check

- Read from the project's public sign-in settings on 28 Oct: **Google, Apple, e-mail and phone sign-in are all switched on**, and sign-ups are allowed.
- **Not visible to Claude:** which client ids each provider lists, whether the Google clients and the Apple App ID capability exist, and whether the consent screen is published. These are the three console jobs above.
- **Not done:** nothing was run on a phone or simulator (Google sign-in does not work in the iOS simulator; Apple needs an Apple ID signed in on the phone). A test needs your go-ahead. Suggested checks on a real phone, per app: Google (existing account, then closing the sheet, then a brand-new Google account), Apple (same three, once with "Share My Email" and once with "Hide My Email"), then e-mail and phone sign-in still work.

## 5. When the branches are merged

- iOS, both apps: run `pod install` (the vendor app gains the Google and Apple plugins, so its `Podfile.lock` changes) and open the project in Xcode once to check the Signing & Capabilities tab shows Sign in with Apple.
- Re-archive and check the new build with `scripts/check_build_has_settings.sh` as usual.
- The privacy answers do not change: Google and Apple give the app the name and e-mail it already declares (`docs/DATA_COLLECTED_USER_APP.md`).
