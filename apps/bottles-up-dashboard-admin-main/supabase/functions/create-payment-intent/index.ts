// Supabase Edge Function: create-payment-intent
// Creates a Stripe PaymentIntent and Stripe Customer (if needed),
// returns the client_secret, ephemeral_key and customer ID to the Flutter app
// so flutter_stripe can present the Payment Sheet natively.
//
// Deploy:  supabase functions deploy create-payment-intent
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//          supabase secrets set STRIPE_PUBLISHABLE_KEY=pk_test_...
//
// Request body:
//   { user_id, email, payment_type, amount (cents), currency,
//     booking_id?, event_id?, description?, metadata? }
//
// Response:
//   { payment_intent, ephemeral_key, customer, publishable_key, transaction_id }

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

    // Verify caller JWT
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
    } = body

    if (!payment_type || !amount || amount <= 0) {
      return json({ error: 'payment_type and a positive amount are required' }, 400)
    }

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
      apiVersion: '2023-10-16',
    })

    // ── Get or create Stripe Customer ─────────────────────────────────────────
    let stripeCustomerId: string

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

    // ── Ephemeral Key (for Payment Sheet) ─────────────────────────────────────
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: stripeCustomerId },
      { apiVersion: '2023-10-16' },
    )

    // ── Payment Intent ────────────────────────────────────────────────────────
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount), // already in cents from client
      currency: currency.toLowerCase(),
      customer: stripeCustomerId,
      description: description ?? `Bottles Up – ${payment_type}`,
      automatic_payment_methods: { enabled: true },
      metadata: {
        supabase_user_id: user.id,
        payment_type,
        ...(booking_id && { booking_id }),
        ...(event_id && { event_id }),
        ...metadata,
      },
    })

    // ── Record transaction in DB ──────────────────────────────────────────────
    const { data: txn } = await supabase
      .from('payment_transactions')
      .insert({
        user_id: user.id,
        booking_id: booking_id ?? null,
        event_id: event_id ?? null,
        amount: amount / 100, // store in dollars
        currency: currency.toLowerCase(),
        status: 'pending',
        payment_intent_id: paymentIntent.id,
        payment_type,
        metadata,
      })
      .select('id')
      .single()

    return json({
      payment_intent: paymentIntent.client_secret,
      ephemeral_key: ephemeralKey.secret,
      customer: stripeCustomerId,
      publishable_key: Deno.env.get('STRIPE_PUBLISHABLE_KEY'),
      transaction_id: txn?.id ?? null,
    })
  } catch (err) {
    console.error('create-payment-intent error:', err)
    return json({ error: err instanceof Error ? err.message : 'Internal server error' }, 500)
  }
})
