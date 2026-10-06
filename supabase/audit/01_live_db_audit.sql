-- =============================================================================
-- BottlesUp live database audit, part 1 of 2: SECURITY and SCHEMA DRIFT
--
-- READ-ONLY. This is a single SELECT. It changes nothing.
--
-- Run it in the PRODUCTION project: Supabase Dashboard -> SQL Editor -> paste
-- the whole file -> Run. Export the result as CSV and keep it.
--
-- Result: one row per finding, worst first.
--   severity   CRITICAL | HIGH | MEDIUM | INFO | OK
--   check_name what was checked
--   object     the table / function / policy involved
--   detail     what was found and what to do
--
-- Why each check exists (all come from reading the code in this repo):
--   * The vendor app calls an `exec_sql` RPC and no SQL file defines it.
--   * The vendor handoff doc lists stripe_accounts, payout_records and
--     vendor_subscriptions as having RLS off.
--   * The website selects profiles.verified, which no SQL here creates.
--   * promo_codes is used by the website (discount_*) and the vendor app
--     (event_id / promoter_id) with different columns.
--   * The user app's stripe-webhook updates `bookings` / `event_bookings`
--     while the apps read `events_bookings` / `table_bookings`.
--   * expire_past_tickets() needs pg_cron to run.
-- =============================================================================
with
sensitive(pattern) as (
  values ('stripe|payout|subscription|payment|booking|order|profile|guest|staff|audit|customer|ticket|reconcil|vendor|promo|door')
),

-- ---------------------------------------------------------------------------
-- 1. Functions that run SQL. If callable from the client, anyone holding the
--    app's public key can run arbitrary SQL.
-- ---------------------------------------------------------------------------
c1 as (
  select
    (case
       when p.proname in ('exec_sql','execute_sql','run_sql','exec','run_query','run_migration')
            and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE'))
         then 'CRITICAL'
       when p.proname in ('exec_sql','execute_sql','run_sql','exec','run_query','run_migration') then 'HIGH'
       else 'MEDIUM'
     end)::text as severity,
    'dynamic SQL function'::text as check_name,
    (n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')')::text as object,
    format('anon can execute=%s, authenticated can execute=%s, security definer=%s. %s',
           has_function_privilege('anon', p.oid, 'EXECUTE'),
           has_function_privilege('authenticated', p.oid, 'EXECUTE'),
           p.prosecdef,
           case when p.proname in ('exec_sql','execute_sql','run_sql','exec','run_query','run_migration')
                then 'Revoke EXECUTE from anon/authenticated/public, then drop it if nothing legitimate uses it.'
                else 'Uses EXECUTE with a text argument: review that the argument cannot be influenced by a caller.' end)::text as detail
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.prokind = 'f'
    and n.nspname not in ('pg_catalog', 'information_schema')
    and (
      p.proname in ('exec_sql','execute_sql','run_sql','exec','run_query','run_migration')
      or (n.nspname = 'public' and p.prosrc ~* '\mexecute\M' and pg_get_function_identity_arguments(p.oid) ~* '\mtext\M')
    )
),

-- ---------------------------------------------------------------------------
-- 2. SECURITY DEFINER functions that anonymous callers can run and whose body
--    shows no sign of an auth check. Some are meant to be public; confirm each.
-- ---------------------------------------------------------------------------
c2 as (
  select 'MEDIUM'::text, 'security definer open to anon'::text,
         (n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')')::text,
         'SECURITY DEFINER, executable by anon, and the body mentions none of auth.uid / auth.jwt / is_cms_admin / is_door_staff. Confirm it is meant to be public.'::text
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef
    and has_function_privilege('anon', p.oid, 'EXECUTE')
    and p.prosrc !~* '(auth\.uid|auth\.jwt|auth\.role|is_cms_admin|is_door_staff|is_staff|current_setting)'
    and p.proname not in ('exec_sql','execute_sql','run_sql','exec','run_query','run_migration')  -- already reported by check 1
),

