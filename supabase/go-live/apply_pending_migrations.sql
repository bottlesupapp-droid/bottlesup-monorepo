-- ALL PENDING MIGRATIONS IN ONE PASTE (website branch feat/business-brief-2, same bytes as supabase/migrations): the outbox claim migration and the eight tranche-2 migrations of the 15 Oct brief.
-- HOW: run supabase/audit/16_preflight_business_brief_2.sql FIRST (it must return no rows; it did on production on 19 Oct before this file was written), then paste this whole file into the
-- Supabase dashboard > SQL editor (production project) and Run. Each migration is wrapped in its own begin/commit, in this order, so an error rolls back THAT migration and stops the rest
-- (the earlier ones stay applied; send the error text, do not edit a file). Then run supabase/audit/17_postflight_business_brief_2.sql: every row ok = true.
-- UNDO: supabase/go-live/rollback_business_brief_2.sql (migrations 2 to 9) and supabase/go-live/rollback_outbox_claim.sql (migration 1).
-- NOT in here: the two September files (already live in production) and nothing else. Never use `supabase db push`.

-- ====================================================================================================
-- 20261019100000_outbox_claim
-- ====================================================================================================
begin;
-- Outbox sender, database side: hand a batch of queued messages to ONE sender at a time, and record how each one went.
--
-- Since 20261018110000 the app queues guest messages (table seated, wait estimate changed, VIP invitation) in public.site_outbox and nothing sent them.
-- The new edge function `process-outbox` sends them by e-mail. This file is the part that must not go wrong: two runs of the sender (a retry, a
-- slow run overlapping the next scheduled one) must never send the same message twice, and a message that keeps failing must stop being tried.
--
--   * outbox_claim(limit)    atomically picks up to `limit` (1 to 50) queued messages, oldest first, that nobody holds, stamps them as held
--                            (claimed_at) and counts the attempt. A hold lasts 10 minutes: if the sender dies half way, the message becomes
--                            available again after that, which is also the pause between a failed attempt and the next one.
--                            It uses FOR UPDATE SKIP LOCKED, so two runs at the same moment get different messages.
--   * outbox_finish(id, result, error)   result 'sent' marks it sent; 'retry' leaves it queued for another go (and fails it for good after the
--                            5th attempt); 'failed' fails it at once (no recipient, unknown kind, too old). Only a message that is still
--                            'queued' can change, so a late or repeated report cannot undo a final state. Returns the state it ended in, or
--                            null when there was nothing to change.
--
-- Both are for the service role only (the edge function). Nothing a person can call. Plain CREATE, never CREATE OR REPLACE. One column is added to
-- a table that has existed since 18 Oct; no row is changed.

alter table public.site_outbox add column claimed_at timestamptz;

create function public.outbox_claim(p_limit int default 20)
returns table (id uuid, kind text, venue_id uuid, ref_id uuid, payload jsonb, attempts int, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  update public.site_outbox o
     set claimed_at = clock_timestamp(), attempts = o.attempts + 1
   where o.id in (
     select q.id
       from public.site_outbox q
      where q.status = 'queued'
        and q.attempts < 5
        and (q.claimed_at is null or q.claimed_at < clock_timestamp() - interval '10 minutes')
      order by q.created_at, q.id
      limit least(greatest(coalesce(p_limit, 20), 1), 50)
        for update skip locked
   )
  returning o.id, o.kind, o.venue_id, o.ref_id, o.payload, o.attempts, o.created_at
$$;

create function public.outbox_finish(p_id uuid, p_result text, p_error text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.site_outbox;
  v_state text;
begin
  if p_result is null or p_result not in ('sent', 'retry', 'failed') then
    raise exception 'result must be sent, retry or failed';
  end if;

  select * into v_row from public.site_outbox where id = p_id and status = 'queued' for update;
  if not found then return null; end if;

  if p_result = 'sent' then
    v_state := 'sent';
  elsif p_result = 'failed' or v_row.attempts >= 5 then
    v_state := 'failed';
  else
    v_state := 'queued';
  end if;

  update public.site_outbox
     set status = v_state,
         sent_at = case when v_state = 'sent' then clock_timestamp() else sent_at end,
         last_error = case when v_state = 'sent' then null else left(nullif(btrim(p_error), ''), 500) end
   where id = p_id;
  return v_state;
end;
$$;

revoke all on function public.outbox_claim(int), public.outbox_finish(uuid, text, text) from public, anon, authenticated;
grant execute on function public.outbox_claim(int), public.outbox_finish(uuid, text, text) to service_role;
commit;

-- ====================================================================================================
-- 20261020100000_venue_payment_rules
-- ====================================================================================================
begin;
-- Payment settings of a venue, for the people who run it (developer brief 15 Oct, section 15: "Bottle payments: Pay Ahead / Pay at Venue / Customer
-- Chooses"; "Deposit required, amount per table or package, recipient, purpose").
--
--   * venue_payment_rules(venue)       what the venue's payment settings are now (owner or manager of that venue).
--   * save_venue_payment_rules(venue, details)   changes the bottle payment mode, and ONLY that.
--
-- Why only the bottle payment mode is changeable here:
--   * bottle_payment_mode ('pay_ahead' | 'pay_at_club' | 'both') is read by the checkout when a booking is made and stored on the booking
--     (bottle_payment_choice), so changing it affects NEW bookings only. Existing bookings keep the terms they were made under.
--   * deposit_is_credit (the deposit is credited against the bottle bill) is NOT stored per booking: the checkout, the totals and the
--     reconciliation read the venue's current value. Changing it would change how bookings that already exist are worked out, which the brief
--     forbids ("existing bookings retain their original terms"). It is therefore read-only here until each booking carries its own copy; asking to
--     change it is refused with a plain sentence. (BottlesUp staff can still change it in the CMS, as before.)
--   * the deposit amount is per table type and already has its own editor (save_venue_table_type).
--
-- Both columns exist in production but are defined by no migration in this repository (they were added by hand); the first statement stops
-- this migration if they are missing, rather than guessing. Plain CREATE FUNCTION; setup_* helpers are from 20261010100000_venue_setup.sql.

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'bottle_payment_mode')
     or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'deposit_is_credit') then
    raise exception 'site_venues.bottle_payment_mode and site_venues.deposit_is_credit must exist before this migration. Nothing was changed.';
  end if;
end $$;

create function public.venue_payment_rules(p_venue uuid)
returns table (bottle_payment_mode text, deposit_is_credit boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_venue_editor(p_venue);
  return query select v.bottle_payment_mode::text, v.deposit_is_credit from public.site_venues v where v.id = p_venue;
end;
$$;

create function public.save_venue_payment_rules(p_venue uuid, p_details jsonb)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mode text;
  v_old text;
begin
  perform public.require_venue_editor(p_venue);
  if p_details is not null and jsonb_typeof(p_details) = 'object' and p_details ? 'deposit_is_credit' then
    raise exception 'whether the deposit is credited against the bottle bill cannot be changed here, because bookings that already exist are worked out with it; ask the BottlesUp team';
  end if;
  perform public.setup_only_keys(p_details, array['bottle_payment_mode']);

  v_mode := public.setup_text(p_details, 'bottle_payment_mode', 'bottle payment', 20);
  if v_mode is null then raise exception 'choose how bottles are paid'; end if;
  if v_mode not in ('pay_ahead', 'pay_at_club', 'both') then raise exception 'bottle payment must be pay ahead, pay at the venue, or the customer chooses'; end if;

  select v.bottle_payment_mode::text into v_old from public.site_venues v where v.id = p_venue for update;
  if not found then raise exception 'not allowed'; end if;
  if v_old = v_mode then return v_mode; end if;

  update public.site_venues set bottle_payment_mode = v_mode where id = p_venue;
  perform public.venue_setup_log('venue.payment_rules_saved', 'site_venues', p_venue, p_venue, jsonb_build_object('bottle_payment_mode_from', v_old, 'bottle_payment_mode_to', v_mode));
  return v_mode;
end;
$$;

revoke all on function public.venue_payment_rules(uuid), public.save_venue_payment_rules(uuid, jsonb) from public, anon;
grant execute on function public.venue_payment_rules(uuid), public.save_venue_payment_rules(uuid, jsonb) to authenticated, service_role;
commit;

-- ====================================================================================================
-- 20261020110000_booking_guests_and_activity
-- ====================================================================================================
begin;
-- A booking's Guests and Activity (developer brief 15 Oct, section 14: "Tables & Bookings > Night > Booking. Tabs: Overview | Orders | Payments | Guests |
-- Activity"; "guest allowance", "check-in status, changes and cancellations"; section 19: "Retain failed, refunded and adjusted transactions ... without deleting history").
--
--   * desk_booking_guests(booking)     who is on the booking: the holder and each invited guest ticket (name, whether the ticket was e-mailed,
--                                      whether they are in), the party size, the table's guest limit and how many more guests can be invited.
--                                      The manager or owner of the club, and the server who was given the table. NEVER an e-mail address or phone.
--   * desk_booking_activity(booking)   what happened to the booking, newest first: payments recorded, verified, flagged and resolved, bottle service
--                                      moves, seating and estimates, server changes, and every scan at the door. Manager or owner of the club only.
--                                      Staff are named by profile name ("Staff member" when they have none), never by e-mail; only a fixed list of
--                                      detail fields is passed on (amounts, methods, statuses, reasons), never a whole audit record.
--
-- Both are read only. Both answer "not allowed" for a booking that does not exist or belongs to another club, so a stranger cannot learn which
-- ids exist. Plain CREATE FUNCTION. Needs the server desk and payments (20261014*), cash and flags (20261018100000), seating (20261018110000)
-- and guest tickets (20260923100000) migrations.

create function public.desk_booking_guests(p_booking uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_level text;
  b record;
  v_guests jsonb;
  v_issued int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  v_level := public.desk_booking_level(p_booking);
  if v_level is null or v_level not in ('manager', 'server') then raise exception 'not allowed'; end if;

  select bk.customer_name, bk.guest_count, bk.checked_in_at, coalesce(tt.max_guests, bk.guest_count) as max_guests, tt.name as table_name
    into b
    from public.site_table_bookings bk
    join public.site_table_types tt on tt.id = bk.table_type_id
   where bk.id = p_booking;
  if not found then raise exception 'not allowed'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', g.id, 'name', g.guest_name, 'ticket_sent', g.ticket_sent_at is not null, 'checked_in_at', g.checked_in_at
         ) order by g.created_at, g.id), '[]'::jsonb), count(*)::int
    into v_guests, v_issued
    from public.guest_tickets g
   where g.booking_id = p_booking;

  return jsonb_build_object(
    'holder_name', b.customer_name,
    'holder_checked_in_at', b.checked_in_at,
    'party_size', b.guest_count,
    'max_guests', b.max_guests,
    'table_name', b.table_name,
    'guests', v_guests,
    'guests_issued', v_issued,
    'guests_in', (select count(*)::int from jsonb_array_elements(v_guests) x where x ->> 'checked_in_at' is not null),
    -- the same rule the guest ticket function uses: the holder plus the invited guests fit the table's guest limit
    'guests_left', greatest(b.max_guests - 1 - v_issued, 0)
  );
