-- 18: what stops an account from being deleted (the delete-account function runs DELETE FROM auth.users). Read-only. Run it BEFORE applying website migration
-- 20261029100000_account_deletion_actor_fks.sql to see every blocker in the real database (including any a repository migration does not know about, e.g. a table made by hand),
-- and AFTER: it must return NO ROWS.
--   * 'refuses deletion': a foreign key to auth.users, or to a table that is deleted together with the person (profiles, site_memberships, door_staff, vendors, ...), with no
--     "on delete" rule. Any person with a row in that column cannot delete their account. The migration fixes the ones it lists; a row here that is NOT in the migration needs a decision.
--   * 'fails on deletion': a foreign key set to null on delete whose column is NOT NULL (the delete would raise "null value ... violates not-null").
-- Before the migration, expect 52 'refuses deletion' rows on a database that has the tranche-2 migrations (51 columns into auth.users + site_invitations.membership_id), more once the
-- brief-3 migrations are in (14 more), and none for 'fails on deletion'.
-- Not run against production by Claude. On a scratch copy built from the repository it returns 52 rows before the migration and none after.

with recursive gone(rel) as (
  select 'auth.users'::regclass
  union
  select c.conrelid from pg_constraint c join gone on c.confrelid = gone.rel where c.contype = 'f' and c.confdeltype = 'c'
)
select 'refuses deletion' as problem,
       c.conrelid::regclass::text || '.' || a.attname as column_name,
       c.conname::text as constraint_name,
       c.confrelid::regclass::text as points_at,
       case when a.attnotnull then 'NOT NULL' else 'nullable' end as column_is
  from pg_constraint c
  join gone on c.confrelid = gone.rel
  join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
 where c.contype = 'f' and c.confdeltype in ('a', 'r')
union all
select 'fails on deletion',
       c.conrelid::regclass::text || '.' || a.attname,
       c.conname::text,
       c.confrelid::regclass::text,
       'NOT NULL with on delete set null'
  from pg_constraint c
  join gone on c.confrelid = gone.rel
  join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
 where c.contype = 'f' and c.confdeltype = 'n' and a.attnotnull
order by 1, 2;
