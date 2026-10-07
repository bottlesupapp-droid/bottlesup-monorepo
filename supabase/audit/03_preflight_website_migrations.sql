-- Pre-flight for the website migrations 20261006120000 .. 20261011100000 and the two 20260830 fixes.
--
-- READ ONLY. One SELECT, nothing is created, changed or locked. Run it in the PRODUCTION SQL editor (and, when a staging
-- project exists, there too) BEFORE applying any of those migrations, and send back the result.
--
-- It answers, from the migration files themselves (this file is generated from them):
--   1. Would any migration collide with something that already exists? (They use plain CREATE on purpose, so a collision
--      stops the migration; this tells you first.)  -> rows marked STOP
--   2. Is everything they build on there, with the columns the committed migrations say production has?  -> STOP / WARN
--   3. What state are the two LIVE functions the fix migrations replace in (checkin_ticket, verify_ticket_otp)?
--        OLD            the fix will apply
--        ALREADY FIXED  the migration does nothing
--        DIFFERENT      the migration will STOP and change nothing; send the function text (\sf public.<name>)
--   4. Would re-adding scan_attempts_result_check reject rows that are already there?
--
-- The last column of the first row says OK when there is no STOP row. Anything marked STOP means: do not apply yet.
-- Generated 6 migrations: 67 functions, 8 tables, 14 policies, 4 triggers, 12 indexes, 10 new columns.
with
exp_cols(tbl, col, typ) as (values
    ('audit_log', 'id', 'uuid'),
    ('audit_log', 'actor_id', 'uuid'),
    ('audit_log', 'actor_email', 'text'),
    ('audit_log', 'action', 'text'),
    ('audit_log', 'entity_type', 'text'),
    ('audit_log', 'entity_id', 'text'),
    ('audit_log', 'details', 'jsonb'),
    ('audit_log', 'created_at', 'timestamp with time zone'),
    ('cms_admins', 'id', 'uuid'),
    ('cms_admins', 'email', 'text'),
    ('cms_admins', 'created_at', 'timestamp with time zone'),
    ('door_staff', 'id', 'uuid'),
    ('door_staff', 'email', 'text'),
    ('door_staff', 'created_at', 'timestamp with time zone'),
    ('partner_accounts', 'id', 'uuid'),
    ('partner_accounts', 'user_type', 'text'),
    ('partner_accounts', 'legal_name', 'text'),
    ('partner_accounts', 'date_of_birth', 'date'),
    ('partner_accounts', 'onboarding_step', 'integer'),
    ('partner_accounts', 'onboarding_status', 'text'),
    ('partner_accounts', 'created_at', 'timestamp with time zone'),
    ('partner_accounts', 'updated_at', 'timestamp with time zone'),
    ('partner_leads', 'id', 'uuid'),
    ('partner_leads', 'email', 'text'),
    ('partner_leads', 'venue_name', 'text'),
    ('partner_leads', 'created_at', 'timestamp with time zone'),
    ('profiles', 'id', 'uuid'),
    ('profiles', 'name', 'text'),
    ('profiles', 'email', 'text'),
    ('profiles', 'phone_number', 'text'),
    ('profiles', 'age', 'integer'),
    ('profiles', 'avatar_url', 'text'),
    ('profiles', 'verified', 'boolean'),
    ('scan_attempts', 'id', 'uuid'),
    ('scan_attempts', 'ticket_code_attempted', 'text'),
    ('scan_attempts', 'result', 'text'),
    ('scan_attempts', 'order_id', 'uuid'),
    ('scan_attempts', 'scanned_by', 'uuid'),
    ('scan_attempts', 'created_at', 'timestamp with time zone'),
    ('scan_attempts', 'booking_id', 'uuid'),
    ('site_bottles', 'id', 'uuid'),
    ('site_bottles', 'venue_id', 'uuid'),
    ('site_bottles', 'name', 'text'),
    ('site_bottles', 'size', 'text'),
    ('site_bottles', 'description', 'text'),
    ('site_bottles', 'price_cents', 'integer'),
    ('site_bottles', 'currency', 'text'),
    ('site_bottles', 'category', 'text'),
    ('site_bottles', 'image_url', 'text'),
    ('site_bottles', 'is_available', 'boolean'),
    ('site_bottles', 'is_sold_out', 'boolean'),
    ('site_bottles', 'stock_quantity', 'integer'),
    ('site_bottles', 'sort_order', 'integer'),
    ('site_bottles', 'created_at', 'timestamp with time zone'),
    ('site_bottles', 'updated_at', 'timestamp with time zone'),
    ('site_content', 'id', 'integer'),
    ('site_content', 'contact_email', 'text'),
    ('site_content', 'contact_phone', 'text'),
    ('site_content', 'address', 'text'),
    ('site_content', 'social_instagram', 'text'),
    ('site_content', 'social_twitter', 'text'),
    ('site_content', 'social_facebook', 'text'),
    ('site_content', 'social_linkedin', 'text'),
    ('site_content', 'footer_tagline', 'text'),
    ('site_content', 'hero_headline', 'text'),
    ('site_content', 'hero_subtext', 'text'),
    ('site_content', 'updated_at', 'timestamp with time zone'),
    ('site_content', 'payments_mode', 'text'),
    ('site_content', 'bottlesup_fee_bps', 'integer'),
    ('site_events', 'id', 'uuid'),
    ('site_events', 'title', 'text'),
    ('site_events', 'description', 'text'),
    ('site_events', 'venue_name', 'text'),
    ('site_events', 'address', 'text'),
    ('site_events', 'start_date', 'timestamp with time zone'),
    ('site_events', 'end_date', 'timestamp with time zone'),
    ('site_events', 'cover_image_url', 'text'),
    ('site_events', 'gallery', 'ARRAY'),
    ('site_events', 'category', 'text'),
    ('site_events', 'status', 'text'),
    ('site_events', 'capacity', 'integer'),
    ('site_events', 'created_at', 'timestamp with time zone'),
    ('site_events', 'updated_at', 'timestamp with time zone'),
    ('site_events', 'slug', 'text'),
    ('site_events', 'banner_image_url', 'text'),
    ('site_events', 'lineup', 'jsonb'),
    ('site_events', 'good_to_know', 'ARRAY'),
    ('site_events', 'organizer_name', 'text'),
    ('site_events', 'organizer_bio', 'text'),
    ('site_events', 'organizer_verified', 'boolean'),
    ('site_events', 'organizer_instagram', 'text'),
    ('site_events', 'organizer_email', 'text'),
    ('site_events', 'organizer_avatar_url', 'text'),
    ('site_orders', 'id', 'uuid'),
    ('site_orders', 'event_id', 'uuid'),
    ('site_orders', 'tier_id', 'uuid'),
    ('site_orders', 'customer_name', 'text'),
    ('site_orders', 'customer_email', 'text'),
    ('site_orders', 'customer_phone', 'text'),
    ('site_orders', 'quantity', 'integer'),
    ('site_orders', 'amount_total_cents', 'integer'),
    ('site_orders', 'currency', 'text'),
    ('site_orders', 'stripe_checkout_session_id', 'text'),
    ('site_orders', 'stripe_payment_intent_id', 'text'),
    ('site_orders', 'status', 'text'),
    ('site_orders', 'ticket_code', 'text'),
    ('site_orders', 'ticket_sent_at', 'timestamp with time zone'),
    ('site_orders', 'created_at', 'timestamp with time zone'),
    ('site_orders', 'updated_at', 'timestamp with time zone'),
    ('site_orders', 'checked_in_at', 'timestamp with time zone'),
    ('site_orders', 'checked_in_by', 'uuid'),
    ('site_orders', 'is_non_transferable', 'boolean'),
    ('site_orders', 'access_code_verified', 'boolean'),
    ('site_orders', 'access_code_verified_at', 'timestamp with time zone'),
    ('site_table_booking_bottles', 'id', 'uuid'),
    ('site_table_booking_bottles', 'booking_id', 'uuid'),
    ('site_table_booking_bottles', 'bottle_id', 'uuid'),
    ('site_table_booking_bottles', 'bottle_name', 'text'),
    ('site_table_booking_bottles', 'size', 'text'),
    ('site_table_booking_bottles', 'unit_price_cents', 'integer'),
    ('site_table_booking_bottles', 'quantity', 'integer'),
    ('site_table_booking_bottles', 'line_total_cents', 'integer'),
    ('site_table_booking_bottles', 'created_at', 'timestamp with time zone'),
    ('site_table_bookings', 'id', 'uuid'),
    ('site_table_bookings', 'venue_id', 'uuid'),
    ('site_table_bookings', 'table_type_id', 'uuid'),
    ('site_table_bookings', 'time_slot_id', 'uuid'),
    ('site_table_bookings', 'booking_date', 'date'),
    ('site_table_bookings', 'customer_name', 'text'),
    ('site_table_bookings', 'customer_email', 'text'),
    ('site_table_bookings', 'customer_phone', 'text'),
    ('site_table_bookings', 'guest_count', 'integer'),
    ('site_table_bookings', 'amount_total_cents', 'integer'),
    ('site_table_bookings', 'currency', 'text'),
    ('site_table_bookings', 'stripe_checkout_session_id', 'text'),
    ('site_table_bookings', 'stripe_payment_intent_id', 'text'),
    ('site_table_bookings', 'status', 'text'),
    ('site_table_bookings', 'confirmation_code', 'text'),
    ('site_table_bookings', 'confirmation_sent_at', 'timestamp with time zone'),
    ('site_table_bookings', 'checked_in_at', 'timestamp with time zone'),
    ('site_table_bookings', 'checked_in_by', 'uuid'),
    ('site_table_bookings', 'created_at', 'timestamp with time zone'),
    ('site_table_bookings', 'updated_at', 'timestamp with time zone'),
    ('site_table_bookings', 'hours', 'integer'),
    ('site_table_bookings', 'deposit_cents', 'integer'),
    ('site_table_bookings', 'bottle_subtotal_cents', 'integer'),
    ('site_table_bookings', 'tax_cents', 'integer'),
    ('site_table_bookings', 'bottlesup_fee_cents', 'integer'),
    ('site_table_bookings', 'fulfillment_status', 'text'),
    ('site_table_bookings', 'bottle_sign_text', 'text'),
    ('site_table_types', 'id', 'uuid'),
    ('site_table_types', 'venue_id', 'uuid'),
    ('site_table_types', 'name', 'text'),
    ('site_table_types', 'description', 'text'),
    ('site_table_types', 'max_guests', 'integer'),
    ('site_table_types', 'min_spend_cents', 'integer'),
    ('site_table_types', 'deposit_cents', 'integer'),
    ('site_table_types', 'currency', 'text'),
    ('site_table_types', 'inventory_count', 'integer'),
    ('site_table_types', 'image_url', 'text'),
    ('site_table_types', 'sort_order', 'integer'),
    ('site_table_types', 'created_at', 'timestamp with time zone'),
    ('site_table_types', 'updated_at', 'timestamp with time zone'),
    ('site_table_types', 'badge_label', 'text'),
    ('site_table_types', 'is_featured', 'boolean'),
    ('site_table_types', 'floor_id', 'uuid'),
    ('site_table_types', 'pos_x', 'numeric'),
    ('site_table_types', 'pos_y', 'numeric'),
    ('site_table_types', 'width', 'numeric'),
    ('site_table_types', 'height', 'numeric'),
    ('site_table_types', 'min_guests', 'integer'),
    ('site_table_types', 'pricing_mode', 'text'),
    ('site_table_types', 'hourly_rate_cents', 'integer'),
    ('site_table_types', 'min_hours', 'integer'),
    ('site_ticket_tiers', 'id', 'uuid'),
    ('site_ticket_tiers', 'event_id', 'uuid'),
    ('site_ticket_tiers', 'name', 'text'),
    ('site_ticket_tiers', 'price_cents', 'integer'),
    ('site_ticket_tiers', 'currency', 'text'),
    ('site_ticket_tiers', 'capacity', 'integer'),
    ('site_ticket_tiers', 'sold_count', 'integer'),
    ('site_ticket_tiers', 'created_at', 'timestamp with time zone'),
    ('site_ticket_tiers', 'updated_at', 'timestamp with time zone'),
    ('site_ticket_tiers', 'requires_access_code', 'boolean'),
    ('site_ticket_tiers', 'is_non_transferable', 'boolean'),
    ('site_venue_floors', 'id', 'uuid'),
    ('site_venue_floors', 'venue_id', 'uuid'),
    ('site_venue_floors', 'label', 'text'),
    ('site_venue_floors', 'image_url', 'text'),
    ('site_venue_floors', 'sort_order', 'integer'),
    ('site_venue_floors', 'created_at', 'timestamp with time zone'),
    ('site_venue_floors', 'updated_at', 'timestamp with time zone'),
    ('site_venue_time_slots', 'id', 'uuid'),
    ('site_venue_time_slots', 'venue_id', 'uuid'),
    ('site_venue_time_slots', 'day_of_week', 'integer'),
    ('site_venue_time_slots', 'start_time', 'time without time zone'),
    ('site_venue_time_slots', 'label', 'text'),
    ('site_venue_time_slots', 'created_at', 'timestamp with time zone'),
    ('site_venues', 'id', 'uuid'),
    ('site_venues', 'name', 'text'),
    ('site_venues', 'slug', 'text'),
    ('site_venues', 'description', 'text'),
    ('site_venues', 'address', 'text'),
    ('site_venues', 'cover_image_url', 'text'),
    ('site_venues', 'gallery', 'ARRAY'),
    ('site_venues', 'status', 'text'),
    ('site_venues', 'created_at', 'timestamp with time zone'),
    ('site_venues', 'updated_at', 'timestamp with time zone'),
    ('site_venues', 'booking_start_date', 'date'),
    ('site_venues', 'booking_end_date', 'date'),
    ('site_venues', 'tax_rate_bps', 'integer'),
    ('site_venues', 'show_bottle_images', 'boolean'),
    ('ticket_otp_codes', 'id', 'uuid'),
    ('ticket_otp_codes', 'order_id', 'uuid'),
    ('ticket_otp_codes', 'code_hash', 'text'),
    ('ticket_otp_codes', 'status', 'text'),
    ('ticket_otp_codes', 'sent_to_email', 'text'),
    ('ticket_otp_codes', 'attempts', 'integer'),
    ('ticket_otp_codes', 'max_attempts', 'integer'),
    ('ticket_otp_codes', 'created_at', 'timestamp with time zone'),
    ('ticket_otp_codes', 'expires_at', 'timestamp with time zone'),
    ('ticket_otp_codes', 'verified_at', 'timestamp with time zone'),
    ('ticket_otp_codes', 'verified_by', 'uuid'),
    ('ticket_tier_access_codes', 'id', 'uuid'),
    ('ticket_tier_access_codes', 'tier_id', 'uuid'),
    ('ticket_tier_access_codes', 'code_hash', 'text'),
    ('ticket_tier_access_codes', 'created_at', 'timestamp with time zone'),
    ('ticket_tier_access_codes', 'updated_at', 'timestamp with time zone'),
    ('vip_emails', 'id', 'uuid'),
    ('vip_emails', 'email', 'text'),
    ('vip_emails', 'first_name', 'text'),
    ('vip_emails', 'last_name', 'text'),
    ('vip_emails', 'source', 'text'),
    ('vip_emails', 'mailchimp_synced', 'boolean'),
    ('vip_emails', 'created_at', 'timestamp with time zone')),
