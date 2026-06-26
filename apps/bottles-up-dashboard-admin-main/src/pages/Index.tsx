import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { CalendarDays, Users, Building2, Store, AlertCircle, LogOut, User, Package, BookOpen, Wine, DollarSign } from 'lucide-react'
import { useDashboardStats } from '@/hooks/useSupabase'
import { useAuth } from '../hooks/useAuth'
import { Skeleton } from '@/components/ui/skeleton'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { useState } from 'react'
import { SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar'
import { AppSidebar } from '@/components/AppSidebar'
import { EventsChart } from '@/components/EventsChart'

const Index = () => {
  const { stats, loading, error } = useDashboardStats()
  const { user, signOut } = useAuth()
  const [loggingOut, setLoggingOut] = useState(false)

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-background">
        <Alert className="max-w-md">
          <AlertCircle className="h-4 w-4 text-red-400" />
          <AlertDescription>Error loading dashboard data: {error}</AlertDescription>
        </Alert>
      </div>
    )
  }

  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(amount)

  const statCards = [
    { title: 'Total Users', value: stats.totalUsers, icon: Users, color: 'text-blue-400', description: 'Registered user profiles' },
    { title: 'Total Vendors', value: stats.totalVendors, icon: Store, color: 'text-green-400', description: 'Active vendors on platform' },
    { title: 'Total Clubs', value: stats.totalClubs, icon: Building2, color: 'text-purple-400', description: 'Registered nightclubs' },
    { title: 'Total Events', value: stats.totalEvents, icon: CalendarDays, color: 'text-orange-400', description: 'Events created' },
    { title: 'Total Bookings', value: stats.totalBookings, icon: BookOpen, color: 'text-pink-400', description: 'Club & event bookings' },
    { title: 'Bottles Listed', value: stats.totalBottles, icon: Wine, color: 'text-red-400', description: 'Premium bottles on menu' },
    { title: 'Inventory Items', value: stats.totalInventory, icon: Package, color: 'text-yellow-400', description: 'Vendor inventory items' },
    { title: 'Confirmed Revenue', value: formatCurrency(stats.confirmedRevenue), icon: DollarSign, color: 'text-emerald-400', description: 'Paid booking revenue' },
  ]

  return (
    <SidebarProvider>
      <div className="min-h-screen flex w-full bg-background">
        <AppSidebar />
        <main className="flex-1 p-6 space-y-6">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <SidebarTrigger className="text-foreground hover:bg-accent" />
              <div>
                <h1 className="text-3xl font-bold text-foreground">Admin Dashboard</h1>
                <p className="text-muted-foreground">Bottles Up platform overview</p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <div className="hidden sm:flex items-center gap-2 text-sm text-muted-foreground">
                <User className="h-4 w-4" />
                <span>{user?.email}</span>
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={async () => {
                  setLoggingOut(true)
                  try { await signOut() } catch { /* ignore */ } finally { setLoggingOut(false) }
                }}
                disabled={loggingOut}
                className="flex items-center gap-2"
              >
                <LogOut className="h-4 w-4" />
                <span className="hidden sm:inline">{loggingOut ? 'Signing out...' : 'Sign Out'}</span>
              </Button>
            </div>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {statCards.map(({ title, value, icon: Icon, color, description }) => (
              <Card key={title} className="bg-card border border-border">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
                  <Icon className={`h-4 w-4 ${color}`} />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-foreground">
                    {loading ? <Skeleton className="h-8 w-16" /> : (typeof value === 'number' ? value.toLocaleString() : value)}
                  </div>
                  <CardDescription className="text-xs text-muted-foreground">{description}</CardDescription>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* Charts — real data from the last 6 months */}
          <EventsChart />

          {/* Overview Card */}
          <Card className="bg-card border border-border">
            <CardHeader>
              <CardTitle className="text-foreground">Platform Overview</CardTitle>
              <CardDescription className="text-muted-foreground">
                Real-time data from the Bottles Up Supabase database.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Use the sidebar to manage users, vendors, clubs, events, bookings, and inventory.
                All data is sourced directly from Supabase.
              </p>
            </CardContent>
          </Card>
        </main>
      </div>
    </SidebarProvider>
  )
}

export default Index
