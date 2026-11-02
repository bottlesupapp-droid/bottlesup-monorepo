-- 42: PRE-FLIGHT for the website migration 20261121100000_sales_source. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.can_access_venue(uuid, text[])') is not null and to_regprocedure('public.require_venue_editor(uuid)') is not null
          and to_regprocedure('public.venue_setup_log(text, text, uuid, uuid, jsonb)') is not null and to_regprocedure('public.night_booking_ids(uuid, date)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end, case when to_regprocedure('public.require_venue_editor(uuid)') is null then 'public.require_venue_editor missing' end,
                   case when to_regprocedure('public.venue_setup_log(text, text, uuid, uuid, jsonb)') is null then 'public.venue_setup_log missing' end, case when to_regprocedure('public.night_booking_ids(uuid, date)') is null then 'public.night_booking_ids missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist',
         (to_regclass('public.site_venues') is not null and to_regclass('public.site_table_bookings') is not null and to_regclass('public.site_refund_requests') is not null
          and (select count(*) = 4 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_bookings' and column_name in ('amount_total_cents', 'amount_paid_cents', 'discount_cents', 'staff_discount_cents'))
          and (select count(*) = 3 from information_schema.columns where table_schema = 'public' and table_name = 'site_refund_requests' and column_name in ('booking_id', 'status', 'approved_cents'))),
         'site_venues, site_table_bookings (amount_total_cents, amount_paid_cents, discount_cents, staff_discount_cents), site_refund_requests (booking_id, status, approved_cents)'
  union all
  select 3, 'none of the new names is taken (6 functions, 2 tables)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources']))
          and to_regclass('public.site_venue_sales_source') is null and to_regclass('public.site_closing_reports') is null),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources'])), case when to_regclass('public.site_venue_sales_source') is not null then 'site_venue_sales_source' end, case when to_regclass('public.site_closing_reports') is not null then 'site_closing_reports' end)
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: every club starts on BottlesUp entries (no club has chosen a source, and no closing report exists): nothing changes for anyone until a club chooses closing report upload',
         true, (select count(*)::text from public.site_venues) || ' clubs'
  union all
  select 6, 'INFORMATION: the migration only adds; it sends nothing and changes no booking, payment or report. The vendor app needs a rebuild to show Sales Tracking',
         true, 'two new tables, six new functions'
) r order by n;
