-- UNDO supabase/go-live/schedule_report_jobs.sql: stops the scheduled call to run-report-jobs. Reports already queued stay queued (and are sent if the job is scheduled again).
-- Run as the postgres role. Safe to run twice.
select cron.unschedule(jobid) from cron.job where jobname = 'report-jobs';
