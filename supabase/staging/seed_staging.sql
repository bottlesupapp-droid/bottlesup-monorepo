-- Staging seed. Run in the STAGING project's SQL editor, never in production.
--
-- Before running:
--   1. Dashboard -> Authentication -> Users -> Add user, twice (use emails you control).
--   2. Put those two emails in the two places marked EDIT below.
--
-- It is safe to run more than once.

-- EDIT: the first user becomes a CMS admin (can sign in at /cms).
insert into public.cms_admins (id, email)
select id, email from auth.users where email = 'admin@example.com'
on conflict (id) do nothing;

-- EDIT: the second user becomes a server who may record club payments
-- (signs in at /staff/login, lands on the My Tables dashboard).
insert into public.door_staff (id, email, name, role, can_record_payments)
select id, email, 'Staging Server', 'server', true from auth.users where email = 'server@example.com'
on conflict (id) do nothing;

-- Staging must never take real payments.
update public.site_content set payments_mode = 'test';

-- Check what you ended up with (all three should return a row):
select 'cms_admins' as what, count(*) as rows from public.cms_admins
union all select 'door_staff', count(*) from public.door_staff
union all select 'payments_mode=' || payments_mode, count(*) from public.site_content group by payments_mode;
