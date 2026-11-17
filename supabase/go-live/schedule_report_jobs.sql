-- SCHEDULES the automatic report e-mails: every 5 minutes the database asks the edge function run-report-jobs to send the reports that were queued when a night was closed
-- (website migration 20261126100000_auto_report_jobs and the function run-report-jobs). Add this only AFTER the migration is applied and the function is deployed.
--
-- The function refuses every caller except one that sends the project's SERVICE ROLE key as the bearer token. The key is NEVER in this file or in the repository: the job reads it from Supabase
-- Vault (a secret named service_role_key) at the moment it runs, exactly as the social jobs do (supabase/go-live/schedule_social_jobs.sql). If that secret already exists you have nothing to add.
-- If it does not, put it there once, yourself, in the dashboard SQL editor:
--     select vault.create_secret('<paste the service_role key here>', 'service_role_key', 'Bearer token for the scheduled edge functions');
-- Until that secret exists the job runs and does NOTHING (the select below returns no row, so no request is made).
--
-- Safe to run when nothing is queued, and with every switch off nothing is. The function also needs RESEND_API_KEY set (already set for the other e-mails): without it a queued report waits and says so.
-- Run as the postgres role (a job runs as whoever schedules it). A job with the same name is replaced, never duplicated, so running this twice leaves one job. Undo: supabase/go-live/rollback_report_jobs_schedule.sql.
begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule('report-jobs', '*/5 * * * *', $job$
select net.http_post(
  url := 'https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/run-report-jobs',
  headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || s.decrypted_secret),
  body := '{}'::jsonb,
  timeout_milliseconds := 55000)
from vault.decrypted_secrets s where s.name = 'service_role_key'
$job$);

commit;