end;
$$;

create function public.desk_booking_activity(p_booking uuid, p_limit int default 100)
returns table (at timestamptz, kind text, action text, actor text, details jsonb)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.desk_booking_level(p_booking) is distinct from 'manager' then raise exception 'not allowed'; end if;

  return query
  with pay as (select p.id from public.site_table_booking_club_payments p where p.booking_id = p_booking),
       line as (select l.id from public.site_table_booking_bottles l where l.booking_id = p_booking),
       flag as (select f.id from public.site_payment_flags f where f.payment_id in (select id from pay)),
  events as (
    select a.created_at as at, 'audit'::text as kind, a.action as action, a.actor_id as actor_id,
           (select coalesce(jsonb_object_agg(k, v), '{}'::jsonb)
              from jsonb_each(coalesce(a.details, '{}'::jsonb)) as d(k, v)
             where k in ('amount_paid_cents', 'billed_amount_cents', 'payment_method', 'old_status', 'new_status', 'reason',
                         'estimate_minutes', 'from_minutes', 'to_minutes', 'method', 'recorded_as', 'resolution')) as details
      from public.audit_log a
     where (a.entity_type = 'site_table_bookings' and a.entity_id = p_booking::text)
        or (a.entity_type = 'site_table_booking_bottles' and a.entity_id in (select id::text from line))
        or (a.entity_type = 'site_table_booking_club_payments' and a.entity_id in (select id::text from pay))
        or (a.entity_type = 'site_payment_flags' and a.entity_id in (select id::text from flag))
    union all
    select s.created_at, 'scan', 'scan.' || s.result, s.scanned_by,
           jsonb_build_object('guest', s.guest_ticket_id is not null)
      from public.scan_attempts s
     where s.booking_id = p_booking
  )
  select e.at, e.kind, e.action,
         case when e.actor_id is null then 'Staff member' else coalesce(nullif(btrim(pr.name), ''), 'Staff member') end,
         e.details
    from events e
    left join public.profiles pr on pr.id = e.actor_id
   order by e.at desc, e.action
   limit v_limit;
end;
$$;

revoke all on function public.desk_booking_guests(uuid), public.desk_booking_activity(uuid, int) from public, anon;
grant execute on function public.desk_booking_guests(uuid), public.desk_booking_activity(uuid, int) to authenticated, service_role;
commit;

-- ====================================================================================================
-- 20261020120000_org_event_states
-- ====================================================================================================
begin;
-- Where each of an organizer's events stands, and exactly what blocks publishing it (developer brief 15 Oct, section 10: "Statuses: Draft, Awaiting
-- Venue Approval, Ready to Publish, Live, Ended and Cancelled. Permit draft work while approval is pending and explain exactly what blocks publishing.").
--
-- list_org_event_states(org) answers for the events of an organizer's business (the organizer only, like list_org_events):
--   state     draft | awaiting_venue_approval | ready_to_publish | live | ended
--   blockers  what still stands between a draft and publishing, as keys the app words:
--               business_verification  the business is not verified yet
--               venue_request          no club has been asked to host the event
--               venue_declined         the club that was asked declined (or the request was cancelled)
--               venue_approval         a club was asked and has not agreed terms yet
--   agreement_id / agreement_status / venue_name: the club connection behind it, when there is one.
--
-- Worked out from what exists, never stored: an event is LIVE when it is published and has not ended (it ended when its end time passed, or 12 hours
-- after it started when it has none, the same rule the app uses), READY TO PUBLISH only when the business is verified AND a club has agreed terms (an
-- active agreement, or one with changes proposed on top of an agreed version), AWAITING VENUE APPROVAL while a club has been asked and has not agreed.
-- A published event has no blockers. "Cancelled" is not here: events have no cancelled status in the database yet, so none is shown rather than guessed.
-- Publishing itself is still done by the BottlesUp team (an organizer cannot publish). Plain CREATE FUNCTION; read only.

