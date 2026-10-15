-- Post-flight for the four website migrations 20261014100000 .. 20261014130000 (server desk, service requests, bottle orders, payments).
--
-- READ ONLY. One SELECT. Run it in the SQL editor of the project you just applied them to, and send me the grid. It confirms that:
--   1. everything they create is there: 23 functions, 2 tables, 2 storage policies;
--   2. the functions run with their owner's rights and a pinned search path (so they cannot be pointed at other objects);
--   3. nothing is exposed that should not be: anonymous visitors can call none of them; signed-in people can call exactly the 18 meant
--      for the app and not the 5 internal helpers; the two new tables have row level security on and nobody can read or write them
--      directly (only the functions can).
-- The first row says OK when there is no STOP row.
with
funcs(name, secdef, app_callable) as (values
  ('desk_log', true, false), ('booking_venue', true, false), ('desk_level', true, false), ('desk_membership', true, false), ('desk_staff_problem', true, false),
  ('assign_booking_server', true, true), ('unassign_booking_server', true, true), ('list_venue_booking_servers', true, true), ('my_assigned_tables', true, true),
  ('create_service_request', true, true), ('list_service_requests', true, true), ('update_service_request', true, true),
  ('desk_booking_level', true, true), ('desk_orders', true, true), ('desk_booking_orders', true, true), ('desk_set_service_status', true, true),
  ('receipt_booking', false, true), ('desk_booking_money', true, true), ('desk_record_payment', true, true), ('desk_pending_verifications', true, true),
  ('desk_verify_payment', true, true), ('desk_table_status', true, true), ('desk_tonight', true, true)),
tables(name) as (values ('site_booking_servers'), ('site_service_requests')),
policies(name) as (values ('desk staff read club payment receipts'), ('desk staff add club payment receipts')),
found as (
  select f.name, f.secdef, f.app_callable, p.oid, p.prosecdef, p.proconfig
  from funcs f left join pg_proc p on p.proname = f.name and p.pronamespace = 'public'::regnamespace
),
checks as (
  select 'STOP' as severity, 'function missing' as "check", name as item, 'not found in public' as detail from found where oid is null
  union all
  select 'STOP', 'function defined more than once', name, 'more than one version exists'
  from found group by name having count(oid) > 1
  union all
  select 'STOP', 'owner rights wrong', name, case when secdef then 'should run with its owner''s rights (security definer)' else 'should not be security definer' end
  from found where oid is not null and prosecdef is distinct from secdef
  union all
  select 'STOP', 'search path not pinned', name, 'should be pinned to public'
  from found where oid is not null and coalesce(proconfig::text, '') not like '%search_path=public%'
  union all
  select 'STOP', 'anonymous visitors can call it', name, 'public/anon must not be able to execute this'
  from found where oid is not null and has_function_privilege('anon', oid, 'EXECUTE')
  union all
  select 'STOP', 'signed-in people cannot call it', name, 'the app calls this one'
  from found where oid is not null and app_callable and not has_function_privilege('authenticated', oid, 'EXECUTE')
  union all
  select 'STOP', 'signed-in people can call an internal helper', name, 'this one is internal: only other functions may use it'
  from found where oid is not null and not app_callable and has_function_privilege('authenticated', oid, 'EXECUTE')
  union all
  select 'STOP', 'table missing', t.name, 'not found in public' from tables t where to_regclass('public.' || t.name) is null
  union all
  select 'STOP', 'row level security is off', t.name, 'must be on'
  from tables t where to_regclass('public.' || t.name) is not null and not (select relrowsecurity from pg_class where oid = to_regclass('public.' || t.name))
  union all
  select 'STOP', 'a client can reach the table directly', t.name || ' / ' || r.role || ' / ' || pr.priv, 'only the functions may read or write this table'
  from tables t cross join (values ('anon'), ('authenticated')) r(role) cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) pr(priv)
  where to_regclass('public.' || t.name) is not null and has_table_privilege(r.role, to_regclass('public.' || t.name), pr.priv)
  union all
  select 'STOP', 'storage policy missing', pl.name, 'not found on storage.objects'
  from policies pl where not exists (select 1 from pg_policies x where x.schemaname = 'storage' and x.tablename = 'objects' and x.policyname = pl.name)
  union all
  select 'STOP', 'storage policy open to anonymous visitors', x.policyname, 'roles: ' || array_to_string(x.roles, ',')
  from pg_policies x
  where x.schemaname = 'storage' and x.tablename = 'objects' and x.policyname in (select name from policies) and not (x.roles = array['authenticated']::name[])
  union all
  select 'INFO', 'what is in place', 'functions found',
         (select count(*) from found where oid is not null)::text || ' of 23; app-callable: ' || (select count(*) from found where oid is not null and app_callable)::text
  union all
  select 'INFO', 'other policies on the receipt bucket (older, left as they are)', x.policyname, x.cmd::text
  from pg_policies x
  where x.schemaname = 'storage' and x.tablename = 'objects' and x.qual ilike '%club-payment-receipts%' and x.policyname not in (select name from policies)
)
select 0 as ord,
       case when count(*) filter (where severity = 'STOP') = 0 then 'OK' else 'STOP' end as severity,
       'summary' as "check",
       count(*) filter (where severity = 'STOP')::text || ' STOP' as item,
       case when count(*) filter (where severity = 'STOP') = 0
            then 'everything is there and nothing is exposed'
            else 'something is missing or exposed: send me this grid before going on' end as detail
from checks
union all
select 1, severity, "check", item, detail from checks
order by 1, 2, 3, 4;
