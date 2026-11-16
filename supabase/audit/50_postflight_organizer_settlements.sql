-- 50: POST-FLIGHT for the website migration 20261122120000_organizer_settlements. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 13 function(s) exist' as check_name,
         (select count(*) = 13 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_log_add', 'settlement_base', 'settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_log_add', 'settlement_base', 'settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge'])) as detail
  union all
  select 2, 'every function that is not a pure calculation runs with its owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_log_add', 'settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge'])),
         '12 functions'
  union all
  select 3, 'signed-in people (and the service role) can call the eleven public functions; visitors cannot (the database checks who may do what inside)',
         (select bool_and(has_function_privilege('authenticated', p.oid, 'execute') and has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute') and count_ok = 11)
            from (select p2.oid, count(*) over () as count_ok from pg_proc p2 where p2.pronamespace = 'public'::regnamespace and p2.proname = any (array['settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge'])) p),
         'authenticated and service_role; not anon'
  union all
  select 4, 'the two internal helpers cannot be called by anyone signed in',
         (not has_function_privilege('authenticated', 'public.settlement_log_add(uuid, text, text, text, text, bigint, text)', 'execute') and not has_function_privilege('anon', 'public.settlement_log_add(uuid, text, text, text, text, bigint, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.settlement_base(jsonb, bigint)', 'execute') and not has_function_privilege('anon', 'public.settlement_base(jsonb, bigint)', 'execute')),
         'settlement_log_add, settlement_base'
  union all
  select 5, 'tables site_settlements and site_settlement_log have row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_settlements') is not null and to_regclass('public.site_settlement_log') is not null
          and (select bool_and(c.relrowsecurity) from pg_class c where c.oid in ('public.site_settlements'::regclass, 'public.site_settlement_log'::regclass))
          and not has_table_privilege('anon', 'public.site_settlements', 'select') and not has_table_privilege('authenticated', 'public.site_settlements', 'select')
          and not has_table_privilege('authenticated', 'public.site_settlements', 'insert') and not has_table_privilege('authenticated', 'public.site_settlements', 'update') and not has_table_privilege('authenticated', 'public.site_settlements', 'delete')
          and not has_table_privilege('anon', 'public.site_settlement_log', 'select') and not has_table_privilege('authenticated', 'public.site_settlement_log', 'select')
          and not has_table_privilege('authenticated', 'public.site_settlement_log', 'insert') and not has_table_privilege('authenticated', 'public.site_settlement_log', 'update') and not has_table_privilege('authenticated', 'public.site_settlement_log', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'no settlement and no history exists yet: nothing existing was changed',
         ((select count(*) = 0 from public.site_settlements) and (select count(*) = 0 from public.site_settlement_log)),
         (select count(*)::text from public.site_settlements) || ' settlements, ' || (select count(*)::text from public.site_settlement_log) || ' history lines'
  union all
  select 7, 'there is one settlement per agreement (a unique index), and the five statuses are the ones the functions use',
         (exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'site_settlements' and indexname = 'site_settlements_one_per_agreement' and indexdef like 'CREATE UNIQUE INDEX%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_settlements'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%estimated%reviewed%approved%paid%disputed%')),
         'site_settlements_one_per_agreement; estimated, reviewed, approved, paid, disputed'
  union all
  select 8, 'the database refuses a paid settlement without its payment, a disputed one without its reason, an adjustment without a note, and an amount owed below zero',
         ((select count(*) = 4 from pg_constraint c where c.conrelid = 'public.site_settlements'::regclass and c.conname in ('site_settlements_paid_check', 'site_settlements_disputed_check', 'site_settlements_adjustment_needs_note', 'site_settlements_payable_check'))),
         'site_settlements_paid_check, _disputed_check, _adjustment_needs_note, _payable_check'
  union all
  select 9, 'the person columns do not block deleting an account (ON DELETE SET NULL)',
         ((select count(*) = 7 and bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
            where c.contype = 'f' and ((c.conrelid = 'public.site_settlements'::regclass and a.attname in ('entered_by', 'reviewed_by', 'approved_by', 'paid_recorded_by', 'disputed_by', 'organizer_ack_by')) or (c.conrelid = 'public.site_settlement_log'::regclass and a.attname = 'actor')))),
         'entered_by, reviewed_by, approved_by, paid_recorded_by, disputed_by, organizer_ack_by, actor'
  union all
  select 10 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_log_add', 'settlement_base', 'settlements_for_venue', 'settlements_for_organizer', 'settlement_detail', 'settlement_save_sales', 'settlement_adjust', 'settlement_review', 'settlement_approve', 'settlement_record_payment', 'settlement_question', 'settlement_resolve', 'settlement_acknowledge'])
) r order by n;
