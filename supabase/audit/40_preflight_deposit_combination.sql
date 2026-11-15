-- 40: PRE-FLIGHT for the website migration 20261120100000_deposit_combination. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.require_venue_editor(uuid)') is not null and to_regprocedure('public.setup_only_keys(jsonb, text[])') is not null and to_regprocedure('public.setup_text(jsonb, text, text, int)') is not null and to_regprocedure('public.setup_int(jsonb, text, text, int, int)') is not null and to_regprocedure('public.venue_setup_log(text, text, uuid, uuid, jsonb)') is not null and to_regprocedure('public.save_venue_deposit_terms(uuid, jsonb)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.require_venue_editor(uuid)') is null then 'public.require_venue_editor missing' end, case when to_regprocedure('public.setup_only_keys(jsonb, text[])') is null then 'public.setup_only_keys missing' end, case when to_regprocedure('public.setup_text(jsonb, text, text, int)') is null then 'public.setup_text missing' end, case when to_regprocedure('public.setup_int(jsonb, text, text, int, int)') is null then 'public.setup_int missing' end, case when to_regprocedure('public.venue_setup_log(text, text, uuid, uuid, jsonb)') is null then 'public.venue_setup_log missing' end, case when to_regprocedure('public.save_venue_deposit_terms(uuid, jsonb)') is null then 'public.save_venue_deposit_terms missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist',
         (to_regclass('public.site_table_bookings') is not null and to_regclass('public.site_venues') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'deposit_terms') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'deposit_is_credit') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_bookings' and column_name = 'deposit_terms')),
         'site_table_bookings.deposit_terms, site_venues.deposit_is_credit, site_venues.deposit_terms'
  union all
  select 3, 'none of the new names is taken (1 functions, 0 tables, 0 columns, 0 triggers)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination']))),
         concat_ws(', ', coalesce((select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination'])), ''))
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: how the clubs stand now (a combination needs the credit switch to agree with its credit share)', true, (select count(*)::text from public.site_venues where deposit_is_credit) || ' of ' || (select count(*)::text from public.site_venues) || ' clubs credit the deposit toward the bottle bill; ' || (select count(*)::text from public.site_venues where deposit_terms is not null) || ' have chosen terms'
  union all
  select 6, 'INFORMATION: the checkout and the totals functions need the new deposit allocation code deployed together with this: deploy create-table-booking-checkout, site-stripe-webhook, site-booking-status and confirm-bottle-addon after applying (they carry the shared code)', true, 'see the pull request'
) r order by n;
