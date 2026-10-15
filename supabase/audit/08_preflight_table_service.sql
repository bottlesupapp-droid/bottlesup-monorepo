-- Pre-flight for the four website migrations 20261014100000 .. 20261014130000 (server desk, service requests, bottle orders, payments).
--
-- READ ONLY. One SELECT; nothing is created, changed or locked. Run it in the PRODUCTION SQL editor BEFORE applying them, and send me the
-- grid. The first row says OK when there is no STOP row. Anything marked STOP means: do not apply yet.
--
-- It answers:
--   1. Would any of them collide with something that already exists? (They use plain CREATE on purpose, so a collision stops the
--      migration; this tells you first.)  -> STOP
--   2. Is everything they build on there? The first nine website migrations (workspaces, venue setup, bookings by night, ...) and the
--      production-only money tables, columns and receipt bucket that the last two read.  -> STOP
--
-- The two money migrations (20261014120000 and 130000) stop on their own with a message if a production-only column is missing; this
-- just tells you first. Read from production on 14 Oct 2026 (supabase/audit/06_server_desk_definitions.sql).
with
new_tables(name) as (values ('site_booking_servers'), ('site_service_requests')),
new_funcs(name) as (values
  ('desk_log'), ('booking_venue'), ('assign_booking_server'), ('unassign_booking_server'), ('list_venue_booking_servers'), ('my_assigned_tables'),
  ('desk_level'), ('desk_membership'), ('desk_staff_problem'), ('create_service_request'), ('list_service_requests'), ('update_service_request'),
  ('desk_booking_level'), ('desk_orders'), ('desk_booking_orders'), ('desk_set_service_status'),
  ('receipt_booking'), ('desk_booking_money'), ('desk_record_payment'), ('desk_pending_verifications'), ('desk_verify_payment'),
  ('desk_table_status'), ('desk_tonight')),
new_policies(name) as (values ('desk staff read club payment receipts'), ('desk staff add club payment receipts')),
need_tables(name, from_where) as (values
  ('site_memberships', 'tenancy migration 20261006120000'), ('site_shifts', 'tenancy migration 20261006120000'),
  ('site_venues', 'website schema'), ('site_venue_time_slots', 'website schema'), ('site_table_types', 'website schema'),
  ('site_table_bookings', 'website schema'), ('site_table_booking_bottles', 'website schema'),
  ('site_table_booking_club_payments', 'production only'), ('audit_log', 'website schema'), ('profiles', 'shared with the apps')),
need_funcs(name, from_where) as (values
  ('active_memberships', 'tenancy migration 20261006120000'), ('can_access_venue', 'tenancy migration 20261006120000'),
  ('require_venue_editor', 'venue setup migration 20261010100000'), ('booking_night', 'venue bookings migration 20261011100000')),