new_funcs(name) as (values
    ('active_memberships'),
    ('is_org_member'),
    ('can_access_venue'),
    ('can_access_event'),
    ('can_view_membership'),
    ('can_invite_role'),
    ('create_organization'),
    ('create_org_venue'),
    ('create_shift'),
    ('invite_member'),
    ('resend_invitation'),
    ('revoke_invitation'),
    ('accept_invitation'),
    ('revoke_membership'),
    ('my_workspaces'),
    ('my_venues'),
    ('list_invitations'),
    ('clean_social_links'),
    ('username_available'),
    ('save_my_profile'),
    ('site_org_after_insert'),
    ('verification_missing'),
    ('save_business_details'),
    ('submit_verification'),
    ('review_verification'),
    ('my_businesses'),
    ('search_venues'),
    ('request_venue_claim'),
    ('review_venue_claim'),
    ('update_venue_profile'),
    ('venue_setup_status'),
    ('list_venue_claims'),
    ('admin_verification_queue'),
    ('admin_venue_claims'),
    ('business_media_org'),
    ('invitable_roles'),
    ('list_team'),
    ('list_team_invitations'),
    ('list_shifts'),
    ('reserve_invitation_email'),
    ('has_door_role'),
    ('can_scan_event'),
    ('door_events'),
    ('door_scan_ticket'),
    ('door_verify_ticket_code'),
    ('door_guests'),
    ('require_venue_editor'),
    ('venue_setup_log'),
    ('setup_only_keys'),
    ('setup_int'),
    ('setup_text'),
    ('setup_url'),
    ('setup_bool'),
    ('list_venue_time_slots'),
    ('add_venue_time_slot'),
    ('remove_venue_time_slot'),
    ('list_venue_floors'),
    ('save_venue_floor'),
    ('remove_venue_floor'),
    ('list_venue_table_types'),
    ('save_venue_table_type'),
    ('remove_venue_table_type'),
    ('list_venue_bottles'),
    ('save_venue_bottle'),
    ('remove_venue_bottle'),
    ('booking_night'),
    ('list_venue_bookings')),
