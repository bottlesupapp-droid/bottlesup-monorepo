-- 56: POST-FLIGHT for the website migration 20261125100000_settlement_adjustments. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 10 function(s) exist' as check_name,
         (select count(*) = 10 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustment_log_add', 'settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustment_log_add', 'settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive'])) as detail
  union all
  select 2, 'every function runs with its owner''s rights and a fixed search path',
         (select count(*) = 10 and bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustment_log_add', 'settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive'])),
         '10 functions'
  union all
  select 3, 'signed-in people (and the service role) can call the nine public functions; visitors cannot (the database checks who may do what inside)',
         (select count(*) = 9 and bool_and(has_function_privilege('authenticated', p.oid, 'execute') and has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute'))
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive'])),
         'authenticated and service_role; not anon'
  union all
  select 4, 'the internal history writer cannot be called by anyone signed in',
         (not has_function_privilege('authenticated', 'public.settlement_adjustment_log_add(uuid, uuid, text, text, text, text, bigint, text)', 'execute') and not has_function_privilege('anon', 'public.settlement_adjustment_log_add(uuid, uuid, text, text, text, text, bigint, text)', 'execute')),
         'settlement_adjustment_log_add'
  union all
  select 5, 'tables site_settlement_adjustments and site_settlement_adjustment_log have row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_settlement_adjustments') is not null and to_regclass('public.site_settlement_adjustment_log') is not null
          and (select bool_and(c.relrowsecurity) from pg_class c where c.oid in ('public.site_settlement_adjustments'::regclass, 'public.site_settlement_adjustment_log'::regclass))
          and not has_table_privilege('anon', 'public.site_settlement_adjustments', 'select') and not has_table_privilege('authenticated', 'public.site_settlement_adjustments', 'select')
          and not has_table_privilege('authenticated', 'public.site_settlement_adjustments', 'insert') and not has_table_privilege('authenticated', 'public.site_settlement_adjustments', 'update') and not has_table_privilege('authenticated', 'public.site_settlement_adjustments', 'delete')
          and not has_table_privilege('anon', 'public.site_settlement_adjustment_log', 'select') and not has_table_privilege('authenticated', 'public.site_settlement_adjustment_log', 'select')
          and not has_table_privilege('authenticated', 'public.site_settlement_adjustment_log', 'insert') and not has_table_privilege('authenticated', 'public.site_settlement_adjustment_log', 'update') and not has_table_privilege('authenticated', 'public.site_settlement_adjustment_log', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'no adjustment and no history exists yet: nothing existing was changed',
         ((select count(*) = 0 from public.site_settlement_adjustments) and (select count(*) = 0 from public.site_settlement_adjustment_log)),
         (select count(*)::text from public.site_settlement_adjustments) || ' adjustments, ' || (select count(*)::text from public.site_settlement_adjustment_log) || ' history lines'
  union all
  select 7, 'the four kinds and the four statuses are the ones the functions use',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_settlement_adjustments'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%refund%chargeback%correction%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_settlement_adjustments'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%open%disputed%settled%waived%')),
         'refund, chargeback, correction; open, disputed, settled, waived'
  union all
  select 8, 'the database refuses a refund that adds, an amount of nothing, a question without its reason, a settled one without its payment (for the exact amount) and a waived one that was owed to the organizer',
         ((select count(*) = 5 from pg_constraint c where c.conrelid = 'public.site_settlement_adjustments'::regclass and c.conname in ('site_settlement_adjustments_sign_check', 'site_settlement_adjustments_amount_cents_check', 'site_settlement_adjustments_disputed_check', 'site_settlement_adjustments_settled_check', 'site_settlement_adjustments_waived_check'))),
         'site_settlement_adjustments_sign_check, _amount_cents_check, _disputed_check, _settled_check, _waived_check'
  union all
  select 9, 'the person columns do not block deleting an account (ON DELETE SET NULL)',
         ((select count(*) = 5 and bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
            where c.contype = 'f' and ((c.conrelid = 'public.site_settlement_adjustments'::regclass and a.attname in ('recorded_by', 'disputed_by', 'organizer_ack_by', 'resolved_by')) or (c.conrelid = 'public.site_settlement_adjustment_log'::regclass and a.attname = 'actor')))),
         'recorded_by, disputed_by, organizer_ack_by, resolved_by, actor'
  union all
  select 10, 'the original settlement tables were not changed: the same 33 columns and the same 4 constraints that make a paid settlement final',
         ((select count(*) = 33 from information_schema.columns where table_schema = 'public' and table_name = 'site_settlements')
          and (select count(*) = 4 from pg_constraint c where c.conrelid = 'public.site_settlements'::regclass and c.conname in ('site_settlements_paid_check', 'site_settlements_disputed_check', 'site_settlements_adjustment_needs_note', 'site_settlements_payable_check'))),
         'site_settlements'
  union all
  select 20 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['settlement_adjustment_log_add', 'settlement_adjustments', 'settlement_adjustment_flags_for_venue', 'settlement_adjustment_flags_for_organizer', 'settlement_adjustment_record', 'settlement_adjustment_question', 'settlement_adjustment_answer', 'settlement_adjustment_acknowledge', 'settlement_adjustment_settle', 'settlement_adjustment_waive'])
) r order by n;
