-- Undo for the eight website migrations 20261020100000 .. 20261020170000 (branch feat/business-brief-2): payment settings, booking guests and activity, organizer event
-- states, organizer-provided door staff, walk-in booking, add bottles checks, partial delivery, group admission. Run it in ONE transaction (it is wrapped below). It removes exactly the functions those files create, puts
-- back the invite_member() that 20261006120000_tenancy_foundation.sql defines, drops the two columns they add, and drops the admissions table.
--
-- What it deletes: the club's "allow organizer door staff" switches (site_agreements.organizer_door_staff) and how many bottles of each order were handed over so
-- far (site_table_booking_bottles.delivered_quantity; a line that is Delivered stays Delivered), and the record of group admissions at the door (site_order_admissions;
-- an order that was marked checked in stays checked in, but how many of a group came in is lost). Nothing else is data: walk-in bookings and bottles added at a table stay
-- (they are ordinary bookings, paid 0, seated), invitations and memberships already made stay valid, and the app simply stops offering the screens.
-- invite_member() is put back ONLY if it is the version the door staff migration wrote (it mentions event_door_allowed); if someone changed it since, it is left
-- alone and a notice says so. Afterwards run supabase/audit/16_preflight_business_brief_2.sql: it returns no rows once every object is gone (the post-flight 17 then fails, as it should).
begin;

drop function if exists public.door_guest_admissions(uuid);
drop function if exists public.door_admission_counts(uuid[]);
drop function if exists public.door_admit_group(text, int, uuid);
drop table if exists public.site_order_admissions;

drop function if exists public.desk_deliver_part(uuid, int, int);
drop function if exists public.desk_booking_deliveries(uuid);
alter table public.site_table_booking_bottles drop column if exists delivered_quantity;
drop function if exists public.desk_bottle_menu(uuid);
drop function if exists public.desk_may_add_bottles(uuid);

drop function if exists public.desk_create_walkin(uuid, date, uuid, uuid, int, int, text, text, text, boolean);
drop function if exists public.desk_walkin_options(uuid, date);

do $do$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'invite_member' and position('event_door_allowed' in p.prosrc) > 0) then
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
$$;
    $sql$;
  else
    raise notice 'invite_member() does not apply the organizer door staff rule (already restored, or changed by hand): left alone.';
  end if;
end
$do$;

drop function if exists public.revoke_event_door_access(uuid, uuid);
drop function if exists public.venue_event_door_staff(uuid);
drop function if exists public.set_organizer_door_staff(uuid, boolean);
drop function if exists public.venue_door_permissions(uuid);
drop function if exists public.organizer_event_door_status(uuid);
drop function if exists public.event_door_allowed(uuid);
alter table public.site_agreements drop column if exists organizer_door_staff;

drop function if exists public.list_org_event_states(uuid);
drop function if exists public.desk_booking_activity(uuid, int);
drop function if exists public.desk_booking_guests(uuid);
drop function if exists public.save_venue_payment_rules(uuid, jsonb);
drop function if exists public.venue_payment_rules(uuid);

commit;
