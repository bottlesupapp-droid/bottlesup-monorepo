-- 16: PRE-FLIGHT for the eight tranche-2 website migrations 20261020100000 .. 20261020170000 (branch feat/business-brief-2). Read-only. It lists problems; ROWS = STOP.
--   * a function name these files create already exists, or a column the door staff or partial delivery migration adds already exists (the files are plain CREATEs: they would fail);
--   * a prerequisite function, table or column is missing (the earlier migrations, or a production-only column, are not there);
--   * invite_member() is neither the version the door staff migration was written against nor the one it writes (that migration would stop and change nothing, by design).
-- Run it BEFORE applying. AFTER they are applied it will (correctly) list every name as already existing: use 17_postflight_business_brief_2.sql then.
-- Not run against production by Claude; on a scratch copy it returns no rows before the migrations and lists all 23 objects after.

select 'function already exists' as problem, p.proname::text as name
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = any(array['venue_payment_rules','save_venue_payment_rules','desk_booking_guests','desk_booking_activity','list_org_event_states','event_door_allowed','organizer_event_door_status','venue_door_permissions','set_organizer_door_staff','venue_event_door_staff','revoke_event_door_access','desk_walkin_options','desk_create_walkin','desk_may_add_bottles','desk_bottle_menu','desk_booking_deliveries','desk_deliver_part','door_admit_group','door_admission_counts','door_guest_admissions']::text[])
union all
select 'column already exists', 'site_agreements.organizer_door_staff'
  where exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'site_agreements' and c.column_name = 'organizer_door_staff')
union all
select 'table already exists', 'site_order_admissions'
  where to_regclass('public.site_order_admissions') is not null
union all
select 'column already exists', 'site_table_booking_bottles.delivered_quantity'
  where exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'site_table_booking_bottles' and c.column_name = 'delivered_quantity')
union all
select 'MISSING prerequisite function', f from unnest(array['desk_log','desk_level','desk_booking_level','desk_enqueue','has_door_role','can_scan_event','can_access_venue','require_venue_editor','require_org_organizer','setup_text','setup_only_keys','can_invite_role','invite_member','booking_night','active_memberships']::text[]) f
  where not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = f)
union all
select 'MISSING prerequisite table', t from unnest(array['site_venues','site_events','site_organizations','site_memberships','site_invitations','site_agreements','site_table_bookings','site_table_types','site_venue_time_slots','site_booking_seating','site_night_closes','site_outbox','site_table_booking_club_payments','site_table_booking_bottles','site_payment_flags','site_shifts','guest_tickets','scan_attempts','audit_log','profiles']::text[]) t where to_regclass('public.' || t) is null
union all
select 'MISSING prerequisite column', x from unnest(array['site_venues.bottle_payment_mode','site_venues.deposit_is_credit','site_table_types.name','site_table_types.max_guests','site_table_types.min_guests','site_table_types.pricing_mode','site_table_types.deposit_cents','site_table_types.hourly_rate_cents','site_table_types.min_hours','site_table_types.inventory_count','site_table_types.sort_order','site_table_types.currency','site_venue_time_slots.day_of_week','site_venue_time_slots.start_time','site_venue_time_slots.label','site_table_bookings.venue_id','site_table_bookings.table_type_id','site_table_bookings.time_slot_id','site_table_bookings.booking_date','site_table_bookings.customer_name','site_table_bookings.customer_email','site_table_bookings.customer_phone','site_table_bookings.guest_count','site_table_bookings.hours','site_table_bookings.deposit_cents','site_table_bookings.bottle_subtotal_cents','site_table_bookings.tax_cents','site_table_bookings.bottlesup_fee_cents','site_table_bookings.amount_total_cents','site_table_bookings.amount_paid_cents','site_table_bookings.currency','site_table_bookings.status','site_table_bookings.bottle_payment_choice','site_table_bookings.confirmation_code','site_table_bookings.checked_in_at','site_table_bookings.checked_in_by','site_booking_seating.booking_id','site_booking_seating.seated_by','site_booking_seating.seated_at','site_booking_seating.method','site_booking_seating.confirmation','site_table_booking_bottles.quantity','site_table_booking_bottles.payment_status','site_table_booking_bottles.service_status','site_table_booking_bottles.cancelled_at','site_table_booking_bottles.bottle_id','site_bottles.price_cents','site_bottles.is_available','site_bottles.is_sold_out','site_bottles.stock_quantity','site_bottles.sort_order','site_night_closes.business_night','site_night_closes.status','site_table_bookings.reconciled_at','site_orders.ticket_code','site_orders.quantity','site_orders.status','site_orders.checked_in_at','site_orders.checked_in_by','site_orders.is_non_transferable','site_orders.access_code_verified','scan_attempts.result','scan_attempts.order_id']::text[]) x
  where not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = split_part(x, '.', 1) and c.column_name = split_part(x, '.', 2))
union all
-- invite_member is replaced by a compare-and-swap: it must be exactly the 20261006120000 version (fingerprint below) or already carry the rule.
select 'invite_member is neither the expected version nor the new one (the door staff migration will stop; reconcile by hand first)',
       md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, ''))
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'invite_member'
   and pg_get_function_identity_arguments(p.oid) = 'p_org uuid, p_email text, p_role text, p_venue uuid, p_event uuid, p_shift uuid, p_access_start timestamp with time zone, p_access_end timestamp with time zone, p_valid_for interval'
   and position('event_door_allowed' in p.prosrc) = 0
   and md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')) <> 'cada6eec917b99ecd953f4c4dcb64040'
order by 1, 2;
