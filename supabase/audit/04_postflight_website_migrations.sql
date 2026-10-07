-- Post-flight for the website migrations 20261006120000 .. 20261011100000 and 20260830130000.
--
-- READ ONLY. One SELECT. Run it in the SQL editor of the project you just applied them to, and send the result back.
-- It confirms, from the migration files themselves (this file is generated from them), that:
--   1. everything they create is there: 67 functions, 8 tables, 14 policies, 4 triggers, 13 indexes, 11 new columns, the image bucket;
--   2. the entry-code fix is in (verify_ticket_otp has the fixed definition) and the scan result constraint allows 'wrong_event';
--   3. nothing is exposed that should not be: the eight new tables have row level security on, anonymous visitors have no
--      access to them, signed-in people can only SELECT from them, the invitation token hashes are unreadable, and no
--      function is callable by anonymous visitors or (beyond the intended 57) by signed-in people.
-- The first row says OK when there is no STOP row.
with
new_funcs(name, intended) as (values
    ('active_memberships', 'yes'),
    ('is_org_member', 'yes'),
    ('can_access_venue', 'yes'),
    ('can_access_event', 'yes'),
    ('can_view_membership', 'yes'),
    ('can_invite_role', 'yes'),
    ('create_organization', 'yes'),
    ('create_org_venue', 'yes'),
    ('create_shift', 'yes'),
    ('invite_member', 'yes'),
    ('resend_invitation', 'yes'),
    ('revoke_invitation', 'yes'),
    ('accept_invitation', 'yes'),
    ('revoke_membership', 'yes'),
    ('my_workspaces', 'yes'),
    ('my_venues', 'yes'),
    ('list_invitations', 'yes'),
    ('clean_social_links', 'no'),
    ('username_available', 'yes'),
    ('save_my_profile', 'yes'),
    ('site_org_after_insert', 'no'),
    ('verification_missing', 'yes'),
    ('save_business_details', 'yes'),
    ('submit_verification', 'yes'),
    ('review_verification', 'yes'),
    ('my_businesses', 'yes'),
    ('search_venues', 'yes'),
    ('request_venue_claim', 'yes'),
    ('review_venue_claim', 'yes'),
    ('update_venue_profile', 'yes'),
    ('venue_setup_status', 'yes'),
    ('list_venue_claims', 'yes'),
    ('admin_verification_queue', 'yes'),
    ('admin_venue_claims', 'yes'),
    ('business_media_org', 'no'),
    ('invitable_roles', 'yes'),
    ('list_team', 'yes'),
    ('list_team_invitations', 'yes'),
    ('list_shifts', 'yes'),
    ('reserve_invitation_email', 'yes'),
    ('has_door_role', 'yes'),
    ('can_scan_event', 'yes'),
    ('door_events', 'yes'),
    ('door_scan_ticket', 'yes'),
    ('door_verify_ticket_code', 'yes'),
    ('door_guests', 'yes'),
    ('require_venue_editor', 'no'),
    ('venue_setup_log', 'no'),
    ('setup_only_keys', 'no'),
    ('setup_int', 'no'),
    ('setup_text', 'no'),
    ('setup_url', 'no'),
    ('setup_bool', 'no'),
    ('list_venue_time_slots', 'yes'),
    ('add_venue_time_slot', 'yes'),
    ('remove_venue_time_slot', 'yes'),
    ('list_venue_floors', 'yes'),
    ('save_venue_floor', 'yes'),
    ('remove_venue_floor', 'yes'),
    ('list_venue_table_types', 'yes'),
    ('save_venue_table_type', 'yes'),
    ('remove_venue_table_type', 'yes'),
    ('list_venue_bottles', 'yes'),
    ('save_venue_bottle', 'yes'),
    ('remove_venue_bottle', 'yes'),
    ('booking_night', 'yes'),
    ('list_venue_bookings', 'yes')),
new_tables(name) as (values
    ('site_organizations'),
    ('site_shifts'),
    ('site_memberships'),
    ('site_invitations'),
    ('site_business_profiles'),
    ('site_verifications'),
    ('site_verification_events'),
    ('site_venue_claims')),
