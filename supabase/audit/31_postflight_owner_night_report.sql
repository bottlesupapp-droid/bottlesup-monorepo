-- 31: POST-FLIGHT for the website migration 20261115100000_owner_night_report. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 1 function(s) exist' as check_name,
         (select count(*) = 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report'])) as detail
  union all
  select 2, 'the app-facing functions (and any trigger function meant to) run with their owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report']))
  union all
  select 3, 'signed-in people (and the service role) can call the app-facing functions; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.owner_night_report(uuid, date)', 'execute') and has_function_privilege('service_role', 'public.owner_night_report(uuid, date)', 'execute') and not has_function_privilege('anon', 'public.owner_night_report(uuid, date)', 'execute')),
         'owner_night_report'
  union all
  select 3 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['owner_night_report'])
) r order by n;
