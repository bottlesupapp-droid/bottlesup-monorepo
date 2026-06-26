// Supabase Edge Function: process-refund
// Stripe is called SERVER-SIDE ONLY — the secret key never reaches the browser.
//
// Deploy:  supabase functions deploy process-refund
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_live_...
//
// Request body: { booking_id: string, booking_type: 'club' | 'event' }
// Returns:      { success: true, refund_id: string, amount: number }
//            or { error: string } with appropriate HTTP status

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno&no-check'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    // ── 1. Extract admin JWT ──────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Missing authorization header' }, 401)

    // Use service role for all DB writes so we bypass RLS in this trusted function
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Verify the calling user's identity via their JWT
    const { data: { user }, error: userError } =
      await supabase.auth.getUser(authHeader.replace('Bearer ', ''))
    if (userError || !user) return json({ error: 'Invalid token' }, 401)

    // ── 2. Verify admin role ──────────────────────────────────────────────────
    const { data: vendor } = await supabase
      .from('vendors')
      .select('role')
      .eq('id', user.id)
      .single()
    if (vendor?.role !== 'admin') return json({ error: 'Admin privileges required' }, 403)

    // ── 3. Parse request ──────────────────────────────────────────────────────
    const { booking_id, booking_type } = (await req.json()) as {
      booking_id: string
      booking_type: 'club' | 'event'
    }
    if (!booking_id || !booking_type) {
      return json({ error: 'booking_id and booking_type are required' }, 400)
    }

    const table = booking_type === 'club' ? 'clubs_bookings' : 'events_bookings'

    // ── 4. Fetch booking ──────────────────────────────────────────────────────
    const { data: booking, error: bookingError } = await supabase
      .from(table)
      .select('*')
      .eq('id', booking_id)
      .single()

    if (bookingError || !booking) return json({ error: 'Booking not found' }, 404)
    if (booking.payment_status === 'refunded') {
      return json({ error: 'Booking is already refunded' }, 400)
    }
    if (!booking.payment_reference) {
      return json({ error: 'No Stripe payment reference on this booking' }, 400)
    }

    // ── 5. Create Stripe refund ───────────────────────────────────────────────
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (!stripeKey) return json({ error: 'Stripe not configured on server' }, 500)

    const stripe = new Stripe(stripeKey, {
      apiVersion: '2023-10-16',
      httpClient: Stripe.createFetchHttpClient(),
    })

    const refund = await stripe.refunds.create({
      payment_intent: booking.payment_reference,
      reason: 'requested_by_customer',
    })

    const before = { payment_status: booking.payment_status, status: booking.status }
    const after = {
      payment_status: 'refunded',
      status: 'cancelled',
      stripe_refund_id: refund.id,
    }

    // ── 6. Update booking ─────────────────────────────────────────────────────
    await supabase
      .from(table)
      .update({ payment_status: 'refunded', status: 'cancelled', updated_at: new Date().toISOString() })
      .eq('id', booking_id)

    // ── 7. Audit log ──────────────────────────────────────────────────────────
    await supabase.from('admin_audit_log').insert({
      admin_id: user.id,
      action: 'process_refund',
      target_table: table,
      target_id: booking_id,
      before,
      after,
    })

    return json({ success: true, refund_id: refund.id, amount: refund.amount })
  } catch (err) {
    console.error('process-refund error:', err)
    return json(
      { error: err instanceof Error ? err.message : 'Internal server error' },
      500,
    )
  }
})