new_policies(tbl, pol) as (values
    ('public.site_organizations', 'members read their organizations'),
    ('public.site_memberships', 'read own or managed memberships'),
    ('public.site_invitations', 'read invitations you can manage'),
    ('public.site_shifts', 'read shifts for venues you can reach'),
    ('public.site_venues', 'members read their venues'),
    ('public.site_events', 'members read their events'),
    ('storage.objects', 'public read business media'),
    ('storage.objects', 'members add business media'),
    ('storage.objects', 'owners replace business media'),
    ('storage.objects', 'owners delete business media'),
    ('public.site_business_profiles', 'business members read their details'),
    ('public.site_verifications', 'business members read their verification'),
    ('public.site_verification_events', 'business members read their verification history'),
    ('public.site_venue_claims', 'owners read their venue requests')),
new_triggers(tbl, trg) as (values
    ('public.site_organizations', 'site_organizations_set_updated_at'),
    ('public.site_business_profiles', 'site_business_profiles_set_updated_at'),
    ('public.site_verifications', 'site_verifications_set_updated_at'),
    ('public.site_organizations', 'site_organizations_after_insert')),
new_indexes(name) as (values
    ('site_venues_org_id_idx'),
    ('site_events_org_id_idx'),
    ('site_shifts_venue_id_idx'),
    ('site_memberships_user_id_idx'),
    ('site_memberships_org_id_idx'),
    ('site_memberships_one_active_per_scope'),
    ('site_invitations_token_hash_idx'),
    ('site_invitations_org_id_idx'),
    ('profiles_username_unique'),
    ('site_verification_events_org_idx'),
    ('site_venue_claims_one_pending'),
    ('site_venue_claims_venue_idx'),
    ('site_events_venue_id_idx')),
new_cols(tbl, col) as (values
    ('public.site_venues', 'org_id'),
    ('public.site_events', 'org_id'),
    ('public.profiles', 'username'),
    ('public.profiles', 'bio'),
    ('public.profiles', 'city'),
    ('public.profiles', 'social_links'),
    ('public.profiles', 'profile_completed_at'),
    ('public.site_invitations', 'email_token_hash'),
    ('public.site_invitations', 'email_sent_at'),
    ('public.site_invitations', 'email_send_count'),
    ('public.site_events', 'venue_id')),
