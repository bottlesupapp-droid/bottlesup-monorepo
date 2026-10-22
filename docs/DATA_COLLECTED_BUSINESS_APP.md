# What the BottlesUp Business app collects

For the client and the client's lawyer (answer 15 of 20 Oct: "the client arranges the legal wording; the developer explains what is collected; no placeholder as final").
Written 22 Oct 2026 from the code of the vendor app (`apps/bottles-up-vendor`, branch `feat/business-brief-3`). It is a list of facts, **not** a privacy policy: it makes no promise about
retention, region, legal basis or rights, because the app does not decide any of those. The same list is in the app under More > Settings > "What this app collects"
(`lib/features/profile/logic/data_collected.dart`); change both together.

## What the app collects or stores

| What | Where it goes | Who can see it |
|---|---|---|
| Sign-in email address or phone number, and name | BottlesUp's database (Supabase Auth and the `profiles` row) | The person; BottlesUp; the owner/manager of the business they work for sees their name and role in Team |
| Which businesses/clubs the person works for and their role | BottlesUp's database (`site_memberships`) | As above |
| Which workspace was used last | On the phone only (`shared_preferences`) | The phone |
| Bookings and guests: names; an email or phone number only where the staff member types one (walk-in booking, door sale, VIP list) | BottlesUp's database | By role: a server sees their tables, a manager the club, the owner the business. A guest's email is not sent to the server desk screens |
| Orders, deliveries, payments recorded (amount, method, till receipt number), refunds, discounts and free bottles, tables held or moved, notes, chat, incident reports, inventory, cash handovers | BottlesUp's database | By role |
| Who did each thing and when (the activity history) | BottlesUp's database (`audit_log` and the module tables) | Managers and owners of that club; BottlesUp |
| Receipt photos (payments and refunds) | Private storage bucket `club-payment-receipts`, filed under the booking | The people at that club who need to see a payment |
| Photos of a venue, table, bottle, event or floor plan | Public storage bucket `business-media` | Everyone who opens the booking pages |
| QR codes read by the camera | Not kept; the ticket or booking code is checked in the database and the scan result is logged against the staff member | The club's managers |
| Crash reports | Sentry, **only** when the installed build was made with a Sentry address; the person, the web requests, the trail of screens and screenshots are removed before sending | BottlesUp |

## What it does not collect

Location, contacts, an advertising identifier, any analytics profile or advertising SDK. No device identifier is sent with payments. No push notifications in this version. Card numbers
are never handled by the app (guests pay on the website through the payment provider).

## Other contact with outside services

* The text font (Inter) is fetched from Google Fonts the first time the app runs, so Google sees the phone's internet address. (Bundling the font with the app would remove this; say if you want it.)
* About every 15 seconds the app asks BottlesUp's server whether it answers, to tell the person when they are offline. No personal details are sent.

## Things that need the client

* **The legal privacy policy and terms** (the website's `/privacy-policy` page is what the app links to; the older in-app Terms of Service screen for classic vendor accounts is still generic text and needs the lawyer's wording).
* **Retention periods and region:** the app states none. They are decided by BottlesUp (database and storage settings).
* **Support contact details:** the classic vendor screens Contact Support and About still show `support@bottlesup.com` and a phone number `+1-800-BOTTLES (24/7)` that were typed in as placeholders; they need the real details (or removing).
* **Apple privacy answers / Google Data safety form:** they can be filled in from the table above; say if you want a pre-filled draft of each.
