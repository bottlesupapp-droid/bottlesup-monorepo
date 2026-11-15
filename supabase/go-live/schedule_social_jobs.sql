-- SCHEDULES the three background jobs of the social features (runbook step 7 and the last line of step 6):
--   social-sweep-media  once a day at 03:45 UTC  -> edge function sweep-social-media    (removes the files no post uses any more)
--   split-refunds       every 5 minutes          -> edge function process-split-refunds (pays back the friends' shares that are due)
--   pro-bookings        every 10 minutes         -> edge function process-pro-bookings  (marketplace housekeeping, then the refunds that wait)
--
-- The three functions refuse every caller except one that sends the project's SERVICE ROLE key as the bearer token. The key is NEVER in this file or in the repository:
-- each job reads it from Supabase Vault (a secret named service_role_key) at the moment it runs. Put it there once, yourself, in the dashboard SQL editor:
--     select vault.create_secret('<paste the service_role key here>', 'service_role_key', 'Bearer token for the scheduled edge functions');
-- Until that secret exists the jobs run and do NOTHING (the select below returns no row, so no request is made); once it exists the next run works, no re-scheduling needed.
-- To change the key later: select vault.update_secret((select id from vault.secrets where name = 'service_role_key'), '<new key>');
--
-- All three functions are safe to run when there is nothing to do, and with every feature switch OFF there is nothing to do. pg_net sends the request and the job returns
-- at once; the function's answer is kept for a few hours in net._http_response (supabase/audit/44_postflight_social_jobs.sql reads it).
--
-- pg_cron, pg_net and supabase_vault are already installed on this project (chat-purge-expired runs on pg_cron). Run as the postgres role (a job runs as whoever schedules it).
-- One transaction: all three jobs or none. A job with the same name is replaced, never duplicated, so running this twice leaves three jobs.
-- Undo: supabase/go-live/rollback_social_jobs.sql.
begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule('social-sweep-media', '45 3 * * *', $job$
select net.http_post(
  url := 'https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/sweep-social-media',
  headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || s.decrypted_secret),
  body := '{}'::jsonb,
  timeout_milliseconds := 30000)
from vault.decrypted_secrets s where s.name = 'service_role_key'
$job$);

select cron.schedule('split-refunds', '*/5 * * * *', $job$
select net.http_post(
  url := 'https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/process-split-refunds',
  headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || s.decrypted_secret),
  body := '{}'::jsonb,
  timeout_milliseconds := 30000)
from vault.decrypted_secrets s where s.name = 'service_role_key'
$job$);

select cron.schedule('pro-bookings', '*/10 * * * *', $job$
select net.http_post(
  url := 'https://hwmynlghrmtoufyrcihp.supabase.co/functions/v1/process-pro-bookings',
  headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || s.decrypted_secret),
  body := '{}'::jsonb,
  timeout_milliseconds := 30000)
from vault.decrypted_secrets s where s.name = 'service_role_key'
$job$);

commit;
