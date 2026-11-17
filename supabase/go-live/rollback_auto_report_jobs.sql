-- ROLLBACK for 20261126100000_auto_report_jobs.sql: stops the automatic report e-mails and removes what the migration built. It DELETES the switches and the queue of jobs (which reports were
-- queued, and how each went). Reports already e-mailed stay in the delivery log (site_report_deliveries is the report e-mails migration's, not this one's), and nothing else is changed: the trigger
-- on site_night_closes is dropped, so closing a night goes back to doing exactly what it did before. If the scheduled job (supabase/go-live/schedule_report_jobs.sql) was added, remove it first
-- with supabase/go-live/rollback_report_jobs_schedule.sql (it only calls a function that does nothing when there is nothing queued, so leaving it for a while is harmless).
-- One transaction: all of it or none of it.
begin;

drop trigger if exists report_jobs_after_close on public.site_night_closes;

drop function if exists public.report_job_finish(uuid, text, text);
drop function if exists public.report_job_begin(uuid, text, int);
drop function if exists public.report_job_data(uuid);
drop function if exists public.report_job_claim(int);
drop function if exists public.report_jobs_on_close();
drop function if exists public.report_jobs_enqueue(uuid, date);
drop function if exists public.report_auto_status(text, uuid, uuid);
drop function if exists public.report_auto_set(text, uuid, uuid, boolean);
drop function if exists public.report_job_act_as_end(text, text);
drop function if exists public.report_job_act_as(uuid);

drop table if exists public.site_report_jobs;
drop table if exists public.site_report_auto;

commit;
