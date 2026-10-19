-- READ ONLY. One SELECT; nothing is created, changed or locked. It reads system catalogs and COUNTS rows. It returns no names, emails or amounts
-- (the only text it can return from your data is table, trigger and function names).
--
-- WHY: the vendor app's new screens and the website both use the `site_*` tables. The customer app and the vendor app's classic dashboard use the
-- older tables (events, clubs, events_bookings, event_table_bookings, table_bookings, vendors ...). Nothing in the repository copies data between
-- the two families. This checks the one place the repository cannot see: production itself.
--
-- It answers:
--   1. Does the database copy or link old and site_* data anywhere? Triggers, functions, views, foreign keys and database webhooks.
--      If the first row says OK, nothing in the database does. (Edge functions and webhooks are not visible from SQL: they were read in the
--      repository and are listed in HANDOFF.md.)
--   2. Where do rows actually live, and are people still creating them on the old side? Row counts and the last 30 days, old vs site.
--   3. Who would not be seen across? Old vendors, website partner applications and door staff who have no workspace; accounts with no profile;
--      clubs that exist in both families.
--
-- HOW: Supabase dashboard -> SQL Editor -> New query -> paste ALL of this -> Run -> send me the grid (or the CSV).
-- A line that says "not checked: ..." means a table or column is not in this database; that is an answer, not an error.
--
-- One result set: ord | severity | check | item | result.   Severity: OK / REVIEW (look at it) / INFO.
with
old_tables(name) as (values
  ('events'), ('clubs'), ('venues'), ('events_bookings'), ('event_table_bookings'), ('table_bookings'), ('club_tables'), ('event_tables'),
  ('ticket_types'), ('guest_list'), ('venue_requests'), ('vendor_events'), ('vendors'), ('clubs_with_categories')),
pat as (
  -- strict: the unambiguous table names anywhere in code; loose: the short common words only when they follow from / join / into / update.
  select '(?<![a-z0-9_])(' || string_agg(name, '|') filter (where name not in ('events', 'clubs', 'venues')) || ')(?![a-z0-9_])' as strict_re,
         '(from|join|into|update)[\s(]+(public\.)?(events|clubs|venues)(?![a-z0-9_])' as loose_re,
         '(?<![a-z0-9_])site_[a-z_]+' as site_re
  from old_tables
),
funcs as (
  select p.oid, p.proname, regexp_replace(p.prosrc, '--[^\n]*', '', 'g') as src
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
  join pg_language l on l.oid = p.prolang and l.lanname in ('sql', 'plpgsql')
  where p.prokind in ('f', 'p')
),
trig as (
  select c.relname as tbl, t.tgname, p.proname, pn.nspname as fn_schema, regexp_replace(coalesce(p.prosrc, ''), '--[^\n]*', '', 'g') as src
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  join pg_proc p on p.oid = t.tgfoid
  join pg_namespace pn on pn.oid = p.pronamespace
  where not t.tgisinternal
),
bridges(severity, "check", item, detail) as (
  select 'REVIEW', 'trigger on an old table reads or writes a site_* table', tbl || ' / ' || tgname, 'function ' || proname
  from trig, pat where tbl in (select name from old_tables) and src ~* pat.site_re
  union all
  select 'REVIEW', 'trigger on a site_* table reads or writes an old table', tbl || ' / ' || tgname, 'function ' || proname
  from trig, pat where tbl like 'site\_%' and (src ~* pat.strict_re or src ~* pat.loose_re)
  union all
  select 'REVIEW', 'function mentions both an old table and a site_* table', f.proname || '(' || pg_get_function_identity_arguments(f.oid) || ')', 'could be a sync or copy: read it'
  from funcs f, pat where f.src ~* pat.site_re and (f.src ~* pat.strict_re or f.src ~* pat.loose_re)
  union all
  select 'REVIEW', 'view mentions both an old table and a site_* table', v.viewname, 'a view that joins the two families'
  from pg_views v, pat
  where v.schemaname = 'public' and v.definition ~* pat.site_re and (v.definition ~* pat.strict_re or v.definition ~* pat.loose_re)
  union all
  select 'REVIEW', 'foreign key between an old table and a site_* table', cl.relname || ' -> ' || cf.relname, k.conname
  from pg_constraint k
  join pg_class cl on cl.oid = k.conrelid
  join pg_class cf on cf.oid = k.confrelid
  join pg_namespace n on n.oid = cl.relnamespace and n.nspname = 'public'
  where k.contype = 'f'
    and ((cl.relname in (select name from old_tables) and cf.relname like 'site\_%')
      or (cf.relname in (select name from old_tables) and cl.relname like 'site\_%'))
  union all
  -- A database webhook is a trigger that calls an edge function. It can be the thing that copies data; this lists them so the edge function can be read.
  select 'INFO', 'database webhook (a trigger that calls an edge function)', tbl || ' / ' || tgname, 'calls supabase_functions.' || proname
  from trig where fn_schema = 'supabase_functions' and proname = 'http_request'
),
tables_all(side, name) as (values
  ('old', 'events'), ('old', 'clubs'), ('old', 'venues'), ('old', 'events_bookings'), ('old', 'event_table_bookings'), ('old', 'table_bookings'),
  ('old', 'payment_transactions'), ('old', 'vendors'), ('old', 'partner_accounts'), ('old', 'door_staff'), ('shared', 'profiles'),
  ('site', 'site_events'), ('site', 'site_venues'), ('site', 'site_table_bookings'), ('site', 'site_table_booking_club_payments'),
  ('site', 'site_orders'), ('site', 'guest_tickets'), ('site', 'site_organizations'), ('site', 'site_memberships')),
