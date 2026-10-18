-- Undo for website migration 20261019100000_outbox_claim.sql (the outbox sender's claim/finish functions). Run it in one transaction.
-- It removes the two functions and the hold column; queued, sent and failed messages stay exactly as they are (the hold is only a timestamp).
-- Stop the schedule that calls the process-outbox function first, or its next run will fail on the missing functions (it then does nothing).
begin;
drop function if exists public.outbox_finish(uuid, text, text);
drop function if exists public.outbox_claim(int);
alter table public.site_outbox drop column if exists claimed_at;
commit;
