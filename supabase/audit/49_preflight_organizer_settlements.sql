-- 49: PRE-FLIGHT for the website migration 20261122120000_organizer_settlements. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.agreement_in_force(public.site_agreements)') is not null and to_regprocedure('public.agreement_sample(jsonb, bigint)') is not null
          and to_regprocedure('public.can_access_venue(uuid, text[])') is not null and to_regprocedure('public.can_access_event(uuid, text[])') is not null and to_regprocedure('public.is_org_member(uuid, text[])') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.agreement_in_force(public.site_agreements)') is null then 'public.agreement_in_force missing' end, case when to_regprocedure('public.agreement_sample(jsonb, bigint)') is null then 'public.agreement_sample missing' end,
                   case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end, case when to_regprocedure('public.can_access_event(uuid, text[])') is null then 'public.can_access_event missing' end,
                   case when to_regprocedure('public.is_org_member(uuid, text[])') is null then 'public.is_org_member missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist (event agreements and agreement access are applied)',
         (to_regclass('public.site_agreements') is not null and to_regclass('public.site_agreement_versions') is not null and to_regclass('public.site_events') is not null and to_regclass('public.site_venues') is not null
          and to_regclass('public.site_organizations') is not null and to_regclass('public.profiles') is not null
          and (select count(*) = 6 from information_schema.columns where table_schema = 'public' and table_name = 'site_agreements' and column_name in ('event_id', 'venue_id', 'organizer_org_id', 'status', 'active_version', 'current_version'))
          and (select count(*) = 3 from information_schema.columns where table_schema = 'public' and table_name = 'site_agreement_versions' and column_name in ('agreement_id', 'version', 'terms'))),
         'site_agreements (event_id, venue_id, organizer_org_id, status, active_version, current_version), site_agreement_versions (agreement_id, version, terms), site_events, site_venues, site_organizations, profiles'
  union all
  select 3, 'none of the new names is taken (13 functions, 2 tables)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_log_add', 'settlement_base', 'settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge']))
          and to_regclass('public.site_settlements') is null and to_regclass('public.site_settlement_log') is null),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_log_add', 'settlement_base', 'settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge'])),
                   case when to_regclass('public.site_settlements') is not null then 'site_settlements' end, case when to_regclass('public.site_settlement_log') is not null then 'site_settlement_log' end)
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: agreements in force that have a share of bar sales to settle (these are the ones that would show a settlement to enter once the vendor app is rebuilt)',
         true, (select count(*)::text from public.site_agreements a join public.site_agreement_versions v on v.agreement_id = a.id and v.version = a.active_version
                 where a.status in ('active', 'changes_pending') and coalesce((v.terms ->> 'bar_percent')::numeric, 0) > 0) || ' agreements'
  union all
  select 6, 'INFORMATION: the migration only adds. It sends nothing, calls no payment provider and pays no one; a payment is recorded after it was made somewhere else. BottlesUp''s own payouts (site_payout_items) are not touched. Tickets and tables are not part of a settlement',
         true, 'two new tables, thirteen new functions'
) r order by n;
