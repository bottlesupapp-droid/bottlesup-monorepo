-- 46: POST-FLIGHT for the website migration 20261122100000_door_exits_and_overrides. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 8 function(s) exist' as check_name,
         (select count(*) = 8 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights'])) as detail
  union all
  select 2, 'every function runs with its owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights']))
  union all
  select 3, 'signed-in people (and the service role) can call the seven public functions; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.can_manage_door(uuid)', 'execute') and has_function_privilege('service_role', 'public.can_manage_door(uuid)', 'execute') and not has_function_privilege('anon', 'public.can_manage_door(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.set_event_exit_tracking(uuid, boolean)', 'execute') and has_function_privilege('service_role', 'public.set_event_exit_tracking(uuid, boolean)', 'execute') and not has_function_privilege('anon', 'public.set_event_exit_tracking(uuid, boolean)', 'execute')
          and has_function_privilege('authenticated', 'public.door_record_exit(text, integer, uuid)', 'execute') and has_function_privilege('service_role', 'public.door_record_exit(text, integer, uuid)', 'execute') and not has_function_privilege('anon', 'public.door_record_exit(text, integer, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.door_occupancy(uuid)', 'execute') and has_function_privilege('service_role', 'public.door_occupancy(uuid)', 'execute') and not has_function_privilege('anon', 'public.door_occupancy(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.door_override_entry(text, text, integer, uuid)', 'execute') and has_function_privilege('service_role', 'public.door_override_entry(text, text, integer, uuid)', 'execute') and not has_function_privilege('anon', 'public.door_override_entry(text, text, integer, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.door_override_log(uuid)', 'execute') and has_function_privilege('service_role', 'public.door_override_log(uuid)', 'execute') and not has_function_privilege('anon', 'public.door_override_log(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.door_club_nights(uuid)', 'execute') and has_function_privilege('service_role', 'public.door_club_nights(uuid)', 'execute') and not has_function_privilege('anon', 'public.door_club_nights(uuid)', 'execute')),
         'can_manage_door, set_event_exit_tracking, door_record_exit, door_occupancy, door_override_entry, door_override_log, door_club_nights'
  union all
  select 4, 'the helper door_order_in answers for any order id, so only the service role may call it (not signed-in people, not visitors)',
         (has_function_privilege('service_role', 'public.door_order_in(uuid)', 'execute') and not has_function_privilege('authenticated', 'public.door_order_in(uuid)', 'execute') and not has_function_privilege('anon', 'public.door_order_in(uuid)', 'execute')),
         'service_role only'
  union all
  select 5, 'table site_order_exits has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_order_exits') is not null and (select relrowsecurity from pg_class where oid = 'public.site_order_exits'::regclass)
          and not has_table_privilege('anon', 'public.site_order_exits', 'select') and not has_table_privilege('authenticated', 'public.site_order_exits', 'select')
          and not has_table_privilege('anon', 'public.site_order_exits', 'insert') and not has_table_privilege('authenticated', 'public.site_order_exits', 'insert')
          and not has_table_privilege('authenticated', 'public.site_order_exits', 'update') and not has_table_privilege('authenticated', 'public.site_order_exits', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'table site_door_overrides has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_door_overrides') is not null and (select relrowsecurity from pg_class where oid = 'public.site_door_overrides'::regclass)
          and not has_table_privilege('anon', 'public.site_door_overrides', 'select') and not has_table_privilege('authenticated', 'public.site_door_overrides', 'select')
          and not has_table_privilege('anon', 'public.site_door_overrides', 'insert') and not has_table_privilege('authenticated', 'public.site_door_overrides', 'insert')
          and not has_table_privilege('authenticated', 'public.site_door_overrides', 'update') and not has_table_privilege('authenticated', 'public.site_door_overrides', 'delete')),
         'RLS on, no grants'
  union all
  select 7, 'no event tracks exits, and no exit or override exists: nothing existing was changed',
         ((select count(*) = 0 from public.site_events where track_exits) and (select count(*) = 0 from public.site_order_exits) and (select count(*) = 0 from public.site_door_overrides)),
         (select count(*)::text from public.site_events where track_exits) || ' events tracking, ' || (select count(*)::text from public.site_order_exits) || ' exits, ' || (select count(*)::text from public.site_door_overrides) || ' overrides'
  union all
  select 8, 'the person columns do not block deleting an account (ON DELETE SET NULL), and an order or event that is deleted takes its exits and overrides with it (ON DELETE CASCADE)',
         ((select count(*) = 2 and bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
            where c.contype = 'f' and ((c.conrelid = 'public.site_order_exits'::regclass and a.attname = 'exited_by') or (c.conrelid = 'public.site_door_overrides'::regclass and a.attname = 'overridden_by')))
          and (select count(*) = 3 and bool_and(confdeltype = 'c') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
            where c.contype = 'f' and ((c.conrelid = 'public.site_order_exits'::regclass and a.attname = 'order_id') or (c.conrelid = 'public.site_door_overrides'::regclass and a.attname in ('order_id', 'event_id'))))),
         'exited_by, overridden_by set null; order_id, event_id cascade'
  union all
  select 9, 'an exit is at least one guest, and an override needs a written reason of 5 to 300 characters',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_order_exits'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%guests > 0%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_door_overrides'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%char_length(reason)%' and pg_get_constraintdef(c.oid) like '%5%' and pg_get_constraintdef(c.oid) like '%300%')),
         'guests > 0; reason 5 to 300'
  union all
  select 10, 'site_events.track_exits is a boolean that cannot be null and defaults to off',
         (select count(*) = 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_events' and column_name = 'track_exits' and data_type = 'boolean' and is_nullable = 'NO' and column_default = 'false'),
         'boolean not null default false'
  union all
  select 10 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['can_manage_door', 'set_event_exit_tracking', 'door_order_in', 'door_record_exit', 'door_occupancy', 'door_override_entry', 'door_override_log', 'door_club_nights'])
) r order by n;
