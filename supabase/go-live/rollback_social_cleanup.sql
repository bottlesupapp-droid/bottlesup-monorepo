-- ROLLBACK for supabase/go-live/schedule_social_cleanup.sql: removes the daily social clean-up job. Expired stories, old read notifications and old caption-idea requests then stay
-- until someone runs public.social_housekeeping() by hand (service role). Deletes nothing else.
--
-- The pg_cron extension is deliberately left installed (dropping it would also remove any other job on the project, such as the chat clean-up).
select cron.unschedule('social-housekeeping');
