-- Test login: gives bottlesupapp@gmail.com the roles needed to try the vendor app ("BottlesUp Business") end to end.
-- Run it in the production SQL editor (Supabase dashboard > SQL editor). Safe to run twice: a role the person already has is skipped.
--
-- WHAT IT DOES (3 rows in site_memberships, nothing else is touched):
--   * OWNER  of the club business "Active Lounge" : Overview, Floor, Tonight, Team, Venues, Agreements, VIP, money, close the night
--   * DOOR   at the venue "Active Lounge"         : the ticket scanner, walk-in at the door, group admission
--   * SERVER at the venue "Active Lounge"         : the server's own tables and orders
-- With three roles the app shows its workspace picker after sign-in, so one login can try the owner, door and server sides.
-- Active Lounge is the club that already holds the test staff of every role (manager, server, security, verifier), so no real client's data is exposed.
--
-- NOT INCLUDED, on purpose: an ORGANIZER workspace. The three organizer businesses (Baldguy, Eonics, EONICS: MEMBERS ONLY) are other people's, and an
-- organizer would see their events and guests. If you want to test the organizer side, tell Claude to prepare a separate test organizer business.
--
-- WHEN TO USE: after the account exists and has signed in once (it has: bottlesupapp@gmail.com, confirmed, last sign-in 18 Oct 2026).
-- The password is yours; nothing here sets or reads it.
-- TO UNDO: run the last block of this file (it revokes the three roles; nothing is deleted).

do $$
declare
  v_user  uuid;
  v_org   uuid;
  v_venue uuid;
  n int;
begin
  select id into v_user from auth.users where lower(email) = 'bottlesupapp@gmail.com';
  if v_user is null then raise exception 'no account with the e-mail bottlesupapp@gmail.com: create it first'; end if;

  select count(*) into n from public.site_organizations where name = 'Active Lounge' and kind = 'venue_owner';
  if n <> 1 then raise exception 'found % club businesses called "Active Lounge": expected exactly one', n; end if;
  select id into v_org from public.site_organizations where name = 'Active Lounge' and kind = 'venue_owner';

  select count(*) into n from public.site_venues where name = 'Active Lounge' and org_id = v_org;
  if n <> 1 then raise exception 'found % venues called "Active Lounge" in that business: expected exactly one', n; end if;
  select id into v_venue from public.site_venues where name = 'Active Lounge' and org_id = v_org;

  insert into public.site_memberships (org_id, user_id, role, venue_id, status)
  values (v_org, v_user, 'owner',  null,    'active'),
         (v_org, v_user, 'door',   v_venue, 'active'),
         (v_org, v_user, 'server', v_venue, 'active')
  on conflict do nothing;   -- the table allows one active row per person, role and scope
end $$;

-- CHECK: should list exactly owner, door, server, all active.
select m.role, o.name as business, coalesce(v.name, 'all venues') as scope, m.status
from public.site_memberships m
join auth.users u on u.id = m.user_id
join public.site_organizations o on o.id = m.org_id
left join public.site_venues v on v.id = m.venue_id
where lower(u.email) = 'bottlesupapp@gmail.com' and m.status = 'active'
order by m.role;

-- ---------------------------------------------------------------------------------------------------------------------------------------
-- UNDO (run only when the testing is over; it is a separate block so running the file top to bottom does not execute it):
--
-- update public.site_memberships m
--    set status = 'revoked', revoked_at = now()
--   from auth.users u
--  where u.id = m.user_id and lower(u.email) = 'bottlesupapp@gmail.com' and m.status = 'active'
--    and m.org_id = (select id from public.site_organizations where name = 'Active Lounge' and kind = 'venue_owner');
