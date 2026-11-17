-- 57: PRE-FLIGHT for the website migration 20261126100000_auto_report_jobs. Read-only.
-- One result set. Rows 1 to 5 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.report_send_begin(text, uuid, uuid, uuid, text, text, integer, boolean)') is not null and to_regprocedure('public.report_scope_allowed(text, uuid, uuid, uuid)') is not null
          and to_regprocedure('public.night_report(uuid, date)') is not null and to_regprocedure('public.owner_night_report(uuid, date)') is not null and to_regprocedure('public.organizer_event_sales(uuid)') is not null
          and to_regprocedure('public.night_sales_sources(uuid, date)') is not null and to_regprocedure('public.venue_timezone(uuid)') is not null
          and to_regprocedure('public.agreement_in_force(public.site_agreements)') is not null and to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.report_send_begin(text, uuid, uuid, uuid, text, text, integer, boolean)') is null then 'report_send_begin missing (apply 20261119100000_report_emails)' end,
                   case when to_regprocedure('public.night_report(uuid, date)') is null then 'night_report missing (close night)' end, case when to_regprocedure('public.owner_night_report(uuid, date)') is null then 'owner_night_report missing' end,
                   case when to_regprocedure('public.organizer_event_sales(uuid)') is null then 'organizer_event_sales missing (agreement access)' end, case when to_regprocedure('public.night_sales_sources(uuid, date)') is null then 'night_sales_sources missing (sales source)' end,
                   case when to_regprocedure('public.agreement_in_force(public.site_agreements)') is null then 'agreement_in_force missing' end, case when to_regprocedure('public.venue_timezone(uuid)') is null then 'venue_timezone missing' end) as detail
  union all
  select 2, 'the tables this builds on exist',
         (to_regclass('public.site_night_closes') is not null and to_regclass('public.site_report_recipients') is not null and to_regclass('public.site_report_deliveries') is not null and to_regclass('public.site_agreements') is not null
          and to_regclass('public.site_events') is not null and to_regclass('public.site_venues') is not null and to_regclass('public.site_organizations') is not null),
         'site_night_closes, site_report_recipients, site_report_deliveries, site_agreements, site_events, site_venues, site_organizations'
  union all
  select 3, 'none of the new names is taken (10 functions, 2 tables, 1 trigger)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_auto_set', 'report_auto_status', 'report_jobs_enqueue', 'report_jobs_on_close', 'report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish']))
          and to_regclass('public.site_report_auto') is null and to_regclass('public.site_report_jobs') is null
          and not exists (select 1 from pg_trigger t where t.tgname = 'report_jobs_after_close' and not t.tgisinternal)),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_auto_set', 'report_auto_status', 'report_jobs_enqueue', 'report_jobs_on_close', 'report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish'])),
                   case when to_regclass('public.site_report_auto') is not null then 'site_report_auto' end, case when to_regclass('public.site_report_jobs') is not null then 'site_report_jobs' end,
                   case when exists (select 1 from pg_trigger t where t.tgname = 'report_jobs_after_close' and not t.tgisinternal) then 'trigger report_jobs_after_close' end)
  union all
  select 4, 'site_night_closes has no trigger yet (the migration adds exactly one, which never stops a night from closing)',
         not exists (select 1 from pg_trigger t where t.tgrelid = 'public.site_night_closes'::regclass and not t.tgisinternal),
         (select count(*)::text from pg_trigger t where t.tgrelid = 'public.site_night_closes'::regclass and not t.tgisinternal) || ' triggers now'
  union all
  select 5, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 6, 'INFORMATION: nights closed so far, and report lists (nothing is sent for them: only nights closed AFTER someone switches a report on)',
         true, (select count(*)::text from public.site_night_closes) || ' night closes; ' || (select count(*)::text from public.site_report_recipients) || ' addresses on report lists'
  union all
  select 7, 'INFORMATION: the migration only adds. It sends nothing: every switch is off until a person switches it on, and the server job that sends is a separate function that is deployed and scheduled in a separate step. Existing tables and functions are unchanged; the one change to an existing table is a trigger that only queues, and only warns if queueing fails.',
         true, 'two new tables, ten new functions, one trigger'
) r order by n;
