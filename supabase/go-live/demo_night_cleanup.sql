-- Removes the demo night put in by demo_night.sql, and anything recorded against it in the app, and ONLY that: bookings whose e-mail ends in
-- @demo.bottlesup.invalid AND whose confirmation code starts with DEMO-. Real bookings are never matched.
--
-- Production refuses to delete a recorded club payment (a trigger), so that guard is switched off for the length of this one transaction, for
-- these bookings' payments only, and switched back on before it commits. The audit log keeps its entries (who did what), and receipt photos
-- uploaded for demo payments stay in the storage bucket (a file nobody can reach any more: delete them in Storage > club-payment-receipts if you wish).
begin;

create temporary table demo_ids on commit drop as
  select b.id from public.site_table_bookings b
  where b.customer_email like '%@demo.bottlesup.invalid' and b.confirmation_code like 'DEMO-%';

alter table public.site_table_booking_club_payments disable trigger no_delete_club_payments;
delete from public.site_table_bookings where id in (select id from demo_ids);
alter table public.site_table_booking_club_payments enable trigger no_delete_club_payments;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'no_delete_club_payments' and tgrelid = 'public.site_table_booking_club_payments'::regclass and tgenabled <> 'D') then
    raise exception 'the payment-delete guard did not come back on: nothing was changed';
  end if;
end $$;

commit;
