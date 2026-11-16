-- ROLLBACK for 20261122110000_stock_overview.sql: removes the one read-only function. It changed no data, so there is nothing to restore; the vendor app's Inventory "Overview" page then says the
-- stock figures are not set up on this server yet, and everything else in Inventory works as before.
drop function if exists public.stock_overview(uuid, timestamptz, timestamptz);
