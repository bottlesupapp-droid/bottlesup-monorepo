-- 20: how the vendor app's "Delete account" really works in production. Read-only; ONE result set (the dashboard SQL editor shows only the last one).
-- The vendor app calls the database function delete_account() (apps/bottles-up-vendor/lib/features/auth/services/supabase_auth_service.dart). The vendor repo's own migration
-- (apps/bottles-up-vendor/supabase/migrations/006_delete_account_function.sql) says it deletes the caller's row in the classic public.vendors table and that a trigger on that table then
-- deletes the sign-in (public.delete_auth_user_on_vendor_delete). This shows what production really has:
--   * 'function'            the source of delete_account() and delete_auth_user_on_vendor_delete(); detail = runs with its owner's rights (true/false); grants = who may call it
--   * 'trigger on vendors'  every trigger on public.vendors (the one that calls the second function should be here, enabled = O)
--   * 'count'               accounts, vendors rows, accounts WITHOUT a vendors row (for them delete_account() deletes nothing), how many of those have a workspace membership
--                           (invited staff), and vendors rows without an account. Counts only: no names, e-mails or ids.
-- If a function body contains a key or token, redact it before sending the result to anyone.
-- Not run against production by Claude (the CLI link was refused on 23 Oct). On a scratch copy built from the repository the function rows are absent and the counts run.

select 'function' as kind, n.nspname || '.' || p.proname as name, p.prosecdef::text as detail,
       'authenticated: ' || has_function_privilege('authenticated', p.oid, 'execute')::text || ', anon: ' || has_function_privilege('anon', p.oid, 'execute')::text as grants,
       pg_get_functiondef(p.oid) as source
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname in ('delete_account', 'delete_auth_user_on_vendor_delete')
union all
select 'trigger on vendors', t.tgname, 'enabled = ' || t.tgenabled::text, '', pg_get_triggerdef(t.oid)
  from pg_trigger t where t.tgrelid = 'public.vendors'::regclass and not t.tgisinternal
union all
select 'count', c.label, c.n::text, '', ''
  from (values
    ('accounts in auth.users', (select count(*) from auth.users)),
    ('rows in public.vendors', (select count(*) from public.vendors)),
    ('accounts WITHOUT a vendors row', (select count(*) from auth.users u where not exists (select 1 from public.vendors v where v.id = u.id))),
    ('...of those, with a workspace membership (invited staff)', (select count(*) from auth.users u where not exists (select 1 from public.vendors v where v.id = u.id) and exists (select 1 from public.site_memberships m where m.user_id = u.id))),
    ('vendors rows without an account', (select count(*) from public.vendors v where not exists (select 1 from auth.users u where u.id = v.id)))
  ) as c(label, n)
order by 1, 2;
