-- 28: PRE-FLIGHT for the three website migrations 20261111100000_atomic_table_checkout, 20261113100000_oversold_booking_queue and 20261114100000_booking_sign_text. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migrations build on is there, and none of their names is taken). Rows 5 and 6 are information only (they never block).
select * from (
  select 1 as n, 'the functions these build on exist (shared table count, desk level, desk log, booking level)' as check_name,
         (to_regprocedure('public.site_table_taken_count(uuid, uuid, date, text)') is not null
          and to_regprocedure('public.desk_level(uuid)') is not null
          and to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is not null
          and to_regprocedure('public.desk_booking_level(uuid)') is not null) as ok,
         concat_ws(', ',
           case when to_regprocedure('public.site_table_taken_count(uuid, uuid, date, text)') is null then 'site_table_taken_count missing' end,
           case when to_regprocedure('public.desk_level(uuid)') is null then 'desk_level missing' end,
           case when to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is null then 'desk_log missing' end,
           case when to_regprocedure('public.desk_booking_level(uuid)') is null then 'desk_booking_level missing' end) as detail
  union all
  select 2, 'the tables and columns these build on exist',
         (to_regclass('public.site_table_blocks') is not null and to_regclass('public.site_table_bookings') is not null and to_regclass('public.site_table_types') is not null
          and to_regclass('public.site_venue_time_slots') is not null and to_regclass('public.site_venues') is not null
          and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_bookings' and column_name = 'bottle_sign_text')
          and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_bookings' and column_name = 'confirmation_sent_at')
          and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_types' and column_name = 'inventory_count')),
         'site_table_blocks, site_table_bookings (bottle_sign_text, confirmation_sent_at), site_table_types (inventory_count), site_venue_time_slots, site_venues'
  union all
  select 3, 'none of the new names is taken (5 functions, 1 table)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
                        and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign'))
          and to_regclass('public.site_booking_conflicts') is null),
         coalesce((select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace
                     and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign')), '')
           || case when to_regclass('public.site_booking_conflicts') is not null then ' + table site_booking_conflicts exists' else '' end
  union all
  select 4, 'the service role exists (the checkout and the Stripe fulfilment call the new functions as service_role)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: booking states a manager can close a conflict with (the booking status rule allows refunded and cancelled)',
         coalesce((select pg_get_constraintdef(c.oid) like '%refunded%' and pg_get_constraintdef(c.oid) like '%cancelled%' from pg_constraint c
                    where c.conrelid = 'public.site_table_bookings'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%status%' and pg_get_constraintdef(c.oid) like '%paid%' limit 1), false),
         coalesce((select pg_get_constraintdef(c.oid) from pg_constraint c where c.conrelid = 'public.site_table_bookings'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%status%' and pg_get_constraintdef(c.oid) like '%paid%' limit 1), 'no status rule found')
  union all
  select 6, 'INFORMATION: arrival times from yesterday on where PAID bookings already outnumber the tables the club has (these are not flagged by the new code, which only looks at new payments)',
         true,
         coalesce((select count(*)::text || ' arrival time(s): ' || string_agg(x, '; ') from (
                     select t.name || ' x' || count(*) || ' of ' || t.inventory_count || ' on ' || b.booking_date as x
                       from public.site_table_bookings b join public.site_table_types t on t.id = b.table_type_id
                      where b.status = 'paid' and b.booking_date >= current_date - 1
                      group by t.id, t.name, t.inventory_count, b.time_slot_id, b.booking_date
                     having count(*) > t.inventory_count limit 20) q), 'none')
) r order by n;