fn_state as (
  select n.name, n.intended, p.oid,
         has_function_privilege('anon', p.oid, 'execute') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
  from new_funcs n left join pg_proc p on p.pronamespace = 'public'::regnamespace and p.proname = n.name
),
checks as (
  -- 1. everything is there
  select 'STOP' sev, 'missing: function' chk, name item, 'was not created' detail from fn_state where oid is null
  union all select 'STOP', 'missing: table', n.name, 'was not created' from new_tables n
    where not exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = n.name and c.relkind = 'r')
  union all select 'STOP', 'missing: policy', n.tbl || ' / ' || n.pol, 'was not created' from new_policies n
    where not exists (select 1 from pg_policies p where p.schemaname || '.' || p.tablename = n.tbl and p.policyname = n.pol)
  union all select 'STOP', 'missing: trigger', n.tbl || ' / ' || n.trg, 'was not created' from new_triggers n
    where not exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace s on s.oid = c.relnamespace
                      where not t.tgisinternal and t.tgname = n.trg and s.nspname || '.' || c.relname = n.tbl)
  union all select 'STOP', 'missing: index', n.name, 'was not created' from new_indexes n
    where not exists (select 1 from pg_indexes i where i.schemaname = 'public' and i.indexname = n.name)
  union all select 'STOP', 'missing: column', n.tbl || '.' || n.col, 'was not added' from new_cols n
    where not exists (select 1 from information_schema.columns c where 'public.' || c.table_name = n.tbl and c.column_name = n.col)
  union all select 'STOP', 'missing: storage bucket', 'business-media', 'was not created' where not exists (select 1 from storage.buckets where id = 'business-media')
  -- 2. the fixes
  union all select case when p.oid is null then 'STOP' when md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')) = 'c109bccac3091ce5bdf9dcec1a4f7f7f' then 'OK' else 'STOP' end,
         'verify_ticket_otp', 'entry-code fix',
         case when p.oid is null then 'function missing' when md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')) = 'c109bccac3091ce5bdf9dcec1a4f7f7f' then 'has the fixed definition' else 'does NOT have the fixed definition' end
    from (select 1) one left join pg_proc p on p.pronamespace = 'public'::regnamespace and p.proname = 'verify_ticket_otp' and pg_get_function_identity_arguments(p.oid) = 'p_ticket_code text, p_code text'
  union all select case when pg_get_constraintdef(c.oid) like '%wrong_event%' then 'OK' else 'STOP' end, 'scan_attempts_result_check', 'allows wrong_event',
         coalesce(pg_get_constraintdef(c.oid), 'constraint missing')
    from (select 1) one left join pg_constraint c on c.conname = 'scan_attempts_result_check' and c.conrelid = 'public.scan_attempts'::regclass
  -- 3. exposure
  union all select 'STOP', 'exposed: callable by anonymous visitors', name, 'revoke execute from anon and public' from fn_state
    where anon_exec and name not in ('business_media_org')
  union all select 'INFO', 'harmless: callable by anonymous visitors', name, 'a pure helper the image storage policy uses' from fn_state where anon_exec and name = 'business_media_org'
  union all select 'STOP', 'exposed: callable by signed-in people, not intended', name, 'revoke execute from authenticated' from fn_state
    where auth_exec and intended = 'no' and name not in ('business_media_org', 'clean_social_links', 'site_org_after_insert')
  union all select 'INFO', 'harmless: callable by signed-in people', name, 'a pure text helper, or a trigger function that cannot be called directly' from fn_state
    where auth_exec and intended = 'no' and name in ('business_media_org', 'clean_social_links', 'site_org_after_insert')
  union all select 'STOP', 'not callable by signed-in people, but should be', name, 'grant execute to authenticated' from fn_state where oid is not null and not auth_exec and intended = 'yes'
  union all select 'STOP', 'table without row level security', n.name, 'anyone with a grant could read or write it' from new_tables n
    join pg_class c on c.relnamespace = 'public'::regnamespace and c.relname = n.name where not c.relrowsecurity
  union all select 'STOP', 'anonymous visitors have access to a new table', n.name || ' (' || priv || ')', 'revoke all from anon'
    from new_tables n cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) priv
    where exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = n.name) and has_table_privilege('anon', 'public.' || n.name, priv)
  union all select 'STOP', 'signed-in people can write a new table directly', n.name || ' (' || priv || ')', 'every change should go through the functions'
    from new_tables n cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) priv
    where exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = n.name) and has_table_privilege('authenticated', 'public.' || n.name, priv)
  union all select 'STOP', 'a secret column is readable', 'site_invitations.' || a.attname, 'token hashes must not be readable by signed-in people or anonymous visitors'
    from pg_attribute a where a.attrelid = to_regclass('public.site_invitations') and a.attnum > 0 and not a.attisdropped and a.attname like '%hash%'
      and (has_column_privilege('authenticated', 'public.site_invitations', a.attname, 'select') or has_column_privilege('anon', 'public.site_invitations', a.attname, 'select'))
  -- worth reading: who can see the profile columns the migration added (profiles predates these migrations, so its rules are production's own)
  union all select 'INFO', 'profiles policy', p.policyname, p.cmd || ' for ' || coalesce(array_to_string(p.roles, ','), '-') || ': ' || coalesce(left(p.qual, 120), 'no condition')
    from pg_policies p where p.schemaname = 'public' and p.tablename = 'profiles'
)
select sev as severity, chk as "check", item, detail from (
  select 0 ord, case when exists (select 1 from checks where sev = 'STOP') then 'STOP' else 'OK' end sev, 'summary' chk,
         (select count(*) from checks where sev = 'STOP')::text || ' blocking finding(s)' item,
         case when exists (select 1 from checks where sev = 'STOP') then 'something is missing or exposed; send this result back' else 'everything is in place and nothing extra is exposed' end detail
  union all select case sev when 'STOP' then 1 when 'OK' then 2 else 3 end, sev, chk, item, detail from checks
) r order by ord, chk, item;