-- ---------------------------------------------------------------------------
-- 3. Tables with row level security OFF that the public API roles can reach.
-- ---------------------------------------------------------------------------
c3 as (
  select
    (case
       when has_table_privilege('anon', c.oid, 'INSERT,UPDATE,DELETE') then 'CRITICAL'
       when has_table_privilege('anon', c.oid, 'SELECT') and c.relname ~* (select pattern from sensitive) then 'CRITICAL'
       when has_table_privilege('authenticated', c.oid, 'INSERT,UPDATE,DELETE') and c.relname ~* (select pattern from sensitive) then 'HIGH'
       else 'MEDIUM'
     end)::text,
    'RLS disabled'::text,
    ('public.' || c.relname)::text,
    format('row level security is OFF. anon: read=%s write=%s | authenticated: read=%s write=%s. Enable RLS and add policies, or revoke the grants.',
           has_table_privilege('anon', c.oid, 'SELECT'),
           has_table_privilege('anon', c.oid, 'INSERT,UPDATE,DELETE'),
           has_table_privilege('authenticated', c.oid, 'SELECT'),
           has_table_privilege('authenticated', c.oid, 'INSERT,UPDATE,DELETE'))::text
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity
    and (has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
         or has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE'))
),

-- Views run with their owner's rights, so they skip RLS unless security_invoker is on.
c3b as (
  select
    (case when has_table_privilege('anon', c.oid, 'SELECT') then 'HIGH' else 'MEDIUM' end)::text,
    'view bypasses RLS'::text,
    ('public.' || c.relname)::text,
    format('view runs with its owner''s rights (security_invoker is not set). anon read=%s, authenticated read=%s. Set security_invoker=true or revoke access.',
           has_table_privilege('anon', c.oid, 'SELECT'),
           has_table_privilege('authenticated', c.oid, 'SELECT'))::text
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v'
    and coalesce(c.reloptions::text, '') !~ 'security_invoker=(true|on)'
    and (has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('authenticated', c.oid, 'SELECT'))
),

-- ---------------------------------------------------------------------------
-- 4. Policies that let (almost) anyone do (almost) anything. Includes storage.
-- ---------------------------------------------------------------------------
c4 as (
  select severity, check_name, object, detail from (
    select
      (case
         when (roles && array['anon','public']::name[]) and cmd <> 'SELECT' then 'CRITICAL'
         when cmd <> 'SELECT' then 'HIGH'
         when (roles && array['anon','public']::name[]) and tablename ~* (select pattern from sensitive) then 'HIGH'
         else 'INFO'
       end)::text as severity,
      'permissive policy'::text as check_name,
      (schemaname || '.' || tablename || ' :: ' || policyname)::text as object,
      format('cmd=%s roles=%s using=%s with_check=%s. The condition is always true.',
             cmd, roles, coalesce(qual, '-'), coalesce(with_check, '-'))::text as detail
    from pg_policies
    where schemaname in ('public', 'storage')
      and permissive = 'PERMISSIVE'
      and not (roles = array['service_role']::name[])
      and (
        (cmd in ('SELECT', 'DELETE') and coalesce(qual, '') ~ '^\(?\s*true\s*\)?$')
        or (cmd = 'INSERT' and coalesce(with_check, '') ~ '^\(?\s*true\s*\)?$')
        or (cmd in ('UPDATE', 'ALL') and (coalesce(qual, '') ~ '^\(?\s*true\s*\)?$' or coalesce(with_check, '') ~ '^\(?\s*true\s*\)?$'))
      )
  ) q
  where severity <> 'INFO'
),

-- Public storage buckets (anyone with the URL can read the files).
c5 as (
  select 'INFO'::text, 'public storage bucket'::text, b.name::text,
         format('public=true, size limit=%s, allowed types=%s', coalesce(b.file_size_limit::text, 'none'), coalesce(b.allowed_mime_types::text, 'any'))::text
  from storage.buckets b
  where b.public
),

-- ---------------------------------------------------------------------------
-- 5. Realtime: tables that broadcast changes. Without RLS that is a data feed.
-- ---------------------------------------------------------------------------
c6 as (
  select 'MEDIUM'::text, 'realtime without RLS'::text,
         (pt.schemaname || '.' || pt.tablename)::text,
         'table is in the supabase_realtime publication and has RLS off, so its changes can be streamed to any subscriber.'::text
  from pg_publication_tables pt
  join pg_class c on c.oid = format('%I.%I', pt.schemaname, pt.tablename)::regclass
  where pt.pubname = 'supabase_realtime' and not c.relrowsecurity
),

-- ---------------------------------------------------------------------------
-- 6. Which of the three schema families actually exist in this database.
--    "bookings" / "event_bookings" matter: the user app's stripe-webhook writes
--    to them, but the apps read events_bookings / table_bookings.
-- ---------------------------------------------------------------------------
expected(family, tbl) as (
  values
    ('website','site_events'), ('website','site_ticket_tiers'), ('website','site_orders'),
    ('website','site_venues'), ('website','site_table_types'), ('website','site_table_bookings'),
    ('website','site_table_booking_bottles'), ('website','door_staff'), ('website','partner_accounts'),
    ('website','cms_admins'), ('website','audit_log'), ('website','scan_attempts'),
    ('app','events'), ('app','events_bookings'), ('app','table_bookings'), ('app','event_table_bookings'),
    ('app','bookings'), ('app','event_bookings'), ('app','club_table_bookings'), ('app','club_tables'),
    ('app','clubs'), ('app','venues'), ('app','payment_transactions'), ('app','stripe_customers'),
    ('vendor','vendors'), ('vendor','stripe_accounts'), ('vendor','payout_records'),
    ('vendor','vendor_subscriptions'), ('vendor','event_team_members'), ('vendor','ticket_types'),
    ('shared','profiles'), ('shared','promo_codes')
),
c7 as (
  select 'INFO'::text, 'table inventory'::text, (family || ': ' || tbl)::text,
         (case when to_regclass('public.' || tbl) is null then 'MISSING'
               else 'present, RLS ' || (case when (select relrowsecurity from pg_class where oid = to_regclass('public.' || tbl)) then 'on' else 'OFF' end)
          end)::text
  from expected
),

-- ---------------------------------------------------------------------------
-- 7. Specific drift between the codebases.
-- ---------------------------------------------------------------------------
cols as (
  select table_name, column_name, data_type
  from information_schema.columns
  where table_schema = 'public'
),
promo as (
  select
    exists (select 1 from cols where table_name = 'promo_codes') as present,
    exists (select 1 from cols where table_name = 'promo_codes' and column_name in ('discount_type', 'discount_value', 'applies_to')) as website_cols,
    exists (select 1 from cols where table_name = 'promo_codes' and column_name in ('event_id', 'promoter_id')) as vendor_cols,
    (select string_agg(column_name, ', ' order by column_name) from cols where table_name = 'promo_codes') as all_cols
),
c8 as (
  -- profiles.verified: the website selects it
  select (case when to_regclass('public.profiles') is null then 'INFO'
               when exists (select 1 from cols where table_name = 'profiles' and column_name = 'verified') then 'INFO'
               else 'HIGH' end)::text,
         'drift: profiles.verified'::text, 'public.profiles.verified'::text,
         (case when to_regclass('public.profiles') is null then 'profiles table does not exist'
               when exists (select 1 from cols where table_name = 'profiles' and column_name = 'verified') then 'column exists'
               else 'column is MISSING. The website selects it, so its profile query errors and the profile comes back empty.' end)::text
  union all
  -- promo_codes: two incompatible shapes
  select (case when not present then 'INFO'
               when website_cols and vendor_cols then 'INFO'
               else 'HIGH' end)::text,
         'drift: promo_codes columns'::text, 'public.promo_codes'::text,
         (case when not present then 'table does not exist'
               when website_cols and vendor_cols then 'has both the website columns and the vendor columns. columns: ' || all_cols
               when website_cols then 'has website columns only; the vendor app queries event_id / promoter_id, which are missing. columns: ' || all_cols
               when vendor_cols then 'has vendor columns only; the website expects discount_type / discount_value / applies_to, which are missing. columns: ' || all_cols
               else 'has neither expected set. columns: ' || all_cols end)::text
  from promo
  union all
  -- events.id type: vendor schema says text, user app says uuid
  select 'INFO'::text, 'drift: events.id type'::text, 'public.events.id'::text,
         coalesce((select 'type is ' || data_type from cols where table_name = 'events' and column_name = 'id'), 'events table does not exist')::text
  union all
  -- the two webhook targets that the apps do not read
  select (case when to_regclass('public.' || t) is not null then 'MEDIUM' else 'INFO' end)::text,
         'drift: webhook target table'::text, ('public.' || t)::text,
         (case when to_regclass('public.' || t) is not null
               then 'exists. The user app''s stripe-webhook marks payments paid here, but the apps read events_bookings / table_bookings. Check that paid bookings are not stuck pending.'
               else 'does not exist, so the user app''s stripe-webhook cannot update it. Confirm which table it should update.' end)::text
  from (values ('bookings'), ('event_bookings')) w(t)
  union all
  -- ticket codes unique?
  select (case when to_regclass('public.table_bookings') is null
                 or exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'table_bookings' and indexdef ilike '%unique%' and indexdef ilike '%ticket_code%')
               then 'INFO' else 'MEDIUM' end)::text,
         'drift: unique ticket_code'::text, 'public.table_bookings.ticket_code'::text,
         (case when to_regclass('public.table_bookings') is null then 'table_bookings does not exist (not applicable)'
               when exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'table_bookings' and indexdef ilike '%unique%' and indexdef ilike '%ticket_code%') then 'unique index present'
               else 'no unique index on ticket_code' end)::text
),

