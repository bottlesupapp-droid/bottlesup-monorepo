-- ROLLBACK for 20261122120000_organizer_settlements.sql: removes the organizer settlement RECORDS. It DELETES what was recorded: every settlement (the sales figures entered, the amounts, the approvals, the recorded
-- external payments with their references) and the whole history. Nothing was ever sent to anyone and BottlesUp's own payouts (site_payout_items) are not touched. Take a copy first if the records matter:
--   select * from public.site_settlements;  select * from public.site_settlement_log;
-- One transaction: all of it or none of it.
begin;

drop function if exists public.settlement_acknowledge(uuid);
drop function if exists public.settlement_resolve(uuid, text);
drop function if exists public.settlement_question(uuid, text);
drop function if exists public.settlement_record_payment(uuid, bigint, date, text, text);
drop function if exists public.settlement_approve(uuid);
drop function if exists public.settlement_review(uuid);
drop function if exists public.settlement_adjust(uuid, bigint, text);
drop function if exists public.settlement_save_sales(uuid, bigint, text);
drop function if exists public.settlement_detail(uuid);
drop function if exists public.settlements_for_organizer(uuid);
drop function if exists public.settlements_for_venue(uuid);
drop function if exists public.settlement_base(jsonb, bigint);
drop function if exists public.settlement_log_add(uuid, text, text, text, text, bigint, text);

drop table if exists public.site_settlement_log;
drop table if exists public.site_settlements;

commit;
