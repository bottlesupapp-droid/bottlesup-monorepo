-- 30: PRE-FLIGHT for the website migration 20261115100000_owner_night_report. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.night_report(uuid, date)') is not null and to_regprocedure('public.night_booking_ids(uuid, date)') is not null and to_regprocedure('public.is_org_member(uuid, text[])') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.night_report(uuid, date)') is null then 'public.night_report missing' end, case when to_regprocedure('public.night_booking_ids(uuid, date)') is null then 'public.night_booking_ids missing' end, case when to_regprocedure('public.is_org_member(uuid, text[])') is null then 'public.is_org_member missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist',
         (to_regclass('public.site_organizations') is not null and to_regclass('public.site_table_bookings') is not null and to_regclass('public.site_venues') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'org_id') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_bookings' and column_name = 'currency') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_organizations' and column_name = 'name')),
         'site_organizations.name, site_table_bookings.currency, site_venues.org_id'
  union all
  select 3, 'none of the new names is taken (1 functions, 0 tables, 0 columns, 0 triggers)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report']))),
         concat_ws(', ', coalesce((select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report'])), ''))
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: the clubs and closed nights this report will read', true, (select count(*)::text || ' clubs, ' || (select count(*) from public.site_night_closes where status = 'closed')::text || ' closed nights' from public.site_venues)
) r order by n;
