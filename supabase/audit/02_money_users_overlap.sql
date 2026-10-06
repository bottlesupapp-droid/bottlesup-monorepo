-- =============================================================================
-- BottlesUp live database audit, part 2 of 2: REAL MONEY, REAL USERS, OVERLAP
--
-- READ-ONLY. A single SELECT that returns aggregates only (counts, date ranges,
-- totals). It reads no personal data and changes nothing.
--
-- Run it in the PRODUCTION project, same as part 1. Export as CSV.
--
-- It answers the question that decides the migration plan:
--   "Did real customers or real payments ever go through the OLD app tables
--    (events_bookings, table_bookings, payment_transactions ...), or only
--    through the website's site_* tables?"
-- If the old tables hold paid rows, they must be archived and kept readable,
-- never dropped, and the apps need a transition plan, not a clean cutover.
--
-- Every table and column is checked for existence first, so a missing table
-- simply produces no row instead of an error.
--
-- Result columns: section, name, value
-- =============================================================================
with
tables_of_interest(tbl) as (
  values
    ('site_events'), ('site_orders'), ('site_table_bookings'), ('site_venues'), ('door_staff'), ('partner_accounts'),
    ('events'), ('events_bookings'), ('table_bookings'), ('event_table_bookings'), ('bookings'), ('event_bookings'),
    ('club_table_bookings'), ('clubs'), ('venues'), ('payment_transactions'), ('stripe_customers'),
    ('vendors'), ('stripe_accounts'), ('payout_records'), ('vendor_subscriptions'), ('profiles')
),
present as (
  select tbl from tables_of_interest where to_regclass('public.' || tbl) is not null
),

-- exact row counts
row_counts as (
  select 'row count'::text as section, tbl::text as name,
         (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', tbl), false, true, '')))[1]::text as value
  from present
),

-- when was each table first / last written to?
date_ranges as (
  select 'first / last row'::text, i.table_name::text,
         (xpath('/row/v/text()', query_to_xml(
            format('select coalesce(min(created_at)::date::text, ''empty'') || '' to '' || coalesce(max(created_at)::date::text, ''empty'') as v from public.%I', i.table_name),
            false, true, '')))[1]::text
  from information_schema.columns i
  where i.table_schema = 'public' and i.column_name = 'created_at'
    and i.table_name in (select tbl from present)
    and i.table_name not in ('profiles', 'events', 'clubs', 'venues', 'vendors', 'site_venues', 'site_events')
),

-- how are bookings / orders distributed by status?
status_mix as (
  select 'status mix'::text, i.table_name::text,
         (xpath('/row/v/text()', query_to_xml(
            format($q$select coalesce(string_agg(s || '=' || n, ', ' order by n desc), 'empty') as v
                      from (select status::text as s, count(*) as n from public.%I group by 1) x$q$, i.table_name),
            false, true, '')))[1]::text
  from information_schema.columns i
  where i.table_schema = 'public' and i.column_name = 'status'
    and i.table_name in ('site_orders', 'site_table_bookings', 'events_bookings', 'table_bookings', 'event_table_bookings',
                         'bookings', 'event_bookings', 'club_table_bookings', 'payment_transactions')
),

-- paid money per table. Units differ by table, shown in the name.
money_targets(tbl, col, filter, unit) as (
  values
    ('site_orders',          'amount_total_cents', 'status = ''paid''',                         'cents (website tickets)'),
    ('site_table_bookings',  'amount_total_cents', 'status = ''paid''',                         'cents (website tables)'),
    ('events_bookings',      'total_amount',       'status in (''confirmed'', ''checkedIn'')',  'currency units (app tickets)'),
    ('table_bookings',       'total_price',        'status = ''confirmed''',                    'currency units (app tables)')
),
money as (
  select 'paid total'::text, (m.tbl || ' - ' || m.unit)::text,
         (xpath('/row/v/text()', query_to_xml(
            format('select coalesce(sum(%I), 0)::text || '' over '' || count(*)::text || '' paid rows'' as v from public.%I where %s', m.col, m.tbl, m.filter),
            false, true, '')))[1]::text
  from money_targets m
  where exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = m.tbl and c.column_name = m.col)
    and exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = m.tbl and c.column_name = 'status')
),

-- live Stripe customers: ids that came from live mode
stripe as (
  select 'stripe customers'::text, 'stripe_customers rows'::text,
         (xpath('/row/v/text()', query_to_xml('select count(*)::text as v from public.stripe_customers', false, true, '')))[1]::text
  where to_regclass('public.stripe_customers') is not null
),

-- accounts and sign-in methods
auth_users as (
  select 'auth'::text, 'accounts (auth.users)'::text, count(*)::text from auth.users
),
auth_providers as (
  select 'auth'::text, ('sign-ins via ' || provider)::text, count(*)::text
  from auth.identities
  group by provider
),
profiles_gap as (
  select 'auth'::text, 'accounts with NO profiles row'::text,
         (xpath('/row/v/text()', query_to_xml('select count(*)::text as v from auth.users u where not exists (select 1 from public.profiles p where p.id = u.id)', false, true, '')))[1]::text
  where to_regclass('public.profiles') is not null
),

-- customers that exist in BOTH worlds: bought on the website (matched by email)
-- and have an account (so could also sign in to the app)
website_customers as (
  select 'overlap'::text, 'distinct website customer emails (orders + tables)'::text,
         (xpath('/row/v/text()', query_to_xml(
            'select count(*)::text as v from (
               select lower(customer_email) as e from public.site_orders
               union
               select lower(customer_email) from public.site_table_bookings) x', false, true, '')))[1]::text
  where to_regclass('public.site_orders') is not null and to_regclass('public.site_table_bookings') is not null
),
website_customers_with_account as (
  select 'overlap'::text, 'of those, with an auth account'::text,
         (xpath('/row/v/text()', query_to_xml(
            'select count(*)::text as v from (
               select lower(customer_email) as e from public.site_orders
               union
               select lower(customer_email) from public.site_table_bookings) x
             where exists (select 1 from auth.users u where lower(u.email) = x.e)', false, true, '')))[1]::text
  where to_regclass('public.site_orders') is not null and to_regclass('public.site_table_bookings') is not null
)

select section, name, value
from (
  select * from row_counts
  union all select * from date_ranges
  union all select * from status_mix
  union all select * from money
  union all select * from stripe
  union all select * from auth_users
  union all select * from auth_providers
  union all select * from profiles_gap
  union all select * from website_customers
  union all select * from website_customers_with_account
) r
order by case section when 'paid total' then 1 when 'status mix' then 2 when 'first / last row' then 3
                      when 'row count' then 4 when 'stripe customers' then 5 when 'auth' then 6 else 7 end,
         name;
