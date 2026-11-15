-- 21: POST-FLIGHT for supabase/go-live/schedule_chat_purge.sql. Read-only. Every row should say ok = true.
-- Row 8 stays false until the job has run once (up to an hour after scheduling, at minute 30): that is "not yet", not a fault.
select * from (
  select 1 as n, 'pg_cron is installed' as check_name, coalesce((select extversion from pg_extension where extname = 'pg_cron'), 'missing') as actual, 'a version' as expected,
         exists (select 1 from pg_extension where extname = 'pg_cron') as ok
  union all select 2, 'exactly one job named chat-purge-expired', (select count(*) from cron.job where jobname = 'chat-purge-expired')::text, '1',
         (select count(*) from cron.job where jobname = 'chat-purge-expired') = 1
  union all select 3, 'the job runs only the purge function', coalesce((select command from cron.job where jobname = 'chat-purge-expired'), 'none'), 'select public.chat_purge_expired()',
         coalesce((select command from cron.job where jobname = 'chat-purge-expired'), '') = 'select public.chat_purge_expired()'
  union all select 4, 'once an hour at minute 30, and active', coalesce((select schedule || ' active=' || active from cron.job where jobname = 'chat-purge-expired'), 'none'), '30 * * * * active=true',
         coalesce((select schedule = '30 * * * *' and active from cron.job where jobname = 'chat-purge-expired'), false)
  union all select 5, 'the job runs as postgres (the owner of the function)', coalesce((select username from cron.job where jobname = 'chat-purge-expired'), 'none'), 'postgres',
         coalesce((select username = 'postgres' from cron.job where jobname = 'chat-purge-expired'), false)
  union all select 6, 'visitors and signed-in people cannot use the cron schema', (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage'))::text, '0',
         (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage')) = 0
  union all select 7, 'visitors and signed-in people cannot call the purge function', (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'chat_purge_expired' and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')))::text, '0',
         (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'chat_purge_expired' and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))) = 0
  union all select 8, 'the latest run of the job succeeded', coalesce((select d.status || ' at ' || to_char(d.start_time at time zone 'utc', 'YYYY-MM-DD HH24:MI') || ' UTC' from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname = 'chat-purge-expired' order by d.start_time desc limit 1), 'no run yet'), 'succeeded',
         coalesce((select d.status = 'succeeded' from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname = 'chat-purge-expired' order by d.start_time desc limit 1), false)
) x order by n;
