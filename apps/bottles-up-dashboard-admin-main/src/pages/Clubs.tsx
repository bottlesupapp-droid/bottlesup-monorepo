import { Building2, Star, MapPin, CheckCircle } from "lucide-react";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/AppSidebar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { useClubs } from "@/hooks/useSupabase";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";

const Clubs = () => {
  const { data: clubs, loading, error } = useClubs();

  const formatCurrency = (min: number | null, max: number | null) => {
    if (min == null && max == null) return '—';
    const fmt = (v: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(v);
    if (min != null && max != null) return `${fmt(min)} – ${fmt(max)}`;
    if (min != null) return `From ${fmt(min)}`;
    return `Up to ${fmt(max!)}`;
  };

  const stats = {
    total: clubs.length,
    active: clubs.filter(c => c.is_active).length,
    avgRating: clubs.length > 0
      ? (clubs.reduce((sum, c) => sum + (c.avg_rating ?? 0), 0) / clubs.length).toFixed(1)
      : '0',
    totalReviews: clubs.reduce((sum, c) => sum + (c.review_count ?? 0), 0),
  };

  if (error) {
    return (
      <SidebarProvider>
        <div className="min-h-screen flex w-full bg-background">
          <AppSidebar />
          <main className="flex-1 p-6">
            <div className="text-center text-red-500">Error loading clubs: {error}</div>
          </main>
        </div>
      </SidebarProvider>
    );
  }

  return (
    <SidebarProvider>
      <div className="min-h-screen flex w-full bg-background">
        <AppSidebar />
        <main className="flex-1 p-6 space-y-6">
          <div className="flex items-center gap-4">
            <SidebarTrigger className="text-foreground hover:bg-accent" />
            <div>
              <h1 className="text-3xl font-bold text-foreground">Clubs</h1>
              <p className="text-muted-foreground">Manage nightclub listings</p>
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
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Clubs</CardTitle>
                    <Building2 className="h-4 w-4 text-primary" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.total}</div>
                    <p className="text-xs text-muted-foreground">Registered clubs</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Active</CardTitle>
                    <CheckCircle className="h-4 w-4 text-green-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.active}</div>
                    <p className="text-xs text-muted-foreground">Open for bookings</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Avg Rating</CardTitle>
                    <Star className="h-4 w-4 text-yellow-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.avgRating}</div>
                    <p className="text-xs text-muted-foreground">Platform average</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Reviews</CardTitle>
                    <Star className="h-4 w-4 text-blue-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.totalReviews}</div>
                    <p className="text-xs text-muted-foreground">Across all clubs</p>
                  </CardContent>
                </Card>
              </>
            )}
          </div>

          {/* Table */}
          <Card className="bg-card border border-border">
            <CardHeader>
              <CardTitle className="text-foreground flex items-center gap-2">
                <Building2 className="h-5 w-5" /> All Clubs
              </CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">
                  {Array.from({ length: 6 }).map((_, i) => (
                    <Skeleton key={i} className="h-12 w-full" />
                  ))}
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow className="border-border">
                      <TableHead className="text-muted-foreground">Club</TableHead>
                      <TableHead className="text-muted-foreground">Location</TableHead>
                      <TableHead className="text-muted-foreground">Price Range</TableHead>
                      <TableHead className="text-muted-foreground">Rating</TableHead>
                      <TableHead className="text-muted-foreground">Reviews</TableHead>
                      <TableHead className="text-muted-foreground">Dress Code</TableHead>
                      <TableHead className="text-muted-foreground">Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {clubs.map((club) => (
                      <TableRow key={club.id} className="border-border hover:bg-muted/50">
                        <TableCell>
                          <div className="flex items-center gap-3">
                            {club.image_url ? (
                              <img src={club.image_url} alt={club.name} className="h-10 w-10 rounded object-cover" />
                            ) : (
                              <div className="h-10 w-10 rounded bg-muted flex items-center justify-center">
                                <Building2 className="h-5 w-5 text-muted-foreground" />
                              </div>
                            )}
                            <div>
                              <div className="font-medium text-foreground">{club.name}</div>
                              {club.email && <div className="text-xs text-muted-foreground">{club.email}</div>}
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center gap-1 text-sm text-foreground">
                            <MapPin className="h-3 w-3 text-muted-foreground" />
                            {club.location}
                          </div>
                        </TableCell>
                        <TableCell className="text-sm text-foreground">
                          {formatCurrency(club.price_min, club.price_max)}
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center gap-1">
                            <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />
                            <span className="text-sm text-foreground">{club.avg_rating ?? '—'}</span>
                          </div>
                        </TableCell>
                        <TableCell className="text-sm text-foreground">{club.review_count ?? 0}</TableCell>
                        <TableCell className="text-sm text-foreground">{club.dress_code || '—'}</TableCell>
                        <TableCell>
                          {club.is_active
                            ? <Badge className="bg-green-100 text-green-800">Active</Badge>
                            : <Badge variant="outline">Inactive</Badge>}
                        </TableCell>
                      </TableRow>
                    ))}
                    {clubs.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                          No clubs found
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
    </SidebarProvider>
  );
};

export default Clubs;
