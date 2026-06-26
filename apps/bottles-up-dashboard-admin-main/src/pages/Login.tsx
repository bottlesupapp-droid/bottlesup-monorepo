import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Loader2, Eye, EyeOff, Lock } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'

// ── In-memory rate limiter ────────────────────────────────────────────────────
const MAX_ATTEMPTS = 5
const LOCKOUT_MS = 15 * 60 * 1000 // 15 minutes

interface AttemptRecord { attempts: number; lockedUntil?: number }
const _records = new Map<string, AttemptRecord>()

function isLocked(key: string): boolean {
  const r = _records.get(key)
  if (!r || r.attempts < MAX_ATTEMPTS) return false
  if (r.lockedUntil && Date.now() < r.lockedUntil) return true
  _records.delete(key) // lockout expired
  return false
}
function lockoutRemaining(key: string): number {
  if (!isLocked(key)) return 0
  return Math.max(0, (_records.get(key)!.lockedUntil ?? 0) - Date.now())
}
function recordFailure(key: string): void {
  const r = _records.get(key)
  const attempts = (r?.attempts ?? 0) + 1
  _records.set(key, {
    attempts,
    lockedUntil: attempts >= MAX_ATTEMPTS ? Date.now() + LOCKOUT_MS : r?.lockedUntil,
  })
}
function attemptsLeft(key: string): number {
  return Math.max(0, MAX_ATTEMPTS - (_records.get(key)?.attempts ?? 0))
}
function resetAttempts(key: string): void { _records.delete(key) }

function fmtMs(ms: number): string {
  const total = Math.ceil(ms / 1000)
  const m = Math.floor(total / 60).toString().padStart(2, '0')
  const s = (total % 60).toString().padStart(2, '0')
  return `${m}:${s}`
}
// ─────────────────────────────────────────────────────────────────────────────

const Login: React.FC = () => {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [lockoutMs, setLockoutMs] = useState(0)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const { signIn, user } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()

  const locationState = location.state as { from?: { pathname?: string }; error?: string } | null
  const fromPath = locationState?.from?.pathname ?? '/'

  useEffect(() => {
    if (locationState?.error) setError(locationState.error)
  }, [locationState?.error])

  useEffect(() => {
    if (user) navigate(fromPath, { replace: true })
  }, [user, navigate, fromPath])

  const startLockoutTick = useCallback((key: string) => {
    if (timerRef.current) clearInterval(timerRef.current)
    timerRef.current = setInterval(() => {
      const ms = lockoutRemaining(key)
      setLockoutMs(ms)
      if (ms <= 0 && timerRef.current) clearInterval(timerRef.current)
    }, 1000)
  }, [])

  useEffect(() => () => { if (timerRef.current) clearInterval(timerRef.current) }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    // Sanitise — trim and lower-case email
    const key = email.trim().toLowerCase()

    if (!key || !password) {
      setError('Please fill in all fields')
      return
    }

    // Validate email format
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(key)) {
      setError('Please enter a valid email address')
      return
    }

    // Enforce field-length limits (prevents oversized payloads)
    if (key.length > 254 || password.length > 128) {
      setError('Input too long')
      return
    }

    if (isLocked(key)) {
      const ms = lockoutRemaining(key)
      setLockoutMs(ms)
      startLockoutTick(key)
      return
    }

    setLoading(true)
    try {
      const { error: signInError } = await signIn(key, password)
      if (signInError) {
        recordFailure(key)
        const left = attemptsLeft(key)
        if (isLocked(key)) {
          const ms = lockoutRemaining(key)
          setLockoutMs(ms)
          startLockoutTick(key)
          setError(`Too many failed attempts. Account locked for 15 minutes.`)
        } else if (left <= 2) {
          setError(`${signInError.message} (${left} attempt${left === 1 ? '' : 's'} left before lockout)`)
        } else {
          setError(signInError.message)
        }
      } else {
        resetAttempts(key)
        navigate(fromPath, { replace: true })
      }
    } catch {
      setError('An unexpected error occurred')
    } finally {
      setLoading(false)
    }
  }

  const locked = lockoutMs > 0

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Bottles Up</h1>
          <p className="text-gray-600">Admin Dashboard</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Sign In</CardTitle>
            <CardDescription>
              Enter your admin credentials to access the dashboard
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <Alert variant="destructive">
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              )}

              {locked && (
                <Alert className="border-orange-300 bg-orange-50 text-orange-800">
                  <Lock className="h-4 w-4 text-orange-600" />
                  <AlertDescription className="ml-2">
                    Account locked. Try again in <strong>{fmtMs(lockoutMs)}</strong>
                  </AlertDescription>
                </Alert>
              )}

              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="admin@bottlesup.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  disabled={loading || locked}
                  maxLength={254}
                  autoComplete="username"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    placeholder="Enter your password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    disabled={loading || locked}
                    maxLength={128}
                    autoComplete="current-password"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="absolute right-0 top-0 h-full px-3 py-2 hover:bg-transparent"
                    onClick={() => setShowPassword(!showPassword)}
                    disabled={loading || locked}
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </Button>
                </div>
              </div>

              <Button
                type="submit"
                className="w-full"
                disabled={loading || locked}
              >
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Signing in...
                  </>
                ) : locked ? (
                  <>
                    <Lock className="mr-2 h-4 w-4" />
                    Locked — {fmtMs(lockoutMs)}
                  </>
                ) : (
                  'Sign In'
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        <div className="text-center text-xs text-gray-500">
          <p>Admin access required. Contact your administrator to request access.</p>
        </div>
      </div>
    </div>
  )
}

export default Login
