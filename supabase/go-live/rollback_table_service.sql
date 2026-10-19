-- Undoes the four website migrations 20261014100000 .. 20261014130000 (server desk, service requests, bottle orders, payments).
--
-- WHAT IT REMOVES: the 23 functions, the two new tables and the two new storage policies on the receipt bucket. Nothing else is touched:
-- production's own functions, tables and policies (including the older receipt policies) are not named here.
--
-- WHAT YOU LOSE: the table-to-server assignments (site_booking_servers) and the service requests (site_service_requests) made since. Payments
-- recorded through these functions stay: they are rows in production's own payments table, which this does not touch (and which refuses
-- deletes). Orders moved through these functions stay moved.
--
-- WHEN: only if something is wrong with the new tabs. The website and the old apps do not use any of this, so removing it changes nothing for
-- them. Run it in the SQL editor of the project. It is one transaction: it either removes everything or nothing.
begin;

drop policy if exists "desk staff read club payment receipts" on storage.objects;
drop policy if exists "desk staff add club payment receipts" on storage.objects;

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in (
        'desk_log', 'booking_venue', 'assign_booking_server', 'unassign_booking_server', 'list_venue_booking_servers', 'my_assigned_tables',
        'desk_level', 'desk_membership', 'desk_staff_problem', 'create_service_request', 'list_service_requests', 'update_service_request',
        'desk_booking_level', 'desk_orders', 'desk_booking_orders', 'desk_set_service_status',
        'receipt_booking', 'desk_booking_money', 'desk_record_payment', 'desk_pending_verifications', 'desk_verify_payment',
        'desk_table_status', 'desk_tonight')
  loop
    execute 'drop function ' || r.sig;
  end loop;
end $$;

drop table if exists public.site_service_requests;
drop table if exists public.site_booking_servers;

commit;
