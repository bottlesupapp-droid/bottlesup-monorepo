-- 38: PRE-FLIGHT for the website migration 20261119100000_report_emails. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.is_org_member(uuid, text[])') is not null and to_regprocedure('public.can_access_venue(uuid, text[])') is not null and to_regprocedure('public.can_access_event(uuid, text[])') is not null and to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.is_org_member(uuid, text[])') is null then 'public.is_org_member missing' end, case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end, case when to_regprocedure('public.can_access_event(uuid, text[])') is null then 'public.can_access_event missing' end, case when to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is null then 'public.desk_log missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist',
         (to_regclass('public.site_events') is not null and to_regclass('public.site_organizations') is not null and to_regclass('public.site_venues') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_organizations' and column_name = 'name') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'org_id') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'name') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_events' and column_name = 'org_id') and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_events' and column_name = 'title')),
         'site_events.org_id, site_events.title, site_organizations.name, site_venues.name, site_venues.org_id'
  union all
  select 3, 'none of the new names is taken (7 functions, 2 tables, 0 columns, 0 triggers)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_scope_allowed', 'report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_send_finish', 'report_deliveries'])) and to_regclass('public.site_report_recipients') is null and to_regclass('public.site_report_deliveries') is null),
         concat_ws(', ', coalesce((select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_scope_allowed', 'report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_send_finish', 'report_deliveries'])), ''), case when to_regclass('public.site_report_recipients') is not null then 'table site_report_recipients exists' else '' end, case when to_regclass('public.site_report_deliveries') is not null then 'table site_report_deliveries exists' else '' end)
  union all
  select 4, 'the roles exist (the functions are granted to authenticated and service_role and taken from anon)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: both lists start empty: nothing is e-mailed until someone adds an address and presses E-mail this report', true, 'two new tables'
  union all
  select 6, 'INFORMATION: the e-mail function (send-report-email) needs the RESEND_API_KEY secret and the service role key in the project; the migration alone sends nothing', true, 'check in the Supabase dashboard'
) r order by n;
