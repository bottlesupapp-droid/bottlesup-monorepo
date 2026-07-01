import { Wine, Star, DollarSign, CheckCircle } from "lucide-react";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/AppSidebar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { useBottles } from "@/hooks/useSupabase";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";

const categoryColors: Record<string, string> = {
  champagne: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  spirits:   'bg-purple-100 text-purple-800 border-purple-200',
  wine:      'bg-red-100 text-red-800 border-red-200',
  beer:      'bg-orange-100 text-orange-800 border-orange-200',
  cocktail:  'bg-blue-100 text-blue-800 border-blue-200',
}

const Bottles = () => {
  const { data: bottles, loading, error } = useBottles();

  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);

  const categories = [...new Set(bottles.map(b => b.category).filter(Boolean))];

  const stats = {
    total: bottles.length,
    available: bottles.filter(b => b.is_available).length,
    featured: bottles.filter(b => b.is_featured).length,
    avgPrice: bottles.length > 0
      ? bottles.reduce((sum, b) => sum + b.price, 0) / bottles.length
      : 0,
  };

  if (error) {
    return (
      <SidebarProvider>
        <div className="min-h-screen flex w-full bg-background">
          <AppSidebar />
          <main className="flex-1 p-6">
            <div className="text-center text-red-500">Error loading bottles: {error}</div>
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
              <h1 className="text-3xl font-bold text-foreground">Bottles</h1>
              <p className="text-muted-foreground">Premium bottle menu across clubs</p>
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
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Bottles</CardTitle>
                    <Wine className="h-4 w-4 text-primary" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.total}</div>
                    <p className="text-xs text-muted-foreground">{categories.length} categories</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Available</CardTitle>
                    <CheckCircle className="h-4 w-4 text-green-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.available}</div>
                    <p className="text-xs text-muted-foreground">On menu now</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Featured</CardTitle>
                    <Star className="h-4 w-4 text-yellow-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.featured}</div>
                    <p className="text-xs text-muted-foreground">Highlighted items</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Avg Price</CardTitle>
                    <DollarSign className="h-4 w-4 text-blue-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{formatCurrency(stats.avgPrice)}</div>
                    <p className="text-xs text-muted-foreground">Per bottle</p>
                  </CardContent>
                </Card>
              </>
            )}
          </div>

          {/* Table */}
          <Card className="bg-card border border-border">
            <CardHeader>
              <CardTitle className="text-foreground flex items-center gap-2">
                <Wine className="h-5 w-5" /> All Bottles
              </CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">
                  {Array.from({ length: 8 }).map((_, i) => (
                    <Skeleton key={i} className="h-12 w-full" />
                  ))}
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow className="border-border">
                      <TableHead className="text-muted-foreground">Bottle</TableHead>
                      <TableHead className="text-muted-foreground">Category</TableHead>
                      <TableHead className="text-muted-foreground">Subcategory</TableHead>
                      <TableHead className="text-muted-foreground">Volume</TableHead>
                      <TableHead className="text-muted-foreground">ABV</TableHead>
                      <TableHead className="text-muted-foreground">Price</TableHead>
                      <TableHead className="text-muted-foreground">Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {bottles.map((bottle) => (
                      <TableRow key={bottle.id} className="border-border hover:bg-muted/50">
                        <TableCell>
                          <div className="flex items-center gap-3">
                            {bottle.image_url ? (
                              <img src={bottle.image_url} alt={bottle.name} className="h-10 w-10 rounded object-cover" />
                            ) : (
                              <div className="h-10 w-10 rounded bg-muted flex items-center justify-center">
                                <Wine className="h-5 w-5 text-muted-foreground" />
                              </div>
                            )}
                            <div>
                              <div className="font-medium text-foreground flex items-center gap-2">
                                {bottle.name}
                                {bottle.is_featured && (
                                  <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />
                                )}
                              </div>
                              {bottle.brand && (
                                <div className="text-xs text-muted-foreground">{bottle.brand}</div>
                              )}
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <Badge
                            variant="outline"
                            className={`capitalize ${categoryColors[bottle.category?.toLowerCase() ?? ''] ?? ''}`}
                          >
                            {bottle.category || '—'}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-sm text-foreground capitalize">
                          {bottle.subcategory?.replace('_', ' ') || '—'}
                        </TableCell>
                        <TableCell className="text-sm text-foreground">
                          {bottle.volume_ml ? `${bottle.volume_ml}ml` : '—'}
                        </TableCell>
                        <TableCell className="text-sm text-foreground">
                          {bottle.alcohol_content != null ? `${bottle.alcohol_content}%` : '—'}
                        </TableCell>
                        <TableCell className="font-medium text-foreground">
                          {formatCurrency(bottle.price)}
                        </TableCell>
                        <TableCell>
                          {bottle.is_available
                            ? <Badge className="bg-green-100 text-green-800">Available</Badge>
                            : <Badge variant="outline" className="text-red-700">Unavailable</Badge>}
                        </TableCell>
                      </TableRow>
                    ))}
                    {bottles.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                          No bottles found
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

export default Bottles;
