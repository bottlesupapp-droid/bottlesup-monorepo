# Invitation links that open the BottlesUp Business app

An invitation e-mail contains `https://www.bottlesupapp.com/accept-invite?token=...`. Today a tap opens the website page. This is what it takes for the link to open the app instead (when it is installed), and what is already done in the code.

**Status (22 Oct 2026):** the Android side is in the code (`apps/bottles-up-vendor/android/app/src/main/AndroidManifest.xml`, branch `feat/business-brief-3`) but cannot work until the website vouches for the app (part 1). The iOS side is **not** wired in the code on purpose (part 2). Neither has been tried on a phone. Without these steps nothing breaks: the link keeps opening the website page, where the person can still paste the whole link into the app (the screen shown to a signed-in person with no workspace yet).

What the app already does with the link: it opens `/accept-invite?token=...`; for a person who is not signed in yet it keeps the token, shows the sign-in, and then takes them to the invitation (the routing is tested in `test/workspace/workspace_routing_test.dart`). `test/workspace/app_links_test.dart` keeps the Android filter in step with the link the app writes.

## 1. Android (Google)

The app declares that it handles `https://www.bottlesupapp.com/accept-invite*` (an intent filter with `autoVerify`). Android only trusts that after it fetches a file from the website that names this app and its signing certificate.

1. In the **Play Console** > your app > **Test and release > Setup > App signing** (also reached by "App integrity"): copy the **SHA-256 certificate fingerprint of the App signing key** (the one Google signs the store build with: NOT the upload key). If you also want to test a build installed from a file signed with your upload key, copy the **upload key certificate** SHA-256 as well (it is in the same page; the upload key is the one in `~/bottlesup-secrets/android/`).
2. Create `apps/bottles-up-website-main/public/.well-known/assetlinks.json` with exactly this content, putting your fingerprints in (each is 32 pairs of hex digits separated by colons):

   ```json
   [
     {
       "relation": ["delegate_permission/common.handle_all_urls"],
       "target": {
         "namespace": "android_app",
         "package_name": "com.bottlesup.vendor",
         "sha256_cert_fingerprints": [
           "THE:APP:SIGNING:KEY:SHA-256",
           "THE:UPLOAD:KEY:SHA-256:OPTIONAL"
         ]
       }
     }
   ]
   ```

3. Deploy the website. The file must be reachable, with no redirect, at `https://www.bottlesupapp.com/.well-known/assetlinks.json` and answer `200` as JSON. (`vercel.json` rewrites everything to the app's page, but Vercel serves a real file in `public/` first, so this works; check the address in a browser.) The invitation e-mail uses `www`, so `www` is the host that must serve it; if you also want the bare `bottlesupapp.com` to work, it needs the same file and a second `<data android:host>` line in the manifest.
4. Check it: Google's tester `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://www.bottlesupapp.com&relation=delegate_permission/common.handle_all_urls` must list `com.bottlesup.vendor` and your fingerprint. On a phone with the app installed from the Play Store (or an internal test track): `adb shell pm get-app-links com.bottlesup.vendor` must say `www.bottlesupapp.com: verified`. Then open an invitation link from an e-mail or a message: it opens the app on the invitation screen.

If the file is wrong or missing, Android simply does not verify and the link opens in the browser as today.

## 2. iOS (Apple): not wired in the code

Universal links need three things on Apple's side that are yours to do, so nothing was added to the Xcode project (adding an entitlement the App ID does not have makes the signed build fail):

1. In the **Apple Developer** account (team `4T453RG45S`) > Certificates, Identifiers & Profiles > Identifiers > the App ID of the app (bundle `com..bottlesUp.ORG` today; Apple may object to the double dot, so settle the final bundle ID first, because the file below names it) > enable the **Associated Domains** capability. Regenerate the App Store provisioning profile afterwards.
2. In Xcode (or `ios/Runner/Runner.entitlements` referenced by the Runner target's `CODE_SIGN_ENTITLEMENTS`), add the entitlement `com.apple.developer.associated-domains` with the value `applinks:www.bottlesupapp.com`.
3. Serve `https://www.bottlesupapp.com/.well-known/apple-app-site-association` (no extension, no redirect, `200`, ideally `Content-Type: application/json`; add a header rule for it in `vercel.json` when you add the file):

   ```json
   {
     "applinks": {
       "details": [
         {
           "appIDs": ["4T453RG45S.<THE FINAL BUNDLE ID>"],
           "components": [{ "/": "/accept-invite*" }]
         }
       ]
     }
   }
   ```

Tell Claude when 1 to 3 are done and it will wire the entitlement and check it; nothing here needs to be built until then. Until it is, an iOS tap opens the website page, as today.

## 3. What the link still cannot do

It does not sign anyone in, and it never accepts an invitation by itself: the invitation screen checks, in the database, that the token is real, still valid and for the signed-in person's e-mail, exactly as before.
