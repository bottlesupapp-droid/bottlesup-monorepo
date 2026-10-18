-- 15: CHECK that production already is what the two September migrations describe (read-only: it changes nothing).
--   supabase/migrations/20260923100000_guest_tickets_and_checkin_fix.sql   (guest tickets + checkin_ticket + lookup, applied by hand 23 Sep)
--   supabase/migrations/20260925100000_after_midnight_availability.sql     (after-midnight availability, applied by hand 25 Sep)
-- No rows = production matches, so those two migration files change nothing there (they would print "already applied").
-- Rows = a difference. Do NOT "fix" it by running the migrations; look at the row, then ask.
--
-- The function checks compare a fingerprint (md5 of the whitespace-normalised body + security definer + search_path), the same fingerprint the
-- migrations use. The expected values were taken from a database built by replaying the repository (tests/db/run.sh), so a DIFFERENT value
-- means production's function is not the text in the repository: send me the grid, and run  \sf public.<name>  to see it.

with expected_fn(fn, args, fp) as (values
  ('checkin_ticket',                   'p_ticket_code text',                                           '03a021e69be0b56ef384a55f49e4c275'),
  ('lookup_table_booking_for_checkin', 'p_code text',                                                  '3a8375657efba19b87137bda1b4a4cbe'),
  ('get_unavailable_table_types',      'p_venue_id uuid, p_booking_date date, p_time_slot_id uuid',   '5123b477984bdf2be9bd9249891ed7fd')
),
live_fn as (
  select p.proname as fn, pg_get_function_identity_arguments(p.oid) as args, p.oid,
         md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')) as fp
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
)
select 'function missing' as problem, e.fn || '(' || e.args || ')' as detail
  from expected_fn e where not exists (select 1 from live_fn l where l.fn = e.fn and l.args = e.args)
union all
select 'function differs from the repository (fingerprint ' || l.fp || ', expected ' || e.fp || ')', e.fn || '(' || e.args || ')'
  from expected_fn e join live_fn l on l.fn = e.fn and l.args = e.args where l.fp <> e.fp
union all
select 'MISSING table', 'public.guest_tickets' where to_regclass('public.guest_tickets') is null
union all
select 'guest_tickets: row level security is OFF', 'public.guest_tickets'
  from pg_class c where c.oid = to_regclass('public.guest_tickets') and not c.relrowsecurity
union all
select 'guest_tickets: unexpected policy set', coalesce(string_agg(p.polname || ' (' || p.polcmd::text || ')', ', ' order by p.polname), 'none')
  from pg_policy p where p.polrelid = to_regclass('public.guest_tickets')
  having coalesce(string_agg(p.polname || ' (' || p.polcmd::text || ')', ', ' order by p.polname), 'none') <> 'admins read guest tickets (r)'
     and to_regclass('public.guest_tickets') is not null
union all
select 'guest_tickets: MISSING column', x from unnest(array['id','booking_id','guest_name','guest_email','guest_code','ticket_sent_at','checked_in_at','checked_in_by','created_at']) x
  where to_regclass('public.guest_tickets') is not null
    and not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'guest_tickets' and c.column_name = x)
union all
select 'guest_tickets: guest_code is not unique', 'public.guest_tickets.guest_code'
  where to_regclass('public.guest_tickets') is not null
    and not exists (select 1 from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any (i.indkey)
                    where i.indrelid = 'public.guest_tickets'::regclass and i.indisunique and a.attname = 'guest_code' and i.indnatts = 1)
union all
select 'MISSING column', 'public.scan_attempts.guest_ticket_id'
  where not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'scan_attempts' and c.column_name = 'guest_ticket_id')
union all
select 'MISSING column (the lookup function reads it)', 'public.site_venues.deposit_is_credit'
  where not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'site_venues' and c.column_name = 'deposit_is_credit')
union all
select 'lookup_table_booking_for_checkin is callable by anonymous visitors', 'public.lookup_table_booking_for_checkin(text)'
  where to_regprocedure('public.lookup_table_booking_for_checkin(text)') is not null
    and has_function_privilege('anon', 'public.lookup_table_booking_for_checkin(text)', 'execute')
union all
select 'lookup_table_booking_for_checkin is NOT callable by signed-in staff', 'public.lookup_table_booking_for_checkin(text)'
  where to_regprocedure('public.lookup_table_booking_for_checkin(text)') is not null
    and not has_function_privilege('authenticated', 'public.lookup_table_booking_for_checkin(text)', 'execute')
union all
-- After 25 Sep an after-midnight booking is stored under the day the guest ARRIVES, which is the day after the slot's own day_of_week.
-- A row here is one stored under the night itself (the 7 rows moved on 25 Sep should no longer appear; a new one means a path that skips computeArrivalDate).
select 'after-midnight booking stored under the night, not the arrival day', b.confirmation_code || ' on ' || b.booking_date || ' (' || ts.start_time || ', slot day ' || ts.day_of_week || ', ' || b.status || ')'
  from public.site_table_bookings b join public.site_venue_time_slots ts on ts.id = b.time_slot_id
  where ts.start_time < time '06:00:00' and extract(dow from b.booking_date)::int = ts.day_of_week
order by 1, 2
