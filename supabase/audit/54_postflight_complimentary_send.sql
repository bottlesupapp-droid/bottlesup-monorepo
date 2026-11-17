-- 54: POST-FLIGHT for the website migration 20261124100000_complimentary_send. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 4 function(s) exist' as check_name,
         (select count(*) = 4 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle'])) as detail
  union all
  select 2, 'every function runs with its owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle'])),
         (select string_agg(p.proname || '=' || p.prosecdef || ' ' || coalesce(p.proconfig::text, 'no path'), '; ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle']))
  union all
  select 3, 'signed-in people (and the service role) can call the two staff functions; visitors cannot (the database checks who may send inside)',
         (has_function_privilege('authenticated', 'public.comp_offer_send_begin(uuid)', 'execute') and has_function_privilege('service_role', 'public.comp_offer_send_begin(uuid)', 'execute') and not has_function_privilege('anon', 'public.comp_offer_send_begin(uuid)', 'execute') and has_function_privilege('authenticated', 'public.comp_offer_sends(uuid)', 'execute') and has_function_privilege('service_role', 'public.comp_offer_sends(uuid)', 'execute') and not has_function_privilege('anon', 'public.comp_offer_sends(uuid)', 'execute')),
         'comp_offer_send_begin, comp_offer_sends'
  union all
  select 4, 'only the service role can say whether an e-mail went, or count a visit to the public page',
         (has_function_privilege('service_role', 'public.comp_offer_send_finish(uuid, boolean, text)', 'execute') and not has_function_privilege('authenticated', 'public.comp_offer_send_finish(uuid, boolean, text)', 'execute') and not has_function_privilege('anon', 'public.comp_offer_send_finish(uuid, boolean, text)', 'execute') and has_function_privilege('service_role', 'public.comp_claim_throttle(text, integer, integer)', 'execute') and not has_function_privilege('authenticated', 'public.comp_claim_throttle(text, integer, integer)', 'execute') and not has_function_privilege('anon', 'public.comp_claim_throttle(text, integer, integer)', 'execute')),
         'comp_offer_send_finish, comp_claim_throttle'
  union all
  select 5, 'table site_comp_offer_sends has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_comp_offer_sends') is not null and (select relrowsecurity from pg_class where oid = 'public.site_comp_offer_sends'::regclass)
          and not has_table_privilege('anon', 'public.site_comp_offer_sends', 'select') and not has_table_privilege('authenticated', 'public.site_comp_offer_sends', 'select')
          and not has_table_privilege('anon', 'public.site_comp_offer_sends', 'insert') and not has_table_privilege('authenticated', 'public.site_comp_offer_sends', 'insert')
          and not has_table_privilege('authenticated', 'public.site_comp_offer_sends', 'update') and not has_table_privilege('authenticated', 'public.site_comp_offer_sends', 'delete')),
         'RLS on, no grants'
  union all
  select 6, 'table site_comp_claim_attempts has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_comp_claim_attempts') is not null and (select relrowsecurity from pg_class where oid = 'public.site_comp_claim_attempts'::regclass)
          and not has_table_privilege('anon', 'public.site_comp_claim_attempts', 'select') and not has_table_privilege('authenticated', 'public.site_comp_claim_attempts', 'select')
          and not has_table_privilege('anon', 'public.site_comp_claim_attempts', 'insert') and not has_table_privilege('authenticated', 'public.site_comp_claim_attempts', 'insert')
          and not has_table_privilege('authenticated', 'public.site_comp_claim_attempts', 'update') and not has_table_privilege('authenticated', 'public.site_comp_claim_attempts', 'delete')),
         'RLS on, no grants'
  union all
  select 7, 'no e-mail has been logged and no visit counted yet: nothing existing was changed',
         ((select count(*) = 0 from public.site_comp_offer_sends) and (select count(*) = 0 from public.site_comp_claim_attempts)),
         (select count(*)::text from public.site_comp_offer_sends) || ' attempts, ' || (select count(*)::text from public.site_comp_claim_attempts) || ' visits'
  union all
  select 8, 'the person column does not block deleting an account (ON DELETE SET NULL), and a log row goes with its offer',
         ((select count(*) = 1 and bool_and(confdeltype = 'n') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey) where c.contype = 'f' and c.conrelid = 'public.site_comp_offer_sends'::regclass and a.attname = 'sent_by')
          and (select count(*) = 1 and bool_and(confdeltype = 'c') from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey) where c.contype = 'f' and c.conrelid = 'public.site_comp_offer_sends'::regclass and a.attname = 'offer_id')),
         'sent_by set null, offer_id cascade'
  union all
  select 9, 'an attempt is pending, sent or failed; a failure is only ever "not configured" or "send failed" (the provider''s words are never kept)',
         (exists (select 1 from pg_constraint c where c.conrelid = 'public.site_comp_offer_sends'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%pending%sent%failed%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_comp_offer_sends'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%not_configured%send_failed%')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_comp_offer_sends'::regclass and c.conname = 'site_comp_offer_sends_finished_together')
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_comp_offer_sends'::regclass and c.conname = 'site_comp_offer_sends_failure_when_failed')),
         'pending/sent/failed, not_configured/send_failed'
  union all
  select 10 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle'])
) r order by n;
