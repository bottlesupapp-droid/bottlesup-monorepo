import React, { useEffect } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { Loader2 } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'

interface ProtectedRouteProps {
  children: React.ReactNode
  requireAdmin?: boolean
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requireAdmin = false,
}) => {
  const { user, loading, isAdmin, signOut } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()

  // Belt-and-suspenders: if a valid session somehow reaches the UI but the user
  // is not an admin (e.g. role was revoked mid-session), sign them out immediately.
  useEffect(() => {
    if (!loading && user && requireAdmin && !isAdmin) {
      signOut().then(() => {
        navigate('/login', {
          replace: true,
          state: { error: 'Access denied: admin privileges required.' },
        })
      })
    }
  }, [loading, user, requireAdmin, isAdmin, signOut, navigate])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="w-full max-w-md">
          <CardContent className="flex flex-col items-center justify-center p-8">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600 mb-4" />
            <p className="text-gray-600">Verifying access...</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  // Non-admin with active session: render nothing while the useEffect signs them out.
  if (requireAdmin && !isAdmin) {
    return null
  }

  return <>{children}</>
}

export default ProtectedRoute
