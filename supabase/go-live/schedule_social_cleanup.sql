-- SCHEDULES the daily clean-up of the social side: once a day at 03:15 the database runs public.social_housekeeping()
-- (migration 20261105100000_safety_moderation): it deletes stories that expired more than 7 days ago, notifications that were read more than 90 days ago, and caption-idea
-- requests older than two days. It never touches posts, comments, messages or reports.
--
-- This is the database-only half of the clean-up. The other half, removing the PICTURES AND VIDEOS no post uses any more (a story's files after the story is deleted, an upload
-- whose post was never made, a deleted account's folder), needs the storage API, so it is the edge function `sweep-social-media`: see supabase/go-live/README.md,
-- "Going live: the social side", step 5. Without it the rows go but the files stay (they only cost space).
--
-- It turns on the pg_cron extension (the same one the chat clean-up uses) in the schema Supabase expects (pg_catalog), then adds ONE job. Run it as the postgres role (the job runs as
-- whoever schedules it). One transaction: all of it or none of it.
-- Check afterwards with supabase/audit/24_postflight_social_cleanup.sql. Undo: supabase/go-live/rollback_social_cleanup.sql.
begin;

create extension if not exists pg_cron with schema pg_catalog;

-- A job with this name is replaced, never duplicated, so running this twice leaves one job.
select cron.schedule('social-housekeeping', '15 3 * * *', $job$select public.social_housekeeping()$job$);

commit;
