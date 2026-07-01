import { useState } from 'react'
import { Users as UsersIcon, UserCheck, Calendar, ShieldCheck, BookOpen } from 'lucide-react'
import { SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar'
import { AppSidebar } from '@/components/AppSidebar'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Button } from '@/components/ui/button'
import { useProfiles } from '@/hooks/useSupabase'
import { UserBookingsDialog } from '@/components/UserBookingsDialog'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import type { Profile } from '@/types/supabase'

const Users = () => {
  const { data: profiles, loading, error } = useProfiles()
  const [selectedUser, setSelectedUser] = useState<Profile | null>(null)

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return '—'
    return new Intl.DateTimeFormat('en-US', { year: 'numeric', month: 'short', day: 'numeric' }).format(new Date(dateStr))
  }

  const getInitials = (name: string | null, email: string | null) => {
    if (name) return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
    if (email) return email[0].toUpperCase()
    return '?'
  }

  const now = new Date()
  const stats = {
    totalUsers: profiles.length,
    verifiedUsers: profiles.filter(p => p.verified).length,
    newUsersThisMonth: profiles.filter(p => {
      if (!p.created_at) return false
      const d = new Date(p.created_at)
      return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
    }).length,
    adminUsers: profiles.filter(p => p.is_admin || p.role === 'admin').length,
  }

  if (error) {
    return (
      <SidebarProvider>
        <div className="min-h-screen flex w-full bg-background">
          <AppSidebar />
          <main className="flex-1 p-6">
            <div className="text-center text-red-500">Error loading users: {error}</div>
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
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <SidebarTrigger className="text-foreground hover:bg-accent" />
              <div>
                <h1 className="text-3xl font-bold text-foreground">User Management</h1>
                <p className="text-muted-foreground">Manage and monitor user profiles</p>
              </div>
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
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Users</CardTitle>
                    <UsersIcon className="h-4 w-4 text-primary" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.totalUsers}</div>
                    <p className="text-xs text-muted-foreground">Registered profiles</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Verified</CardTitle>
                    <UserCheck className="h-4 w-4 text-green-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.verifiedUsers}</div>
                    <p className="text-xs text-muted-foreground">
                      {stats.totalUsers > 0 ? ((stats.verifiedUsers / stats.totalUsers) * 100).toFixed(1) : 0}% verified
                    </p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">New This Month</CardTitle>
                    <Calendar className="h-4 w-4 text-blue-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.newUsersThisMonth}</div>
                    <p className="text-xs text-muted-foreground">Recently joined</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Admins</CardTitle>
                    <ShieldCheck className="h-4 w-4 text-purple-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.adminUsers}</div>
                    <p className="text-xs text-muted-foreground">Admin role users</p>
                  </CardContent>
                </Card>
              </>
            )}
          </div>

          {/* Table */}
          <Card className="bg-card border border-border">
            <CardHeader>
              <CardTitle className="text-foreground flex items-center gap-2">
                <UsersIcon className="h-5 w-5" /> All Users
              </CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-4">
                  {Array.from({ length: 8 }).map((_, i) => (
                    <div key={i} className="flex items-center space-x-4">
                      <Skeleton className="h-10 w-10 rounded-full" />
                      <div className="space-y-2 flex-1">
                        <Skeleton className="h-4 w-[200px]" />
                        <Skeleton className="h-4 w-[150px]" />
                      </div>
                      <Skeleton className="h-4 w-[80px]" />
                    </div>
                  ))}
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow className="border-border">
                      <TableHead className="text-muted-foreground">User</TableHead>
                      <TableHead className="text-muted-foreground">Email</TableHead>
                      <TableHead className="text-muted-foreground">Phone</TableHead>
                      <TableHead className="text-muted-foreground">Age</TableHead>
                      <TableHead className="text-muted-foreground">Role</TableHead>
                      <TableHead className="text-muted-foreground">Status</TableHead>
                      <TableHead className="text-muted-foreground">Joined</TableHead>
                      <TableHead className="text-muted-foreground">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {profiles.map((profile) => (
                      <TableRow key={profile.id} className="border-border hover:bg-muted/50">
                        <TableCell>
                          <div className="flex items-center space-x-3">
                            <Avatar>
                              <AvatarImage src={profile.avatar_url || undefined} />
                              <AvatarFallback className="bg-primary text-primary-foreground">
                                {getInitials(profile.name, profile.email)}
                              </AvatarFallback>
                            </Avatar>
                            <div>
                              <div className="font-medium text-foreground">{profile.name || 'No name'}</div>
                              <div className="text-xs text-muted-foreground">ID: {profile.id.slice(0, 8)}…</div>
                            </div>
                          </div>
                        </TableCell>
                        <TableCell className="text-sm text-foreground">{profile.email || '—'}</TableCell>
                        <TableCell className="text-sm text-foreground">{profile.phone_number || '—'}</TableCell>
                        <TableCell className="text-sm text-foreground">{profile.age ?? '—'}</TableCell>
                        <TableCell>
                          <Badge variant={profile.is_admin || profile.role === 'admin' ? 'default' : 'secondary'}>
                            {profile.role || 'user'}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <Badge variant={profile.verified ? 'default' : 'outline'}>
                            {profile.verified ? 'Verified' : 'Unverified'}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-sm text-foreground">{formatDate(profile.created_at)}</TableCell>
                        <TableCell>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => setSelectedUser(profile)}
                          >
                            <BookOpen className="h-3 w-3 mr-1" />
                            Bookings
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                    {profiles.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={8} className="text-center text-muted-foreground py-8">
                          No users found
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </main>
      </div>

      <UserBookingsDialog
        userId={selectedUser?.id ?? null}
        userName={selectedUser?.name ?? selectedUser?.email ?? null}
        onClose={() => setSelectedUser(null)}
      />
    </SidebarProvider>
  )
}

export default Users
