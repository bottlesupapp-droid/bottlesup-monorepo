-- 35: POST-FLIGHT for the website migration 20261117100000_agreement_access. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 7 function(s) exist' as check_name,
         (select count(*) = 7 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['set_agreement_grant', 'agreement_grants', 'organizer_venue_access', 'organizer_event_sales', 'agreement_grant_keys', 'agreement_grant_available', 'agreement_in_force'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['set_agreement_grant', 'agreement_grants', 'organizer_venue_access', 'organizer_event_sales', 'agreement_grant_keys', 'agreement_grant_available', 'agreement_in_force'])) as detail
  union all
  select 2, 'the app-facing functions (and any trigger function meant to) run with their owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['set_agreement_grant', 'agreement_grants', 'organizer_venue_access', 'organizer_event_sales'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['set_agreement_grant', 'agreement_grants', 'organizer_venue_access', 'organizer_event_sales']))
  union all
  select 3, 'signed-in people (and the service role) can call the app-facing functions; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.set_agreement_grant(uuid, text, boolean)', 'execute') and has_function_privilege('service_role', 'public.set_agreement_grant(uuid, text, boolean)', 'execute') and not has_function_privilege('anon', 'public.set_agreement_grant(uuid, text, boolean)', 'execute') and has_function_privilege('authenticated', 'public.agreement_grants(uuid, text)', 'execute') and has_function_privilege('service_role', 'public.agreement_grants(uuid, text)', 'execute') and not has_function_privilege('anon', 'public.agreement_grants(uuid, text)', 'execute') and has_function_privilege('authenticated', 'public.organizer_venue_access(uuid)', 'execute') and has_function_privilege('service_role', 'public.organizer_venue_access(uuid)', 'execute') and not has_function_privilege('anon', 'public.organizer_venue_access(uuid)', 'execute') and has_function_privilege('authenticated', 'public.organizer_event_sales(uuid)', 'execute') and has_function_privilege('service_role', 'public.organizer_event_sales(uuid)', 'execute') and not has_function_privilege('anon', 'public.organizer_event_sales(uuid)', 'execute')),
         'set_agreement_grant, agreement_grants, organizer_venue_access, organizer_event_sales'
  union all
  select 4, 'the internal helpers are not callable by the app',
         (not has_function_privilege('authenticated', 'public.agreement_grant_keys()', 'execute') and not has_function_privilege('anon', 'public.agreement_grant_keys()', 'execute') and not has_function_privilege('authenticated', 'public.agreement_grant_available(text)', 'execute') and not has_function_privilege('anon', 'public.agreement_grant_available(text)', 'execute') and not has_function_privilege('authenticated', 'public.agreement_in_force(public.site_agreements)', 'execute') and not has_function_privilege('anon', 'public.agreement_in_force(public.site_agreements)', 'execute')),
         'agreement_grant_keys, agreement_grant_available, agreement_in_force'
  union all
  select 5, 'table site_agreement_grants has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_agreement_grants') is not null and (select relrowsecurity from pg_class where oid = 'public.site_agreement_grants'::regclass)
          and not has_table_privilege('anon', 'public.site_agreement_grants', 'select') and not has_table_privilege('authenticated', 'public.site_agreement_grants', 'select')
          and not has_table_privilege('anon', 'public.site_agreement_grants', 'insert') and not has_table_privilege('authenticated', 'public.site_agreement_grants', 'insert')
          and not has_table_privilege('authenticated', 'public.site_agreement_grants', 'update') and not has_table_privilege('authenticated', 'public.site_agreement_grants', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'nothing is shared yet: no grant exists, so no club has allowed anything',
         ((select count(*) = 0 from public.site_agreement_grants)),
         (select count(*)::text from public.site_agreement_grants)
  union all
  select 7, 'the six things, in order, and the three that can be shown today',
         (public.agreement_grant_keys() = array['bar_sales', 'ticket_checkins', 'capacity', 'table_sales', 'chat', 'settlement']::text[] and public.agreement_grant_available('ticket_checkins') and public.agreement_grant_available('capacity') and public.agreement_grant_available('table_sales') and not public.agreement_grant_available('bar_sales') and not public.agreement_grant_available('chat') and not public.agreement_grant_available('settlement')),
         'bar_sales, ticket_checkins, capacity, table_sales, chat, settlement'
  union all
  select 8, 'the grants table keeps its key rule and its person column does not block deleting an account',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_agreement_grants'::regclass and c.contype = 'c') and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_agreement_grants'::regclass and c.contype = 'p') and (select confdeltype = 'n' from pg_constraint c where c.conrelid = 'public.site_agreement_grants'::regclass and c.contype = 'f' and c.confrelid = 'auth.users'::regclass)),
         'grant_key check, primary key, granted_by ON DELETE SET NULL'
  union all
  select 8 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['set_agreement_grant', 'agreement_grants', 'organizer_venue_access', 'organizer_event_sales', 'agreement_grant_keys', 'agreement_grant_available', 'agreement_in_force'])
) r order by n;
