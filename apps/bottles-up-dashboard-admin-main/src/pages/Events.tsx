import { useState } from 'react'
import { CalendarDays, Users, DollarSign, Star, EyeOff, Trash2 } from 'lucide-react'
import { SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar'
import { AppSidebar } from '@/components/AppSidebar'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Button } from '@/components/ui/button'
import { useEvents } from '@/hooks/useSupabase'
import { useAdminActions } from '@/hooks/useAdminActions'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { useToast } from '@/hooks/use-toast'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import type { Event } from '@/types/supabase'

type Action = { type: 'unpublish' | 'remove'; event: Event }

const Events = () => {
  const { data: events, loading, error, refetch } = useEvents()
  const { unpublishEvent, removeEvent, loading: acting, error: actionError } = useAdminActions()
  const { toast } = useToast()
  const [pending, setPending] = useState<Action | null>(null)

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return '—'
    return new Intl.DateTimeFormat('en-US', { year: 'numeric', month: 'short', day: 'numeric' }).format(new Date(dateStr))
  }

  const formatCurrency = (amount: number | null) => {
    if (amount == null) return '—'
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount)
  }

  const getStatusBadge = (status: string | null, isActive: boolean | null) => {
    if (!isActive) return <Badge variant="outline" className="bg-gray-100 text-gray-700">Inactive</Badge>
    switch (status?.toLowerCase()) {
      case 'active': return <Badge className="bg-green-100 text-green-800 border-green-200">Active</Badge>
      case 'cancelled': return <Badge className="bg-red-100 text-red-800 border-red-200">Cancelled</Badge>
      case 'completed': return <Badge className="bg-blue-100 text-blue-800 border-blue-200">Completed</Badge>
      case 'draft': return <Badge variant="outline">Draft</Badge>
      default: return <Badge variant="secondary">{status || 'Unknown'}</Badge>
    }
  }

  const stats = {
    total: events.length,
    active: events.filter(e => e.is_active && e.status === 'active').length,
    featured: events.filter(e => e.is_featured).length,
    totalRevenue: events.reduce((sum, e) => sum + (e.revenue ?? 0), 0),
  }

  const handleConfirm = async () => {
    if (!pending) return
    const { type, event } = pending
    const ok = type === 'unpublish'
      ? await unpublishEvent(event.id, event.name)
      : await removeEvent(event.id, event.name)
    setPending(null)
    if (ok) {
      toast({ title: type === 'unpublish' ? 'Event unpublished' : 'Event removed', description: event.name })
      refetch()
    } else {
      toast({ variant: 'destructive', title: 'Action failed', description: actionError ?? 'Unknown error' })
    }
  }

  if (error) {
    return (
      <SidebarProvider>
        <div className="min-h-screen flex w-full bg-background">
          <AppSidebar />
          <main className="flex-1 p-6">
            <div className="text-center text-red-500">Error loading events: {error}</div>
          </main>
        </div>
      </SidebarProvider>
    )
  }

  return (
    <SidebarProvider>
      <div className="min-h-screen flex w-full bg-background">
        <AppSidebar />
        <main className="flex-1 p-6 space-y-6">
          <div className="flex items-center gap-4">
            <SidebarTrigger className="text-foreground hover:bg-accent" />
            <div>
              <h1 className="text-3xl font-bold text-foreground">Events</h1>
              <p className="text-muted-foreground">Manage platform events</p>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {loading ? (
              Array.from({ length: 4 }).map((_, i) => (
                <Card key={i} className="bg-card border border-border">
                  <CardHeader className="pb-2"><Skeleton className="h-4 w-20" /></CardHeader>
                  <CardContent><Skeleton className="h-8 w-16 mb-2" /><Skeleton className="h-3 w-24" /></CardContent>
                </Card>
              ))
            ) : (
              <>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Events</CardTitle>
                    <CalendarDays className="h-4 w-4 text-primary" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.total}</div>
                    <p className="text-xs text-muted-foreground">All events</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Active</CardTitle>
                    <Users className="h-4 w-4 text-green-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.active}</div>
                    <p className="text-xs text-muted-foreground">Live events</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Featured</CardTitle>
                    <Star className="h-4 w-4 text-yellow-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.featured}</div>
                    <p className="text-xs text-muted-foreground">Promoted events</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Revenue</CardTitle>
                    <DollarSign className="h-4 w-4 text-blue-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{formatCurrency(stats.totalRevenue)}</div>
                    <p className="text-xs text-muted-foreground">Across all events</p>
                  </CardContent>
                </Card>
              </>
            )}
          </div>

          {/* Table */}
          <Card className="bg-card border border-border">
            <CardHeader>
              <CardTitle className="text-foreground flex items-center gap-2">
                <CalendarDays className="h-5 w-5" /> All Events
              </CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">
                  {Array.from({ length: 8 }).map((_, i) => <Skeleton key={i} className="h-12 w-full" />)}
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow className="border-border">
                      <TableHead className="text-muted-foreground">Event</TableHead>
                      <TableHead className="text-muted-foreground">Date</TableHead>
                      <TableHead className="text-muted-foreground">City</TableHead>
                      <TableHead className="text-muted-foreground">Ticket Price</TableHead>
                      <TableHead className="text-muted-foreground">Capacity</TableHead>
                      <TableHead className="text-muted-foreground">Bookings</TableHead>
                      <TableHead className="text-muted-foreground">Revenue</TableHead>
                      <TableHead className="text-muted-foreground">Status</TableHead>
                      <TableHead className="text-muted-foreground">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {events.map((event) => (
                      <TableRow key={event.id} className="border-border hover:bg-muted/50">
                        <TableCell>
                          <div className="font-medium text-foreground flex items-center gap-2">
                            {event.name}
                            {event.is_featured && <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />}
                            {event.is_private && <Badge variant="outline" className="text-xs">Private</Badge>}
                          </div>
                          {event.dress_code && (
                            <div className="text-xs text-muted-foreground">Dress: {event.dress_code}</div>
                          )}
                        </TableCell>
                        <TableCell className="text-sm text-foreground">{formatDate(event.event_date)}</TableCell>
                        <TableCell className="text-sm text-foreground">{event.city || '—'}</TableCell>
                        <TableCell className="text-sm text-foreground">{formatCurrency(event.ticket_price)}</TableCell>
                        <TableCell className="text-sm text-foreground">{event.max_capacity ?? '—'}</TableCell>
                        <TableCell className="text-sm text-foreground">{event.current_bookings ?? 0}</TableCell>
                        <TableCell className="text-sm text-foreground">{formatCurrency(event.revenue)}</TableCell>
                        <TableCell>{getStatusBadge(event.status, event.is_active)}</TableCell>
                        <TableCell>
                          <div className="flex items-center gap-2">
                            {event.is_active && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="text-yellow-700 border-yellow-300 hover:bg-yellow-50"
                                onClick={() => setPending({ type: 'unpublish', event })}
                              >
                                <EyeOff className="h-3 w-3 mr-1" />
                                Unpublish
                              </Button>
                            )}
                            {event.status !== 'cancelled' && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="text-red-700 border-red-300 hover:bg-red-50"
                                onClick={() => setPending({ type: 'remove', event })}
                              >
                                <Trash2 className="h-3 w-3 mr-1" />
                                Remove
                              </Button>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                    {events.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={9} className="text-center text-muted-foreground py-8">No events found</TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </main>
      </div>

      {pending && (
        <ConfirmDialog
          open={!!pending}
          onOpenChange={open => { if (!open) setPending(null) }}
          title={pending.type === 'unpublish' ? 'Unpublish Event?' : 'Remove Event?'}
          description={
            pending.type === 'unpublish'
              ? `"${pending.event.name}" will be hidden from users immediately. Existing bookings are unaffected.`
              : `"${pending.event.name}" will be marked cancelled. Bookings are NOT automatically refunded — process those separately in Bookings.`
          }
          confirmLabel={pending.type === 'unpublish' ? 'Unpublish' : 'Remove'}
          variant="destructive"
          loading={acting}
          onConfirm={handleConfirm}
        />
      )}
    </SidebarProvider>
  )
}

export default Events
