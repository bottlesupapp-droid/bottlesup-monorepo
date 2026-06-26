// Supabase Edge Function: stripe-webhook
// Receives Stripe webhook events and updates payment_transactions +
// events_bookings / clubs_bookings accordingly.
//
// Deploy:  supabase functions deploy stripe-webhook
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//          supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
//
// In Stripe Dashboard → Developers → Webhooks, add endpoint:
//   https://<project>.supabase.co/functions/v1/stripe-webhook
// Events to listen for:
//   payment_intent.succeeded
//   payment_intent.payment_failed
//   checkout.session.completed
//   checkout.session.expired

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno&no-check'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

serve(async (req: Request) => {
  const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
    apiVersion: '2023-10-16',
  })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // ── Verify Stripe signature ───────────────────────────────────────────────
  const signature = req.headers.get('stripe-signature')
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')

  if (!signature || !webhookSecret) {
    return json({ error: 'Missing stripe-signature or webhook secret' }, 400)
  }

  let event: Stripe.Event
  try {
    const body = await req.text()
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret)
  } catch (err) {
    console.error('Webhook signature verification failed:', err)
    return json({ error: 'Invalid signature' }, 400)
  }

  // ── Handle events ─────────────────────────────────────────────────────────
  try {
    switch (event.type) {

      // ── Payment Sheet succeeded ───────────────────────────────────────────
      case 'payment_intent.succeeded': {
        const pi = event.data.object as Stripe.PaymentIntent
        await handlePaymentSuccess({
          supabase,
          paymentIntentId: pi.id,
          bookingId: pi.metadata?.booking_id,
          eventId: pi.metadata?.event_id,
          amountPaid: pi.amount_received / 100,
        })
        break
      }

      case 'payment_intent.payment_failed': {
        const pi = event.data.object as Stripe.PaymentIntent
        await supabase
          .from('payment_transactions')
          .update({ status: 'failed' })
          .eq('payment_intent_id', pi.id)
        break
      }

      // ── Checkout session succeeded ────────────────────────────────────────
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.CheckoutSession
        await handlePaymentSuccess({
          supabase,
          sessionId: session.id,
          paymentIntentId: typeof session.payment_intent === 'string'
            ? session.payment_intent
            : session.payment_intent?.id,
          bookingId: session.metadata?.booking_id,
          eventId: session.metadata?.event_id,
          amountPaid: (session.amount_total ?? 0) / 100,
        })
        break
      }

      case 'checkout.session.expired': {
        const session = event.data.object as Stripe.CheckoutSession
        await supabase
          .from('payment_transactions')
          .update({ status: 'cancelled' })
          .eq('stripe_session_id', session.id)
        break
      }

      default:
        console.log(`Unhandled event type: ${event.type}`)
    }

    return json({ received: true })
  } catch (err) {
    console.error('Webhook handler error:', err)
    return json({ error: 'Handler failed' }, 500)
  }
})

// ── Shared success handler ────────────────────────────────────────────────────
async function handlePaymentSuccess({
  supabase,
  paymentIntentId,
  sessionId,
  bookingId,
  eventId,
  amountPaid,
}: {
  supabase: ReturnType<typeof createClient>
  paymentIntentId?: string | null
  sessionId?: string | null
  bookingId?: string | null
  eventId?: string | null
  amountPaid: number
}) {
  // 1. Update payment_transactions
  const txnFilter = paymentIntentId
    ? { payment_intent_id: paymentIntentId }
    : { stripe_session_id: sessionId! }

  const column = Object.keys(txnFilter)[0]
  const value = Object.values(txnFilter)[0]

  await supabase
    .from('payment_transactions')
    .update({ status: 'paid', ...(paymentIntentId && { payment_intent_id: paymentIntentId }) })
    .eq(column, value)

  // 2. Confirm the booking if we have a booking_id
  if (bookingId) {
    // Try events_bookings first
    const { data: evtBooking } = await supabase
      .from('events_bookings')
      .select('id')
      .eq('id', bookingId)
      .maybeSingle()

    if (evtBooking) {
      await supabase
        .from('events_bookings')
        .update({ status: 'confirmed', payment_status: 'paid' })
        .eq('id', bookingId)

      // Increment current_bookings on the event
      if (eventId) {
        await supabase.rpc('increment_event_bookings', { event_id: eventId })
      }
      return
    }

    // Fall back to clubs_bookings
    await supabase
      .from('clubs_bookings')
      .update({ status: 'confirmed', payment_status: 'paid' })
      .eq('id', bookingId)
  }
}
