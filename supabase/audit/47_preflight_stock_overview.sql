-- 47: PRE-FLIGHT for the website migration 20261122110000_stock_overview. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and its name is free). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the function this builds on exists' as check_name,
         (to_regprocedure('public.can_access_venue(uuid, text[])') is not null) as ok,
         case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' else '' end as detail
  union all
  select 2, 'the tables and columns this builds on exist (the inventory ledger, partial delivery and the table desk migrations are applied)',
         (to_regclass('public.site_bottles') is not null and to_regclass('public.site_stock_thresholds') is not null and to_regclass('public.site_table_booking_bottles') is not null and to_regclass('public.site_table_bookings') is not null
          and (select count(*) = 5 from information_schema.columns where table_schema = 'public' and table_name = 'site_bottles' and column_name in ('venue_id', 'name', 'size', 'category', 'stock_quantity'))
          and (select count(*) = 7 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_booking_bottles' and column_name in ('payment_status', 'service_status', 'cancelled_at', 'quantity', 'delivered_quantity', 'bottle_id', 'created_at'))
          and (select count(*) = 2 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_bookings' and column_name in ('venue_id', 'status'))),
         'site_bottles, site_stock_thresholds, site_table_booking_bottles (payment_status, service_status, cancelled_at, quantity, delivered_quantity, bottle_id, created_at), site_table_bookings (venue_id, status)'
  union all
  select 3, 'the new name is not taken (stock_overview)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'stock_overview')),
         (select string_agg(p.oid::regprocedure::text, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'stock_overview')
  union all
  select 4, 'the roles exist (the function is granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: the migration adds one read-only function. It changes no stock figure, movement, booking or bottle line; the Inventory screen gets an Overview button after the vendor app is rebuilt',
         true, (select count(*)::text from public.site_bottles) || ' bottles'
  union all
  select 6, 'INFORMATION: bottles on lines of cancelled bookings or cancelled lines are NOT counted as sold by the overview (the brief says cancelled orders release their reservation); desk_bottle_menu() still counts a cancelled LINE, so its "left" can be lower by that amount',
         true, (select count(*)::text from public.site_table_booking_bottles where cancelled_at is not null) || ' cancelled lines today'
) r order by n;
