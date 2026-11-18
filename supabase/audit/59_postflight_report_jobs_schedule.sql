-- 59: POST-FLIGHT for supabase/go-live/schedule_report_jobs.sql (the automatic report e-mails). Read-only. Prints no secret (only whether it exists).
-- Rows 1 to 6 should say ok = true as soon as the job is scheduled. Rows 7 to 9 stay false until the service_role key is in Vault (a secret named service_role_key) and the next run has happened
-- (up to 5 minutes): that is "not yet", not a fault. With the secret in place and nothing queued, a run answers HTTP 200 and does nothing.
select * from (
  select 1 as n, 'the job report-jobs exists, once' as check_name,
         (select count(*)::text from cron.job where jobname = 'report-jobs') as actual,
         '1' as expected,
         (select count(*) from cron.job where jobname = 'report-jobs') = 1 as ok
  union all select 2, 'it runs every 5 minutes and is active',
         coalesce((select string_agg(schedule || ' active=' || active, ' | ') from cron.job where jobname = 'report-jobs'), 'none'),
         '*/5 * * * * active=true',
         coalesce((select bool_and(schedule = '*/5 * * * *' and active) from cron.job where jobname = 'report-jobs'), false)
  union all select 3, 'it calls the function run-report-jobs (and nothing else)',
         (select count(*)::text from cron.job where jobname = 'report-jobs' and command like '%/functions/v1/run-report-jobs''%'),
         '1',
         (select count(*) from cron.job where jobname = 'report-jobs' and command like '%/functions/v1/run-report-jobs''%') = 1
  union all select 4, 'the job holds no key (the command reads it from Vault)',
         (select count(*)::text from cron.job where jobname = 'report-jobs' and (command ~ 'eyJ[A-Za-z0-9_-]{20,}' or command ~ 'sb_secret_')),
         '0',
         (select count(*) from cron.job where jobname = 'report-jobs' and (command ~ 'eyJ[A-Za-z0-9_-]{20,}' or command ~ 'sb_secret_')) = 0
  union all select 5, 'visitors and signed-in people cannot use the cron schema or read Vault',
         (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage') or has_table_privilege(r.role, 'vault.decrypted_secrets', 'select') or has_table_privilege(r.role, 'vault.secrets', 'select'))::text,
         '0',
         (select count(*) from (values ('anon'), ('authenticated')) r(role) where has_schema_privilege(r.role, 'cron', 'usage') or has_table_privilege(r.role, 'vault.decrypted_secrets', 'select') or has_table_privilege(r.role, 'vault.secrets', 'select')) = 0
  union all select 6, 'the job runs as postgres',
         coalesce((select string_agg(distinct username, ', ') from cron.job where jobname = 'report-jobs'), 'none'),
         'postgres',
         coalesce((select bool_and(username = 'postgres') from cron.job where jobname = 'report-jobs'), false)
  union all select 7, 'the Vault secret service_role_key exists (the job does nothing until it does)',
         (select count(*)::text from vault.secrets where name = 'service_role_key'),
         '1',
         (select count(*) from vault.secrets where name = 'service_role_key') = 1
  union all select 8, 'the job has run at least once, and its latest run succeeded (this only means the request was handed to pg_net)',
         coalesce((select coalesce((select d.status from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1), 'no run yet') from cron.job j where j.jobname = 'report-jobs'), 'no job'),
         'succeeded',
         coalesce((select coalesce((select d.status = 'succeeded' from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1), false) from cron.job j where j.jobname = 'report-jobs'), false)
  union all select 9, 'every request pg_net answered in the last 6 hours got HTTP 200 (pg_net keeps no URL: these are all the project''s scheduled calls, this job and the social jobs)',
         coalesce((select string_agg(status_code::text || ' x' || c, ', ' order by status_code) from (select status_code, count(*) c from net._http_response where created > now() - interval '6 hours' group by status_code) r), 'no answer yet'),
         '200 only, at least one',
         coalesce((select count(*) > 0 and bool_and(status_code = 200) from net._http_response where created > now() - interval '6 hours'), false)
) x order by n;
