-- 45: PRE-FLIGHT for the website migration 20261122100000_door_exits_and_overrides. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.active_memberships()') is not null and to_regprocedure('public.can_access_event(uuid, text[])') is not null and to_regprocedure('public.can_access_venue(uuid, text[])') is not null
          and to_regprocedure('public.has_door_role()') is not null and to_regprocedure('public.can_scan_event(uuid)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.active_memberships()') is null then 'public.active_memberships missing' end, case when to_regprocedure('public.can_access_event(uuid, text[])') is null then 'public.can_access_event missing' end,
                   case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end, case when to_regprocedure('public.has_door_role()') is null then 'public.has_door_role missing' end,
                   case when to_regprocedure('public.can_scan_event(uuid)') is null then 'public.can_scan_event missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist',
         (to_regclass('public.site_events') is not null and to_regclass('public.site_orders') is not null and to_regclass('public.site_order_admissions') is not null and to_regclass('public.site_ticket_tiers') is not null and to_regclass('public.scan_attempts') is not null
          and (select count(*) = 3 from information_schema.columns where table_schema = 'public' and table_name = 'site_events' and column_name in ('venue_id', 'start_date', 'end_date'))
          and (select count(*) = 6 from information_schema.columns where table_schema = 'public' and table_name = 'site_orders' and column_name in ('ticket_code', 'quantity', 'checked_in_at', 'is_non_transferable', 'access_code_verified', 'status'))),
         'site_events (venue_id, start_date, end_date), site_orders (ticket_code, quantity, checked_in_at, is_non_transferable, access_code_verified, status), site_order_admissions, site_ticket_tiers, scan_attempts'
  union all
  select 3, 'none of the new names is taken (8 functions, 2 tables, 1 column)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights']))
          and to_regclass('public.site_order_exits') is null and to_regclass('public.site_door_overrides') is null
          and not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_events' and column_name = 'track_exits')),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights'])),
                   case when to_regclass('public.site_order_exits') is not null then 'site_order_exits' end, case when to_regclass('public.site_door_overrides') is not null then 'site_door_overrides' end,
                   case when exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_events' and column_name = 'track_exits') then 'site_events.track_exits' end)
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: no event tracks exits after this (the new column defaults to off): the door looks and works exactly as before until an owner, organizer or manager turns it on for a night',
         true, (select count(*)::text from public.site_events) || ' events'
  union all
  select 6, 'INFORMATION: the migration only adds; door_admit_group() and the scanners are not touched, nothing is sent, and no order, ticket or payment changes. The vendor app needs a rebuild to show Inside now, Exit mode, the door filters and Door control',
         true, 'two new tables, one new column, eight new functions'
) r order by n;
