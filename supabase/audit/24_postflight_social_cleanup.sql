-- 24: POST-FLIGHT for supabase/go-live/schedule_social_cleanup.sql. Read-only. Every row should say ok = true.
-- Row 8 stays false until the job has run once (the next 03:15 after scheduling): that is "not yet", not a fault.
select * from (
  select 1 as n, 'pg_cron is installed' as check_name, coalesce((select extversion from pg_extension where extname = 'pg_cron'), 'missing') as actual, 'a version' as expected,
         exists (select 1 from pg_extension where extname = 'pg_cron') as ok
  union all select 2, 'exactly one job named social-housekeeping', (select count(*) from cron.job where jobname = 'social-housekeeping')::text, '1',
         (select count(*) from cron.job where jobname = 'social-housekeeping') = 1
  union all select 3, 'the job runs only the housekeeping function', coalesce((select command from cron.job where jobname = 'social-housekeeping'), 'none'), 'select public.social_housekeeping()',
         coalesce((select command from cron.job where jobname = 'social-housekeeping'), '') = 'select public.social_housekeeping()'
  union all select 4, 'once a day at 03:15, and active', coalesce((select schedule || ' active=' || active from cron.job where jobname = 'social-housekeeping'), 'none'), '15 3 * * * active=true',
         coalesce((select schedule = '15 3 * * *' and active from cron.job where jobname = 'social-housekeeping'), false)
  union all select 5, 'the job runs as postgres (the owner of the function)', coalesce((select username from cron.job where jobname = 'social-housekeeping'), 'none'), 'postgres',
         coalesce((select username = 'postgres' from cron.job where jobname = 'social-housekeeping'), false)
  union all select 6, 'visitors and signed-in people cannot use the cron schema', (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage'))::text, '0',
         (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage')) = 0
  union all select 7, 'visitors and signed-in people cannot call the housekeeping function', (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'social_housekeeping' and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')))::text, '0',
         (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'social_housekeeping' and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))) = 0
  union all select 8, 'the latest run of the job succeeded', coalesce((select d.status || ' at ' || to_char(d.start_time at time zone 'utc', 'YYYY-MM-DD HH24:MI') || ' UTC' from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname = 'social-housekeeping' order by d.start_time desc limit 1), 'not run yet'), 'succeeded',
         coalesce((select d.status = 'succeeded' from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname = 'social-housekeeping' order by d.start_time desc limit 1), false)
) x order by n;
