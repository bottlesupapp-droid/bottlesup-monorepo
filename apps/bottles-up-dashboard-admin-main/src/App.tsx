import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/contexts/AuthContext";
import ProtectedRoute from "@/components/ProtectedRoute";
import Index from "./pages/Index";
import Inventory from "./pages/Inventory";
import Users from "./pages/Users";
import Events from "./pages/Events";
import Vendors from "./pages/Vendors";
import Clubs from "./pages/Clubs";
import Bookings from "./pages/Bookings";
import Bottles from "./pages/Bottles";
import Login from "./pages/Login";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          {/* Public routes */}
          <Route path="/login" element={<Login />} />

          {/* Protected admin-only routes */}
          <Route path="/" element={<ProtectedRoute requireAdmin={true}><Index /></ProtectedRoute>} />
          <Route path="/users" element={<ProtectedRoute requireAdmin={true}><Users /></ProtectedRoute>} />
          <Route path="/inventory" element={<ProtectedRoute requireAdmin={true}><Inventory /></ProtectedRoute>} />
          <Route path="/events" element={<ProtectedRoute requireAdmin={true}><Events /></ProtectedRoute>} />
          <Route path="/vendors" element={<ProtectedRoute requireAdmin={true}><Vendors /></ProtectedRoute>} />
          <Route path="/clubs" element={<ProtectedRoute requireAdmin={true}><Clubs /></ProtectedRoute>} />
          <Route path="/bookings" element={<ProtectedRoute requireAdmin={true}><Bookings /></ProtectedRoute>} />
          <Route path="/bottles" element={<ProtectedRoute requireAdmin={true}><Bottles /></ProtectedRoute>} />

          <Route path="*" element={<NotFound />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  </QueryClientProvider>
);

export default App;
