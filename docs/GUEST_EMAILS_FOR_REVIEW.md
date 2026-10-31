# The four guest e-mails, for you to read before they are switched on

Written 1 Nov 2026. **These are not being sent.** The app queues them (`site_outbox`); the function that sends them (`process-outbox`) is deployed but **not scheduled**, so staff see "Queued, not sent yet". Switching them on is one small step (a schedule), and I will only do it when you say so.

What a guest would receive, rendered from the real code with made-up details (Alex Morgan, Active Lounge, Booth 4). The wording was a first draft written from the client's brief and was meant to be reviewed before this is switched on. Each is plain text here; the real e-mail is the same words in the BottlesUp look.

## How they behave (so you know what "on" means)

- Sent a few minutes after the staff action, from `tickets@bottlesupapp.com` (or the address in `TICKETS_FROM_EMAIL`), through Resend, like the ticket e-mails.
- A message is **checked again when it goes out**: a guest who was un-seated is not told they are seated, a cleared estimate is not announced, an ended VIP membership is not invited.
- A message **older than 12 hours is never sent** ("your table is ready" a day late is worse than silence). The 3 messages in production today are from 20 to 22 October, so they would be marked failed, not sent.
- No address, or a made-up one, is marked failed with a reason a manager can read. Up to 5 tries, 10 minutes apart, if the provider fails.

## 1. You are seated

**Subject:** You're seated at Active Lounge

> Hi Alex Morgan,
>
> Your party has been seated at Active Lounge.
> Your server estimates about 25 minutes for bottle service.
>
> Venue: Active Lounge
> Table: Booth 4
> Party: 6 guests
> Arrival time: 10:30 PM
> Booking code: BU-7K2Q9
>
> View your booking: https://bottlesupapp.com/booking/BU-7K2Q9
>
> This message only lets you know where things stand. It does not change what you have paid or what is still due at the venue.

When: a server seats the party. (The estimate line is left out if no estimate was given.)

## 2. Updated service estimate

**Subject:** Updated service estimate at Active Lounge

> Hi Alex Morgan,
>
> The service estimate for your table at Active Lounge has changed.
> Your server now estimates about 40 minutes for bottle service.
>
> Venue: Active Lounge
> Table: Booth 4
> Party: 6 guests
> Arrival time: 10:30 PM
> Booking code: BU-7K2Q9
>
> View your booking: https://bottlesupapp.com/booking/BU-7K2Q9
>
> This message only lets you know where things stand. It does not change what you have paid or what is still due at the venue.

When: staff change the wait estimate of a seated table.

## 3. Your table is booked (a walk-in a manager booked)

**Subject:** Your table at Active Lounge is booked

> Hi Alex Morgan,
>
> Your table at Active Lounge is booked.
>
> Venue: Active Lounge
> Table: Booth 4
> Party: 6 guests
> Arrival time: 10:30 PM
> Booking code: BU-7K2Q9
> Still to pay at the club: $450.00
>
> View your booking: https://bottlesupapp.com/booking/BU-7K2Q9
>
> Show your booking code to the team at the venue. What is still to pay is paid at the club.

When: a manager books a table for a guest who is at the club.

## 4. Your VIP access

**Subject:** Your VIP access at Active Lounge

> Hi Alex Morgan,
>
> Active Lounge has added you to its VIP list. Give your code to the door team when you arrive.
>
> Venue: Active Lounge
> Level: Gold
> Your code: VIP-4821
> Valid from: 2026-11-01
> Valid until: 2027-11-01
>
> Keep this code to yourself. If you were not expecting this message, you can ignore it.

When: a club adds a guest to its VIP list. (The dates are shown as 2026-11-01; I can make them read "1 November 2026" if you prefer.)

## What I would suggest you look at

1. Is the sender name/address right for guests ("tickets@" for a table e-mail)?
2. The VIP dates read as `2026-11-01`: friendlier as "1 November 2026"?
3. The last line of e-mails 1 and 2 ("does not change what you have paid") is there on purpose so nobody reads a seating message as a receipt. Keep it?

When you are happy, say "switch the guest e-mails on" (and what to change). That is a schedule in the database plus a deploy check; it can be undone by removing the schedule.
