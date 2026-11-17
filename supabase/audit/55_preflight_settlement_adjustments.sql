-- 55: PRE-FLIGHT for the website migration 20261125100000_settlement_adjustments. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.can_access_venue(uuid, text[])') is not null and to_regprocedure('public.can_access_event(uuid, text[])') is not null
          and to_regprocedure('public.is_org_member(uuid, text[])') is not null and to_regprocedure('public.settlement_detail(uuid)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end, case when to_regprocedure('public.can_access_event(uuid, text[])') is null then 'public.can_access_event missing' end,
                   case when to_regprocedure('public.is_org_member(uuid, text[])') is null then 'public.is_org_member missing' end, case when to_regprocedure('public.settlement_detail(uuid)') is null then 'public.settlement_detail missing (apply 20261122120000_organizer_settlements first)' end) as detail
  union all
  select 2, 'the settlements tables and the columns this builds on exist (organizer settlements is applied)',
         (to_regclass('public.site_settlements') is not null and to_regclass('public.site_settlement_log') is not null
          and (select count(*) = 8 from information_schema.columns where table_schema = 'public' and table_name = 'site_settlements' and column_name in ('id', 'status', 'paid_amount_cents', 'paid_on', 'event_id', 'venue_id', 'organizer_org_id', 'currency'))),
         'site_settlements (id, status, paid_amount_cents, paid_on, event_id, venue_id, organizer_org_id, currency), site_settlement_log'
  union all
  select 3, 'none of the new names is taken (10 functions, 2 tables)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustment_log_add', 'settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive']))
          and to_regclass('public.site_settlement_adjustments') is null and to_regclass('public.site_settlement_adjustment_log') is null),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustment_log_add', 'settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive'])),
                   case when to_regclass('public.site_settlement_adjustments') is not null then 'site_settlement_adjustments' end, case when to_regclass('public.site_settlement_adjustment_log') is not null then 'site_settlement_adjustment_log' end)
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: settlements by status (only a PAID settlement can take an adjustment after payment; the migration changes none of them)',
         true, coalesce((select string_agg(s.status || ' ' || s.n, ', ' order by s.status) from (select status, count(*) as n from public.site_settlements group by status) s), 'no settlements yet')
  union all
  select 6, 'INFORMATION: the migration only adds. It sends nothing, calls no payment provider and pays no one: an adjustment after payment is a record, and a payment that settles it is recorded after it was made somewhere else. A paid settlement (its figures, its payment record, its history) is never changed by it.',
         true, 'two new tables, ten new functions; no existing table or function is changed'
) r order by n;
