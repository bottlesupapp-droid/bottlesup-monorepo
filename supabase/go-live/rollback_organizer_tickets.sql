-- ROLLBACK for 20261128100000_organizer_tickets.sql: removes the organizer's ticket functions and the two sale-date columns on site_ticket_tiers. It DELETES the sale dates organizers have set (a ticket type goes
-- back to being on sale at all times), so run it only if the feature is being taken out. Ticket types the organizers created stay (they are ordinary rows in site_ticket_tiers), and so do the audit_log rows
-- ('org_tier.created', 'org_tier.updated', 'org_tier.removed'). If the checkout function was deployed with the sale-window check (website PR "sale window"), it keeps working: it reads the columns from the row it
-- fetches, and a row without them is simply on sale. One transaction: all of it or none of it.
begin;

drop function if exists public.remove_org_tier(uuid, uuid);
drop function if exists public.save_org_tier(uuid, uuid, uuid, jsonb);
drop function if exists public.list_org_tiers(uuid, uuid);
drop function if exists public.org_tier_has_sold(uuid);
drop function if exists public.org_tier_event(uuid, uuid);

alter table public.site_ticket_tiers drop constraint if exists site_ticket_tiers_sale_window_check;
alter table public.site_ticket_tiers drop column if exists sale_starts_at;
alter table public.site_ticket_tiers drop column if exists sale_ends_at;

commit;
