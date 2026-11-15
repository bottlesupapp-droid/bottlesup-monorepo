-- SCHEDULES the deletion of ended event chats: once an hour, at minute 30, the database runs public.chat_purge_expired()
-- (migration 20261018120000_chat: deletes every chat whose delete_after has passed, 7 days after its event; messages go with it).
--
-- Why a database schedule and not the process-outbox function: that function also sends the queued guest e-mails, which is a separate decision
-- that is still switched off on purpose (docs/FINAL_STEPS.md). This touches nothing but the chat clean-up.
--
-- It turns on the pg_cron extension (available on this Supabase project, not yet installed) in the schema Supabase expects (pg_catalog), then
-- adds ONE job. Run it as the postgres role (the job runs as whoever schedules it). One transaction: all of it or none of it.
-- Check afterwards with supabase/audit/21_postflight_chat_purge_schedule.sql. Undo: supabase/go-live/rollback_chat_purge_schedule.sql.
begin;

create extension if not exists pg_cron with schema pg_catalog;

-- A job with this name is replaced, never duplicated, so running this twice leaves one job.
select cron.schedule('chat-purge-expired', '30 * * * *', $job$select public.chat_purge_expired()$job$);

commit;
