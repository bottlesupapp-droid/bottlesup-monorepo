-- 19: PRE-FLIGHT for website migration 20261030100000_account_deletion_legacy_columns.sql (the five older-table columns that audit 18 still listed after 20261029100000).
-- Read-only. It lists what would make that migration STOP (it changes nothing when it stops): ROWS = look at them before applying; no rows = it will go through.
--   * 'would stop': the column's foreign key points somewhere other than audit 18 found, is deferrable, is one of several, or covers several columns; a CHECK, primary key,
--     unique index or partial-index condition involves the column (the migration does not know what setting it to null would do to such a rule).
--   * 'trigger to read': a trigger on one of the five tables. The migration does not judge triggers; this only names them so they can be read (a trigger that refuses an update
--     or reacts to the column would also run when the person's deletion sets the column to null).
-- A table or column that is not there is not a problem (the migration skips it). Run AFTER the migration it shows nothing for the first kind and still names the triggers.
-- Not run against production by Claude. On a scratch copy built from the repository it returns no rows.

with cols(tbl, col, target) as (values
  ('admin_audit_log',        'admin_id',    'auth.users'),
  ('conversations',          'created_by',  'auth.users'),
  ('event_rsvps',            'verified_by', 'auth.users'),
  ('vendor_onboarding_data', 'referrer_id', 'public.vendors'),
  ('venues',                 'manager_id',  'public.profiles')),
c as (
  select cols.*, to_regclass('public.' || cols.tbl) as rel,
         (select a.attnum from pg_attribute a where a.attrelid = to_regclass('public.' || cols.tbl) and a.attname = cols.col and not a.attisdropped) as attnum
    from cols)
select 'would stop' as problem, tbl || '.' || col as column_name, 'foreign key ' || k.conname || ' points at ' || k.confrelid::regclass::text || ', not at ' || c.target as detail
  from c join pg_constraint k on k.conrelid = c.rel and k.contype = 'f' and c.attnum = any (k.conkey) where k.confrelid <> to_regclass(c.target)
union all
select 'would stop', tbl || '.' || col, 'foreign key ' || k.conname || ' is deferrable or covers several columns'
  from c join pg_constraint k on k.conrelid = c.rel and k.contype = 'f' and c.attnum = any (k.conkey) where k.condeferrable or array_length(k.conkey, 1) <> 1
union all
select 'would stop', tbl || '.' || col, 'the column has ' || n || ' foreign keys'
  from (select c.tbl, c.col, count(*) as n from c join pg_constraint k on k.conrelid = c.rel and k.contype = 'f' and c.attnum = any (k.conkey) group by c.tbl, c.col having count(*) > 1) m(tbl, col, n)
union all
select 'would stop', tbl || '.' || col, 'CHECK ' || k.conname || ': ' || pg_get_constraintdef(k.oid)
  from c join pg_constraint k on k.conrelid = c.rel and k.contype = 'c' and c.attnum = any (k.conkey)
union all
select 'would stop', tbl || '.' || col, 'constraint ' || k.conname || ' (' || k.contype::text || ')'
  from c join pg_constraint k on k.conrelid = c.rel and k.contype in ('p', 'u', 'x') and c.attnum = any (k.conkey)
union all
select 'would stop', tbl || '.' || col, 'unique index ' || i.indexrelid::regclass::text
  from c join pg_index i on i.indrelid = c.rel and i.indisunique and c.attnum = any (i.indkey::smallint[])
union all
select 'would stop', tbl || '.' || col, 'index condition on ' || i.indexrelid::regclass::text || ': ' || pg_get_expr(i.indpred, i.indrelid)
  from c join pg_index i on i.indrelid = c.rel and i.indpred is not null and pg_get_expr(i.indpred, i.indrelid) ~ ('\m' || c.col || '\M')
union all
select 'trigger to read', t.tgrelid::regclass::text, t.tgname || ': ' || pg_get_triggerdef(t.oid)
  from pg_trigger t where not t.tgisinternal and t.tgrelid in (select rel from c where rel is not null)
order by 1, 2, 3;
