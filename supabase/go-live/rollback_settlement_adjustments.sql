-- ROLLBACK for 20261125100000_settlement_adjustments.sql: removes the adjustments recorded AFTER settlements were paid. It DELETES what was recorded: every adjustment (refunds, chargebacks and
-- corrections with their reasons and references, the recorded external payments that settled them, the questions and answers) and their history. A PAID SETTLEMENT ITSELF IS NOT TOUCHED: its figures, its
-- payment record and its history stay exactly as they are (the migration never changed them), and nothing was ever sent to anyone. Take a copy first if the records matter:
--   select * from public.site_settlement_adjustments;  select * from public.site_settlement_adjustment_log;
-- One transaction: all of it or none of it.
begin;

drop function if exists public.settlement_adjustment_waive(uuid, text);
drop function if exists public.settlement_adjustment_settle(uuid, bigint, date, text, text);
drop function if exists public.settlement_adjustment_acknowledge(uuid);
drop function if exists public.settlement_adjustment_answer(uuid, text);
drop function if exists public.settlement_adjustment_question(uuid, text);
drop function if exists public.settlement_adjustment_record(uuid, text, bigint, text, text);
drop function if exists public.settlement_adjustment_flags_for_organizer(uuid);
drop function if exists public.settlement_adjustment_flags_for_venue(uuid);
drop function if exists public.settlement_adjustments(uuid);
drop function if exists public.settlement_adjustment_log_add(uuid, uuid, text, text, text, text, bigint, text);

drop table if exists public.site_settlement_adjustment_log;
drop table if exists public.site_settlement_adjustments;

commit;
