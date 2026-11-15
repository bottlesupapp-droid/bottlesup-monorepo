-- ROLLBACK for supabase/go-live/schedule_chat_purge.sql: removes the hourly chat clean-up job. Ended event chats then stay until someone runs
-- public.chat_purge_expired() by hand (service role), exactly as before the schedule existed. Deletes nothing else.
--
-- The pg_cron extension is deliberately left installed (dropping it would also remove any other job on the project). If this project has no
-- other job and you want it gone: drop extension pg_cron;
select cron.unschedule('chat-purge-expired');
