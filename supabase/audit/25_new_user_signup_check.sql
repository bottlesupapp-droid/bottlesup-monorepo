-- 25: READ ONLY. Why does a NEW sign-in (Apple, Google, anything) fail with "Database error saving new user"?
-- That message comes from Supabase Auth when inserting the new row into auth.users fails inside Postgres: almost always a trigger on auth.users
-- (or a required column / unique rule it hits). This lists, in one place: every trigger on auth.users with the code it runs, the required columns
-- without a default on vendors and profiles (what such a trigger must fill in), and their unique indexes. It returns code and rules only, no rows of
-- data. Run: Supabase dashboard -> SQL Editor -> New query -> paste ALL -> Run. The exact failing line is in Logs -> Postgres around the time of the attempt.
select 1 as ord, 'trigger on auth.users' as what,
       t.tgname || ' (' || case when t.tgenabled = 'O' then 'enabled' else 'DISABLED' end || ') -> ' || p.proname || ': ' || regexp_replace(pg_get_functiondef(p.oid), '\s+', ' ', 'g') as detail
from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace join pg_proc p on p.oid = t.tgfoid
where n.nspname = 'auth' and c.relname = 'users' and not t.tgisinternal
union all
select 2, 'required column without a default: ' || c.table_name, c.column_name || ' (' || c.data_type || ')'
from information_schema.columns c
where c.table_schema = 'public' and c.table_name in ('vendors', 'profiles') and c.is_nullable = 'NO' and c.column_default is null
union all
select 3, 'unique index on ' || i.tablename, i.indexdef
from pg_indexes i
where i.schemaname = 'public' and i.tablename in ('vendors', 'profiles') and i.indexdef ilike '%unique%'
order by 1, 2;
