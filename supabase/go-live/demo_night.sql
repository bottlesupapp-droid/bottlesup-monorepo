-- OPTIONAL. Puts a small, clearly-marked DEMO night into the club you choose, so the new vendor-app tabs have something to show
-- (orders to move, a table that owes money, a table with no server). Run it in the production SQL editor AFTER the four table-service
-- migrations (go-live/README.md, section 1c) and AFTER the club has a table type, an arrival time and an accepted server.
--
-- WHAT IT ADDS (3 rows in site_table_bookings, 5 in site_table_booking_bottles, 2 in site_booking_servers), all marked so they can be removed:
--   * customer e-mails end in @demo.bottlesup.invalid (not a real domain; nothing can be sent there) and confirmation codes start with DEMO-
--   * "Demo Ada"   : paid, 4 guests, owes $200.00; three bottles (one prepaid, two to be paid at the venue); belongs to your server
--   * "Demo Grace" : paid, 2 guests, paid up, arrived; one bottle on the way; belongs to your server
--   * "Demo Nell"  : paid, 3 guests, owes $60.00; one bottle; belongs to NOBODY (shows under "Tables without a server")
-- It touches nothing else and writes no payment: payments are made by the people testing, in the app.
--
-- THEY ARE REAL ROWS in production tables. They will appear in the CMS bookings list, may be counted in the CMS's booking totals, and anything
-- recorded against them stays. Remove them when the walk-through is over with demo_night_cleanup.sql. Do not run this on a night with real
-- bookings you do not want mixed with demo ones.
--
-- BEFORE RUNNING: change the three values just below.
do $$
declare
  v_venue_name constant text := 'EDIT ME: the exact name of the test club';
  v_server_email constant text := 'EDIT ME: the e-mail of a server who has accepted the invitation';
  v_night constant date := current_date;   -- the business night to show; change it if the phone is in another time zone
  v_venue uuid; v_org uuid; v_type uuid; v_slot uuid; v_server_membership uuid; v_server_user uuid; v_owner_user uuid;
  v_ada uuid; v_grace uuid; v_nell uuid;
  n int;
begin
  select count(*) into n from public.site_venues where name = v_venue_name;
  if n <> 1 then raise exception 'found % clubs called "%": use the exact name of one club', n, v_venue_name; end if;
  select id, org_id into v_venue, v_org from public.site_venues where name = v_venue_name;

  select t.id into v_type from public.site_table_types t where t.venue_id = v_venue order by t.sort_order, t.created_at limit 1;
  if v_type is null then raise exception 'this club has no table type: add one in Venues > Setup first'; end if;
  select s.id into v_slot from public.site_venue_time_slots s where s.venue_id = v_venue and s.start_time >= time '06:00' order by s.start_time limit 1;
  if v_slot is null then raise exception 'this club has no arrival time from 06:00 on: add one in Venues > Setup first'; end if;

  select m.id, m.user_id into v_server_membership, v_server_user
    from public.site_memberships m join auth.users u on u.id = m.user_id
    where m.role = 'server' and m.venue_id = v_venue and m.status = 'active' and lower(u.email) = lower(v_server_email) limit 1;
  if v_server_membership is null then
    raise exception 'no active server with the e-mail "%" at this club: invite them from Team and let them accept first', v_server_email;
  end if;
  select m.user_id into v_owner_user from public.site_memberships m where m.role = 'owner' and m.org_id = v_org and m.status = 'active' limit 1;

  if exists (select 1 from public.site_table_bookings b where b.venue_id = v_venue and b.booking_date = v_night and b.customer_email like '%@demo.bottlesup.invalid') then
    raise exception 'the demo night is already there for % at this club: run demo_night_cleanup.sql first', v_night;
  end if;

  insert into public.site_table_bookings (venue_id, table_type_id, time_slot_id, booking_date, customer_name, customer_email, guest_count,
                                          amount_total_cents, amount_paid_cents, deposit_cents, status, confirmation_code)
  values (v_venue, v_type, v_slot, v_night, 'Demo Ada', 'demo.ada@demo.bottlesup.invalid', 4, 30000, 10000, 10000, 'paid', 'DEMO-' || upper(substr(md5(random()::text), 1, 6)))
  returning id into v_ada;
  insert into public.site_table_bookings (venue_id, table_type_id, time_slot_id, booking_date, customer_name, customer_email, guest_count,
                                          amount_total_cents, amount_paid_cents, deposit_cents, status, confirmation_code, checked_in_at)
  values (v_venue, v_type, v_slot, v_night, 'Demo Grace', 'demo.grace@demo.bottlesup.invalid', 2, 14000, 14000, 14000, 'paid', 'DEMO-' || upper(substr(md5(random()::text), 1, 6)), now())
  returning id into v_grace;
  insert into public.site_table_bookings (venue_id, table_type_id, time_slot_id, booking_date, customer_name, customer_email, guest_count,
                                          amount_total_cents, amount_paid_cents, deposit_cents, status, confirmation_code)
  values (v_venue, v_type, v_slot, v_night, 'Demo Nell', 'demo.nell@demo.bottlesup.invalid', 3, 6000, 0, 0, 'paid', 'DEMO-' || upper(substr(md5(random()::text), 1, 6)))
  returning id into v_nell;

  insert into public.site_table_booking_bottles (booking_id, bottle_name, size, unit_price_cents, quantity, line_total_cents, payment_status, service_status, created_at) values
    (v_ada,   'Patron Silver',     '750ml', 9500,  1, 9500,  'paid',         'awaiting_prep', now() - interval '35 minutes'),
    (v_ada,   'Grey Goose',        '750ml', 8000,  2, 16000, 'due_at_venue', 'preparing',     now() - interval '20 minutes'),
    (v_ada,   'Moet & Chandon',    '750ml', 12000, 1, 12000, 'due_at_venue', 'ready',         now() - interval '8 minutes'),
    (v_grace, 'Don Julio 1942',    '750ml', 14000, 1, 14000, 'paid',         'picked_up',     now() - interval '12 minutes'),
    (v_nell,  'Belvedere',         '750ml', 6000,  1, 6000,  'due_at_venue', 'awaiting_prep', now() - interval '3 minutes');

  insert into public.site_booking_servers (booking_id, membership_id, assigned_by)
  values (v_ada, v_server_membership, coalesce(v_owner_user, v_server_user)), (v_grace, v_server_membership, coalesce(v_owner_user, v_server_user));

  raise notice 'Demo night added for % on %: 3 tables, 5 bottles, 2 given to %.', v_venue_name, v_night, v_server_email;
end $$;