new_tables(name) as (values
    ('site_organizations'),
    ('site_shifts'),
    ('site_memberships'),
    ('site_invitations'),
    ('site_business_profiles'),
    ('site_verifications'),
    ('site_verification_events'),
    ('site_venue_claims')),
new_policies(tbl, pol) as (values
    ('public.site_organizations', 'members read their organizations'),
    ('public.site_memberships', 'read own or managed memberships'),
    ('public.site_invitations', 'read invitations you can manage'),
    ('public.site_shifts', 'read shifts for venues you can reach'),
    ('public.site_venues', 'members read their venues'),
    ('public.site_events', 'members read their events'),
    ('storage.objects', 'public read business media'),
    ('storage.objects', 'members add business media'),
    ('storage.objects', 'owners replace business media'),
    ('storage.objects', 'owners delete business media'),
    ('public.site_business_profiles', 'business members read their details'),
    ('public.site_verifications', 'business members read their verification'),
    ('public.site_verification_events', 'business members read their verification history'),
    ('public.site_venue_claims', 'owners read their venue requests')),
new_triggers(tbl, trg) as (values
    ('public.site_organizations', 'site_organizations_set_updated_at'),
    ('public.site_business_profiles', 'site_business_profiles_set_updated_at'),
    ('public.site_verifications', 'site_verifications_set_updated_at'),
    ('public.site_organizations', 'site_organizations_after_insert')),
