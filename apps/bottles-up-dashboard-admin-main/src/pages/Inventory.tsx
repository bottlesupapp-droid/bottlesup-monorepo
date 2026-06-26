import { Package, DollarSign, TrendingUp, AlertTriangle } from "lucide-react";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/AppSidebar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { useVendorInventory } from "@/hooks/useSupabase";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";

const Inventory = () => {
  const { data: inventory, loading, error } = useVendorInventory();

  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);

  const getStockLevel = (stock: number | null, minStock: number | null) => {
    const s = stock ?? 0;
    const min = minStock ?? 5;
    if (s <= 0) return 'out-of-stock';
    if (s <= min) return 'low-stock';
    if (s <= min * 2) return 'medium-stock';
    return 'high-stock';
  };

  const stockBadgeClass: Record<string, string> = {
    'out-of-stock': 'bg-red-100 text-red-800 border-red-200',
    'low-stock': 'bg-yellow-100 text-yellow-800 border-yellow-200',
    'medium-stock': 'bg-blue-100 text-blue-800 border-blue-200',
    'high-stock': 'bg-green-100 text-green-800 border-green-200',
  };

  const stats = {
    totalItems: inventory.length,
    totalValue: inventory.reduce((sum, item) => sum + (item.price * (item.stock ?? 0)), 0),
    lowStockItems: inventory.filter(item => {
      const level = getStockLevel(item.stock, item.min_stock);
      return level === 'low-stock' || level === 'out-of-stock';
    }).length,
    featuredItems: inventory.filter(item => item.featured).length,
  };

  if (error) {
    return (
      <SidebarProvider>
        <div className="min-h-screen flex w-full bg-background">
          <AppSidebar />
          <main className="flex-1 p-6">
            <div className="text-center text-red-500">Error loading inventory: {error}</div>
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
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <SidebarTrigger className="text-foreground hover:bg-accent" />
              <div>
                <h1 className="text-3xl font-bold text-foreground">Inventory Management</h1>
                <p className="text-muted-foreground">Vendor bottle inventory</p>
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
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Items</CardTitle>
                    <Package className="h-4 w-4 text-primary" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.totalItems}</div>
                    <p className="text-xs text-muted-foreground">Inventory items</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Total Value</CardTitle>
                    <DollarSign className="h-4 w-4 text-green-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{formatCurrency(stats.totalValue)}</div>
                    <p className="text-xs text-muted-foreground">Stock value</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Low Stock</CardTitle>
                    <AlertTriangle className="h-4 w-4 text-yellow-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.lowStockItems}</div>
                    <p className="text-xs text-muted-foreground">Need restocking</p>
                  </CardContent>
                </Card>
                <Card className="bg-card border border-border">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">Featured</CardTitle>
                    <TrendingUp className="h-4 w-4 text-blue-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-foreground">{stats.featuredItems}</div>
                    <p className="text-xs text-muted-foreground">Featured items</p>
                  </CardContent>
                </Card>
              </>
            )}
          </div>

          {/* Table */}
          <Card className="bg-card border border-border">
            <CardHeader>
              <CardTitle className="text-foreground flex items-center gap-2">
                <Package className="h-5 w-5" /> Inventory Items
              </CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-4">
                  {Array.from({ length: 6 }).map((_, i) => (
                    <div key={i} className="flex items-center space-x-4">
                      <Skeleton className="h-16 w-16 rounded" />
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
                      <TableHead className="text-muted-foreground">Product</TableHead>
                      <TableHead className="text-muted-foreground">Category</TableHead>
                      <TableHead className="text-muted-foreground">Price</TableHead>
                      <TableHead className="text-muted-foreground">Stock</TableHead>
                      <TableHead className="text-muted-foreground">Volume</TableHead>
                      <TableHead className="text-muted-foreground">Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {inventory.map((item) => {
                      const stockLevel = getStockLevel(item.stock, item.min_stock);
                      return (
                        <TableRow key={item.id} className="border-border hover:bg-muted/50">
                          <TableCell>
                            <div className="flex items-center space-x-3">
                              {item.image_url ? (
                                <img src={item.image_url} alt={item.name} className="h-12 w-12 rounded object-cover" />
                              ) : (
                                <div className="h-12 w-12 rounded bg-muted flex items-center justify-center">
                                  <Package className="h-6 w-6 text-muted-foreground" />
                                </div>
                              )}
                              <div>
                                <div className="font-medium text-foreground flex items-center gap-2">
                                  {item.brand ? `${item.brand} ` : ''}{item.name}
                                  {item.featured && <Badge variant="secondary" className="text-xs">Featured</Badge>}
                                </div>
                                {item.description && (
                                  <div className="text-xs text-muted-foreground line-clamp-1">{item.description}</div>
                                )}
                                {item.tags && item.tags.length > 0 && (
                                  <div className="flex gap-1 mt-1">
                                    {item.tags.slice(0, 2).map((tag, i) => (
                                      <Badge key={i} variant="outline" className="text-xs">{tag}</Badge>
                                    ))}
                                  </div>
                                )}
                              </div>
                            </div>
                          </TableCell>
                          <TableCell className="text-sm text-foreground">{item.category || '—'}</TableCell>
                          <TableCell className="font-medium text-foreground">{formatCurrency(item.price)}</TableCell>
                          <TableCell>
                            <div className="text-sm font-medium text-foreground">{item.stock ?? 0}</div>
                            {item.min_stock != null && (
                              <div className="text-xs text-muted-foreground">Min: {item.min_stock}</div>
                            )}
                          </TableCell>
                          <TableCell className="text-sm text-foreground">
                            {item.volume ? `${item.volume}${item.unit || 'ml'}` : '—'}
                            {item.alcohol_content != null && (
                              <div className="text-xs text-muted-foreground">{item.alcohol_content}% ABV</div>
                            )}
                          </TableCell>
                          <TableCell>
                            <Badge variant="outline" className={`${stockBadgeClass[stockLevel]} capitalize`}>
                              {stockLevel.replace('-', ' ')}
                            </Badge>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                    {inventory.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                          No inventory items found
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

export default Inventory;
