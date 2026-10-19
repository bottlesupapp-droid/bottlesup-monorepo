-- READ ONLY. Answers the open questions from reading production's definitions on 14 Oct 2026 (HANDOFF.md, "Phase 6 step 23").
-- It reads the system catalogs and COUNTS rows of two staff tables; it returns no names, emails or amounts and changes nothing.
--
-- WHY: the server-desk report showed some access rules that look too loose. Looking is not the same as knowing, so this checks them:
--   1. profiles: can a signed-in user change their own `is_admin`, `role` or `verified`? If is_admin() reads one of them, that is a way to
--      become an admin of the legacy tables. (The report did not include is_admin()'s body.)
--   2. door_staff: how many staff rows have no event (and so see every club in list_my_tables / list_my_bottle_orders / list_my_alerts),
--      how many have an access window that has already ended (nothing in the staff functions checks it), and how many have
--      can_record_payments = false (the flag is never read when recording a payment).
--   3. Which policies depend on is_admin(), so the size of the question in (1) is known.
--
-- HOW: Supabase dashboard -> SQL Editor -> New query -> paste ALL of this -> Run -> send me the grid (or the CSV).
--
-- One result set: ord | check | object | result.

select 1 as ord, 'is_admin() definition' as "check", 'public.is_admin()' as object,
       coalesce((select pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'is_admin' and p.pronargs = 0 limit 1),
                'there is no public.is_admin() with no arguments') as result

union all
select 2, 'can a signed-in user update this column of their own profile?', 'profiles.' || c.column_name,
       'authenticated can UPDATE: ' || has_column_privilege('authenticated', 'public.profiles', c.column_name, 'UPDATE')::text
         || '; anon can UPDATE: ' || has_column_privilege('anon', 'public.profiles', c.column_name, 'UPDATE')::text
from information_schema.columns c
where c.table_schema = 'public' and c.table_name = 'profiles' and c.column_name in ('is_admin', 'role', 'verified')

union all
select 3, 'update policies on profiles', pol.policyname,
       'roles: ' || array_to_string(pol.roles, ',') || '; using: ' || coalesce(pol.qual, '(none)') || '; with check: ' || coalesce(pol.with_check, '(none: any new row value is allowed)')
from pg_policies pol
where pol.schemaname = 'public' and pol.tablename = 'profiles' and pol.cmd in ('UPDATE', 'ALL')

union all
select 4, 'policies that depend on is_admin()', pol.tablename || ' / ' || pol.policyname,
       'for ' || pol.cmd || ' to ' || array_to_string(pol.roles, ',')
from pg_policies pol
where pol.schemaname = 'public'
  and (coalesce(pol.qual, '') ilike '%is_admin()%' or coalesce(pol.with_check, '') ilike '%is_admin()%')

union all
select 5, 'door_staff rows (counts only)', 'door_staff',
       'total: ' || count(*)::text
         || '; with no event assigned (see every club): ' || count(*) filter (where event_id is null)::text
         || '; access window already ended: ' || count(*) filter (where access_end_at is not null and access_end_at < now())::text
         || '; access window not started yet: ' || count(*) filter (where access_start_at is not null and access_start_at > now())::text
         || '; can_record_payments = false: ' || count(*) filter (where not can_record_payments)::text
         || '; roles: ' || coalesce((select string_agg(r.role || '=' || r.n, ', ' order by r.role) from (select role, count(*)::text as n from public.door_staff group by role) r), '-')
from public.door_staff

union all
select 6, 'update policies on event_table_bookings', pol.policyname,
       'roles: ' || array_to_string(pol.roles, ',') || '; using: ' || coalesce(pol.qual, '(none)') || '; with check: ' || coalesce(pol.with_check, '(none: any new row value is allowed)')
from pg_policies pol
where pol.schemaname = 'public' and pol.tablename = 'event_table_bookings' and pol.cmd in ('UPDATE', 'ALL')

order by 1, 3;
