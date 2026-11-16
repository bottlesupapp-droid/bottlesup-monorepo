-- ROLLBACK for 20261122100000_door_exits_and_overrides.sql: removes the door's exits, occupancy and overrides. After it the door works exactly as before the migration (door_admit_group()
-- and the scanners were never changed). It DELETES what the migration recorded: every exit, every override and its reason, and the per-event "track exits" switch. Take a copy first if
-- the overrides are wanted for the record:  select * from public.site_door_overrides;
--
-- One transaction: all of it or none of it.
begin;

drop function if exists public.door_club_nights(uuid);
drop function if exists public.door_override_log(uuid);
drop function if exists public.door_override_entry(text, text, int, uuid);
drop function if exists public.door_occupancy(uuid);
drop function if exists public.door_record_exit(text, int, uuid);
drop function if exists public.door_order_in(uuid);
drop function if exists public.set_event_exit_tracking(uuid, boolean);
drop function if exists public.can_manage_door(uuid);

drop table if exists public.site_door_overrides;
drop table if exists public.site_order_exits;
alter table public.site_events drop column if exists track_exits;

commit;
