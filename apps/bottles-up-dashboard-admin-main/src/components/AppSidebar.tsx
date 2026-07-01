import {
  Calendar,
  LayoutDashboard,
  User,
  Package,
  Users,
  Store,
  Building2,
  BookOpen,
  Wine,
} from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarHeader,
} from "@/components/ui/sidebar";

const menuItems = [
  { title: "Dashboard", url: "/", icon: LayoutDashboard },
  { title: "Users", url: "/users", icon: Users },
  { title: "Vendors", url: "/vendors", icon: Store },
  { title: "Clubs", url: "/clubs", icon: Building2 },
  { title: "Events", url: "/events", icon: Calendar },
  { title: "Bookings", url: "/bookings", icon: BookOpen },
  { title: "Bottles", url: "/bottles", icon: Wine },
  { title: "Inventory", url: "/inventory", icon: Package },
];

export function AppSidebar() {
  const location = useLocation();

  return (
    <Sidebar className="border-r border-border">
      <SidebarHeader className="border-b border-border p-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-primary rounded-lg flex items-center justify-center">
            <div className="w-6 h-6 bg-primary-foreground rounded-sm"></div>
          </div>
          <div>
            <h2 className="text-lg font-bold text-foreground">Bottles Up</h2>
            <p className="text-sm text-muted-foreground">Admin Panel</p>
          </div>
        </div>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel className="text-xs uppercase tracking-wider text-muted-foreground mb-2">
            Main Menu
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {menuItems.map((item) => {
                const isActive = location.pathname === item.url;
                return (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton
                      asChild
                      className={`hover:bg-sidebar-accent hover:text-sidebar-accent-foreground ${
                        isActive ? 'bg-primary text-primary-foreground' : ''
                      }`}
                    >
                      <Link to={item.url} className="flex items-center gap-3 px-3 py-2 rounded-md transition-colors">
                        <item.icon className="w-5 h-5" />
                        <span className="font-medium">{item.title}</span>
                      </Link>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                );
              })}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter className="border-t border-border p-4">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center">
            <User className="w-4 h-4 text-primary-foreground" />
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-foreground">Admin User</p>
            <p className="text-xs text-muted-foreground">Bottles Up Admin</p>
          </div>
        </div>
      </SidebarFooter>
    </Sidebar>
  );
}