-- ---------------------------------------------------------------------------
-- 8. Scheduled jobs and signup triggers.
-- ---------------------------------------------------------------------------
c9 as (
  select 'INFO'::text, 'pg_cron job'::text, 'cron.job'::text,
         (xpath('/row/v/text()', query_to_xml('select coalesce(string_agg(jobname || '': '' || schedule, ''; ''), ''no jobs scheduled'') as v from cron.job', false, true, '')))[1]::text
  where to_regclass('cron.job') is not null
  union all
  select 'MEDIUM'::text, 'pg_cron job'::text, 'public.expire_past_tickets()'::text,
         'pg_cron is not installed, so expire_past_tickets() (root migration 20260626) can never be scheduled and app tickets never auto-expire.'::text
  where to_regclass('cron.job') is null and to_regproc('public.expire_past_tickets()') is not null
),
c10 as (
  select 'INFO'::text, 'trigger on auth.users'::text, t.tgname::text, pg_get_triggerdef(t.oid)::text
  from pg_trigger t
  where t.tgrelid = to_regclass('auth.users') and not t.tgisinternal
),

-- ---------------------------------------------------------------------------
-- 9. checkin_ticket() fall-through. In the committed migrations, a scan answered
--    'expired' or 'code_required' ALSO falls into the admit code. Such a scan is
--    logged twice at the same instant: once as the refusal, once as 'ok'.
--    Fix and explanation: apps/bottles-up-website-main/supabase/proposed/
--    20260830_fix_checkin_ticket_early_returns.sql
-- ---------------------------------------------------------------------------
c11 as (
  select (case when n > 0 then 'HIGH' else 'INFO' end)::text,
         'checkin_ticket fall-through'::text,
         'public.scan_attempts'::text,
         (case when n > 0
               then n || ' scan(s) were logged as BOTH a refusal (expired / code_required) AND an admit at the same instant, so checkin_ticket() admitted tickets it had just refused. Apply the proposed fix and review those orders.'
               else 'no scan was logged as both refused and admitted (or the live function already differs from the committed one)' end)::text
  from (
    select coalesce((xpath('/row/n/text()', query_to_xml(
             'select count(*)::text as n from public.scan_attempts a join public.scan_attempts b on b.order_id = a.order_id and b.created_at = a.created_at and b.result = ''ok'' where a.result in (''expired'', ''code_required'')',
             false, true, '')))[1]::text::int, 0) as n
    where to_regclass('public.scan_attempts') is not null
  ) x
),

all_findings as (
  select * from c1 union all select * from c2 union all select * from c3 union all select * from c3b
  union all select * from c4 union all select * from c5 union all select * from c6
  union all select * from c7 union all select * from c8 union all select * from c9 union all select * from c10 union all select * from c11
  -- explicit "nothing found" rows so an empty result is never ambiguous
  union all select 'OK', 'dynamic SQL function', '-', 'none found' where not exists (select 1 from c1)
  union all select 'OK', 'security definer open to anon', '-', 'none found' where not exists (select 1 from c2)
  union all select 'OK', 'RLS disabled', '-', 'none found' where not exists (select 1 from c3)
  union all select 'OK', 'view bypasses RLS', '-', 'none found' where not exists (select 1 from c3b)
  union all select 'OK', 'permissive policy', '-', 'none found' where not exists (select 1 from c4)
  union all select 'OK', 'realtime without RLS', '-', 'none found' where not exists (select 1 from c6)
)
select severity, check_name, object, detail
from all_findings
order by case severity when 'CRITICAL' then 1 when 'HIGH' then 2 when 'MEDIUM' then 3 when 'INFO' then 4 else 5 end,
         check_name, object;
