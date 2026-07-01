import { useState, useEffect, useCallback, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type {
  Profile, Vendor, Club, Event,
  VendorInventory, EventsBooking, ClubsBooking, Review, Bottle, Category
} from '../types/supabase'

function useSupabaseData<T>(tableName: string) {
  const [data, setData] = useState<T[]>([])
  const [count, setCount] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const { data: result, error: fetchError, count: totalCount } = await supabase
        .from(tableName)
        .select('*', { count: 'exact' })
      if (fetchError) throw fetchError
      setData(result || [])
      setCount(totalCount || 0)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred')
      console.error(`Error fetching ${tableName}:`, err)
    } finally {
      setLoading(false)
    }
  }, [tableName])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  return { data, count, loading, error, refetch: fetchData }
}

export function useProfiles() {
  return useSupabaseData<Profile>('profiles')
}

export function useVendors() {
  return useSupabaseData<Vendor>('vendors')
}

export function useClubs() {
  return useSupabaseData<Club>('clubs')
}

export function useEvents() {
  return useSupabaseData<Event>('events')
}

export function useVendorInventory() {
  return useSupabaseData<VendorInventory>('vendor_inventory')
}

export function useEventsBookings() {
  return useSupabaseData<EventsBooking>('events_bookings')
}

export function useClubsBookings() {
  return useSupabaseData<ClubsBooking>('clubs_bookings')
}

export function useReviews() {
  return useSupabaseData<Review>('reviews')
}

export function useBottles() {
  return useSupabaseData<Bottle>('bottles')
}

export function useCategories() {
  return useSupabaseData<Category>('categories')
}

export function useDashboardStats() {
  const { count: totalUsers, loading: usersLoading, error: usersError } = useProfiles()
  const { count: totalVendors, loading: vendorsLoading, error: vendorsError } = useVendors()
  const { count: totalClubs, loading: clubsLoading, error: clubsError } = useClubs()
  const { count: totalEvents, loading: eventsLoading, error: eventsError } = useEvents()
  const { count: totalInventory, loading: inventoryLoading } = useVendorInventory()
  const { count: totalBottles, loading: bottlesLoading } = useBottles()
  const { data: clubBookings, count: totalClubBookings, loading: clubBookingsLoading } = useClubsBookings()
  const { count: totalEventBookings, loading: eventBookingsLoading } = useEventsBookings()

  const confirmedRevenue = clubBookings
    .filter(b => b.payment_status === 'paid')
    .reduce((sum, b) => sum + (b.total_amount ?? 0), 0)

  const loading = usersLoading || vendorsLoading || clubsLoading || eventsLoading ||
    inventoryLoading || bottlesLoading || clubBookingsLoading || eventBookingsLoading
  const error = usersError || vendorsError || clubsError || eventsError

  return {
    stats: {
      totalUsers,
      totalVendors,
      totalClubs,
      totalEvents,
      totalInventory,
      totalBottles,
      totalBookings: totalClubBookings + totalEventBookings,
      confirmedRevenue,
    },
    loading,
    error
  }
}

export interface ChartDataPoint {
  month: string
  events: number
  bookings: number
}

export function useEventChartData() {
  const [chartData, setChartData] = useState<ChartDataPoint[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchChartData = async () => {
      try {
        const sixMonthsAgo = new Date()
        sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 5)
        sixMonthsAgo.setDate(1)
        sixMonthsAgo.setHours(0, 0, 0, 0)

        const [eventsRes, bookingsRes] = await Promise.all([
          supabase
            .from('events')
            .select('created_at')
            .gte('created_at', sixMonthsAgo.toISOString()),
          supabase
            .from('events_bookings')
            .select('booking_date, ticket_quantity')
            .gte('booking_date', sixMonthsAgo.toISOString()),
        ])

        // Build a map for the last 6 calendar months
        const now = new Date()
        const months: ChartDataPoint[] = Array.from({ length: 6 }, (_, i) => {
          const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1)
          return {
            month: d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' }),
            events: 0,
            bookings: 0,
            _year: d.getFullYear(),
            _month: d.getMonth(),
          } as ChartDataPoint & { _year: number; _month: number }
        })

        const typed = months as (ChartDataPoint & { _year: number; _month: number })[]

        ;(eventsRes.data ?? []).forEach(e => {
          if (!e.created_at) return
          const d = new Date(e.created_at)
          const entry = typed.find(m => m._year === d.getFullYear() && m._month === d.getMonth())
          if (entry) entry.events++
        })

        ;(bookingsRes.data ?? []).forEach(b => {
          if (!b.booking_date) return
          const d = new Date(b.booking_date)
          const entry = typed.find(m => m._year === d.getFullYear() && m._month === d.getMonth())
          if (entry) entry.bookings += b.ticket_quantity ?? 1
        })

        setChartData(typed.map(({ month, events, bookings }) => ({ month, events, bookings })))
      } catch (err) {
        console.error('Error fetching chart data:', err)
      } finally {
        setLoading(false)
      }
    }

    fetchChartData()
  }, [])

  return { chartData, loading }
}

export function useIsAdmin() {
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkAdminStatus = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        if (user?.id) {
          const { data: vendor, error } = await supabase
            .from('vendors')
            .select('role')
            .eq('id', user.id)
            .single()
          if (error) {
            setIsAdmin(false)
          } else {
            setIsAdmin(vendor?.role === 'admin')
          }
        } else {
          setIsAdmin(false)
        }
      } catch {
        setIsAdmin(false)
      } finally {
        setLoading(false)
      }
    }
    checkAdminStatus()
  }, [])

  return { isAdmin, loading }
}

// Hook for fetching bookings belonging to a specific user
export function useUserBookings(userId: string | null) {
  const [clubBookings, setClubBookings] = useState<ClubsBooking[]>([])
  const [eventBookings, setEventBookings] = useState<EventsBooking[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchBookings = useCallback(async (uid: string) => {
    setLoading(true)
    setError(null)
    try {
      const [clubRes, eventRes] = await Promise.all([
        supabase.from('clubs_bookings').select('*').eq('user_id', uid).order('booking_date', { ascending: false }),
        supabase.from('events_bookings').select('*').eq('user_id', uid).order('booking_date', { ascending: false }),
      ])
      if (clubRes.error) throw clubRes.error
      if (eventRes.error) throw eventRes.error
      setClubBookings(clubRes.data ?? [])
      setEventBookings(eventRes.data ?? [])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load bookings')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (userId) fetchBookings(userId)
    else {
      setClubBookings([])
      setEventBookings([])
    }
  }, [userId, fetchBookings])

  const totalSpend = useMemo(
    () =>
      [...clubBookings, ...eventBookings].reduce((s, b) => s + (b.total_amount ?? 0), 0),
    [clubBookings, eventBookings]
  )

  return { clubBookings, eventBookings, loading, error, totalSpend }
}
