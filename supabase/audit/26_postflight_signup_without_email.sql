-- 26: POST-FLIGHT for the website migration 20261031100000_signup_without_email (handle_new_user() makes no vendors row for an account with no e-mail). Read-only. Every row should say ok = true.
-- Row 1 is also the PRE-FLIGHT: before the migration the fingerprint must be 0f54e77c86333964079e1a41efa8ea67 (production's version of 29 Oct 2026); the migration refuses anything else by itself.
with fn as (
  select p.oid, p.prosecdef, p.proconfig,
         md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')) as fingerprint
  from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'handle_new_user' and pg_get_function_identity_arguments(p.oid) = ''
),
trg as (
  select t.tgname, t.tgenabled, p.proname from pg_trigger t join pg_proc p on p.oid = t.tgfoid
  where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
)
select * from (
  select 1 as n, 'handle_new_user() is the fixed version (fingerprint)' as check_name, coalesce((select fingerprint from fn), 'missing') as actual, '9c85aa68c490b14d9fa1982dfe1c572e' as expected,
         coalesce((select fingerprint from fn), '') = '9c85aa68c490b14d9fa1982dfe1c572e' as ok
  union all select 2, 'it is security definer with a fixed search_path', coalesce((select prosecdef::text || ' ' || coalesce(proconfig::text, 'none') from fn), 'missing'), 'true {search_path=public}',
         coalesce((select prosecdef and proconfig = array['search_path=public'] from fn), false)
  union all select 3, 'the trigger on auth.users is still the only one, enabled, running it', coalesce((select string_agg(tgname || ':' || tgenabled::text || ':' || proname, ',') from trg), 'none'), 'on_auth_user_created:O:handle_new_user',
         coalesce((select string_agg(tgname || ':' || tgenabled::text || ':' || proname, ',') from trg), '') = 'on_auth_user_created:O:handle_new_user'
  union all select 4, 'vendors.email is still required (nothing was loosened)', coalesce((select is_nullable from information_schema.columns where table_schema = 'public' and table_name = 'vendors' and column_name = 'email'), 'missing'), 'NO',
         coalesce((select is_nullable = 'NO' from information_schema.columns where table_schema = 'public' and table_name = 'vendors' and column_name = 'email'), false)
  union all select 5, 'no vendors row is missing its e-mail (count)', (select count(*) from public.vendors where email is null)::text, '0',
         (select count(*) from public.vendors where email is null) = 0
) x order by n;
