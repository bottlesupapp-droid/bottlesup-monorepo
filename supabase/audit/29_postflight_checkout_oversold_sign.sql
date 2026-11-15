-- 29: POST-FLIGHT for the three website migrations 20261111100000_atomic_table_checkout, 20261113100000_oversold_booking_queue and 20261114100000_booking_sign_text. Read-only.
-- ONE result set (the Supabase CLI shows only the last result set of a file, so everything is in this one). Rows 1 to 7 must say ok = true. Rows 8 to 12 give a fingerprint of each new function's body in
-- the detail column (ok is always true there): compare them with the same query on a replay of the repository; they must be identical.
select * from (
  select 1 as n, 'the five functions exist' as check_name,
         (select count(*) = 5 from pg_proc p where p.pronamespace = 'public'::regnamespace
            and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign')) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace
            and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign')) as detail
  union all
  select 2, 'all five run with their owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace
            and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign')),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace
            and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign'))
  union all
  select 3, 'the checkout reservation and the oversold flag are for the service role only (visitors and signed-in people cannot call them)',
         (has_function_privilege('service_role', to_regprocedure('public.site_reserve_table_booking(uuid, uuid, uuid, date, text, text, text, integer, integer, integer, integer, integer, integer, integer, text, text, uuid, integer, text)'), 'execute')
          and not has_function_privilege('anon', to_regprocedure('public.site_reserve_table_booking(uuid, uuid, uuid, date, text, text, text, integer, integer, integer, integer, integer, integer, integer, text, text, uuid, integer, text)'), 'execute')
          and not has_function_privilege('authenticated', to_regprocedure('public.site_reserve_table_booking(uuid, uuid, uuid, date, text, text, text, integer, integer, integer, integer, integer, integer, integer, text, text, uuid, integer, text)'), 'execute')
          and has_function_privilege('service_role', 'public.site_flag_oversold_booking(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.site_flag_oversold_booking(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.site_flag_oversold_booking(uuid)', 'execute')),
         'site_reserve_table_booking, site_flag_oversold_booking'
  union all
  select 4, 'the manager''s functions are for signed-in people and not for visitors (the database checks who is the club''s manager)',
         (has_function_privilege('authenticated', 'public.desk_booking_conflicts(uuid, boolean)', 'execute') and not has_function_privilege('anon', 'public.desk_booking_conflicts(uuid, boolean)', 'execute')
          and has_function_privilege('authenticated', 'public.desk_resolve_booking_conflict(uuid, text, text)', 'execute') and not has_function_privilege('anon', 'public.desk_resolve_booking_conflict(uuid, text, text)', 'execute')
          and has_function_privilege('authenticated', 'public.desk_booking_sign(uuid)', 'execute') and not has_function_privilege('anon', 'public.desk_booking_sign(uuid)', 'execute')),
         'desk_booking_conflicts, desk_resolve_booking_conflict, desk_booking_sign'
  union all
  select 5, 'site_booking_conflicts exists with row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_booking_conflicts') is not null
          and (select relrowsecurity from pg_class where oid = 'public.site_booking_conflicts'::regclass)
          and not has_table_privilege('anon', 'public.site_booking_conflicts', 'select') and not has_table_privilege('authenticated', 'public.site_booking_conflicts', 'select')
          and not has_table_privilege('anon', 'public.site_booking_conflicts', 'insert') and not has_table_privilege('authenticated', 'public.site_booking_conflicts', 'insert')
          and not has_table_privilege('authenticated', 'public.site_booking_conflicts', 'update') and not has_table_privilege('authenticated', 'public.site_booking_conflicts', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'the conflicts table keeps its state rule, its one-conflict-per-booking rule, and its person columns do not block deleting an account',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_booking_conflicts'::regclass and c.conname = 'site_booking_conflicts_state_check')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_booking_conflicts'::regclass and c.contype = 'u')
          and (select confdeltype = 'n' from pg_constraint c where c.conrelid = 'public.site_booking_conflicts'::regclass and c.contype = 'f'
                 and c.conkey = array[(select attnum from pg_attribute where attrelid = 'public.site_booking_conflicts'::regclass and attname = 'resolved_by')])),
         'state check, unique booking, resolved_by ON DELETE SET NULL'
  union all
  select 7, 'no conflict exists yet (the table is new; rows come only from late payments after the functions are deployed)',
         (select count(*) = 0 from public.site_booking_conflicts) or to_regclass('public.site_booking_conflicts') is null,
         coalesce((select count(*)::text from public.site_booking_conflicts), 'n/a')
  union all
  select 7 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace
     and p.proname in ('site_reserve_table_booking', 'site_flag_oversold_booking', 'desk_booking_conflicts', 'desk_resolve_booking_conflict', 'desk_booking_sign')
) r order by n;
