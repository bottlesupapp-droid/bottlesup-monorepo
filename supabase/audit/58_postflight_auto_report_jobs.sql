-- 58: POST-FLIGHT for the website migration 20261126100000_auto_report_jobs. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 10 function(s) exist' as check_name,
         (select count(*) = 10 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_auto_set', 'report_auto_status', 'report_jobs_enqueue', 'report_jobs_on_close', 'report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_auto_set', 'report_auto_status', 'report_jobs_enqueue', 'report_jobs_on_close', 'report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish'])) as detail
  union all
  select 2, 'every function runs with its owner''s rights and a fixed search path',
         (select count(*) = 10 and bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_auto_set', 'report_auto_status', 'report_jobs_enqueue', 'report_jobs_on_close', 'report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish'])),
         '10 functions'
  union all
  select 3, 'signed-in people (and the service role) can use the switch and read its status; visitors cannot (the database checks who may do what inside)',
         (select count(*) = 2 and bool_and(has_function_privilege('authenticated', p.oid, 'execute') and has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute'))
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_auto_set', 'report_auto_status'])),
         'report_auto_set, report_auto_status'
  union all
  select 4, 'only the service role can run the four job functions (not visitors, not signed-in people)',
         (select count(*) = 4 and bool_and(has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('authenticated', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute'))
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish'])),
         'report_job_claim, report_job_data, report_job_begin, report_job_finish'
  union all
  select 5, 'nobody can run the four internal helpers: not a visitor, not a signed-in person, not even the service role',
         (select count(*) = 4 and bool_and(not has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('authenticated', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute'))
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_jobs_enqueue', 'report_jobs_on_close'])),
         'report_job_act_as, report_job_act_as_end, report_jobs_enqueue, report_jobs_on_close'
  union all
  select 6, 'tables site_report_auto and site_report_jobs have row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_report_auto') is not null and to_regclass('public.site_report_jobs') is not null
          and (select bool_and(c.relrowsecurity) from pg_class c where c.oid in ('public.site_report_auto'::regclass, 'public.site_report_jobs'::regclass))
          and not has_table_privilege('anon', 'public.site_report_auto', 'select') and not has_table_privilege('authenticated', 'public.site_report_auto', 'select')
          and not has_table_privilege('authenticated', 'public.site_report_auto', 'insert') and not has_table_privilege('authenticated', 'public.site_report_auto', 'update') and not has_table_privilege('authenticated', 'public.site_report_auto', 'delete')
          and not has_table_privilege('anon', 'public.site_report_jobs', 'select') and not has_table_privilege('authenticated', 'public.site_report_jobs', 'select')
          and not has_table_privilege('authenticated', 'public.site_report_jobs', 'insert') and not has_table_privilege('authenticated', 'public.site_report_jobs', 'update') and not has_table_privilege('authenticated', 'public.site_report_jobs', 'delete')),
         'RLS on, no grants'
  union all
  select 7, 'no switch and no job exists yet: every report is off and nothing is queued',
         ((select count(*) = 0 from public.site_report_auto) and (select count(*) = 0 from public.site_report_jobs)),
         (select count(*)::text from public.site_report_auto) || ' switches, ' || (select count(*)::text from public.site_report_jobs) || ' jobs'
  union all
  select 8, 'the one trigger on site_night_closes exists, fires after an insert or an update, runs report_jobs_on_close, and is enabled',
         (select count(*) = 1 and bool_and(t.tgenabled = 'O' and (t.tgtype & 1) = 1 and (t.tgtype & 2) = 0 and (t.tgtype & 4) = 4 and (t.tgtype & 16) = 16 and t.tgfoid = 'public.report_jobs_on_close'::regproc)
            from pg_trigger t where t.tgrelid = 'public.site_night_closes'::regclass and t.tgname = 'report_jobs_after_close' and not t.tgisinternal),
         'report_jobs_after_close, after insert or update, for each row'
  union all
  select 9, 'the database refuses a job that is not the right shape, a finished job with no finish time, a state that does not exist, more than five tries, and a second job for the same report and close',
         ((select count(*) = 5 from pg_constraint c where c.conrelid = 'public.site_report_jobs'::regclass and c.conname in ('site_report_jobs_shape', 'site_report_jobs_finished_together', 'site_report_jobs_status_check', 'site_report_jobs_attempts_check', 'site_report_jobs_last_error_check'))
          and exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'site_report_jobs' and indexname = 'site_report_jobs_once' and indexdef like 'CREATE UNIQUE INDEX%')
          and exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'site_report_auto' and indexname = 'site_report_auto_one' and indexdef like 'CREATE UNIQUE INDEX%')),
         'site_report_jobs_shape, _finished_together, _status_check, _attempts_check, _last_error_check, site_report_jobs_once, site_report_auto_one'
  union all
  select 10, 'the person columns do not block deleting an account (ON DELETE SET NULL)',
         ((select count(*) = 2 and bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
            where c.contype = 'f' and ((c.conrelid = 'public.site_report_auto'::regclass and a.attname = 'enabled_by') or (c.conrelid = 'public.site_report_jobs'::regclass and a.attname = 'run_as')))),
         'site_report_auto.enabled_by, site_report_jobs.run_as'
  union all
  select 11, 'the night close table itself was not changed: the same 12 columns and 8 constraints (the trigger is the only change)',
         ((select count(*) = 12 from information_schema.columns where table_schema = 'public' and table_name = 'site_night_closes')
          and (select count(*) = 8 from pg_constraint c where c.conrelid = 'public.site_night_closes'::regclass)),
         'site_night_closes'
  union all
  select 20 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['report_job_act_as', 'report_job_act_as_end', 'report_auto_set', 'report_auto_status', 'report_jobs_enqueue', 'report_jobs_on_close', 'report_job_claim', 'report_job_data', 'report_job_begin', 'report_job_finish'])
) r order by n;
