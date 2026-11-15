-- ROLLBACK for supabase/go-live/schedule_social_jobs.sql: removes the three jobs (sweep, split refunds, pro bookings). From then on the stories' leftover files stay,
-- the refunds that wait are not paid back and the marketplace does not lapse on its own, exactly as before the schedule existed (the refunds done at the moment of cancelling
-- still happen). Deletes nothing else.
--
-- pg_cron and pg_net are deliberately left installed (other jobs use them), and so is the Vault secret service_role_key (remove it yourself if nothing else needs it:
-- delete from vault.secrets where name = 'service_role_key';).
select cron.unschedule(jobname) from cron.job where jobname in ('social-sweep-media', 'split-refunds', 'pro-bookings');
