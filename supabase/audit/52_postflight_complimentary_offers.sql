-- 52: POST-FLIGHT for the website migration 20261123100000_complimentary_offers. Read-only.
-- ONE result set. Every row before the fingerprints must say ok = true. The FINGERPRINT rows give an md5 of each new function's body in the detail column (ok is always true there): compare them with
-- the same query on a replay of the repository (tests/db/run.sh database); they must be identical.
select * from (
  select 1 as n, 'the 13 function(s) exist' as check_name, (select count(*) = 13 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_state', 'comp_token_hash', 'comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel', 'comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])) as ok,
         (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_state', 'comp_token_hash', 'comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel', 'comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])) as detail
  union all
  select 2, 'every function that is not a pure helper runs with its owner''s rights and a fixed search path',
         (select bool_and(p.prosecdef and coalesce(p.proconfig::text, '') like '%search_path=public%') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel', 'comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])),
         '11 functions'
  union all
  select 3, 'signed-in people (and the service role) can call the eight staff functions; visitors cannot',
         (select bool_and(has_function_privilege('authenticated', p.oid, 'execute') and has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute')) and count(*) = 8
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel'])),
         'authenticated and service_role; not anon'
  union all
  select 4, 'only the SERVICE ROLE can make a link or read and submit a claim (not signed-in people, not visitors)',
         (select bool_and(has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('authenticated', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute')) and count(*) = 3
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])),
         'comp_offer_issue_link, comp_claim_view, comp_claim_submit: service_role only'
  union all
  select 5, 'the two helpers cannot be called by anyone signed in',
         (not has_function_privilege('authenticated', 'public.comp_offer_state(text, timestamp with time zone)', 'execute') and not has_function_privilege('anon', 'public.comp_offer_state(text, timestamp with time zone)', 'execute')
          and not has_function_privilege('authenticated', 'public.comp_token_hash(text)', 'execute') and not has_function_privilege('anon', 'public.comp_token_hash(text)', 'execute')),
         'comp_offer_state, comp_token_hash'
  union all
  select 6, 'table site_comp_offers has row level security on and no access for visitors or signed-in people',
         (to_regclass('public.site_comp_offers') is not null and (select relrowsecurity from pg_class where oid = 'public.site_comp_offers'::regclass)
          and not has_table_privilege('anon', 'public.site_comp_offers', 'select') and not has_table_privilege('authenticated', 'public.site_comp_offers', 'select')
          and not has_table_privilege('authenticated', 'public.site_comp_offers', 'insert') and not has_table_privilege('authenticated', 'public.site_comp_offers', 'update') and not has_table_privilege('authenticated', 'public.site_comp_offers', 'delete')),
         'RLS on, no grants'
  union all
  select 7, 'no offer exists yet: nothing existing was changed', (select count(*) = 0 from public.site_comp_offers), (select count(*)::text from public.site_comp_offers) || ' offers'
  union all
  select 8, 'the link token is kept only as a unique hash, never in the clear (a unique column token_hash and no column holding a token)',
         (exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'site_comp_offers' and indexdef like 'CREATE UNIQUE INDEX%token_hash%')
          and not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_comp_offers' and column_name in ('token', 'claim_token', 'link', 'claim_url'))),
         'unique token_hash; no clear token column'
  union all
  select 9, 'the database refuses a cancelled offer without its reason, a delivered one without its time, a placed one without who placed it, and an e-mail that is not one',
         ((select count(*) = 3 from pg_constraint c where c.conrelid = 'public.site_comp_offers'::regclass and c.conname in ('site_comp_offers_cancelled_check', 'site_comp_offers_delivered_check', 'site_comp_offers_location_check'))
          and exists (select 1 from pg_constraint c where c.conrelid = 'public.site_comp_offers'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%recipient_email%')),
         'cancelled, delivered, location and e-mail checks'
  union all
  select 20 + row_number() over (order by p.proname)::int, 'FINGERPRINT ' || p.proname, true,
         md5(regexp_replace(p.prosrc, '\s+', ' ', 'g') || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '') || '|' || pg_get_function_result(p.oid))
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_state', 'comp_token_hash', 'comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel', 'comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])
) r order by n;