create function public.list_org_event_states(p_org uuid)
returns table (event_id uuid, state text, blockers text[], agreement_id uuid, agreement_status text, venue_name text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_verified boolean;
begin
  perform public.require_org_organizer(p_org);
  select coalesce((select v.state = 'verified' from public.site_verifications v where v.org_id = p_org), false) into v_verified;

  return query
  select e.id,
         case
           when e.status = 'published' then
             case when coalesce(e.end_date, e.start_date + interval '12 hours') < now() then 'ended' else 'live' end
           when a.status in ('requested', 'negotiating') or (a.status = 'changes_pending' and a.active_version is null) then 'awaiting_venue_approval'
           when (a.status = 'active' or (a.status = 'changes_pending' and a.active_version is not null)) and v_verified then 'ready_to_publish'
           else 'draft'
         end,
         case
           when e.status = 'published' then '{}'::text[]
           else array_remove(array[
                  case when not v_verified then 'business_verification' end,
                  case when a.id is null and d.id is null then 'venue_request' end,
                  case when a.id is null and d.id is not null then 'venue_declined' end,
                  case when a.status in ('requested', 'negotiating') or (a.status = 'changes_pending' and a.active_version is null) then 'venue_approval' end
                ], null)
         end,
         coalesce(a.id, d.id),
         coalesce(a.status, d.status),
         ven.name
    from public.site_events e
    left join lateral (
      select ag.* from public.site_agreements ag
       where ag.event_id = e.id and ag.organizer_org_id = p_org and ag.status not in ('declined', 'cancelled')
       -- an event asked of two clubs follows the one that has agreed; otherwise the most recent request
       order by (ag.status = 'active' or (ag.status = 'changes_pending' and ag.active_version is not null)) desc, ag.requested_at desc limit 1
    ) a on true
    left join lateral (
      select ag.* from public.site_agreements ag
       where ag.event_id = e.id and ag.organizer_org_id = p_org and ag.status in ('declined', 'cancelled')
       order by ag.closed_at desc limit 1
    ) d on true
    left join public.site_venues ven on ven.id = coalesce(a.venue_id, d.venue_id)
   where e.org_id = p_org
   order by e.start_date desc, e.created_at desc;
end;
$$;

revoke all on function public.list_org_event_states(uuid) from public, anon;
grant execute on function public.list_org_event_states(uuid) to authenticated, service_role;
commit;

-- ====================================================================================================
-- 20261020130000_organizer_door_staff
-- ====================================================================================================
begin;
-- Organizer-provided door staff, when the club permits it (developer brief 15 Oct, "Latest decisions": "Organizers can invite their own door staff when the venue
-- permits it"; section 25: "Agreement setting: Allow Organizer Door Staff - Yes / No. Once approved, organizer invites within agreed permissions ... Venue managers
-- see assignments and can revoke venue access. Door staff cannot change pricing, issue refunds or access banking").
--
-- THE RULE (decided in the database, not by hiding buttons): an organizer may invite door staff for an event only if
--   * the event has NO connection with a club (the organizer's own event: as before), or
--   * the event's club agreement is APPROVED (active, or changes proposed on top of an agreed version) AND the club has ALLOWED organizer door staff on it.
-- The club's permission is a switch on the agreement, off until the club turns it on. Turning it off also cancels the invitations still waiting; people already
-- in keep their access until the club (or the organizer) removes them one by one.
--
--   * site_agreements.organizer_door_staff   the club's permission (additive column, false by default; no row is changed)
--   * event_door_allowed(event)              the rule above (internal)
--   * invite_member(...)                     REPLACED, compare-and-swap (see below): the same function plus ONE line that applies the rule to event invitations
--   * organizer_event_door_status(org)       for the organizer: per event, own event / allowed / not allowed / awaiting the club's approval
--   * venue_door_permissions(venue)          for the club's owner or manager: each live agreement and whether door staff is allowed
--   * set_organizer_door_staff(agreement, allowed)   the club turns it on or off
--   * venue_event_door_staff(venue)          the organizers' door staff and invitations at the club's events: who, which event, state
--   * revoke_event_door_access(membership | invitation)   the club takes someone's access away (the organizer already can, through revoke_membership)
--
-- GUARD for the one replaced live function (invite_member, 20261006120000, in production since 16 Oct): it is replaced only if it is exactly the version this
-- repository has; if it already has the rule nothing is replaced; anything else STOPS, changes nothing. Everything is one statement: all or nothing.
-- Needs the tenancy, team invitations, organizer events and event agreements migrations.

do $migration$
declare
  v_live text;
  v_src text;
  c_before constant text := 'cada6eec917b99ecd953f4c4dcb64040';  -- invite_member as 20261006120000 defines it
begin
  select md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')), p.prosrc
    into v_live, v_src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'invite_member'
     and pg_get_function_identity_arguments(p.oid) = 'p_org uuid, p_email text, p_role text, p_venue uuid, p_event uuid, p_shift uuid, p_access_start timestamp with time zone, p_access_end timestamp with time zone, p_valid_for interval';
  if v_live is null then
    raise exception 'public.invite_member does not exist in this database. Nothing was changed.';
  end if;
  if position('event_door_allowed' in v_src) > 0 then
    raise notice 'invite_member() already applies the door staff rule: this change is already applied. Nothing was changed.';
    return;
  end if;
  if v_live <> c_before then
    raise exception 'invite_member() in this database differs from the version this change was written against (live fingerprint %, expected %). It was NOT replaced, because that could undo a change made directly in the database. Inspect it with \sf public.invite_member and reconcile by hand. Nothing was changed.', v_live, c_before;
  end if;

  execute $sql$ alter table public.site_agreements add column organizer_door_staff boolean not null default false $sql$;

  execute $sql$
    create function public.event_door_allowed(p_event uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as $$
      select case
        when not exists (select 1 from public.site_agreements a where a.event_id = p_event and a.status not in ('declined', 'cancelled')) then true
        else exists (
          select 1 from public.site_agreements a
           where a.event_id = p_event
             and (a.status = 'active' or (a.status = 'changes_pending' and a.active_version is not null))
             and a.organizer_door_staff
        )
      end
    $$
  $sql$;

  execute $sql$
    create or replace function public.invite_member(
      p_org uuid, p_email text, p_role text,
      p_venue uuid default null, p_event uuid default null, p_shift uuid default null,
      p_access_start timestamptz default null, p_access_end timestamptz default null,
      p_valid_for interval default interval '7 days'
    )
    returns table (invitation_id uuid, token text, valid_until timestamptz)
    language plpgsql
    security definer
    set search_path = public
    as $$
    declare
      v_uid uuid := auth.uid();
      v_email text := lower(trim(coalesce(p_email, '')));
      v_token text;
      v_hash bytea;
      v_id uuid;
      v_exp timestamptz;
    begin
      if v_uid is null then raise exception 'not authenticated'; end if;
      if position('@' in v_email) < 2 then raise exception 'valid email required'; end if;
      if p_valid_for <= interval '0' or p_valid_for > interval '30 days' then raise exception 'invalid expiry'; end if;
      if p_access_start is not null and p_access_end is not null and p_access_end <= p_access_start then
        raise exception 'invalid access window';
      end if;
      if not public.can_invite_role(p_org, p_role, p_venue, p_event) then raise exception 'not allowed'; end if;
      if p_event is not null and not public.event_door_allowed(p_event) then
        raise exception 'the club has not allowed door staff for this event';
      end if;
      if p_shift is not null and not exists (
        select 1 from public.site_shifts s where s.id = p_shift and p_venue is not null and s.venue_id = p_venue
      ) then
        raise exception 'shift does not belong to this venue';
      end if;

      v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
      v_hash := sha256(convert_to(v_token, 'utf8'));
      v_exp := now() + p_valid_for;

      select i.id into v_id
      from public.site_invitations i
      where i.org_id = p_org and i.email = v_email and i.role = p_role and i.status = 'pending'
        and i.venue_id is not distinct from p_venue
        and i.event_id is not distinct from p_event
        and i.shift_id is not distinct from p_shift
      for update;

      if v_id is not null then
        update public.site_invitations
          set token_hash = v_hash, expires_at = v_exp, invited_by = v_uid,
              access_start_at = p_access_start, access_end_at = p_access_end
          where id = v_id;
      else
        insert into public.site_invitations
          (org_id, email, role, venue_id, event_id, shift_id, access_start_at, access_end_at, token_hash, expires_at, invited_by)
        values
          (p_org, v_email, p_role, p_venue, p_event, p_shift, p_access_start, p_access_end, v_hash, v_exp, v_uid)
        returning id into v_id;
      end if;

      return query select v_id, v_token, v_exp;
    end;
    $$
  $sql$;

  execute $sql$
    create function public.organizer_event_door_status(p_org uuid)
    returns table (event_id uuid, event_title text, state text, agreement_id uuid, club_name text)
    language plpgsql
    stable
    security definer
    set search_path = public
    as $$
    #variable_conflict use_column
    begin
      perform public.require_org_organizer(p_org);
      return query
        select e.id, e.title,
               case
                 when a.id is null then 'own_event'
                 when not (a.status = 'active' or (a.status = 'changes_pending' and a.active_version is not null)) then 'awaiting_approval'
                 when a.organizer_door_staff then 'allowed'
                 else 'not_allowed'
               end,
               a.id, v.name
          from public.site_events e
          left join lateral (
            select ag.* from public.site_agreements ag
             where ag.event_id = e.id and ag.organizer_org_id = p_org and ag.status not in ('declined', 'cancelled')
             order by (ag.status = 'active' or (ag.status = 'changes_pending' and ag.active_version is not null)) desc, ag.requested_at desc limit 1
          ) a on true
          left join public.site_venues v on v.id = a.venue_id
         where e.org_id = p_org
         order by e.start_date desc, e.created_at desc;
    end;
    $$
  $sql$;

  execute $sql$
    create function public.venue_door_permissions(p_venue uuid)
    returns table (agreement_id uuid, event_id uuid, event_title text, event_start timestamptz, organizer_name text, agreement_status text, approved boolean, door_staff_allowed boolean)
    language plpgsql
    stable
    security definer
    set search_path = public
    as $$
    #variable_conflict use_column
    begin
      perform public.require_venue_editor(p_venue);
      return query
        select a.id, e.id, e.title, e.start_date, o.name, a.status,
               (a.status = 'active' or (a.status = 'changes_pending' and a.active_version is not null)),
               a.organizer_door_staff
          from public.site_agreements a
          join public.site_events e on e.id = a.event_id
          join public.site_organizations o on o.id = a.organizer_org_id
         where a.venue_id = p_venue and a.status not in ('declined', 'cancelled')
         order by e.start_date desc, a.requested_at desc;
    end;
    $$
  $sql$;

  execute $sql$
    create function public.set_organizer_door_staff(p_agreement uuid, p_allowed boolean)
    returns boolean
    language plpgsql
    security definer
    set search_path = public
    as $$
    declare
      a public.site_agreements;
      v_cancelled int := 0;
    begin
      if auth.uid() is null then raise exception 'not authenticated'; end if;
      if p_allowed is null then raise exception 'choose yes or no'; end if;
      select * into a from public.site_agreements where id = p_agreement for update;
      if not found or not public.can_access_venue(a.venue_id, array['owner', 'manager']) then raise exception 'not allowed'; end if;
      if a.status in ('declined', 'cancelled') then raise exception 'this agreement has ended'; end if;
      if a.organizer_door_staff = p_allowed then return p_allowed; end if;

      update public.site_agreements set organizer_door_staff = p_allowed where id = p_agreement;
      if not p_allowed then
        update public.site_invitations i
           set status = 'revoked', revoked_at = now(), revoked_by = auth.uid()
         where i.event_id = a.event_id and i.role = 'door' and i.status = 'pending';
        get diagnostics v_cancelled = row_count;
      end if;
      perform public.desk_log('agreement.door_staff_set', 'site_agreements', p_agreement,
        jsonb_build_object('venue_id', a.venue_id, 'event_id', a.event_id, 'allowed', p_allowed, 'pending_invitations_cancelled', v_cancelled));
      return p_allowed;
    end;
    $$
  $sql$;

  execute $sql$
    create function public.venue_event_door_staff(p_venue uuid)
    returns table (membership_id uuid, invitation_id uuid, event_id uuid, event_title text, organizer_name text, person text, state text, access_start_at timestamptz, access_end_at timestamptz)
    language plpgsql
    stable
    security definer
    set search_path = public
    as $$
    #variable_conflict use_column
    begin
      perform public.require_venue_editor(p_venue);
      return query
        select m.id, null::uuid, e.id, e.title, o.name,
               coalesce(nullif(btrim(p.name), ''), u.email::text),
               case when m.status = 'revoked' then 'revoked'
                    when m.access_end_at is not null and m.access_end_at < now() then 'expired'
                    when m.access_start_at is not null and m.access_start_at > now() then 'scheduled'
                    else 'active' end,
               m.access_start_at, m.access_end_at
          from public.site_memberships m
          join public.site_events e on e.id = m.event_id
          join public.site_organizations o on o.id = m.org_id
          join auth.users u on u.id = m.user_id
          left join public.profiles p on p.id = m.user_id
         where m.role = 'door'
           and exists (select 1 from public.site_agreements a where a.event_id = m.event_id and a.venue_id = p_venue and a.status not in ('declined', 'cancelled'))
        union all
        select null::uuid, i.id, e.id, e.title, o.name, i.email,
               case when i.expires_at < now() then 'invitation_expired' else 'invited' end,
               i.access_start_at, i.access_end_at
          from public.site_invitations i
          join public.site_events e on e.id = i.event_id
          join public.site_organizations o on o.id = i.org_id
         where i.role = 'door' and i.status = 'pending'
           and exists (select 1 from public.site_agreements a where a.event_id = i.event_id and a.venue_id = p_venue and a.status not in ('declined', 'cancelled'))
         order by 4, 6;
    end;
    $$
  $sql$;

  execute $sql$
    create function public.revoke_event_door_access(p_membership uuid default null, p_invitation uuid default null)
    returns void
    language plpgsql
    security definer
    set search_path = public
    as $$
    declare
      v_event uuid;
      v_venue uuid;
    begin
      if auth.uid() is null then raise exception 'not authenticated'; end if;
      if (p_membership is null) = (p_invitation is null) then raise exception 'choose one person or one invitation'; end if;

      if p_membership is not null then
        select m.event_id into v_event from public.site_memberships m where m.id = p_membership and m.role = 'door' and m.status = 'active' for update;
      else
        select i.event_id into v_event from public.site_invitations i where i.id = p_invitation and i.role = 'door' and i.status = 'pending' for update;
      end if;
      if v_event is null then raise exception 'not allowed'; end if;

      select a.venue_id into v_venue
        from public.site_agreements a
       where a.event_id = v_event and a.status not in ('declined', 'cancelled') and public.can_access_venue(a.venue_id, array['owner', 'manager'])
       limit 1;
      if v_venue is null then raise exception 'not allowed'; end if;

      if p_membership is not null then
        update public.site_memberships set status = 'revoked', revoked_at = now(), revoked_by = auth.uid() where id = p_membership;
      else
        update public.site_invitations set status = 'revoked', revoked_at = now(), revoked_by = auth.uid() where id = p_invitation;
      end if;
      perform public.desk_log('event_door_staff.revoked_by_club', case when p_membership is not null then 'site_memberships' else 'site_invitations' end, coalesce(p_membership, p_invitation),
        jsonb_build_object('venue_id', v_venue, 'event_id', v_event));
    end;
    $$
  $sql$;

  execute $sql$ revoke all on function public.event_door_allowed(uuid) from public, anon, authenticated $sql$;
  execute $sql$
    revoke all on function public.organizer_event_door_status(uuid), public.venue_door_permissions(uuid), public.set_organizer_door_staff(uuid, boolean),
      public.venue_event_door_staff(uuid), public.revoke_event_door_access(uuid, uuid) from public, anon
  $sql$;
  execute $sql$
    grant execute on function public.organizer_event_door_status(uuid), public.venue_door_permissions(uuid), public.set_organizer_door_staff(uuid, boolean),
      public.venue_event_door_staff(uuid), public.revoke_event_door_access(uuid, uuid) to authenticated, service_role
  $sql$;

  raise notice 'organizer door staff recorded: the club''s permission, the rule in invite_member(), and the organizer and club views.';
end
$migration$;
commit;

-- ====================================================================================================
-- 20261020140000_desk_walkin
-- ====================================================================================================
begin;
-- Walk-in table booking by the club's manager or owner (developer brief 15 Oct, section 17: "Floor > Available Table > Customer Details > Terms > Bottles >
-- Payment > Confirm. Capture name and email. Show cash method clearly and retain separate verification status. Update shared availability on confirmation.
-- On failed payment or expired hold, explain the outcome and release the hold appropriately.").
--
--   * desk_walkin_options(venue, night)    for each arrival time offered that night, each table type with its seats, deposit, how many there are, how many are
--                                          booked and how many are left (the same count the booking itself checks).
--   * desk_create_walkin(...)              books a table for a guest who is here: all or nothing, in one step, with the count checked while the table type is
--                                          LOCKED, so two people cannot book the last table at the same moment. No separate hold is needed: nothing is held and
--                                          then lost, the booking either exists or it does not, and a refusal says why. The booking is confirmed with the deposit
--                                          DUE AT THE CLUB (amount paid 0): the deposit is collected afterwards with "Record a payment", which keeps cash, card and
--                                          its verification separate and visible. The guest is seated at once (they are here), a confirmation e-mail is queued
--                                          (never claimed sent), and the booking and who made it are logged.
--
-- Same rules as an online booking: the arrival day is the day after the night for an after-midnight time; pricing is the table's flat deposit or its hourly
-- rate times the hours (at least the minimum); the party fits the table; only paid bookings take a table. A closed night takes no new booking, and the
-- same guest cannot be booked twice for the same time (a repeated tap, or a retry after a lost answer). Plain CREATE.
-- Needs the server desk (20261014*), seating and outbox (20261018110000) and close night (20261018140000) migrations.

create function public.desk_walkin_options(p_venue uuid, p_night date)
returns table (
  slot_id uuid, start_time time, slot_label text, table_type_id uuid, table_name text, max_guests int, min_guests int, pricing_mode text,
  deposit_cents int, hourly_rate_cents int, min_hours int, inventory int, booked int, available int
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.desk_level(p_venue) is distinct from 'manager' then raise exception 'not allowed'; end if;
  if p_night is null or abs(p_night - current_date) > 1 then raise exception 'that is not a current night'; end if;
  return query
    select s.id, s.start_time, s.label, t.id, t.name, t.max_guests, t.min_guests, t.pricing_mode, t.deposit_cents, t.hourly_rate_cents, t.min_hours, t.inventory_count,
           b.n, greatest(t.inventory_count - b.n, 0)
      from public.site_venue_time_slots s
      cross join public.site_table_types t
      cross join lateral (
        select count(*)::int as n from public.site_table_bookings k
         where k.table_type_id = t.id and k.time_slot_id = s.id and k.status = 'paid'
           and k.booking_date = case when s.start_time < time '06:00:00' then p_night + 1 else p_night end
      ) b
     where s.venue_id = p_venue and t.venue_id = p_venue and s.day_of_week = extract(dow from p_night)::int
     order by (s.start_time < time '06:00:00'), s.start_time, t.sort_order, t.name;
end;
$$;

create function public.desk_create_walkin(
  p_venue uuid, p_night date, p_table_type uuid, p_slot uuid, p_guests int, p_hours int,
  p_name text, p_email text, p_phone text, p_terms_confirmed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.site_table_types;
  s public.site_venue_time_slots;
  v_name text := btrim(coalesce(p_name, ''));
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_arrival date;
  v_deposit int;
  v_hours int := null;
  v_booked int;
  v_code text;
  v_id uuid;
  v_try int := 0;
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.desk_level(p_venue) is distinct from 'manager' then raise exception 'not allowed'; end if;
  if p_night is null or abs(p_night - current_date) > 1 then raise exception 'that is not a current night'; end if;
  if p_terms_confirmed is not true then raise exception 'confirm that the guest has been told the terms and agrees to them'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then raise exception 'the guest''s name needs 2 to 120 characters'; end if;
  if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or char_length(v_email) > 254 then raise exception 'enter a valid email address for the guest'; end if;
  if v_phone is not null and char_length(v_phone) > 40 then raise exception 'the phone number is too long'; end if;
  if exists (select 1 from public.site_night_closes c where c.venue_id = p_venue and c.business_night = p_night and c.status = 'closed') then
    raise exception 'this night has been closed, so no new booking can be added';
  end if;

  -- The table type is locked until this booking is in, so the count below cannot be out of date when it is used.
  select * into t from public.site_table_types where id = p_table_type and venue_id = p_venue for update;
  if not found then raise exception 'table not found'; end if;
  select * into s from public.site_venue_time_slots where id = p_slot and venue_id = p_venue;
  if not found then raise exception 'arrival time not found'; end if;
  if s.day_of_week <> extract(dow from p_night)::int then raise exception 'that arrival time is not offered on that night'; end if;

  if p_guests is null or p_guests < 1 then raise exception 'how many guests?'; end if;
  if p_guests > t.max_guests then raise exception 'this table seats up to % guests', t.max_guests; end if;
  if t.min_guests is not null and p_guests < t.min_guests then raise exception 'this table needs at least % guests', t.min_guests; end if;

  if t.pricing_mode = 'hourly' then
    if coalesce(t.hourly_rate_cents, 0) <= 0 then raise exception 'this table is not set up for hourly booking yet'; end if;
    if p_hours is null or p_hours < coalesce(t.min_hours, 1) or p_hours > 24 then
      raise exception 'this table needs between % and 24 hours', coalesce(t.min_hours, 1);
    end if;
    v_hours := p_hours;
    v_deposit := t.hourly_rate_cents * p_hours;
  else
    v_deposit := t.deposit_cents;
  end if;

  v_arrival := case when s.start_time < time '06:00:00' then p_night + 1 else p_night end;
  -- The same guest twice for the same time is almost always a repeated tap or a retry after a lost answer: refuse it, so nobody is booked twice.
  if exists (select 1 from public.site_table_bookings k where k.venue_id = p_venue and k.time_slot_id = s.id and k.booking_date = v_arrival
                and lower(k.customer_email) = v_email and k.status = 'paid') then
    raise exception 'this guest already has a booking for that time';
  end if;
  select count(*)::int into v_booked from public.site_table_bookings k
   where k.table_type_id = t.id and k.time_slot_id = s.id and k.booking_date = v_arrival and k.status = 'paid';
  if v_booked >= t.inventory_count then raise exception 'no tables of this type are left for that time'; end if;

  loop
    v_try := v_try + 1;
    v_code := 'BT-' || (select string_agg(substr(chars, 1 + floor(random() * length(chars))::int, 1), '') from generate_series(1, 8));
    exit when not exists (select 1 from public.site_table_bookings where confirmation_code = v_code);
    if v_try > 20 then raise exception 'a confirmation code could not be made, try again'; end if;
  end loop;

  insert into public.site_table_bookings (
    venue_id, table_type_id, time_slot_id, booking_date, customer_name, customer_email, customer_phone, guest_count, hours,
    deposit_cents, bottle_subtotal_cents, tax_cents, bottlesup_fee_cents, amount_total_cents, amount_paid_cents, currency,
    status, bottle_payment_choice, confirmation_code, checked_in_at, checked_in_by
  ) values (
    p_venue, t.id, s.id, v_arrival, v_name, v_email, v_phone, p_guests, v_hours,
    v_deposit, 0, 0, 0, v_deposit, 0, t.currency,
    'paid', 'pay_at_club', v_code, now(), auth.uid()
  ) returning id into v_id;

  insert into public.site_booking_seating (booking_id, seated_by, seated_at, method, confirmation)
    values (v_id, auth.uid(), now(), 'manual', 'Walk-in guest, seated when the booking was made');

  perform public.desk_enqueue('walkin_confirmation', p_venue, v_id, jsonb_build_object('confirmation_code', v_code));
  perform public.desk_log('booking.walkin_created', 'site_table_bookings', v_id,
    jsonb_build_object('venue_id', p_venue, 'table_type_id', t.id, 'deposit_cents', v_deposit, 'guests', p_guests, 'terms_confirmed', true));

  return jsonb_build_object('booking_id', v_id, 'confirmation_code', v_code, 'deposit_cents', v_deposit, 'due_cents', v_deposit, 'arrival_date', v_arrival, 'tables_left', t.inventory_count - v_booked - 1);
end;
$$;

revoke all on function public.desk_walkin_options(uuid, date), public.desk_create_walkin(uuid, date, uuid, uuid, int, int, text, text, text, boolean) from public, anon;
grant execute on function public.desk_walkin_options(uuid, date), public.desk_create_walkin(uuid, date, uuid, uuid, int, int, text, text, text, boolean) to authenticated, service_role;
commit;

-- ====================================================================================================
-- 20261020150000_add_bottles_checks
-- ====================================================================================================
begin;
-- Adding bottles to a table, by the people who work it (developer brief 15 Oct, section 16: "Server workflow ... add bottles" and section 35 step 10: "Add a
-- bottle order and record/confirm its payment").
--
-- The pricing, the stock check, the booking totals and the e-mail to the guest already live in ONE place, the edge function add-table-booking-bottles (shared with
-- the website: a staff-added item is always "due at the club", never a checkout). That function lets in only people on the global door_staff and cms_admins lists,
-- which an invited server or manager is not on (see 20261014120000_desk_orders.sql). So this migration does not touch money at all. It adds the two things the
-- edge function and the app need, decided in the database where the rules can be tested:
--
--   * desk_may_add_bottles(booking)   true when the caller may add bottles to this booking right now, otherwise a plain sentence says why not:
--                                     the caller is the club's manager or owner, or the server the booking was given to (nobody else: not a verifier, not another
--                                     club's staff, not a server of another table); the booking is confirmed; the table has not been closed out; the night has
--                                     not been closed. The edge function asks it with the caller's own login before it adds anything.
--   * desk_bottle_menu(booking)       the bottles the club offers right now (available, not sold out) with the price and, when the club counts stock, how many
--                                     are left by the same count the edge function uses (everything already on a confirmed booking, paid or due at the club).
--                                     It runs the check above first, so a person who may not add bottles cannot read the menu through it either.
--
-- Plain CREATE, nothing replaced, no data written. Needs the server desk (20261014*) and close night (20261018140000) migrations.

create function public.desk_may_add_bottles(p_booking uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_level text;
  v_b record;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  v_level := public.desk_booking_level(p_booking);
  if v_level is null or v_level not in ('manager', 'server') then raise exception 'not allowed'; end if;

  select b.status, b.reconciled_at, b.venue_id, b.booking_date, s.start_time into v_b
    from public.site_table_bookings b
    join public.site_venue_time_slots s on s.id = b.time_slot_id
   where b.id = p_booking;
  if v_b.status is distinct from 'paid' then raise exception 'only a confirmed booking can have bottles added'; end if;
  if v_b.reconciled_at is not null then raise exception 'this table has already been closed out'; end if;
  if exists (select 1 from public.site_night_closes c
              where c.venue_id = v_b.venue_id and c.business_night = public.booking_night(v_b.booking_date, v_b.start_time) and c.status = 'closed') then
    raise exception 'this night has been closed, so no bottles can be added';
  end if;
  return true;
end;
$$;

create function public.desk_bottle_menu(p_booking uuid)
returns table (bottle_id uuid, name text, size text, category text, price_cents int, left_count int)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_venue uuid;
begin
  perform public.desk_may_add_bottles(p_booking);
  select b.venue_id into v_venue from public.site_table_bookings b where b.id = p_booking;
  return query
    select bt.id, bt.name, bt.size, bt.category, bt.price_cents,
           case when bt.stock_quantity is null then null
                else greatest(bt.stock_quantity - coalesce((
                       select sum(l.quantity)::int
                         from public.site_table_booking_bottles l
                         join public.site_table_bookings k on k.id = l.booking_id
                        where l.bottle_id = bt.id and k.status = 'paid' and l.payment_status in ('paid', 'due_at_venue')), 0), 0) end
      from public.site_bottles bt
     where bt.venue_id = v_venue and bt.is_available and not bt.is_sold_out
     order by bt.sort_order, bt.name, bt.id;
end;
$$;

revoke all on function public.desk_may_add_bottles(uuid), public.desk_bottle_menu(uuid) from public, anon;
grant execute on function public.desk_may_add_bottles(uuid), public.desk_bottle_menu(uuid) to authenticated, service_role;
commit;

-- ====================================================================================================
-- 20261020160000_partial_delivery
-- ====================================================================================================
begin;
-- Partial delivery of a bottle order (developer brief 15 Oct, section 16: "partial delivery"; section 35 step 11: "Mark partial or full delivery appropriately").
-- 20261014120000_desk_orders.sql said "Delivering part of a line needs a delivered quantity the table does not have: not built". This adds it.
--
--   * site_table_booking_bottles.delivered_quantity   how many of the line's bottles have been handed over so far (additive column, 0 for every existing line)
--   * desk_deliver_part(line, how_many, already)      hand over some of a line. `already` is how many the caller believes were handed over before this: if someone else
--                                                     moved the line in the meantime (or this is a repeated tap, or a retry after a lost answer) the call is refused and
--                                                     nothing is added twice. The last bottles flip the line to Delivered (served); anything less leaves it On the way.
--   * desk_booking_deliveries(booking)                 the delivered count of every line of one booking (the existing order list is left exactly as it is)
--
-- The same rules as marking a line Delivered (desk_set_service_status): the caller is the club's manager or owner, or the server the booking was given to; the booking is
-- confirmed and not closed out; the line is not cancelled and not still being paid online; an item to be paid at the club is not handed over, not even in part, until the
-- table's balance is zero and a payment was recorded. A line must be Ready or On the way first (nothing is handed over before it is prepared), and a Delivered line is final.
-- Locks the booking and then the line, in that order, like every desk function. Moving a line by hand with desk_set_service_status is unchanged: a line it marks Delivered
-- counts as fully delivered whatever its delivered_quantity says (the app shows Delivered as all of them).
--
-- Plain ADD COLUMN and CREATE FUNCTION (a name collision in the shared database fails loudly, and the file runs in one transaction). Needs the server desk migrations
-- (20261014*) and the production-only line columns payment_status, service_status and cancelled_at they already require.

do $$
declare
  missing text;
begin
  select string_agg(x.c, ', ' order by x.c) into missing
  from (values ('payment_status'), ('service_status'), ('cancelled_at'), ('quantity')) as x(c)
  where not exists (select 1 from information_schema.columns k where k.table_schema = 'public' and k.table_name = 'site_table_booking_bottles' and k.column_name = x.c);
  if missing is not null then
    raise exception 'site_table_booking_bottles is missing % (the server desk migrations 20261014* must be applied first). Nothing was changed.', missing;
  end if;
end $$;

alter table public.site_table_booking_bottles add column delivered_quantity int not null default 0 check (delivered_quantity >= 0);

create function public.desk_booking_deliveries(p_booking uuid)
returns table (line_id uuid, delivered_quantity int)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_level text;
begin
  v_level := public.desk_booking_level(p_booking);
  if v_level is null or v_level not in ('manager', 'server') then raise exception 'not allowed'; end if;
  return query
    select bb.id, bb.delivered_quantity
      from public.site_table_booking_bottles bb
     where bb.booking_id = p_booking and bb.payment_status <> 'pending_payment'
     order by bb.created_at, bb.id;
end;
$$;

create function public.desk_deliver_part(p_line uuid, p_quantity int, p_already int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking_id uuid;
  v_level text;
  v_booking record;
  v_line record;
  v_total int;
  v_status text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select bb.booking_id into v_booking_id from public.site_table_booking_bottles bb where bb.id = p_line;
  v_level := public.desk_booking_level(v_booking_id);
  if v_level is null or v_level not in ('manager', 'server') then raise exception 'not allowed'; end if;

  select b.id, b.venue_id, b.status, b.reconciled_at, b.amount_total_cents, b.amount_paid_cents into v_booking
    from public.site_table_bookings b where b.id = v_booking_id for update;
  select bb.id, bb.quantity, bb.delivered_quantity, bb.payment_status, bb.service_status, bb.cancelled_at into v_line
    from public.site_table_booking_bottles bb where bb.id = p_line for update;

  if v_booking.status is distinct from 'paid' then raise exception 'only a paid booking has orders to serve'; end if;
  if v_booking.reconciled_at is not null then raise exception 'this table has already been closed out'; end if;
  if v_line.cancelled_at is not null then raise exception 'this item was cancelled'; end if;
  if v_line.payment_status = 'pending_payment' then raise exception 'payment not yet verified for this item'; end if;
  if v_line.service_status = 'served' then raise exception 'this item has already been delivered'; end if;
  if v_line.service_status not in ('ready', 'picked_up') then raise exception 'this item is not ready to be delivered yet'; end if;
  if p_already is distinct from v_line.delivered_quantity then raise exception 'someone else has just changed this item, look at it again'; end if;
  if p_quantity is null or p_quantity < 1 then raise exception 'choose how many were delivered'; end if;
  if p_quantity > v_line.quantity - v_line.delivered_quantity then
    raise exception 'only % of this item are left to deliver', v_line.quantity - v_line.delivered_quantity;
  end if;

  if v_line.payment_status = 'due_at_venue' then
    if greatest(v_booking.amount_total_cents - v_booking.amount_paid_cents, 0) > 0 then
      raise exception 'cannot mark delivered - this table still has a balance due at the venue';
    end if;
    if not exists (select 1 from public.site_table_booking_club_payments cp where cp.booking_id = v_booking_id) then
      raise exception 'cannot mark delivered - no payment has been recorded for this table';
    end if;
  end if;

  v_total := v_line.delivered_quantity + p_quantity;
  v_status := case when v_total >= v_line.quantity then 'served' else 'picked_up' end;
  update public.site_table_booking_bottles set delivered_quantity = v_total, service_status = v_status where id = p_line;

  perform public.desk_log('table_booking.bottle_delivered_part', 'site_table_booking_bottles', p_line,
    jsonb_build_object('venue_id', v_booking.venue_id, 'booking_id', v_booking_id, 'delivered_now', p_quantity, 'delivered_total', v_total, 'of', v_line.quantity,
                       'old_status', v_line.service_status, 'new_status', v_status));
  return jsonb_build_object('delivered', v_total, 'quantity', v_line.quantity, 'service_status', v_status);
end;
$$;

revoke all on function public.desk_booking_deliveries(uuid), public.desk_deliver_part(uuid, int, int) from public, anon;
grant execute on function public.desk_booking_deliveries(uuid), public.desk_deliver_part(uuid, int, int) to authenticated, service_role;
commit;

-- ====================================================================================================
-- 20261020170000_group_admission
-- ====================================================================================================
begin;
-- Group admission at the door (developer brief 15 Oct, section 26: "Distinguish Valid, Already Used, Wrong Event, Cancelled/Refunded, Invalid and Group Admission with
-- remaining allowance"; section 12: "group admission allowances").
--
-- A ticket order can cover several guests (site_orders.quantity). Today one scan admits the WHOLE order at once. A group usually arrives in pieces, so the door needs
-- "2 of 4 are in, 2 may still come". This adds that WITHOUT touching the live scan functions (door_scan_ticket, door_verify_ticket_code and the older check-in functions
-- stay exactly as they are): new functions, and one closed table that records each admission.
--
--   * site_order_admissions            one row per admission: which order, how many guests, who, when (closed table, like the other desk records)
--   * door_admit_group(code, count, event)   the scan. Same scope rules and the same outcomes as door_scan_ticket(), plus:
--        'group'     the ticket covers several guests and nobody chose how many yet: NOTHING is admitted, the answer says how many are in and how many are left
--        'too_many'  more than the allowance that is left: nothing is admitted, the answer says how many are left
--        'refunded'  an order that was refunded (door_scan_ticket says 'not_paid' for it): the brief asks for Cancelled/Refunded to be told apart from unpaid
--      With no count a ticket of ONE guest is admitted at once (a scan is still one scan); a ticket of several guests answers 'group' until the person chooses a count.
--      Every answer carries how many guests the ticket covers, how many are in and how many are left. The order is locked while it is counted, so two doors cannot both
--      admit the last guests. An admission is logged in scan_attempts as 'ok' like any other (that table's allowed results are left as they are).
--   * door_admission_counts(events)    how many guests are really in, per event (a partly admitted group counts only the guests who came in)
--   * door_guest_admissions(event)     how many of each ticket order are in, for the guest list
--
-- WHEN AN ORDER IS "CHECKED IN": the first admission also sets site_orders.checked_in_at (and checked_in_by), exactly as a whole-order scan does, so every other scanner and
-- report treats the order as used and refuses it again (they cannot admit the rest of a group twice). The price of that is that those older screens count the whole order
-- as in after the first admission; door_admission_counts() and door_guest_admissions() are the exact figures, and the vendor app uses them. An order admitted whole by an
-- older scanner (checked in, no admission rows) counts as fully in.
--
-- Needs the scoped door scanner (20261009100000). Plain CREATE: a name collision in the shared database fails loudly.

create table public.site_order_admissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.site_orders (id) on delete cascade,
  guests int not null check (guests > 0),
  admitted_by uuid references auth.users (id) on delete set null,
  admitted_at timestamptz not null default now()
);
create index site_order_admissions_order_idx on public.site_order_admissions (order_id);
alter table public.site_order_admissions enable row level security;
revoke all on table public.site_order_admissions from public, anon, authenticated;

create function public.door_admit_group(p_ticket_code text, p_count int default null, p_event uuid default null)
returns table (result text, customer_name text, event_title text, tier_name text, quantity int, admitted int, remaining int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := left(trim(coalesce(p_ticket_code, '')), 200);
  v_event uuid;
  v_title text;
  v_covered boolean;
  v_order record;
  v_end timestamptz;
  v_in int;
  v_left int;
  v_n int;
begin
  if auth.uid() is null or not public.has_door_role() then raise exception 'not authorized'; end if;

  -- Scope is decided before anything about the guest is read, as in door_scan_ticket().
  select o.event_id, e.title into v_event, v_title
  from public.site_orders o join public.site_events e on e.id = o.event_id
  where o.ticket_code = v_code;

  if not found then
    insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by) values (v_code, 'not_found', null, auth.uid());
    return query select 'not_found', null::text, null::text, null::text, null::int, null::int, null::int;
    return;
  end if;

  v_covered := public.can_scan_event(v_event);
  if not v_covered or (p_event is not null and v_event <> p_event) then
    insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by)
      select v_code, 'wrong_event', o.id, auth.uid() from public.site_orders o where o.ticket_code = v_code;
    return query select 'wrong_event', null::text, case when v_covered then v_title end, null::text, null::int, null::int, null::int;
    return;
  end if;

  select o.id as order_id, o.status, o.checked_in_at, o.customer_name as customer, o.quantity as guests, o.is_non_transferable, o.access_code_verified,
         e.title as event_title, e.start_date, e.end_date, t.name as tier_name
  into v_order
  from public.site_orders o
  join public.site_ticket_tiers t on t.id = o.tier_id
  join public.site_events e on e.id = o.event_id
  where o.ticket_code = v_code
  for update of o;

  v_in := coalesce((select sum(a.guests) from public.site_order_admissions a where a.order_id = v_order.order_id), 0)::int;
  if v_in = 0 and v_order.checked_in_at is not null then v_in := v_order.guests; end if;   -- admitted whole by another scanner
  v_left := greatest(v_order.guests - v_in, 0);

  if v_order.status <> 'paid' then
    insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by) values (v_code, 'not_paid', v_order.order_id, auth.uid());
    return query select case when v_order.status = 'refunded' then 'refunded' else 'not_paid' end, v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in, v_left;
    return;
  end if;

  if v_left = 0 then
    insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by) values (v_code, 'already_checked_in', v_order.order_id, auth.uid());
    return query select 'already_checked_in', v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in, 0;
    return;
  end if;

  v_end := coalesce(v_order.end_date, v_order.start_date + interval '12 hours');
  if now() > v_end then
    insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by) values (v_code, 'expired', v_order.order_id, auth.uid());
    return query select 'expired', v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in, v_left;
    return;
  end if;

  if v_order.is_non_transferable and not v_order.access_code_verified then
    insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by) values (v_code, 'code_required', v_order.order_id, auth.uid());
    return query select 'code_required', v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in, v_left;
    return;
  end if;

  if p_count is null then
    if v_order.guests > 1 then
      -- A group: nothing is admitted until the person says how many are coming in.
      return query select 'group', v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in, v_left;
      return;
    end if;
    v_n := 1;
  else
    if p_count < 1 then raise exception 'choose how many are coming in'; end if;
    if p_count > v_left then
      return query select 'too_many', v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in, v_left;
      return;
    end if;
    v_n := p_count;
  end if;

  insert into public.site_order_admissions (order_id, guests, admitted_by) values (v_order.order_id, v_n, auth.uid());
  update public.site_orders set checked_in_at = coalesce(checked_in_at, now()), checked_in_by = coalesce(checked_in_by, auth.uid()) where id = v_order.order_id;
  insert into public.scan_attempts (ticket_code_attempted, result, order_id, scanned_by) values (v_code, 'ok', v_order.order_id, auth.uid());
  return query select 'ok', v_order.customer, v_order.event_title, v_order.tier_name, v_order.guests, v_in + v_n, v_left - v_n;
end;
$$;

-- How many guests are really in, for events the caller covers (others are left out, so nothing is learned about an event that is not theirs).
create function public.door_admission_counts(p_events uuid[])
returns table (event_id uuid, guests_admitted int)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.has_door_role() then raise exception 'not authorized'; end if;
  return query
    select e.id,
           coalesce(sum(case
                          when exists (select 1 from public.site_order_admissions a where a.order_id = o.id)
                            then (select sum(a.guests) from public.site_order_admissions a where a.order_id = o.id)
                          when o.checked_in_at is not null then o.quantity
                          else 0
                        end), 0)::int
      from public.site_events e
      left join public.site_orders o on o.event_id = e.id and o.status = 'paid'
     where e.id = any(coalesce(p_events, '{}'::uuid[])) and public.can_scan_event(e.id)
     group by e.id;
end;
$$;

-- How many guests of each ticket order of an event are in, for the guest list (only orders that have had an admission through door_admit_group).
create function public.door_guest_admissions(p_event uuid)
returns table (order_id uuid, admitted int)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.has_door_role() then raise exception 'not authorized'; end if;
  if not public.can_scan_event(p_event) then raise exception 'not allowed'; end if;
  return query
    select a.order_id, sum(a.guests)::int
      from public.site_order_admissions a join public.site_orders o on o.id = a.order_id
     where o.event_id = p_event and o.status = 'paid'
     group by a.order_id;
end;
$$;

revoke all on function public.door_admit_group(text, int, uuid), public.door_admission_counts(uuid[]), public.door_guest_admissions(uuid) from public, anon;
grant execute on function public.door_admit_group(text, int, uuid), public.door_admission_counts(uuid[]), public.door_guest_admissions(uuid) to authenticated, service_role;
commit;
