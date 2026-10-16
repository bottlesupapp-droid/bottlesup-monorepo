-- READ ONLY. One SELECT; nothing is created, changed or locked. COUNTS only: no names, emails or ids are returned.
--
-- WHY: from the vendor app branch `feat/web-first-onboarding`, a signed-in person with no workspace keeps the classic dashboard ONLY if their
-- `vendors` row has onboarding_completed = true. Everyone else is sent to "Set up your business" (create the account on the website, or use an
-- invitation). Until now the app created a `vendors` row for every account that signed in, so most rows are probably unfinished. This shows
-- how many people each rule affects, before the app is released.
--
-- HOW: Supabase dashboard -> SQL Editor -> New query -> paste ALL of this -> Run -> send me the grid.
select what, n from (
  select 1 as ord, 'vendors rows' as what, count(*) as n from public.vendors
  union all
  select 2, 'finished the classic onboarding (keep the classic dashboard)', count(*) from public.vendors where onboarding_completed is true
  union all
  select 3, 'never finished it (will see "Set up your business" if they have no workspace)', count(*) from public.vendors where onboarding_completed is not true
  union all
  select 4, 'finished it AND have an active workspace (the workspace wins)', count(*) from public.vendors v
  where v.onboarding_completed is true and exists (select 1 from public.site_memberships m where m.user_id = v.id and m.status = 'active')
  union all
  select 5, 'finished it and have NO workspace (classic dashboard only: the people who could still be affected by a change there)', count(*) from public.vendors v
  where v.onboarding_completed is true and not exists (select 1 from public.site_memberships m where m.user_id = v.id and m.status = 'active')
  union all
  select 6, 'never finished it and have NO workspace (will be sent to "Set up your business")', count(*) from public.vendors v
  where v.onboarding_completed is not true and not exists (select 1 from public.site_memberships m where m.user_id = v.id and m.status = 'active')
  union all
  select 7, 'never finished it, row created in the last 30 days', count(*) from public.vendors v
  where v.onboarding_completed is not true and v.created_at > now() - interval '30 days'
) q
order by ord;