counted as (
  select ta.side, ta.name, t.present, q.x
  from tables_all ta
  cross join lateral (
    select to_regclass('public.' || ta.name) is not null as present,
           exists (select 1 from information_schema.columns ic
                   where ic.table_schema = 'public' and ic.table_name = ta.name and ic.column_name = 'created_at'
                     and ic.data_type in ('timestamp with time zone', 'timestamp without time zone', 'date')) as has_ts
  ) t
  cross join lateral (
    select case when t.present then query_to_xml(
             format('select count(*) as total, %s as recent from public.%I',
                    case when t.has_ts then 'count(*) filter (where created_at > now() - interval ''30 days'')' else 'null::bigint' end, ta.name),
             false, true, '') end as x
  ) q
),
probes(ord, "check", item, needs_tables, needs_cols, q) as (values
  (30, 'people', 'sign-in accounts (auth.users)', array['auth.users'], array[]::text[], 'select count(*) as c from auth.users'),
  (31, 'people', 'accounts with no profile row (they would have no name or photo in either app)', array['auth.users', 'profiles'], array['profiles.id'],
       'select count(*) as c from auth.users u where not exists (select 1 from public.profiles p where p.id = u.id)'),
  (32, 'people', 'people with at least one active workspace (site_memberships)', array['site_memberships'], array['site_memberships.user_id', 'site_memberships.status'],
       'select count(distinct user_id) as c from public.site_memberships where status = ''active'''),
  (33, 'people', 'old vendors (vendors table)', array['vendors'], array['vendors.id'], 'select count(*) as c from public.vendors'),
  (34, 'people', 'old vendors with NO active workspace (the app shows them the classic dashboard only)', array['vendors', 'site_memberships'],
       array['vendors.id', 'site_memberships.user_id', 'site_memberships.status'],
       'select count(*) as c from public.vendors v where not exists (select 1 from public.site_memberships m where m.user_id = v.id and m.status = ''active'')'),
  (35, 'people', 'website partner applications (partner_accounts, the old /partners signup)', array['partner_accounts'], array['partner_accounts.id'],
       'select count(*) as c from public.partner_accounts'),
  (36, 'people', 'partner applications (pending or active) with NO workspace', array['partner_accounts', 'site_memberships'],
       array['partner_accounts.id', 'partner_accounts.onboarding_status', 'site_memberships.user_id', 'site_memberships.status'],
       'select count(*) as c from public.partner_accounts a where a.onboarding_status in (''pending'', ''active'') and not exists (select 1 from public.site_memberships m where m.user_id = a.id and m.status = ''active'')'),
  (37, 'people', 'door staff rows (door_staff)', array['door_staff'], array['door_staff.id'], 'select count(*) as c from public.door_staff'),
  (38, 'people', 'door staff with NO workspace (they keep the old /staff pages)', array['door_staff', 'site_memberships'],
       array['door_staff.id', 'site_memberships.user_id', 'site_memberships.status'],
       'select count(*) as c from public.door_staff d where not exists (select 1 from public.site_memberships m where m.user_id = d.id and m.status = ''active'')'),
  (40, 'venues in both families', 'old clubs whose name also exists in site_venues (same club in two places)', array['clubs', 'site_venues'], array['clubs.name', 'site_venues.name'],
       'select count(*) as c from public.clubs c where exists (select 1 from public.site_venues v where lower(trim(v.name)) = lower(trim(c.name)))'),
  (41, 'venues in both families', 'site_venues whose name matches no old club', array['clubs', 'site_venues'], array['clubs.name', 'site_venues.name'],
       'select count(*) as c from public.site_venues v where not exists (select 1 from public.clubs c where lower(trim(v.name)) = lower(trim(c.name)))'),
  (50, 'scheduled jobs', 'pg_cron jobs that mention site_*', array['cron.job'], array[]::text[], 'select count(*) as c from cron.job where command ~* ''site_'''),
  (51, 'scheduled jobs', 'pg_cron jobs that mention an old table', array['cron.job'], array[]::text[],
       'select count(*) as c from cron.job where command ~* ''(events_bookings|event_table_bookings|table_bookings|vendors|clubs)''')
),
probed as (
  select pr.ord, pr."check", pr.item, miss.missing,
         case when miss.missing is null then (xpath('/row/c/text()', query_to_xml(pr.q, false, true, '')))[1]::text end as result
  from probes pr
  cross join lateral (
    select nullif(concat_ws(', ',
             (select string_agg(t, ', ') from unnest(pr.needs_tables) t
              where to_regclass(case when t like '%.%' then t else 'public.' || t end) is null),
             (select string_agg(c, ', ') from unnest(pr.needs_cols) c
              where to_regclass('public.' || split_part(c, '.', 1)) is not null
                and not exists (select 1 from information_schema.columns ic
                                where ic.table_schema = 'public' and ic.table_name = split_part(c, '.', 1) and ic.column_name = split_part(c, '.', 2)))
           ), '') as missing
  ) miss
)
select 0 as ord,
       case when count(*) filter (where severity = 'REVIEW') = 0 then 'OK' else 'REVIEW' end as severity,
       'summary' as "check",
       count(*) filter (where severity = 'REVIEW')::text || ' place(s) where the database itself copies or joins old and site_* data' as item,
       case when count(*) filter (where severity = 'REVIEW') = 0
            then 'none: the two families only meet through the app code (edge functions are not visible from SQL)'
            else 'read the rows below' end as result
from bridges
union all
select 1, severity, "check", item, detail from bridges
union all
select case c.side when 'old' then 20 when 'site' then 21 else 22 end, 'INFO', 'where the rows live: ' || c.side || ' side', c.side || ': ' || c.name,
       case when not c.present then 'table not present in this database'
            else 'rows: ' || coalesce((xpath('/row/total/text()', c.x))[1]::text, '0')
                 || '; added in the last 30 days: ' || coalesce((xpath('/row/recent/text()', c.x))[1]::text, '(no created_at column)') end
from counted c
union all
select pd.ord, 'INFO', pd."check", pd.item, coalesce(pd.result, 'not checked: not in this database: ' || pd.missing) from probed pd
order by 1, 2, 3, 4;
