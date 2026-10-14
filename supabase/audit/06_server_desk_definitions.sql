-- READ ONLY. Lists the DEFINITIONS (never any rows) of the production-only functions and tables behind the server desk,
-- bottle orders and payment evidence, so they can be committed and tested instead of guessed at.
--
-- WHY: about 17 of the 24 database functions the website calls, and several columns, exist only in production. The server
-- dashboard (My Tables, Orders, Scan), payment evidence and the manager's Tonight/Orders all read them. They cannot be
-- rebuilt on the new workspace roles without seeing how they work today. This is the quick alternative to `supabase db pull`
-- (which needs Docker): paste this, run it, export the result, send it back.
--
-- HOW: Supabase dashboard -> SQL Editor -> New query -> paste ALL of this -> Run. Then use the result grid's
-- "Export -> Download CSV" (or copy it) and put the file at  supabase/production-snapshot/server_desk_definitions.csv
-- in the monorepo (or just send it to me).
--
-- SAFE: every statement is a SELECT on the system catalogs (pg_proc, pg_class, pg_policies, information_schema, storage.buckets).
-- It reads no booking, payment, customer or staff rows, and changes nothing. Function bodies are business logic; skim the
-- result for anything that looks like a secret (a key or password hard-coded in a function) before sharing, and tell me if so.
--
-- One result set: kind | object | definition. Rows are grouped by kind.

with
-- Functions: the ones the website's staff screens call, plus anything whose name suggests the same area, in case production has
-- helpers I do not know about. Aggregates and extension functions are skipped.
fns as (
  select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args, p.prosecdef, p.proconfig
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind = 'f'
    and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
    and (
      p.proname in (
        'list_my_tables', 'list_my_bottle_orders', 'list_my_alerts', 'update_bottle_service_status',
        'request_table_payment', 'request_table_closeout', 'record_club_payment', 'list_club_payments',
        'correct_club_payment', 'manager_verify_club_payment', 'list_reconciliation_queue',
        'get_booking_reconciliation', 'close_table_booking_reconciliation', 'lookup_table_booking_for_checkin',
        'search_table_bookings_for_checkin', 'get_venue_revenue_report', 'is_door_staff', 'is_cms_admin'
      )
      or p.proname ~ '(table_booking|club_payment|bottle|closeout|reconcil|refund|revenue|substitut|fulfil|cash|handover|walk_?in|service_request|checkin|check_in)'
      or p.proname like 'list\_my\_%'
    )
),
-- Tables: the same idea. The explicit names are the production-only tables the website's code reads; the pattern catches
-- related ones that no committed migration mentions.
tbls as (
  select c.oid, c.relname, c.relrowsecurity, c.relforcerowsecurity
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and (
      c.relname in (
        'site_table_bookings', 'site_table_booking_bottles', 'site_table_booking_club_payments', 'site_table_booking_refunds',
        'site_table_booking_bottle_substitutions', 'site_table_types', 'site_venue_time_slots', 'site_bottles', 'site_orders',
        'door_staff', 'guest_tickets', 'site_vip_guests', 'profiles', 'promo_codes', 'promo_code_venues', 'scan_attempts'
      )
      or c.relname ~ '(table_booking|club_payment|refund|settlement|cash|handover|service_request|walk_?in|reconcil|bottle_sign)'
    )
)

-- 1. Function bodies.
select 1 as ord, 'function' as kind, f.proname || '(' || f.args || ')' as object, pg_get_functiondef(f.oid) as definition
from fns f

union all
-- 2. Who may call each function, and how it runs.
select 2, 'function_access', f.proname || '(' || f.args || ')',
       'security_definer=' || f.prosecdef
       || '; search_path=' || coalesce((select string_agg(x, ',') from unnest(f.proconfig) x where x like 'search_path=%'), '(not pinned)')
       || '; anon_can_execute=' || has_function_privilege('anon', f.oid, 'execute')
       || '; authenticated_can_execute=' || has_function_privilege('authenticated', f.oid, 'execute')
from fns f

union all
-- 3. Columns: name, type, not null, default, per table.
select 3, 'table_columns', t.relname,
       (select string_agg(
                 a.attname || ' ' || format_type(a.atttypid, a.atttypmod)
                 || case when a.attnotnull then ' not null' else '' end
                 || coalesce(' default ' || pg_get_expr(d.adbin, d.adrelid), ''),
                 E'\n' order by a.attnum)
        from pg_attribute a
        left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
        where a.attrelid = t.oid and a.attnum > 0 and not a.attisdropped)
from tbls t

union all
-- 4. Constraints (keys, checks such as the allowed statuses, foreign keys).
select 4, 'table_constraints', t.relname,
       (select string_agg(c.conname || ': ' || pg_get_constraintdef(c.oid), E'\n' order by c.conname)
        from pg_constraint c where c.conrelid = t.oid)
from tbls t

union all
-- 5. Indexes (a unique index is often what makes "repeated taps do not duplicate" true).
select 5, 'table_indexes', t.relname,
       (select string_agg(i.indexdef, E'\n' order by i.indexname)
        from pg_indexes i where i.schemaname = 'public' and i.tablename = t.relname)
from tbls t

union all
-- 6. Row level security: is it on, and each policy.
select 6, 'table_rls', t.relname,
       'rls_enabled=' || t.relrowsecurity || '; rls_forced=' || t.relforcerowsecurity
       || coalesce(E'\n' || (select string_agg(
                 'policy "' || p.policyname || '" for ' || p.cmd || ' to ' || array_to_string(p.roles, ',')
                 || coalesce(E'\n   using: ' || p.qual, '')
                 || coalesce(E'\n   with check: ' || p.with_check, ''),
                 E'\n' order by p.policyname)
              from pg_policies p where p.schemaname = 'public' and p.tablename = t.relname), '')
from tbls t

union all
-- 7. Triggers (they can change rows behind the function's back).
select 7, 'table_triggers', t.relname,
       (select string_agg(pg_get_triggerdef(g.oid), E'\n' order by g.tgname)
        from pg_trigger g where g.tgrelid = t.oid and not g.tgisinternal)
from tbls t

union all
-- 8. Direct table privileges for the app's roles (what a signed-in or anonymous person could do without a function).
select 8, 'table_grants', t.relname,
       'anon: ' || (select string_agg(p, ',') from unnest(array['select', 'insert', 'update', 'delete']) p where has_table_privilege('anon', t.oid, p))
       || E'\nauthenticated: ' || (select string_agg(p, ',') from unnest(array['select', 'insert', 'update', 'delete']) p where has_table_privilege('authenticated', t.oid, p))
from tbls t

union all
-- 9. Storage buckets (where receipt photos and similar evidence live) and their rules. Names and limits only, no files.
select 9, 'storage_bucket', b.id,
       'public=' || b.public || '; file_size_limit=' || coalesce(b.file_size_limit::text, '(none)')
       || '; allowed_mime_types=' || coalesce(array_to_string(b.allowed_mime_types, ','), '(any)')
from storage.buckets b

union all
select 10, 'storage_policy', p.policyname,
       'for ' || p.cmd || ' to ' || array_to_string(p.roles, ',')
       || coalesce(E'\n   using: ' || p.qual, '')
       || coalesce(E'\n   with check: ' || p.with_check, '')
from pg_policies p
where p.schemaname = 'storage' and p.tablename = 'objects'

order by 1, 3;
