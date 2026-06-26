import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'

interface AuditEntry {
  action: string
  targetTable: string
  targetId: string
  before?: Record<string, unknown>
  after?: Record<string, unknown>
}

export function useAdminActions() {
  const { user } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const logAction = async (entry: AuditEntry) => {
    if (!user) return
    const { error: logError } = await supabase.from('admin_audit_log').insert({
      admin_id: user.id,
      action: entry.action,
      target_table: entry.targetTable,
      target_id: entry.targetId,
      before: entry.before ?? null,
      after: entry.after ?? null,
    })
    if (logError) console.error('Audit log failed:', logError.message)
  }

  const wrap = async (fn: () => Promise<void>): Promise<boolean> => {
    setLoading(true)
    setError(null)
    try {
      await fn()
      return true
    } catch (e) {
      setError(e instanceof Error ? e.message : 'An unexpected error occurred')
      return false
    } finally {
      setLoading(false)
    }
  }

  // ── Vendor actions ────────────────────────────────────────────────────────

  const approveVendor = (vendorId: string, vendorName: string | null) =>
    wrap(async () => {
      const { error: dbError } = await supabase
        .from('vendors')
        .update({ status: 'active', updated_at: new Date().toISOString() })
        .eq('id', vendorId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'approve_vendor',
        targetTable: 'vendors',
        targetId: vendorId,
        before: { status: 'suspended' },
        after: { status: 'active', business_name: vendorName },
      })
    })

  const suspendVendor = (vendorId: string, vendorName: string | null) =>
    wrap(async () => {
      const { error: dbError } = await supabase
        .from('vendors')
        .update({ status: 'suspended', updated_at: new Date().toISOString() })
        .eq('id', vendorId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'suspend_vendor',
        targetTable: 'vendors',
        targetId: vendorId,
        before: { status: 'active', business_name: vendorName },
        after: { status: 'suspended' },
      })
    })

  // ── Event actions ─────────────────────────────────────────────────────────

  const unpublishEvent = (eventId: string, eventName: string) =>
    wrap(async () => {
      const { error: dbError } = await supabase
        .from('events')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('id', eventId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'unpublish_event',
        targetTable: 'events',
        targetId: eventId,
        before: { is_active: true, name: eventName },
        after: { is_active: false },
      })
    })

  const removeEvent = (eventId: string, eventName: string) =>
    wrap(async () => {
      const { error: dbError } = await supabase
        .from('events')
        .update({ is_active: false, status: 'cancelled', updated_at: new Date().toISOString() })
        .eq('id', eventId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'remove_event',
        targetTable: 'events',
        targetId: eventId,
        before: { is_active: true, name: eventName },
        after: { is_active: false, status: 'cancelled' },
      })
    })

  // ── User / profile actions ────────────────────────────────────────────────

  const updateUserRole = (userId: string, newRole: string, oldRole: string | null) =>
    wrap(async () => {
      const { error: dbError } = await supabase
        .from('profiles')
        .update({ role: newRole, updated_at: new Date().toISOString() })
        .eq('id', userId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'update_user_role',
        targetTable: 'profiles',
        targetId: userId,
        before: { role: oldRole },
        after: { role: newRole },
      })
    })

  const toggleUserVerified = (userId: string, verified: boolean) =>
    wrap(async () => {
      const { error: dbError } = await supabase
        .from('profiles')
        .update({ verified, updated_at: new Date().toISOString() })
        .eq('id', userId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: verified ? 'verify_user' : 'unverify_user',
        targetTable: 'profiles',
        targetId: userId,
        before: { verified: !verified },
        after: { verified },
      })
    })

  // ── Booking status actions ────────────────────────────────────────────────

  const updateBookingStatus = (
    bookingId: string,
    bookingType: 'club' | 'event',
    newStatus: string,
    oldStatus: string | null,
  ) =>
    wrap(async () => {
      const table = bookingType === 'club' ? 'table_bookings' : 'events_bookings'
      const { error: dbError } = await supabase
        .from(table)
        .update({ status: newStatus })
        .eq('id', bookingId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'update_booking_status',
        targetTable: table,
        targetId: bookingId,
        before: { status: oldStatus },
        after: { status: newStatus },
      })
    })

  // ── Booking / refund actions ──────────────────────────────────────────────

  const flagRefund = (
    bookingId: string,
    bookingType: 'club' | 'event',
    amount: number | null,
  ) =>
    wrap(async () => {
      const table = bookingType === 'club' ? 'table_bookings' : 'events_bookings'
      const updateData = bookingType === 'club'
        ? { status: 'flagged', updated_at: new Date().toISOString() }
        : { payment_status: 'flagged', updated_at: new Date().toISOString() }
      const { error: dbError } = await supabase
        .from(table)
        .update(updateData)
        .eq('id', bookingId)
      if (dbError) throw new Error(dbError.message)
      await logAction({
        action: 'flag_refund',
        targetTable: table,
        targetId: bookingId,
        before: { payment_status: 'paid' },
        after: { payment_status: 'flagged', total_amount: amount },
      })
    })

  // processRefund delegates to the edge function so Stripe key stays server-side
  const processRefund = async (
    bookingId: string,
    bookingType: 'club' | 'event',
  ): Promise<boolean> => {
    setLoading(true)
    setError(null)
    try {
      const { data, error: fnError } = await supabase.functions.invoke('process-refund', {
        body: { booking_id: bookingId, booking_type: bookingType },
      })
      if (fnError) throw new Error(fnError.message)
      if (data?.error) throw new Error(data.error as string)
      return true
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Refund failed')
      return false
    } finally {
      setLoading(false)
    }
  }

  return {
    loading,
    error,
    // vendor
    approveVendor,
    suspendVendor,
    // event
    unpublishEvent,
    removeEvent,
    // booking
    updateBookingStatus,
    flagRefund,
    processRefund,
    // user
    updateUserRole,
    toggleUserVerified,
  }
}
