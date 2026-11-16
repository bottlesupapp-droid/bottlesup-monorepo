-- 48: POST-FLIGHT for the website migration 20261122110000_stock_overview. Read-only.
-- ONE result set. Every row before the fingerprint must say ok = true. The FINGERPRINT row gives an md5 of the function's body in the detail column (ok is always true there): compare it with
-- the same query on a replay of the repository (tests/db/run.sh database); it must be identical.
select * from (
  select 1 as n, 'the function exists' as check_name,
         (to_regprocedure('public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)') is not null) as ok,
         'stock_overview(uuid, timestamptz, timestamptz)' as detail
  union all
  select 2, 'it runs with its owner''s rights and a fixed search path, and only reads (it is stable)',
         (select p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%' and p.provolatile = 's' from pg_proc p where p.oid = to_regprocedure('public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)')),
         (select p.prosecdef::text || ' ' || coalesce(p.proconfig::text, 'no path') || ' volatility ' || p.provolatile::text from pg_proc p where p.oid = to_regprocedure('public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)'))
  union all
  select 3, 'signed-in people (and the service role) can call it; visitors cannot (the database checks inside that the caller is the club''s owner or manager)',
         (has_function_privilege('authenticated', 'public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)', 'execute')
          and has_function_privilege('service_role', 'public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)', 'execute')
          and not has_function_privilege('anon', 'public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)', 'execute')),
         'authenticated, service_role; not anon'
  union all
  select 4, 'it returns the thirteen columns the vendor app reads',
         (select count(*) = 13 and bool_and(c in ('bottle_id', 'name', 'size', 'category', 'tracked', 'on_hand', 'reserved', 'handed_over', 'available', 'sold', 'low_threshold', 'is_low', 'is_sold_out'))
            from (select unnest(p.proargnames[(p.pronargs + 1):]) as c from pg_proc p where p.oid = to_regprocedure('public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)')) x),
         'bottle_id, name, size, category, tracked, on_hand, reserved, handed_over, available, sold, low_threshold, is_low, is_sold_out'
  union all
  select 5, 'exactly one function of that name exists (nothing was replaced or duplicated)',
         (select count(*) = 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'stock_overview'),
         'one function named stock_overview'
  union all
  select 6, 'FINGERPRINT stock_overview', true,
         (select md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid)) from pg_proc p where p.oid = to_regprocedure('public.stock_overview(uuid, timestamp with time zone, timestamp with time zone)'))
) r order by n;
