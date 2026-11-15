-- 44: POST-FLIGHT for supabase/go-live/schedule_social_jobs.sql. Read-only. Prints no secret (only whether it exists).
-- Rows 1 to 6 should say ok = true as soon as the jobs are scheduled. Rows 7 to 9 stay false until you have put the service_role key in Vault and the next run has happened
-- (up to 5 minutes for the refund job, 10 for the pro-bookings job, the next 03:45 UTC for the sweep): that is "not yet", not a fault.
select * from (
  select 1 as n, 'the three jobs exist, once each' as check_name,
         (select string_agg(jobname || '=' || c, ', ' order by jobname) from (select jobname, count(*)::text c from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings') group by jobname) j) as actual,
         'pro-bookings=1, social-sweep-media=1, split-refunds=1' as expected,
         (select count(*) from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings')) = 3 as ok
  union all select 2, 'schedules: sweep daily 03:45, refunds every 5 min, pro bookings every 10 min, all active',
         (select string_agg(jobname || ' ' || schedule || ' active=' || active, ' | ' order by jobname) from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings')),
         'pro-bookings */10 * * * * active=true | social-sweep-media 45 3 * * * active=true | split-refunds */5 * * * * active=true',
         coalesce((select count(*) = 3 from cron.job where active and ((jobname = 'social-sweep-media' and schedule = '45 3 * * *') or (jobname = 'split-refunds' and schedule = '*/5 * * * *') or (jobname = 'pro-bookings' and schedule = '*/10 * * * *'))), false)
  union all select 3, 'each job calls its own function (and nothing else)',
         (select count(*)::text from cron.job where (jobname = 'social-sweep-media' and command like '%/functions/v1/sweep-social-media''%') or (jobname = 'split-refunds' and command like '%/functions/v1/process-split-refunds''%') or (jobname = 'pro-bookings' and command like '%/functions/v1/process-pro-bookings''%')),
         '3',
         (select count(*) from cron.job where (jobname = 'social-sweep-media' and command like '%/functions/v1/sweep-social-media''%') or (jobname = 'split-refunds' and command like '%/functions/v1/process-split-refunds''%') or (jobname = 'pro-bookings' and command like '%/functions/v1/process-pro-bookings''%')) = 3
  union all select 4, 'no job holds a key (the command reads it from Vault)',
         (select count(*)::text from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings') and (command ~ 'eyJ[A-Za-z0-9_-]{20,}' or command ~ 'sb_secret_')),
         '0',
         (select count(*) from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings') and (command ~ 'eyJ[A-Za-z0-9_-]{20,}' or command ~ 'sb_secret_')) = 0
  union all select 5, 'visitors and signed-in people cannot use the cron schema or read Vault',
         (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage') or has_table_privilege(r.role, 'vault.decrypted_secrets', 'select') or has_table_privilege(r.role, 'vault.secrets', 'select'))::text,
         '0',
         (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage') or has_table_privilege(r.role, 'vault.decrypted_secrets', 'select') or has_table_privilege(r.role, 'vault.secrets', 'select')) = 0
  union all select 6, 'the jobs run as postgres',
         coalesce((select string_agg(distinct username, ', ') from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings')), 'none'),
         'postgres',
         coalesce((select bool_and(username = 'postgres') from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings')), false)
  union all select 7, 'the Vault secret service_role_key exists (the jobs do nothing until it does)',
         (select count(*)::text from vault.secrets where name = 'service_role_key'),
         '1',
         (select count(*) from vault.secrets where name = 'service_role_key') = 1
  union all select 8, 'every job has run at least once, and its latest run succeeded (this only means the request was handed to pg_net)',
         coalesce((select string_agg(j.jobname || '=' || coalesce((select d.status from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1), 'no run yet'), ', ' order by j.jobname) from cron.job j where j.jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings')), 'no jobs'),
         'all succeeded',
         coalesce((select bool_and(coalesce((select d.status = 'succeeded' from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1), false)) from cron.job j where j.jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings')), false)
  union all select 9, 'the functions answered HTTP 200 to every request of the last 6 hours (pg_net keeps no URL, so this is all of them: they are this project''s only pg_net callers)',
         coalesce((select string_agg(status_code::text || ' x' || c, ', ' order by status_code) from (select status_code, count(*) c from net._http_response where created > now() - interval '6 hours' group by status_code) r), 'no answer yet'),
         '200 only, at least one',
         coalesce((select count(*) > 0 and bool_and(status_code = 200) from net._http_response where created > now() - interval '6 hours'), false)
) x order by n;
