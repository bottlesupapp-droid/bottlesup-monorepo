-- 39: POST-FLIGHT for the website migration 20261119100000_report_emails. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 7 function(s) exist' as check_name,
         (select count(*) = 7 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_deliveries', 'report_send_finish', 'report_scope_allowed'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_deliveries', 'report_send_finish', 'report_scope_allowed'])) as detail
  union all
  select 2, 'the app-facing functions (and any trigger function meant to) run with their owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_deliveries', 'report_send_finish'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_deliveries', 'report_send_finish']))
  union all
  select 3, 'signed-in people (and the service role) can call the app-facing functions; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.report_recipients(text, uuid, uuid)', 'execute') and has_function_privilege('service_role', 'public.report_recipients(text, uuid, uuid)', 'execute') and not has_function_privilege('anon', 'public.report_recipients(text, uuid, uuid)', 'execute') and has_function_privilege('authenticated', 'public.add_report_recipient(text, uuid, uuid, text)', 'execute') and has_function_privilege('service_role', 'public.add_report_recipient(text, uuid, uuid, text)', 'execute') and not has_function_privilege('anon', 'public.add_report_recipient(text, uuid, uuid, text)', 'execute') and has_function_privilege('authenticated', 'public.remove_report_recipient(uuid)', 'execute') and has_function_privilege('service_role', 'public.remove_report_recipient(uuid)', 'execute') and not has_function_privilege('anon', 'public.remove_report_recipient(uuid)', 'execute') and has_function_privilege('authenticated', 'public.report_send_begin(text, uuid, uuid, uuid, text, text, int, boolean)', 'execute') and has_function_privilege('service_role', 'public.report_send_begin(text, uuid, uuid, uuid, text, text, int, boolean)', 'execute') and not has_function_privilege('anon', 'public.report_send_begin(text, uuid, uuid, uuid, text, text, int, boolean)', 'execute') and has_function_privilege('authenticated', 'public.report_deliveries(text, uuid, uuid, uuid, text, int)', 'execute') and has_function_privilege('service_role', 'public.report_deliveries(text, uuid, uuid, uuid, text, int)', 'execute') and not has_function_privilege('anon', 'public.report_deliveries(text, uuid, uuid, uuid, text, int)', 'execute')),
         'report_recipients, add_report_recipient, remove_report_recipient, report_send_begin, report_deliveries'
  union all
  select 4, 'the service-role-only functions are not callable by signed-in people or visitors',
         (has_function_privilege('service_role', 'public.report_send_finish(jsonb)', 'execute') and not has_function_privilege('authenticated', 'public.report_send_finish(jsonb)', 'execute') and not has_function_privilege('anon', 'public.report_send_finish(jsonb)', 'execute')),
         'report_send_finish'
  union all
  select 5, 'the internal helpers are not callable by the app',
         (not has_function_privilege('authenticated', 'public.report_scope_allowed(text, uuid, uuid, uuid)', 'execute') and not has_function_privilege('anon', 'public.report_scope_allowed(text, uuid, uuid, uuid)', 'execute')),
         'report_scope_allowed'
  union all
  select 6, 'table site_report_recipients has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_report_recipients') is not null and (select relrowsecurity from pg_class where oid = 'public.site_report_recipients'::regclass)
          and not has_table_privilege('anon', 'public.site_report_recipients', 'select') and not has_table_privilege('authenticated', 'public.site_report_recipients', 'select')
          and not has_table_privilege('anon', 'public.site_report_recipients', 'insert') and not has_table_privilege('authenticated', 'public.site_report_recipients', 'insert')
          and not has_table_privilege('authenticated', 'public.site_report_recipients', 'update') and not has_table_privilege('authenticated', 'public.site_report_recipients', 'delete')),
         'RLS on, no grants'
  union all
  select 7, 'table site_report_deliveries has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_report_deliveries') is not null and (select relrowsecurity from pg_class where oid = 'public.site_report_deliveries'::regclass)
          and not has_table_privilege('anon', 'public.site_report_deliveries', 'select') and not has_table_privilege('authenticated', 'public.site_report_deliveries', 'select')
          and not has_table_privilege('anon', 'public.site_report_deliveries', 'insert') and not has_table_privilege('authenticated', 'public.site_report_deliveries', 'insert')
          and not has_table_privilege('authenticated', 'public.site_report_deliveries', 'update') and not has_table_privilege('authenticated', 'public.site_report_deliveries', 'delete')),
         'RLS on, no grants'
  union all
  select 8, 'both tables start empty: no list, no e-mail logged',
         ((select count(*) = 0 from public.site_report_recipients) and (select count(*) = 0 from public.site_report_deliveries)),
         (select count(*)::text from public.site_report_recipients) || ' recipients, ' || (select count(*)::text from public.site_report_deliveries) || ' deliveries'
  union all
  select 9, 'the person columns do not block deleting an account (ON DELETE SET NULL)',
         ((select bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey) where c.contype = 'f' and ((c.conrelid = 'public.site_report_recipients'::regclass and a.attname = 'added_by') or (c.conrelid = 'public.site_report_deliveries'::regclass and a.attname = 'sent_by')))),
         'added_by, sent_by'
  union all
  select 10, 'the kinds of report are exactly three, and a club list needs a club',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_report_recipients'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%owner_combined%venue_night%organizer_sales%') and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_report_recipients'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%venue_night%venue_id IS NOT NULL%')),
         'owner_combined, venue_night, organizer_sales'
  union all
  select 10 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_send_begin', 'report_deliveries', 'report_send_finish', 'report_scope_allowed'])
) r order by n;
