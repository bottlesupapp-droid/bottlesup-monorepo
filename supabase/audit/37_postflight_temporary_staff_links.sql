-- 37: POST-FLIGHT for the website migration 20261118100000_temporary_staff_links. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 8 function(s) exist' as check_name,
         (select count(*) = 8 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['invite_temporary_staff', 'verify_invitation_code', 'invitation_preview', 'request_invitation_renewal', 'list_invitation_extras', 'issue_invitation_code', 'temporary_invitation_gate', 'invitation_new_link_resets'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['invite_temporary_staff', 'verify_invitation_code', 'invitation_preview', 'request_invitation_renewal', 'list_invitation_extras', 'issue_invitation_code', 'temporary_invitation_gate', 'invitation_new_link_resets'])) as detail
  union all
  select 2, 'the app-facing functions (and any trigger function meant to) run with their owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['invite_temporary_staff', 'verify_invitation_code', 'invitation_preview', 'request_invitation_renewal', 'list_invitation_extras', 'issue_invitation_code', 'invitation_new_link_resets'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['invite_temporary_staff', 'verify_invitation_code', 'invitation_preview', 'request_invitation_renewal', 'list_invitation_extras', 'issue_invitation_code', 'invitation_new_link_resets']))
  union all
  select 3, 'signed-in people (and the service role) can call the app-facing functions; visitors cannot (the database checks who may do what inside)',
         (has_function_privilege('authenticated', 'public.invite_temporary_staff(uuid, text, text, uuid, uuid, uuid, timestamptz, timestamptz, int)', 'execute') and has_function_privilege('service_role', 'public.invite_temporary_staff(uuid, text, text, uuid, uuid, uuid, timestamptz, timestamptz, int)', 'execute') and not has_function_privilege('anon', 'public.invite_temporary_staff(uuid, text, text, uuid, uuid, uuid, timestamptz, timestamptz, int)', 'execute') and has_function_privilege('authenticated', 'public.verify_invitation_code(text, text)', 'execute') and has_function_privilege('service_role', 'public.verify_invitation_code(text, text)', 'execute') and not has_function_privilege('anon', 'public.verify_invitation_code(text, text)', 'execute') and has_function_privilege('authenticated', 'public.invitation_preview(text)', 'execute') and has_function_privilege('service_role', 'public.invitation_preview(text)', 'execute') and not has_function_privilege('anon', 'public.invitation_preview(text)', 'execute') and has_function_privilege('authenticated', 'public.request_invitation_renewal(text, text)', 'execute') and has_function_privilege('service_role', 'public.request_invitation_renewal(text, text)', 'execute') and not has_function_privilege('anon', 'public.request_invitation_renewal(text, text)', 'execute') and has_function_privilege('authenticated', 'public.list_invitation_extras(uuid)', 'execute') and has_function_privilege('service_role', 'public.list_invitation_extras(uuid)', 'execute') and not has_function_privilege('anon', 'public.list_invitation_extras(uuid)', 'execute')),
         'invite_temporary_staff, verify_invitation_code, invitation_preview, request_invitation_renewal, list_invitation_extras'
  union all
  select 4, 'the service-role-only functions are not callable by signed-in people or visitors',
         (has_function_privilege('service_role', 'public.issue_invitation_code(text, text)', 'execute') and not has_function_privilege('authenticated', 'public.issue_invitation_code(text, text)', 'execute') and not has_function_privilege('anon', 'public.issue_invitation_code(text, text)', 'execute')),
         'issue_invitation_code'
  union all
  select 5, 'table site_invitation_codes has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_invitation_codes') is not null and (select relrowsecurity from pg_class where oid = 'public.site_invitation_codes'::regclass)
          and not has_table_privilege('anon', 'public.site_invitation_codes', 'select') and not has_table_privilege('authenticated', 'public.site_invitation_codes', 'select')
          and not has_table_privilege('anon', 'public.site_invitation_codes', 'insert') and not has_table_privilege('authenticated', 'public.site_invitation_codes', 'insert')
          and not has_table_privilege('authenticated', 'public.site_invitation_codes', 'update') and not has_table_privilege('authenticated', 'public.site_invitation_codes', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'every invitation that existed is permanent, with nothing confirmed and nothing asked for (nothing existing was changed)',
         ((select count(*) = 0 from public.site_invitations where kind <> 'permanent' or identity_verified_at is not null or renewal_requested_at is not null)),
         (select count(*)::text from public.site_invitations where kind = 'permanent') || ' of ' || (select count(*)::text from public.site_invitations)
  union all
  select 7, 'the two triggers are on the invitations table (the identity check cannot be skipped, and a new link starts again)',
         (exists (select 1 from pg_trigger g where g.tgname = 'site_invitations_temporary_gate' and g.tgrelid = 'public.site_invitations'::regclass and not g.tgisinternal) and exists (select 1 from pg_trigger g where g.tgname = 'site_invitations_new_link_resets' and g.tgrelid = 'public.site_invitations'::regclass and not g.tgisinternal)),
         'site_invitations_temporary_gate, site_invitations_new_link_resets'
  union all
  select 8, 'the code table keeps only a hash and clears itself with its invitation (no column holds a code, ON DELETE CASCADE)',
         (not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_invitation_codes' and column_name in ('code', 'plain_code', 'code_text')) and (select confdeltype = 'c' from pg_constraint c where c.conrelid = 'public.site_invitation_codes'::regclass and c.contype = 'f' and c.confrelid = 'public.site_invitations'::regclass)),
         'code_hash only'
  union all
  select 8 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['invite_temporary_staff', 'verify_invitation_code', 'invitation_preview', 'request_invitation_renewal', 'list_invitation_extras', 'issue_invitation_code', 'temporary_invitation_gate', 'invitation_new_link_resets'])
) r order by n;
