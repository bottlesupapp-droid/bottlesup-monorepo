-- Check for the two website migrations written for the client's feedback of 10 Oct 2026:
--   20261012100000_cancel_business.sql     (cancel a business added by mistake)
--   20261013100000_organizer_events.sql    (an organizer creates and edits its own draft events)
--
-- READ ONLY. One SELECT. Safe to run BEFORE applying them (it shows what they need and that they are not there yet) and again AFTER
-- (it must say OK). Run it in the SQL editor of the project, and send the result back.
--   1. prerequisites: what the two migrations rely on already exists (the tenancy and onboarding migrations, site_events with the
--      columns the organizer functions write, audit_log). plpgsql does not check column names when a function is created, so a
--      missing column would only fail the first time someone used the screen: this finds it now.
--   2. everything they create is there: 11 functions;
--   3. nothing is exposed: no function is callable by anonymous visitors, and only the four meant for the app are callable by
--      signed-in people (the helpers write audit entries and validate input; they must stay internal);
--   4. each public function runs with its owner's rights with a pinned search_path (it checks the caller itself).
-- The first row says OK when there is no STOP row.
with
funcs(name, intended) as (values
    ('cancel_business', 'yes'),
    ('list_org_events', 'yes'),
    ('save_org_event', 'yes'),
    ('remove_org_event', 'yes'),
    ('require_org_organizer', 'no'),
    ('org_event_log', 'no'),
    ('org_event_only_keys', 'no'),
    ('org_event_text', 'no'),
    ('org_event_int', 'no'),
    ('org_event_url', 'no'),
    ('org_event_time', 'no')),
needs_funcs(name) as (values ('is_org_member'), ('active_memberships'), ('create_organization'), ('is_cms_admin')),
needs_tables(name) as (values
    ('site_organizations'), ('site_memberships'), ('site_invitations'), ('site_business_profiles'), ('site_verifications'),
    ('site_venue_claims'), ('site_venues'), ('site_events'), ('site_ticket_tiers'), ('site_orders'), ('audit_log')),
needs_cols(tbl, col) as (values
    ('site_events', 'title'), ('site_events', 'description'), ('site_events', 'venue_name'), ('site_events', 'address'),
    ('site_events', 'start_date'), ('site_events', 'end_date'), ('site_events', 'category'), ('site_events', 'capacity'),
    ('site_events', 'cover_image_url'), ('site_events', 'status'), ('site_events', 'org_id'), ('site_events', 'organizer_name'),
    ('site_events', 'slug'), ('site_events', 'created_at'), ('site_venues', 'org_id'), ('site_venues', 'status'),
    ('audit_log', 'actor_id'), ('audit_log', 'actor_email'), ('audit_log', 'action'), ('audit_log', 'entity_type'),
    ('audit_log', 'entity_id'), ('audit_log', 'details')),
fn_state as (
  select f.name, f.intended, p.oid, p.prosecdef, p.proconfig,
         has_function_privilege('anon', p.oid, 'execute') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from funcs f left join pg_proc p on p.pronamespace = 'public'::regnamespace and p.proname = f.name
),
checks as (
  -- 1. prerequisites
  select 'STOP' sev, 'prerequisite missing: function' chk, n.name item, 'apply the tenancy and onboarding migrations first' detail from needs_funcs n
    where not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n.name)
  union all select 'STOP', 'prerequisite missing: table', n.name, 'the migrations need it' from needs_tables n
    where not exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = n.name and c.relkind = 'r')
  union all select 'STOP', 'prerequisite missing: column', n.tbl || '.' || n.col, 'the functions write or read it; without it they fail the first time they are used' from needs_cols n
    where not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = n.tbl and c.column_name = n.col)
  union all select 'STOP', 'prerequisite: site_events.status', 'draft / published',
         coalesce('the check constraint reads: ' || (select string_agg(pg_get_constraintdef(c.oid), '; ') from pg_constraint c where c.conrelid = 'public.site_events'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%status%'), 'no check constraint on status')
    where to_regclass('public.site_events') is not null and not exists (
      select 1 from pg_constraint c where c.conrelid = 'public.site_events'::regclass and c.contype = 'c'
        and pg_get_constraintdef(c.oid) like '%status%' and pg_get_constraintdef(c.oid) like '%draft%' and pg_get_constraintdef(c.oid) like '%published%')
  -- 2. everything is there (before applying, these rows are expected)
  union all select 'STOP', 'missing: function', name, 'was not created (expected if the migrations are not applied yet)' from fn_state where oid is null
  -- 3. exposure
  union all select 'STOP', 'exposed: callable by anonymous visitors', name, 'revoke execute from anon and public' from fn_state where anon_exec
  union all select 'STOP', 'exposed: callable by signed-in people, not intended', name, 'revoke execute from authenticated' from fn_state where auth_exec and intended = 'no'
  union all select 'STOP', 'not callable by signed-in people, but should be', name, 'grant execute to authenticated' from fn_state where oid is not null and not auth_exec and intended = 'yes'
  -- 4. how the functions run
  union all select 'STOP', 'does not run with its owner''s rights', name, 'must be security definer: it checks the caller itself' from fn_state where oid is not null and not prosecdef and intended = 'yes'
  union all select 'STOP', 'search_path is not pinned', name, 'a security definer function must set search_path' from fn_state
    where oid is not null and prosecdef and not exists (select 1 from unnest(coalesce(proconfig, '{}')) c where c like 'search_path=%')
  union all select 'INFO', 'present', name, case intended when 'yes' then 'callable by signed-in people' else 'internal' end from fn_state where oid is not null
)
select sev as severity, chk as "check", item, detail from (
  select 0 ord, case when exists (select 1 from checks where sev = 'STOP') then 'STOP' else 'OK' end sev, 'summary' chk,
         (select count(*) from checks where sev = 'STOP')::text || ' blocking finding(s)' item,
         case when exists (select 1 from checks where sev = 'STOP') then 'something is missing or exposed; send this result back' else 'everything is in place and nothing extra is exposed' end detail
  union all select case sev when 'STOP' then 1 else 3 end, sev, chk, item, detail from checks
) r order by ord, chk, item;
