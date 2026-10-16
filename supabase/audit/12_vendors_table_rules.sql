-- READ ONLY. One SELECT over system catalogs: it returns rules and code (policies, triggers, function definitions, column privileges) and a row COUNT.
-- It returns no rows of data, names, emails or ids.
--
-- WHY: the vendors table is wired to other things (a trigger that creates a row for every new account, a trigger that deletes the sign-in when a row
-- is deleted, a trigger that feeds the admin list). This lists its rules and triggers in one place so they can be reviewed by whoever owns the database.
--
-- HOW: Supabase dashboard -> SQL Editor -> New query -> paste ALL of this -> Run.
select 1 as ord, 'trigger on public.vendors' as what,
       t.tgname || ' (' || case when t.tgenabled = 'O' then 'enabled' else 'DISABLED' end || ') -> ' || p.proname as detail
from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
where n.nspname = 'public' and c.relname = 'vendors' and not t.tgisinternal
union all
select 2, 'trigger on auth.users', t.tgname || ' (' || case when t.tgenabled = 'O' then 'enabled' else 'DISABLED' end || ') -> ' || p.proname
from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
where n.nspname = 'auth' and c.relname = 'users' and not t.tgisinternal
union all
select 3, 'function ' || p.proname, regexp_replace(pg_get_functiondef(p.oid), '\s+', ' ', 'g')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('handle_new_user', 'sync_vendor_admins', 'delete_auth_user_on_vendor_delete', 'delete_account', 'is_admin')
union all
select 4, 'vendors policy ' || policyname, cmd || ' to ' || array_to_string(roles, ',') || '; using: ' || coalesce(qual, '-') || '; check: ' || coalesce(with_check, '(none)')
from pg_policies where schemaname = 'public' and tablename = 'vendors'
union all
select 5, 'vendors column privilege (signed-in users, UPDATE)', c.column_name || ' -> ' || has_column_privilege('authenticated', 'public.vendors', c.column_name, 'UPDATE')::text
from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'vendors'
union all
select 6, 'vendor_admins rows (count only)', count(*)::text from public.vendor_admins
order by 1, 2;