new_indexes(name) as (values
    ('site_venues_org_id_idx'),
    ('site_events_org_id_idx'),
    ('site_shifts_venue_id_idx'),
    ('site_memberships_user_id_idx'),
    ('site_memberships_org_id_idx'),
    ('site_memberships_one_active_per_scope'),
    ('site_invitations_token_hash_idx'),
    ('site_invitations_org_id_idx'),
    ('profiles_username_unique'),
    ('site_verification_events_org_idx'),
    ('site_venue_claims_one_pending'),
    ('site_venue_claims_venue_idx')),
new_cols(tbl, col, ine) as (values
    ('public.site_venues', 'org_id', 'no'),
    ('public.site_events', 'org_id', 'no'),
    ('public.profiles', 'username', 'no'),
    ('public.profiles', 'bio', 'no'),
    ('public.profiles', 'city', 'no'),
    ('public.profiles', 'social_links', 'no'),
    ('public.profiles', 'profile_completed_at', 'no'),
    ('public.site_invitations', 'email_token_hash', 'no'),
    ('public.site_invitations', 'email_sent_at', 'no'),
    ('public.site_invitations', 'email_send_count', 'no'),
    ('public.site_events', 'venue_id', 'yes')),
need_tables(name) as (values
    ('audit_log'),
    ('profiles'),
    ('scan_attempts'),
    ('site_bottles'),
    ('site_events'),
    ('site_orders'),
    ('site_table_bookings'),
    ('site_table_types'),
    ('site_ticket_tiers'),
    ('site_venue_floors'),
    ('site_venue_time_slots'),
    ('site_venues'),
    ('ticket_otp_codes')),
