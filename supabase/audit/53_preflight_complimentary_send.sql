-- 53: PRE-FLIGHT for the website migration 20261124100000_complimentary_send. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist (the complimentary offers migration 20261123100000)' as check_name,
         (to_regprocedure('public.comp_offer_state(text, timestamp with time zone)') is not null and to_regprocedure('public.comp_offer_issue_link(uuid)') is not null
          and to_regprocedure('public.comp_claim_view(text)') is not null and to_regprocedure('public.can_access_venue(uuid, text[])') is not null and to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.comp_offer_state(text, timestamp with time zone)') is null then 'public.comp_offer_state missing' end, case when to_regprocedure('public.comp_offer_issue_link(uuid)') is null then 'public.comp_offer_issue_link missing' end,
                   case when to_regprocedure('public.comp_claim_view(text)') is null then 'public.comp_claim_view missing' end, case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end,
                   case when to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is null then 'public.desk_log missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist',
         (to_regclass('public.site_comp_offers') is not null and to_regclass('public.site_venues') is not null
          and (select count(*) = 8 from information_schema.columns where table_schema = 'public' and table_name = 'site_comp_offers' and column_name in ('id', 'venue_id', 'status', 'token_hash', 'sent_at', 'claimed_at', 'recipient_email', 'recipient_name'))
          and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_venues' and column_name = 'time_zone')),
         'site_comp_offers (id, venue_id, status, token_hash, sent_at, claimed_at, recipient_email, recipient_name), site_venues.time_zone'
  union all
  select 3, 'none of the new names is taken (4 functions, 2 tables)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle']))
          and to_regclass('public.site_comp_offer_sends') is null and to_regclass('public.site_comp_claim_attempts') is null),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_send_begin', 'comp_offer_send_finish', 'comp_offer_sends', 'comp_claim_throttle'])), case when to_regclass('public.site_comp_offer_sends') is not null then 'site_comp_offer_sends' end, case when to_regclass('public.site_comp_claim_attempts') is not null then 'site_comp_claim_attempts' end)
  union all
  select 4, 'the roles exist (staff functions are granted to authenticated and service_role; the finish and throttle functions to service_role only)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: offers that exist now (none can have been e-mailed: nothing could send a link before this)', true,
         (select count(*)::text from public.site_comp_offers) || ' offers, ' || (select count(*)::text from public.site_comp_offers where token_hash is not null) || ' with a link'
  union all
  select 6, 'INFORMATION: the migration only adds; it sends nothing. Sending needs the send-complimentary-offer function deployed, the RESEND_API_KEY and SUPABASE_SERVICE_ROLE_KEY secrets (the report e-mails already use them) and, for the right address in the link, the SITE_URL secret; the public page needs comp-claim deployed and the website built from main',
         true, 'two new tables, four new functions, two edge functions'
) r order by n;
