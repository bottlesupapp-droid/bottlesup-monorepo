-- =============================================================================
-- Admin-only RLS enforcement for the Bottles Up admin dashboard
--
-- APPLY: paste into Supabase SQL Editor (Dashboard → SQL Editor → New query)
--        or run via: supabase db push
--
-- HOW IT WORKS
--   1. is_admin() is a SECURITY DEFINER function so it can read the vendors
--      table even while RLS is active on that table (no infinite recursion).
--   2. Every table gets RLS enabled and a single admin-full-access policy.
--   3. vendors gets an additional "read own row" policy so the client-side
--      role check in AuthContext can still resolve role='admin' for the
--      current user without needing service-role privileges.
--
-- CREATING NEW ADMINS (no self-registration allowed)
--   Option A — Supabase Dashboard:
--     1. Invite the user via Authentication → Users → Invite user
--     2. INSERT INTO public.vendors (id, email, name, role)
--          VALUES ('<auth-uid>', '<email>', '<name>', 'admin');
--   Option B — service-role API (server-side only, never expose the key):
--     supabase.auth.admin.createUser({ email, password })
--     then INSERT INTO vendors with role='admin'
-- =============================================================================

-- ─── HELPER: is_admin() ──────────────────────────────────────────────────────
-- Returns true when the calling JWT's uid has a row in vendor_admins.
-- SECURITY DEFINER + SET search_path prevents search-path hijacking.
-- vendor_admins is the dedicated platform-admin identity table (separate from
-- vendors which stores vendor business roles: staff/promoter/venue_owner/organizer).
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.vendor_admins
    WHERE id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ─── VENDOR_ADMINS ───────────────────────────────────────────────────────────
-- RLS is already enabled; this adds the only policy needed: admins can read
-- their own row so the client can verify its own admin status without a
-- service-role key. is_admin() (SECURITY DEFINER) handles server-side checks.
DROP POLICY IF EXISTS "vendor_admins: read own row" ON public.vendor_admins;
CREATE POLICY "vendor_admins: read own row" ON public.vendor_admins
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- ─── VENDORS ─────────────────────────────────────────────────────────────────
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can SELECT their own row so the client can verify
-- their own role without a service-role key.
DROP POLICY IF EXISTS "vendors: read own row" ON public.vendors;
CREATE POLICY "vendors: read own row" ON public.vendors
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Admins have unrestricted access to all rows (supersedes the SELECT-only policy
-- via OR semantics — multiple policies for the same command are OR'd together).
DROP POLICY IF EXISTS "vendors: admin full access" ON public.vendors;
CREATE POLICY "vendors: admin full access" ON public.vendors
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── PROFILES ────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles: admin full access" ON public.profiles;
CREATE POLICY "profiles: admin full access" ON public.profiles
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── CLUBS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clubs: admin full access" ON public.clubs;
CREATE POLICY "clubs: admin full access" ON public.clubs
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── EVENTS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events: admin full access" ON public.events;
CREATE POLICY "events: admin full access" ON public.events
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── CLUBS_BOOKINGS ──────────────────────────────────────────────────────────
ALTER TABLE public.clubs_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clubs_bookings: admin full access" ON public.clubs_bookings;
CREATE POLICY "clubs_bookings: admin full access" ON public.clubs_bookings
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── EVENTS_BOOKINGS ─────────────────────────────────────────────────────────
ALTER TABLE public.events_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events_bookings: admin full access" ON public.events_bookings;
CREATE POLICY "events_bookings: admin full access" ON public.events_bookings
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── VENDOR_INVENTORY ────────────────────────────────────────────────────────
ALTER TABLE public.vendor_inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vendor_inventory: admin full access" ON public.vendor_inventory;
CREATE POLICY "vendor_inventory: admin full access" ON public.vendor_inventory
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── BOTTLES ─────────────────────────────────────────────────────────────────
ALTER TABLE public.bottles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bottles: admin full access" ON public.bottles;
CREATE POLICY "bottles: admin full access" ON public.bottles
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── CATEGORIES ──────────────────────────────────────────────────────────────
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "categories: admin full access" ON public.categories;
CREATE POLICY "categories: admin full access" ON public.categories
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ─── REVIEWS ─────────────────────────────────────────────────────────────────
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reviews: admin full access" ON public.reviews;
CREATE POLICY "reviews: admin full access" ON public.reviews
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
