-- 43: POST-FLIGHT for the website migration 20261121100000_sales_source. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 6 function(s) exist' as check_name,
         (select count(*) = 6 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources'])) as detail
  union all
  select 2, 'every function runs with its owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources']))
  union all
  select 3, 'signed-in people (and the service role) can call all six; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.venue_sales_source(uuid)', 'execute') and has_function_privilege('service_role', 'public.venue_sales_source(uuid)', 'execute') and not has_function_privilege('anon', 'public.venue_sales_source(uuid)', 'execute') and has_function_privilege('authenticated', 'public.save_venue_sales_source(uuid, text)', 'execute') and has_function_privilege('service_role', 'public.save_venue_sales_source(uuid, text)', 'execute') and not has_function_privilege('anon', 'public.save_venue_sales_source(uuid, text)', 'execute') and has_function_privilege('authenticated', 'public.submit_closing_report(uuid, date, timestamp with time zone, timestamp with time zone, bigint, bigint, bigint, boolean, text)', 'execute') and has_function_privilege('service_role', 'public.submit_closing_report(uuid, date, timestamp with time zone, timestamp with time zone, bigint, bigint, bigint, boolean, text)', 'execute') and not has_function_privilege('anon', 'public.submit_closing_report(uuid, date, timestamp with time zone, timestamp with time zone, bigint, bigint, bigint, boolean, text)', 'execute') and has_function_privilege('authenticated', 'public.review_closing_report(uuid, boolean, text)', 'execute') and has_function_privilege('service_role', 'public.review_closing_report(uuid, boolean, text)', 'execute') and not has_function_privilege('anon', 'public.review_closing_report(uuid, boolean, text)', 'execute') and has_function_privilege('authenticated', 'public.closing_reports(uuid, integer)', 'execute') and has_function_privilege('service_role', 'public.closing_reports(uuid, integer)', 'execute') and not has_function_privilege('anon', 'public.closing_reports(uuid, integer)', 'execute') and has_function_privilege('authenticated', 'public.night_sales_sources(uuid, date)', 'execute') and has_function_privilege('service_role', 'public.night_sales_sources(uuid, date)', 'execute') and not has_function_privilege('anon', 'public.night_sales_sources(uuid, date)', 'execute')),
         'venue_sales_source, save_venue_sales_source, submit_closing_report, review_closing_report, closing_reports, night_sales_sources'
  union all
  select 4, 'table site_venue_sales_source has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_venue_sales_source') is not null and (select relrowsecurity from pg_class where oid = 'public.site_venue_sales_source'::regclass)
          and not has_table_privilege('anon', 'public.site_venue_sales_source', 'select') and not has_table_privilege('authenticated', 'public.site_venue_sales_source', 'select')
          and not has_table_privilege('anon', 'public.site_venue_sales_source', 'insert') and not has_table_privilege('authenticated', 'public.site_venue_sales_source', 'insert')
          and not has_table_privilege('authenticated', 'public.site_venue_sales_source', 'update') and not has_table_privilege('authenticated', 'public.site_venue_sales_source', 'delete')),
         'RLS on, no grants'
  union all
  select 5, 'table site_closing_reports has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_closing_reports') is not null and (select relrowsecurity from pg_class where oid = 'public.site_closing_reports'::regclass)
          and not has_table_privilege('anon', 'public.site_closing_reports', 'select') and not has_table_privilege('authenticated', 'public.site_closing_reports', 'select')
          and not has_table_privilege('anon', 'public.site_closing_reports', 'insert') and not has_table_privilege('authenticated', 'public.site_closing_reports', 'insert')
          and not has_table_privilege('authenticated', 'public.site_closing_reports', 'update') and not has_table_privilege('authenticated', 'public.site_closing_reports', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'no club has chosen a source and no closing report exists: nothing existing was changed',
         ((select count(*) = 0 from public.site_venue_sales_source) and (select count(*) = 0 from public.site_closing_reports)),
         (select count(*)::text from public.site_venue_sales_source) || ' sources chosen, ' || (select count(*)::text from public.site_closing_reports) || ' reports'
  union all
  select 7, 'the person columns do not block deleting an account (ON DELETE SET NULL)',
         ((select count(*) = 3 and bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
            where c.contype = 'f' and ((c.conrelid = 'public.site_venue_sales_source'::regclass and a.attname = 'changed_by') or (c.conrelid = 'public.site_closing_reports'::regclass and a.attname in ('submitted_by', 'reviewed_by'))))),
         'changed_by, submitted_by, reviewed_by'
  union all
  select 8, 'the sources are exactly BottlesUp entries and closing report upload (Connected POS is not a value), and the report states are the four',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_venue_sales_source'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%entries%upload%' and pg_get_constraintdef(c.oid) not like '%pos%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_closing_reports'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%submitted%reviewed%rejected%superseded%')),
         'entries, upload; submitted, reviewed, rejected, superseded'
  union all
  select 9, 'a night has one live report (a unique index), a period is at most 36 hours, and discounts plus refunds never pass the gross',
         (exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'site_closing_reports' and indexname = 'site_closing_reports_one_live' and indexdef like '%superseded%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_closing_reports'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%36:00:00%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_closing_reports'::regclass and c.contype = 'c' and c.conname = 'site_closing_reports_within_gross')),
         'site_closing_reports_one_live, 36 hours, site_closing_reports_within_gross'
  union all
  select 10 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources'])
) r order by n;
