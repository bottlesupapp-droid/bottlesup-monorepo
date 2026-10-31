-- 41: POST-FLIGHT for the website migration 20261120100000_deposit_combination. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 1 function(s) exist' as check_name,
         (select count(*) = 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination'])) as detail
  union all
  select 2, 'the app-facing functions (and any trigger function meant to) run with their owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination']))
  union all
  select 3, 'signed-in people (and the service role) can call the app-facing functions; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.save_venue_deposit_combination(uuid, jsonb)', 'execute') and has_function_privilege('service_role', 'public.save_venue_deposit_combination(uuid, jsonb)', 'execute') and not has_function_privilege('anon', 'public.save_venue_deposit_combination(uuid, jsonb)', 'execute')),
         'save_venue_deposit_combination'
  union all
  select 4, 'no club has a combination yet, and no booking carries one (nothing existing was changed)',
         (not exists (select 1 from public.site_venues where deposit_terms ->> 'purpose' = 'combination') and not exists (select 1 from public.site_table_bookings where deposit_terms ->> 'purpose' = 'combination')),
         (select count(*)::text from public.site_venues where deposit_terms ->> 'purpose' = 'combination') || ' clubs, ' || (select count(*)::text from public.site_table_bookings where deposit_terms ->> 'purpose' = 'combination') || ' bookings'
  union all
  select 5, 'the single-purpose function still refuses a combination as a purpose (it has its own function)',
         (pg_get_functiondef('public.save_venue_deposit_terms(uuid, jsonb)'::regprocedure) like '%v_purpose not in (''reservation_fee'', ''minimum_spend_credit'', ''admission'')%'),
         'unchanged'
  union all
  select 5 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['save_venue_deposit_combination'])
) r order by n;
