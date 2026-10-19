-- ROLLBACK for the Phase 2 module migrations 20261018100000 .. 20261018200000 (cash/flags, seating + outbox, chat, security, close night + reports,
-- inventory, VIP, change role, agreements, organizer guests, owner money). Every one of them only ADDED objects, so this only drops what they added:
-- it touches no table, column or function that existed before them. Run it in ONE transaction. IT DELETES THE DATA those modules recorded (chats,
-- alerts, incident reports, closed nights, stock history, VIP lists, agreements...). Export anything you want to keep first.
--
-- Not needed for a failed apply: each migration is applied in its own transaction, so a failure leaves nothing behind.
begin;

-- 1. Functions, newest migration first. Every overload of each name that the migrations created.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any (array[
      'owner_money',
      'organizer_guests',
      'organizer_guest_summary',
      'agreement_detail',
      'agreement_list',
      'agreement_close',
      'agreement_note',
      'agreement_accept',
      'agreement_propose',
      'agreement_request',
      'agreement_sample',
      'agreement_check_terms',
      'agreement_percent',
      'agreement_side',
      'change_member_role',
      'vip_redeem',
      'vip_lookup',
      'vip_invite',
      'vip_detail',
      'vip_list',
      'vip_end_perk',
      'vip_add_perk',
      'vip_reinstate',
      'vip_end',
      'vip_update',
      'vip_add',
      'vip_new_code',
      'vip_date',
      'vip_status',
      'stock_movements',
      'stock_set_threshold',
      'stock_move',
      'stock_list',
      'night_report',
      'reopen_night',
      'close_night',
      'night_close_status',
      'night_check',
      'night_checklist',
      'night_report_data',
      'night_blockers',
      'night_booking_ids',
      'night_checklist_items',
      'security_summary',
      'security_review_incident',
      'security_incident_note',
      'security_incident_detail',
      'security_incidents',
      'security_report_incident',
      'security_task_act',
      'security_tasks',
      'security_create_task',
      'security_alert_act',
      'security_alerts',
      'security_raise_alert',
      'security_has_role',
      'chat_purge_expired',
      'chat_start_direct',
      'chat_people',
      'chat_pin',
      'chat_mark_read',
      'chat_send',
      'chat_messages',
      'chat_conversations',
      'chat_user_at_venue',
      'chat_can_access',
      'desk_booking_messages',
      'desk_booking_seating',
      'desk_unseat',
      'desk_set_estimate',
      'desk_mark_seated',
      'desk_find_booking',
      'desk_enqueue',
      'desk_verifier_summary',
      'desk_list_flags',
      'desk_resolve_flag',
      'desk_flag_payment',
      'desk_receive_handover',
      'desk_list_handovers',
      'desk_submit_handover',
      'desk_cash_position',
      'desk_cash_rows',
      'desk_cash_part'
    ])
  loop
    execute 'drop function ' || r.sig;
  end loop;
end $$;

-- 2. Tables, children before parents. (CASCADE only follows the foreign keys between these new tables and their own policies.)
drop table if exists public.site_agreement_notes cascade;
drop table if exists public.site_agreement_versions cascade;
drop table if exists public.site_agreements cascade;
drop table if exists public.site_vip_redemptions cascade;
drop table if exists public.site_vip_perks cascade;
drop table if exists public.site_vip_members cascade;
drop table if exists public.site_stock_thresholds cascade;
drop table if exists public.site_stock_movements cascade;
drop table if exists public.site_night_closes cascade;
drop table if exists public.site_night_checks cascade;
drop table if exists public.site_security_incident_notes cascade;
drop table if exists public.site_security_incidents cascade;
drop table if exists public.site_security_tasks cascade;
drop table if exists public.site_security_alerts cascade;
drop table if exists public.site_chat_reads cascade;
drop table if exists public.site_chat_messages cascade;
drop table if exists public.site_chat_direct_members cascade;
drop table if exists public.site_chat_conversations cascade;
drop table if exists public.site_outbox cascade;
drop table if exists public.site_booking_seating cascade;
drop table if exists public.site_payment_flags cascade;
drop table if exists public.site_cash_handovers cascade;

-- 3. Make sure nothing is left behind.
do $$
declare n int;
begin
  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace where ns.nspname = 'public' and p.proname = any (array[
      'owner_money',
      'organizer_guests',
      'organizer_guest_summary',
      'agreement_detail',
      'agreement_list',
      'agreement_close',
      'agreement_note',
      'agreement_accept',
      'agreement_propose',
      'agreement_request',
      'agreement_sample',
      'agreement_check_terms',
      'agreement_percent',
      'agreement_side',
      'change_member_role',
      'vip_redeem',
      'vip_lookup',
      'vip_invite',
      'vip_detail',
      'vip_list',
      'vip_end_perk',
      'vip_add_perk',
      'vip_reinstate',
      'vip_end',
      'vip_update',
      'vip_add',
      'vip_new_code',
      'vip_date',
      'vip_status',
      'stock_movements',
      'stock_set_threshold',
      'stock_move',
      'stock_list',
      'night_report',
      'reopen_night',
      'close_night',
      'night_close_status',
      'night_check',
      'night_checklist',
      'night_report_data',
      'night_blockers',
      'night_booking_ids',
      'night_checklist_items',
      'security_summary',
      'security_review_incident',
      'security_incident_note',
      'security_incident_detail',
      'security_incidents',
      'security_report_incident',
      'security_task_act',
      'security_tasks',
      'security_create_task',
      'security_alert_act',
      'security_alerts',
      'security_raise_alert',
      'security_has_role',
      'chat_purge_expired',
      'chat_start_direct',
      'chat_people',
      'chat_pin',
      'chat_mark_read',
      'chat_send',
      'chat_messages',
      'chat_conversations',
      'chat_user_at_venue',
      'chat_can_access',
      'desk_booking_messages',
      'desk_booking_seating',
      'desk_unseat',
      'desk_set_estimate',
      'desk_mark_seated',
      'desk_find_booking',
      'desk_enqueue',
      'desk_verifier_summary',
      'desk_list_flags',
      'desk_resolve_flag',
      'desk_flag_payment',
      'desk_receive_handover',
      'desk_list_handovers',
      'desk_submit_handover',
      'desk_cash_position',
      'desk_cash_rows',
      'desk_cash_part'
  ]);
  if n > 0 then raise exception 'rollback incomplete: % functions remain', n; end if;
  select count(*) into n from pg_class c join pg_namespace ns on ns.oid = c.relnamespace where ns.nspname = 'public' and c.relkind = 'r' and c.relname = any (array[
      'site_agreement_notes',
      'site_agreement_versions',
      'site_agreements',
      'site_vip_redemptions',
      'site_vip_perks',
      'site_vip_members',
      'site_stock_thresholds',
      'site_stock_movements',
      'site_night_closes',
      'site_night_checks',
      'site_security_incident_notes',
      'site_security_incidents',
      'site_security_tasks',
      'site_security_alerts',
      'site_chat_reads',
      'site_chat_messages',
      'site_chat_direct_members',
      'site_chat_conversations',
      'site_outbox',
      'site_booking_seating',
      'site_payment_flags',
      'site_cash_handovers'
  ]);
  if n > 0 then raise exception 'rollback incomplete: % tables remain', n; end if;
end $$;

commit;