need_cols(tbl, col) as (values
  ('site_table_bookings', 'amount_paid_cents'), ('site_table_bookings', 'reconciled_at'), ('site_table_bookings', 'closeout_requested_at'),
  ('site_table_bookings', 'discount_cents'), ('site_table_bookings', 'bottlesup_fee_cents'), ('site_table_bookings', 'deposit_cents'),
  ('site_table_bookings', 'bottle_subtotal_cents'), ('site_table_bookings', 'tax_cents'), ('site_table_bookings', 'currency'),
  ('site_table_booking_bottles', 'payment_status'), ('site_table_booking_bottles', 'service_status'),
  ('site_table_booking_bottles', 'cancelled_at'), ('site_table_booking_bottles', 'cancellation_reason'), ('site_table_booking_bottles', 'is_addon'),
  ('site_table_booking_club_payments', 'booking_id'), ('site_table_booking_club_payments', 'billed_amount_cents'),
  ('site_table_booking_club_payments', 'amount_paid_cents'), ('site_table_booking_club_payments', 'payment_method'),
  ('site_table_booking_club_payments', 'split_breakdown'), ('site_table_booking_club_payments', 'pos_reference'),
  ('site_table_booking_club_payments', 'receipt_photo_path'), ('site_table_booking_club_payments', 'receipt_photo_hash'),
  ('site_table_booking_club_payments', 'recorded_by'), ('site_table_booking_club_payments', 'recorded_at'),
  ('site_table_booking_club_payments', 'customer_confirmation_status'), ('site_table_booking_club_payments', 'dispute_reason'),
  ('site_table_booking_club_payments', 'payer_name'), ('site_table_booking_club_payments', 'payer_email'),
  ('site_table_booking_club_payments', 'manager_verified_at'), ('site_table_booking_club_payments', 'manager_verified_by'),
  ('site_table_booking_club_payments', 'manager_verified_note'), ('site_table_booking_club_payments', 'corrects_payment_id'),
  ('site_table_booking_club_payments', 'bottle_subtotal_cents'), ('site_table_booking_club_payments', 'discount_cents'),
  ('site_table_booking_club_payments', 'tax_cents'), ('site_table_booking_club_payments', 'gratuity_cents'),
  ('site_table_booking_club_payments', 'device_id'), ('site_table_booking_club_payments', 'missing_receipt_reason'),
  ('profiles', 'name'),
  ('audit_log', 'actor_id'), ('audit_log', 'actor_email'), ('audit_log', 'action'), ('audit_log', 'entity_type'), ('audit_log', 'entity_id'),
  ('audit_log', 'details')),
checks as (
  select 'STOP' as severity, 'name already taken (table)' as "check", t.name as item,
         'a table called ' || t.name || ' already exists, so its migration would stop' as detail
  from new_tables t where to_regclass('public.' || t.name) is not null
  union all
  select 'STOP', 'name already taken (function)', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
         'a function with this name already exists in public, so its migration would stop'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in (select name from new_funcs)
  union all
  select 'STOP', 'name already taken (storage policy)', pol.policyname, 'a storage policy with this name already exists'
  from pg_policies pol where pol.schemaname = 'storage' and pol.tablename = 'objects' and pol.policyname in (select name from new_policies)
  union all
  select 'STOP', 'missing table', nt.name, 'needed, from: ' || nt.from_where
  from need_tables nt where to_regclass('public.' || nt.name) is null
  union all
  select 'STOP', 'missing function', nf.name, 'needed, from: ' || nf.from_where
  from need_funcs nf where not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = nf.name)
  union all
  select 'STOP', 'missing column', nc.tbl || '.' || nc.col, 'the money migrations read this column (it exists in production as of 14 Oct 2026)'
  from need_cols nc
  where to_regclass('public.' || nc.tbl) is not null
    and not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = nc.tbl and c.column_name = nc.col)
  union all
  select 'STOP', 'missing storage bucket', 'club-payment-receipts', 'the receipt photos go here (private bucket)'
  where not exists (select 1 from storage.buckets b where b.id = 'club-payment-receipts')
  union all
  select 'WARN', 'receipt bucket is public', 'club-payment-receipts', 'receipts can show partial card digits: the bucket should be private'
  from storage.buckets b where b.id = 'club-payment-receipts' and b.public
  union all
  select 'INFO', 'existing policies on the receipt bucket (left as they are)', pol.policyname,
         'they let any door_staff / CMS admin reach receipts of any club; the new policies add club-scoped access beside them'
  from pg_policies pol
  where pol.schemaname = 'storage' and pol.tablename = 'objects' and pol.qual ilike '%club-payment-receipts%' and pol.policyname not in (select name from new_policies)
)
select 0 as ord,
       case when count(*) filter (where severity = 'STOP') = 0 then 'OK' else 'STOP' end as severity,
       'summary' as "check",
       count(*) filter (where severity = 'STOP')::text || ' STOP, ' || count(*) filter (where severity = 'WARN')::text || ' WARN' as item,
       case when count(*) filter (where severity = 'STOP') = 0
            then 'nothing in the way: the four migrations can be applied, in order, after the first nine'
            else 'do not apply yet: send me this grid' end as detail
from checks
union all
select 1, severity, "check", item, detail from checks
order by 1, 2, 3, 4;
