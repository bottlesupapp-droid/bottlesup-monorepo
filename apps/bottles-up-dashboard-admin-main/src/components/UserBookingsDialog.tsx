import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle } from 'lucide-react'
import { useUserBookings } from '@/hooks/useSupabase'

const statusClass: Record<string, string> = {
  confirmed: 'bg-green-100 text-green-800',
  pending: 'bg-yellow-100 text-yellow-800',
  cancelled: 'bg-red-100 text-red-800',
  completed: 'bg-blue-100 text-blue-800',
  refunded: 'bg-purple-100 text-purple-800',
  flagged: 'bg-orange-100 text-orange-800',
}

const fmt = (d: string | null) =>
  d ? new Intl.DateTimeFormat('en-US', { year: 'numeric', month: 'short', day: 'numeric' }).format(new Date(d)) : '—'

const money = (n: number | null) =>
  n == null ? '—' : new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n)

interface Props {
  userId: string | null
  userName: string | null
  onClose: () => void
}

export function UserBookingsDialog({ userId, userName, onClose }: Props) {
  const { clubBookings, eventBookings, loading, error, totalSpend } = useUserBookings(userId)

  return (
    <Dialog open={!!userId} onOpenChange={open => { if (!open) onClose() }}>
      <DialogContent className="max-w-3xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            Bookings for {userName || 'User'}
            {!loading && (
              <span className="ml-2 text-sm font-normal text-muted-foreground">
                {clubBookings.length + eventBookings.length} total · {money(totalSpend)} spent
              </span>
            )}
          </DialogTitle>
        </DialogHeader>

        {loading && (
          <div className="space-y-2 py-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        )}

        {error && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {!loading && !error && (
          <Tabs defaultValue="clubs">
            <TabsList>
              <TabsTrigger value="clubs">Club Bookings ({clubBookings.length})</TabsTrigger>
              <TabsTrigger value="events">Event Bookings ({eventBookings.length})</TabsTrigger>
            </TabsList>

            <TabsContent value="clubs">
              {clubBookings.length === 0 ? (
                <p className="text-sm text-muted-foreground py-6 text-center">No club bookings.</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Confirmation</TableHead>
                      <TableHead>Date</TableHead>
                      <TableHead>Guests</TableHead>
                      <TableHead>Amount</TableHead>
                      <TableHead>Payment</TableHead>
                      <TableHead>Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {clubBookings.map(b => (
                      <TableRow key={b.id}>
                        <TableCell className="font-mono text-xs">{b.confirmation_code || b.id.slice(0, 8)}</TableCell>
                        <TableCell className="text-sm">{fmt(b.booking_date)}</TableCell>
                        <TableCell className="text-sm">{b.guest_count ?? '—'}</TableCell>
                        <TableCell className="text-sm">{money(b.total_amount)}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className={statusClass[b.payment_status?.toLowerCase() ?? ''] ?? ''}>
                            {b.payment_status || '—'}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline" className={statusClass[b.status?.toLowerCase() ?? ''] ?? ''}>
                            {b.status || '—'}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </TabsContent>

            <TabsContent value="events">
              {eventBookings.length === 0 ? (
                <p className="text-sm text-muted-foreground py-6 text-center">No event bookings.</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Confirmation</TableHead>
                      <TableHead>Date</TableHead>
                      <TableHead>Tickets</TableHead>
                      <TableHead>Amount</TableHead>
                      <TableHead>Payment</TableHead>
                      <TableHead>Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {eventBookings.map(b => (
                      <TableRow key={b.id}>
                        <TableCell className="font-mono text-xs">{b.confirmation_code || b.id.slice(0, 8)}</TableCell>
                        <TableCell className="text-sm">{fmt(b.booking_date)}</TableCell>
                        <TableCell className="text-sm">{b.ticket_quantity ?? '—'}</TableCell>
                        <TableCell className="text-sm">{money(b.total_amount)}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className={statusClass[b.payment_status?.toLowerCase() ?? ''] ?? ''}>
                            {b.payment_status || '—'}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline" className={statusClass[b.status?.toLowerCase() ?? ''] ?? ''}>
                            {b.status || '—'}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </TabsContent>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  )
}
