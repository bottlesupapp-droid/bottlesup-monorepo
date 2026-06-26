-- =============================================================================
-- Admin action support: vendor status column + audit log table
--
-- Run this AFTER 20260614000000_admin_rls.sql (which creates is_admin())
-- Apply in: Supabase Dashboard → SQL Editor → New query
-- =============================================================================

-- ─── VENDORS: add status column ──────────────────────────────────────────────
-- 'active'    → normal operation (default)
-- 'suspended' → blocked by admin, cannot access platform features

ALTER TABLE public.vendors
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active', 'suspended'));

-- ─── ADMIN AUDIT LOG ─────────────────────────────────────────────────────────
-- Every admin write action inserts a row here server-side or via this table.
-- The process-refund edge function also writes here using the service role.

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  action      TEXT        NOT NULL,           -- e.g. 'approve_vendor', 'process_refund'
  target_table TEXT       NOT NULL,           -- e.g. 'vendors', 'events'
  target_id   TEXT        NOT NULL,           -- UUID of the affected row
  before      JSONB,                          -- snapshot before change
  after       JSONB,                          -- snapshot after change
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS admin_audit_log_admin_id_idx  ON public.admin_audit_log (admin_id);
CREATE INDEX IF NOT EXISTS admin_audit_log_action_idx     ON public.admin_audit_log (action);
CREATE INDEX IF NOT EXISTS admin_audit_log_created_at_idx ON public.admin_audit_log (created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Admins can insert their own audit entries
DROP POLICY IF EXISTS "audit_log: admin insert" ON public.admin_audit_log;
CREATE POLICY "audit_log: admin insert" ON public.admin_audit_log
  FOR INSERT TO authenticated
  WITH CHECK (is_admin() AND admin_id = auth.uid());

-- Admins can read the full log
DROP POLICY IF EXISTS "audit_log: admin select" ON public.admin_audit_log;
CREATE POLICY "audit_log: admin select" ON public.admin_audit_log
  FOR SELECT TO authenticated
  USING (is_admin());

-- Service role (used by edge functions) bypasses RLS entirely — no policy needed.
