-- 27: PRE- and POST-FLIGHT for the website migration 20261112100000_profile_date_of_birth (profiles.date_of_birth, and the age kept in step with it by a trigger). Read-only. Every row should say ok = true.
-- BEFORE the migration: rows 1 to 5 and 8 say ok = false (nothing of ours is there yet; actual = missing, none or n/a) and rows 6 and 7 ok = true (the age rule and the existing trigger are the ones the migration relies on).
-- AFTER it: all 8 rows ok = true.
with col as (
  select data_type, is_nullable from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'date_of_birth'
),
fn as (
  select p.prosecdef, p.proconfig, p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'profiles_set_age_from_date_of_birth' and pg_get_function_identity_arguments(p.oid) = ''
),
trg as (
  select t.tgname, t.tgenabled, t.tgtype, t.tgqual is not null as has_when from pg_trigger t where t.tgrelid = 'public.profiles'::regclass and not t.tgisinternal
)
select * from (
  select 1 as n, 'profiles.date_of_birth is a nullable date' as check_name, coalesce((select data_type || ' null=' || is_nullable from col), 'missing') as actual, 'date null=YES' as expected,
         coalesce((select data_type = 'date' and is_nullable = 'YES' from col), false) as ok
  union all select 2, 'the range check is in place (nothing before 1900)', coalesce((select pg_get_constraintdef(oid) from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_date_of_birth_range'), 'missing'),
         'CHECK (((date_of_birth IS NULL) OR (date_of_birth >= ''1900-01-01''::date)))',
         coalesce((select pg_get_constraintdef(oid) = 'CHECK (((date_of_birth IS NULL) OR (date_of_birth >= ''1900-01-01''::date)))' from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_date_of_birth_range'), false)
  union all select 3, 'the age function runs as the caller with a fixed search_path', coalesce((select prosecdef::text || ' ' || coalesce(proconfig::text, 'none') from fn), 'missing'), 'false {search_path=public}',
         coalesce((select not prosecdef and proconfig = array['search_path=public'] from fn), false)
  union all select 4, 'nobody can call the age function from the app (anon, signed-in, public)',
         coalesce((select 'anon=' || has_function_privilege('anon', oid, 'execute') || ' authenticated=' || has_function_privilege('authenticated', oid, 'execute') from fn), 'missing'), 'anon=false authenticated=false',
         coalesce((select not has_function_privilege('anon', oid, 'execute') and not has_function_privilege('authenticated', oid, 'execute') from fn), false)
  union all select 5, 'the trigger is there once: enabled, before insert or update, for each row, only when a date is given',
         coalesce((select string_agg(tgname || ':' || tgenabled::text || ':' || (tgtype & 2 = 2)::text || ':' || (tgtype & 4 = 4)::text || ':' || (tgtype & 16 = 16)::text || ':' || (tgtype & 1 = 1)::text || ':' || has_when::text, ',') from trg where tgname = 'profiles_set_age_from_date_of_birth'), 'none'),
         'profiles_set_age_from_date_of_birth:O:true:true:true:true:true',
         coalesce((select count(*) = 1 and bool_and(tgenabled = 'O' and tgtype & 2 = 2 and tgtype & 4 = 4 and tgtype & 16 = 16 and tgtype & 1 = 1 and has_when) from trg where tgname = 'profiles_set_age_from_date_of_birth'), false)
  union all select 6, 'the age rule is still in force (nobody under 18 can be saved)', coalesce((select pg_get_constraintdef(oid) from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_age_check'), 'missing'), 'CHECK ((age >= 18))',
         coalesce((select pg_get_constraintdef(oid) = 'CHECK ((age >= 18))' from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_age_check'), false)
  union all select 7, 'the other trigger on profiles is untouched', coalesce((select string_agg(tgname, ',' order by tgname) from trg where tgname <> 'profiles_set_age_from_date_of_birth'), 'none'), 'update_profiles_updated_at',
         coalesce((select string_agg(tgname, ',' order by tgname) from trg where tgname <> 'profiles_set_age_from_date_of_birth'), '') = 'update_profiles_updated_at'
  union all select 8, 'no profile has an age that disagrees with its date of birth (count)',
         case when exists (select 1 from col)
              then (xpath('/row/c/text()', query_to_xml('select count(*) as c from public.profiles where date_of_birth is not null and age is distinct from extract(year from age(current_date::timestamp, date_of_birth::timestamp))::int', false, true, '')))[1]::text
              else 'n/a (no column yet)' end,
         '0',
         case when exists (select 1 from col)
              then (xpath('/row/c/text()', query_to_xml('select count(*) as c from public.profiles where date_of_birth is not null and age is distinct from extract(year from age(current_date::timestamp, date_of_birth::timestamp))::int', false, true, '')))[1]::text = '0'
              else false end
) x order by n;
