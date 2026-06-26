// Supabase Edge Function: create-checkout-session
// Creates a Stripe Checkout Session (browser-based hosted payment page).
// The Flutter app opens the returned URL in a browser; after payment Stripe
// redirects back to the deep-link URL so the app can confirm.
//
// Deploy:  supabase functions deploy create-checkout-session
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
//   { user_id, email, payment_type, amount (cents), currency,
//     booking_id?, event_id?, description?, metadata?,
//     success_url, cancel_url }
//
// Response:
//   { checkout_url, session_id, transaction_id }

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
    // ── Auth ──────────────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Missing authorization header' }, 401)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    )
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    // ── Parse request ─────────────────────────────────────────────────────────
    const body = await req.json()
    const {
      payment_type,
      amount,
      currency = 'usd',
      booking_id,
      event_id,
      description,
      metadata = {},
      success_url = 'bottlesup://payment/success',
      cancel_url = 'bottlesup://payment/cancel',
    } = body

    if (!payment_type || !amount || amount <= 0) {
      return json({ error: 'payment_type and a positive amount are required' }, 400)
    }

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
      apiVersion: '2023-10-16',
    })

    // ── Get or create Stripe Customer ─────────────────────────────────────────
    let stripeCustomerId: string | undefined

    const { data: existing } = await supabase
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .maybeSingle()

    if (existing?.stripe_customer_id) {
      stripeCustomerId = existing.stripe_customer_id
    } else {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_user_id: user.id },
      })
      stripeCustomerId = customer.id

      await supabase.from('stripe_customers').insert({
        user_id: user.id,
        stripe_customer_id: stripeCustomerId,
        email: user.email ?? '',
      })
    }

    // ── Create Checkout Session ───────────────────────────────────────────────
    const session = await stripe.checkout.sessions.create({
      customer: stripeCustomerId,
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: currency.toLowerCase(),
            product_data: {
              name: description ?? `Bottles Up – ${payment_type}`,
            },
            unit_amount: Math.round(amount), // already in cents
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url,
      cancel_url,
      metadata: {
        supabase_user_id: user.id,
        payment_type,
        ...(booking_id && { booking_id }),
        ...(event_id && { event_id }),
        ...metadata,
      },
    })

    // ── Record transaction ────────────────────────────────────────────────────
    const { data: txn } = await supabase
      .from('payment_transactions')
      .insert({
        user_id: user.id,
        booking_id: booking_id ?? null,
        event_id: event_id ?? null,
        amount: amount / 100,
        currency: currency.toLowerCase(),
        status: 'pending',
        stripe_session_id: session.id,
        payment_type,
        metadata,
      })
      .select('id')
      .single()

    return json({
      checkout_url: session.url,
      session_id: session.id,
      transaction_id: txn?.id ?? null,
    })
  } catch (err) {
    console.error('create-checkout-session error:', err)
    return json({ error: err instanceof Error ? err.message : 'Internal server error' }, 500)
  }
})