need_funcs(name) as (values
    ('is_cms_admin'),
    ('set_updated_at')),
fixes(fn, args, c_before, c_after) as (values
    ('checkin_ticket', 'p_ticket_code text', '553484477fdc48844c3595be7cd1543f', '28d05a7c0699859b4d97f3e6fed6effd'),
    ('verify_ticket_otp', 'p_ticket_code text, p_code text', '842493fc4bcab29b5acfc94775929bad', 'c109bccac3091ce5bdf9dcec1a4f7f7f')),
live_fns as (
  select f.fn, f.c_before, f.c_after, p.oid,
         md5(btrim(regexp_replace(p.prosrc, '\s+', ' ', 'g')) || '|' || p.prosecdef::text || '|' || coalesce(p.proconfig::text, '')) as live
  from fixes f
  left join pg_proc p on p.proname = f.fn and p.pronamespace = 'public'::regnamespace
                      and pg_get_function_identity_arguments(p.oid) = f.args
),
checks as (
  -- 1. collisions
  select 'STOP' sev, 'already exists: function' chk, n.name item, 'plain CREATE FUNCTION would fail' detail
    from new_funcs n where exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n.name)
  union all
  select 'STOP', 'already exists: table', n.name, 'plain CREATE TABLE would fail'
    from new_tables n where exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = n.name)
  union all
  select 'STOP', 'already exists: policy', n.tbl || ' / ' || n.pol, 'CREATE POLICY would fail'
    from new_policies n where exists (select 1 from pg_policies p where p.schemaname || '.' || p.tablename = n.tbl and p.policyname = n.pol)
  union all
  select 'STOP', 'already exists: trigger', n.tbl || ' / ' || n.trg, 'CREATE TRIGGER would fail'
    from new_triggers n where exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace s on s.oid = c.relnamespace
                                      where not t.tgisinternal and t.tgname = n.trg and s.nspname || '.' || c.relname = n.tbl)
  union all
  select 'STOP', 'already exists: index', n.name, 'CREATE INDEX would fail'
    from new_indexes n where exists (select 1 from pg_indexes i where i.schemaname = 'public' and i.indexname = n.name)
  union all
  select case when n.ine = 'yes' then 'INFO' else 'STOP' end, 'column already exists', n.tbl || '.' || n.col,
         case when n.ine = 'yes' then 'fine: the migration says IF NOT EXISTS' else 'ADD COLUMN would fail' end
    from new_cols n where exists (select 1 from information_schema.columns c where 'public.' || c.table_name = n.tbl and c.column_name = n.col)
  union all
  select 'WARN', 'storage bucket already exists with other settings', b.id,
         'bucket exists with public=' || b.public || ', size limit ' || coalesce(b.file_size_limit::text, 'none') || ', types ' || coalesce(b.allowed_mime_types::text, 'any') || ' (the migration keeps it as it is)'
    from storage.buckets b where b.id = 'business-media' and (b.public is not true or b.file_size_limit is distinct from 5242880)
  -- 2. prerequisites
  union all
  select 'STOP', 'missing table', n.name, 'the migrations read or reference it'
    from need_tables n where not exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = n.name and c.relkind in ('r', 'p'))
  union all
  select 'STOP', 'missing function', n.name || '()', 'the migrations call it'
    from need_funcs n where not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n.name)
  union all
  select 'STOP', 'missing column', e.tbl || '.' || e.col, 'the committed migrations define it, so production should have it'
    from exp_cols e
    where exists (select 1 from need_tables n where n.name = e.tbl)
      and exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = e.tbl)
      and not exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = e.tbl and c.column_name = e.col)
  union all
  select 'WARN', 'column has a different type', e.tbl || '.' || e.col, 'expected ' || e.typ || ', production has ' || c.data_type
    from exp_cols e join information_schema.columns c on c.table_schema = 'public' and c.table_name = e.tbl and c.column_name = e.col
    where exists (select 1 from need_tables n where n.name = e.tbl) and c.data_type <> e.typ
  -- 3. the two live functions the fix migrations replace
  union all
  select case when l.oid is null then 'STOP' when l.live in (l.c_before, l.c_after) then 'INFO' else 'STOP' end,
         'live function state', l.fn,
         case when l.oid is null then 'MISSING: the fix migration will stop'
              when l.live = l.c_after then 'ALREADY FIXED: the migration will do nothing'
              when l.live = l.c_before then 'OLD: the fix will apply'
              else 'DIFFERENT: the migration will STOP and change nothing. Send the output of \sf public.' || l.fn || ' (fingerprint ' || l.live || ')' end
    from live_fns l
  -- 4. the constraint the door scanner migration replaces
  union all
  select 'INFO', 'current scan_attempts_result_check', coalesce(pg_get_constraintdef(c.oid), 'none'), 'the door scanner migration drops and re-adds it with ten allowed results'
    from (select 1) one left join pg_constraint c on c.conname = 'scan_attempts_result_check' and c.conrelid = 'public.scan_attempts'::regclass
  union all
  select 'STOP', 'scan_attempts rows the new constraint would reject', coalesce(s.result, '(null)'), s.n || ' rows: the door scanner migration would fail'
    from (select result, count(*) n from public.scan_attempts
          where result is null or result not in ('ok', 'already_checked_in', 'not_paid', 'not_found', 'expired', 'code_required', 'code_incorrect', 'code_expired', 'no_code_requested', 'wrong_event') group by result) s
  -- environment
  union all
  select 'INFO', 'server', 'postgres', version()
  union all
  select 'INFO', 'extensions', e.extname, e.extversion from pg_extension e where e.extname in ('pgcrypto', 'pg_net', 'uuid-ossp')
)
select sev as severity, chk as "check", item, detail from (
  select 0 ord, case when exists (select 1 from checks where sev = 'STOP') then 'STOP' else 'OK' end sev, 'summary' chk,
         (select count(*) from checks where sev = 'STOP')::text || ' blocking finding(s)' item,
         case when exists (select 1 from checks where sev = 'STOP') then 'do not apply the migrations yet; send this result back' else 'no collisions, nothing missing; read the live function rows below for the two fixes' end detail
  union all
  select case sev when 'STOP' then 1 when 'WARN' then 2 else 3 end, sev, chk, item, detail from checks
) r order by ord, chk, item;
