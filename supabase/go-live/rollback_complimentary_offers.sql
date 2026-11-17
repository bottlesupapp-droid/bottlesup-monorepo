-- ROLLBACK for 20261123100000_complimentary_offers.sql: removes the complimentary offers (every offer, its recipient's e-mail address, the places chosen) and the functions. It DELETES them: take a copy first
-- if they matter (select * from public.site_comp_offers). It does NOT touch a free bottle that an accepted offer already created: those are ordinary free bottles (site_concessions and bottle lines) and stay.
-- Nothing was ever sent to anyone by this migration. One transaction: all of it or none of it.
begin;

drop function if exists public.comp_claim_submit(text, uuid);
drop function if exists public.comp_claim_view(text);
drop function if exists public.comp_offer_issue_link(uuid);
drop function if exists public.comp_offer_cancel(uuid, text);
drop function if exists public.comp_offer_mark_delivered(uuid);
drop function if exists public.comp_offer_accept(uuid, uuid);
drop function if exists public.comp_offer_bookings(uuid, date);
drop function if exists public.comp_offer_set_location(uuid, uuid);
drop function if exists public.comp_offer_tables(uuid);
drop function if exists public.comp_offers_list(uuid);
drop function if exists public.comp_offer_create(uuid, uuid, int, text, text, text, text, uuid, int);
drop function if exists public.comp_token_hash(text);
drop function if exists public.comp_offer_state(text, timestamptz);

drop table if exists public.site_comp_offers;

commit;
