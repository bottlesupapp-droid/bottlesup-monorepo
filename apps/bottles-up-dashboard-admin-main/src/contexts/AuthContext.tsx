import React, { createContext, useEffect, useState } from 'react'
import { User, Session, AuthError } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

interface AuthContextType {
  user: User | null
  session: Session | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<{ error: AuthError | null }>
  signOut: () => Promise<{ error: AuthError | null }>
  isAdmin: boolean
  checkUserAdminStatus: (userId: string) => Promise<boolean>
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined)

interface AuthProviderProps {
  children: React.ReactNode
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)

  // Returns true only when the user has a row in vendor_admins.
  // is_admin() SECURITY DEFINER function on the DB side enforces the same check server-side.
  const checkAdminStatus = async (u: User): Promise<boolean> => {
    try {
      const { data, error } = await Promise.race([
        supabase
          .from('vendor_admins')
          .select('id')
          .eq('id', u.id)
          .maybeSingle<{ id: string }>(),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error('Admin check timeout')), 10000)
        ),
      ])
      if (error || data === null) return false
      return true
    } catch {
      return false
    }
  }

  useEffect(() => {
    const getInitialSession = async () => {
      try {
        const { data: { session }, error } = await supabase.auth.getSession()
        if (error || !session) {
          setSession(null)
          setUser(null)
          setIsAdmin(false)
          setLoading(false)
          return
        }
        setSession(session)
        setUser(session.user)
        const adminOk = await checkAdminStatus(session.user)
        if (!adminOk) {
          // Valid Supabase session but not an admin — revoke immediately.
          await supabase.auth.signOut()
          setUser(null)
          setSession(null)
          setIsAdmin(false)
        } else {
          setIsAdmin(true)
        }
      } catch {
        setSession(null)
        setUser(null)
        setIsAdmin(false)
      } finally {
        setLoading(false)
      }
    }

    getInitialSession()

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        // SIGNED_OUT is the terminal event — just clear state.
        if (event === 'SIGNED_OUT' || !session) {
          setSession(null)
          setUser(null)
          setIsAdmin(false)
          setLoading(false)
          return
        }

        setSession(session)
        setUser(session.user)

        const adminOk = await checkAdminStatus(session.user)
        if (!adminOk) {
          // Revoke the session — the resulting SIGNED_OUT event will clear state.
          await supabase.auth.signOut()
          return
        }
        setIsAdmin(true)
        setLoading(false)
      }
    )

    return () => subscription.unsubscribe()
  }, [])

  const signIn = async (email: string, password: string): Promise<{ error: AuthError | null }> => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) return { error }

    const { data } = await supabase.auth.getSession()
    const u = data.session?.user
    if (u) {
      const adminOk = await checkAdminStatus(u)
      if (!adminOk) {
        await supabase.auth.signOut()
        // Return a synthetic AuthError-shaped object so callers can read .message
        return {
          error: {
            message: 'Access denied: admin privileges required. Contact your administrator.',
            status: 403,
            name: 'AuthApiError',
          } as unknown as AuthError,
        }
      }
      setIsAdmin(true)
    }
    return { error: null }
  }

  const signOut = async () => {
    const { error } = await supabase.auth.signOut()
    return { error }
  }

  const checkUserAdminStatus = async (userId: string): Promise<boolean> => {
    try {
      const { data, error } = await supabase
        .from('vendor_admins')
        .select('id')
        .eq('id', userId)
        .maybeSingle()
      if (error) return false
      return data !== null
    } catch {
      return false
    }
  }

  const value: AuthContextType = {
    user,
    session,
    loading,
    signIn,
    signOut,
    isAdmin,
    checkUserAdminStatus,
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}
