-- ROLLBACK for 20261124100000_complimentary_send.sql: removes the send log (who pressed "E-mail the link", to which address, whether it went) and the public page's visit counts, and the four functions.
-- It DELETES them: take a copy if the log matters (select * from public.site_comp_offer_sends). It does NOT touch an offer or a link that was already made or e-mailed: those stay as they are (site_comp_offers).
-- Rolling back stops the staff app's "E-mail the link" and the public claim page's throttle from working; deploy nothing from the send-complimentary-offer or comp-claim functions while it is rolled back.
-- One transaction: all of it or none of it.
begin;

drop function if exists public.comp_claim_throttle(text, int, int);
drop function if exists public.comp_offer_sends(uuid);
drop function if exists public.comp_offer_send_finish(uuid, boolean, text);
drop function if exists public.comp_offer_send_begin(uuid);

drop table if exists public.site_comp_claim_attempts;
drop table if exists public.site_comp_offer_sends;

commit;
