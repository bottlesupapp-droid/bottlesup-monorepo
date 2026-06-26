-- ============================================================
-- CENTRALIZED TICKET LIFECYCLE
-- Run this once in Supabase SQL Editor (or via CLI: supabase db push)
-- ============================================================

-- 1. Add ticket tracking columns to table_bookings
ALTER TABLE table_bookings
  ADD COLUMN IF NOT EXISTS ticket_code    TEXT,
  ADD COLUMN IF NOT EXISTS qr_code        TEXT,
  ADD COLUMN IF NOT EXISTS checked_in     BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS checked_in_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS checked_in_by  UUID,
  ADD COLUMN IF NOT EXISTS expires_at     TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS idx_table_bookings_ticket_code
  ON table_bookings (ticket_code) WHERE ticket_code IS NOT NULL;

-- 2. Add expires_at to events_bookings
--    (ticket_code, qr_code, checked_in, checked_in_at, checked_in_by assumed to exist)
ALTER TABLE events_bookings
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- ============================================================
-- SECURE TICKET CODE GENERATOR
-- 14-char code: ABCD-EFGH-1234 — unambiguous charset, no 0/O/I/1
-- ============================================================
CREATE OR REPLACE FUNCTION generate_ticket_code()
RETURNS TEXT AS $$
DECLARE
  chars  TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i      INT;
BEGIN
  FOR i IN 1..12 LOOP
    result := result || substr(chars, (floor(random() * length(chars))::int + 1), 1);
    IF i = 4 OR i = 8 THEN
      result := result || '-';
    END IF;
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER: table_bookings — auto-generate ticket code + expiry
-- ============================================================
CREATE OR REPLACE FUNCTION trg_fn_table_booking_ticket()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.ticket_code IS NULL THEN
    NEW.ticket_code := generate_ticket_code();
    NEW.qr_code     := NEW.ticket_code;
  END IF;
  IF NEW.expires_at IS NULL AND NEW.booking_date IS NOT NULL THEN
    NEW.expires_at := (NEW.booking_date::date + INTERVAL '1 day' + INTERVAL '6 hours');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_table_booking_ticket ON table_bookings;
CREATE TRIGGER trg_table_booking_ticket
  BEFORE INSERT ON table_bookings
  FOR EACH ROW EXECUTE FUNCTION trg_fn_table_booking_ticket();

-- ============================================================
-- TRIGGER: events_bookings — auto-generate ticket code + expiry
-- ============================================================
CREATE OR REPLACE FUNCTION trg_fn_events_booking_ticket()
RETURNS TRIGGER AS $$
DECLARE
  ev_date DATE;
BEGIN
  IF NEW.ticket_code IS NULL OR NEW.ticket_code = '' THEN
    NEW.ticket_code := generate_ticket_code();
  END IF;
  IF NEW.qr_code IS NULL OR NEW.qr_code = '' THEN
    NEW.qr_code := NEW.ticket_code;
  END IF;
  IF NEW.expires_at IS NULL THEN
    SELECT event_date INTO ev_date FROM events WHERE id = NEW.event_id;
    IF ev_date IS NOT NULL THEN
      NEW.expires_at := (ev_date + INTERVAL '1 day' + INTERVAL '6 hours');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_events_booking_ticket ON events_bookings;
CREATE TRIGGER trg_events_booking_ticket
  BEFORE INSERT ON events_bookings
  FOR EACH ROW EXECUTE FUNCTION trg_fn_events_booking_ticket();

-- ============================================================
-- EXPIRE TICKETS — call this from Supabase pg_cron or client
-- Schedule: SELECT cron.schedule('expire-tickets', '0 * * * *', 'SELECT expire_past_tickets()');
-- ============================================================
CREATE OR REPLACE FUNCTION expire_past_tickets()
RETURNS void AS $$
BEGIN
  UPDATE events_bookings
  SET status = 'expired', updated_at = now()
  WHERE expires_at < now()
    AND status NOT IN ('cancelled', 'refunded', 'expired', 'checkedIn');

  UPDATE table_bookings
  SET status = 'expired', updated_at = now()
  WHERE expires_at < now()
    AND status NOT IN ('cancelled', 'expired');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- BACKFILL existing table_bookings with ticket codes
-- ============================================================
DO $$
DECLARE
  r        RECORD;
  new_code TEXT;
BEGIN
  FOR r IN SELECT id, booking_date FROM table_bookings WHERE ticket_code IS NULL LOOP
    LOOP
      new_code := generate_ticket_code();
      EXIT WHEN NOT EXISTS (SELECT 1 FROM table_bookings WHERE ticket_code = new_code);
    END LOOP;
    UPDATE table_bookings
    SET ticket_code = new_code,
        qr_code     = new_code,
        expires_at  = CASE
          WHEN r.booking_date IS NOT NULL
          THEN (r.booking_date::date + INTERVAL '1 day' + INTERVAL '6 hours')
          ELSE NULL
        END
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- BACKFILL expires_at for existing events_bookings
UPDATE events_bookings eb
SET expires_at = (e.event_date + INTERVAL '1 day' + INTERVAL '6 hours')
FROM events e
WHERE eb.event_id = e.id
  AND eb.expires_at IS NULL
  AND e.event_date IS NOT NULL;
