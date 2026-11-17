-- 51: PRE-FLIGHT for the website migration 20261123100000_complimentary_offers. Read-only.
-- One result set. Rows 1 to 4 must say ok = true (what the migration builds on is there, and none of its names is taken). Any later row is information only (it never blocks).
select * from (
  select 1 as n, 'the functions this builds on exist' as check_name,
         (to_regprocedure('public.can_access_venue(uuid, text[])') is not null and to_regprocedure('public.desk_request_free_bottle(uuid, uuid, integer, text)') is not null
          and to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is not null and to_regprocedure('public.booking_night(date, time without time zone)') is not null) as ok,
         concat_ws(', ', case when to_regprocedure('public.desk_request_free_bottle(uuid, uuid, integer, text)') is null then 'public.desk_request_free_bottle missing' end, case when to_regprocedure('public.can_access_venue(uuid, text[])') is null then 'public.can_access_venue missing' end,
                   case when to_regprocedure('public.desk_log(text, text, uuid, jsonb)') is null then 'public.desk_log missing' end, case when to_regprocedure('public.booking_night(date, time without time zone)') is null then 'public.booking_night missing' end) as detail
  union all
  select 2, 'the tables and columns this builds on exist (staff discounts and complimentary, floor plans)',
         (to_regclass('public.site_discount_limits') is not null and to_regclass('public.site_concessions') is not null and to_regclass('public.site_venue_floors') is not null and to_regclass('public.site_table_types') is not null
          and to_regclass('public.site_table_bookings') is not null and to_regclass('public.site_bottles') is not null and to_regclass('public.site_events') is not null and to_regclass('public.site_venue_time_slots') is not null
          and (select count(*) = 5 from information_schema.columns where table_schema = 'public' and table_name = 'site_table_types' and column_name in ('venue_id', 'name', 'floor_id', 'pos_x', 'pos_y'))),
         'site_discount_limits, site_concessions, site_venue_floors, site_table_types (venue_id, name, floor_id, pos_x, pos_y), site_table_bookings, site_bottles, site_events, site_venue_time_slots'
  union all
  select 3, 'none of the new names is taken (13 functions, 1 table)',
         (not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_state', 'comp_token_hash', 'comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel', 'comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])) and to_regclass('public.site_comp_offers') is null),
         concat_ws(', ', (select string_agg(p.proname, ', ') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (array['comp_offer_state', 'comp_token_hash', 'comp_offer_create', 'comp_offers_list', 'comp_offer_tables', 'comp_offer_set_location', 'comp_offer_bookings', 'comp_offer_accept', 'comp_offer_mark_delivered', 'comp_offer_cancel', 'comp_offer_issue_link', 'comp_claim_view', 'comp_claim_submit'])), case when to_regclass('public.site_comp_offers') is not null then 'site_comp_offers' end)
  union all
  select 4, 'the roles exist (the staff functions are granted to authenticated and service_role; the link and claim functions to service_role only)',
         exists (select 1 from pg_roles where rolname = 'service_role') and exists (select 1 from pg_roles where rolname = 'authenticated') and exists (select 1 from pg_roles where rolname = 'anon'),
         'service_role, authenticated, anon'
  union all
  select 5, 'INFORMATION: clubs whose owner has set the free-bottle limits (a manager can only make an offer in these; an owner always can)', true,
         (select count(*)::text from public.site_discount_limits) || ' clubs'
  union all
  select 6, 'INFORMATION: the migration only adds. It sends nothing, no visitor can call any of it, and the public claim page and the e-mail with the link are not part of it', true, 'one new table, thirteen new functions'
) r order by n;
