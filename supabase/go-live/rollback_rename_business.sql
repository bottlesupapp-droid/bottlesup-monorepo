-- ROLLBACK for 20261127100000_rename_business.sql: removes the rename_business function and the name_changed_at column. It does NOT undo any rename that already happened (a business keeps the name it was given
-- and its events keep the copy of it); it only removes the way to rename from the app. Dropping the column forgets when each business was last renamed. After this, the Business app's "Change" in Settings
-- answers "not available yet". The audit_log rows ('business.renamed') stay: they are the record of who renamed what. One transaction: all of it or none of it.
begin;

drop function if exists public.rename_business(uuid, text);
alter table public.site_organizations drop column if exists name_changed_at;

commit;
