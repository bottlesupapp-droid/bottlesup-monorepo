// Matches actual Supabase schema for project hwmynlghrmtoufyrcihp
// Last synced: 2026-05-03 — tables: profiles(36), vendors(35), clubs(4), events(18),
//   clubs_bookings(5), vendor_inventory(5), bottles(34), categories(6), reviews(2)

export interface Profile {
  id: string
  name: string | null
  email: string | null
  phone_number: string | null
  age: number | null
  created_at: string
  updated_at: string
  avatar_url: string | null
  is_admin: boolean | null
  role: string | null
  verified: boolean | null
}

export interface Vendor {
  id: string
  email: string
  business_name: string | null
  created_at: string | null
  updated_at: string | null
  role: string | null
  phone: string | null
  logo_url: string | null
  stripe_account_id: string | null
  onboarding_completed: boolean | null
  two_fa_enabled: boolean | null
  /** 'active' | 'suspended' — managed by admin via approve/suspend actions */
  status: string | null
}

export interface AdminAuditLog {
  id: string
  admin_id: string
  action: string
  target_table: string
  target_id: string
  before: Record<string, unknown> | null
  after: Record<string, unknown> | null
  created_at: string
}

export interface VendorDetail {
  id: string
  vendor_id: string | null
  business_name: string | null
  business_type: string | null
  business_description: string | null
  phone_number: string | null
  email: string | null
  city: string | null
  state: string | null
  country: string | null
  is_verified: boolean | null
  verification_status: string | null
  verification_notes: string | null
  created_at: string | null
  updated_at: string | null
}

export interface Club {
  id: string
  name: string
  location: string
  description: string | null
  price_min: number | null
  price_max: number | null
  avg_rating: number | null
  review_count: number | null
  image_url: string | null
  phone: string | null
  email: string | null
  website_url: string | null
  opening_hours: unknown | null
  is_active: boolean | null
  created_at: string | null
  updated_at: string | null
  category_id: string | null
  dress_code: string | null
  age_requirement: string | null
  owner_id: string | null
}

export interface Event {
  id: string
  name: string
  description: string | null
  user_id: string | null
  category_id: string | null
  club_id: string | null
  zone_id: string | null
  images: string[] | null
  event_date: string
  start_time: string | null
  end_time: string | null
  ticket_price: number | null
  max_capacity: number | null
  current_bookings: number | null
  is_featured: boolean | null
  status: string | null
  is_active: boolean | null
  created_at: string | null
  updated_at: string | null
  dress_code: string | null
  rsvp_count: number | null
  city: string | null
  flyer_image_url: string | null
  revenue: number | null
  sales_count: number | null
  is_private: boolean | null
}

export interface VendorInventory {
  id: string
  name: string
  category: string | null
  brand: string | null
  description: string | null
  price: number
  stock: number | null
  min_stock: number | null
  vendor_id: string | null
  featured: boolean | null
  alcohol_content: number | null
  volume: number | null
  unit: string | null
  image_url: string | null
  tags: string[] | null
  created_at: string | null
  updated_at: string | null
}

export interface EventsBooking {
  id: string
  user_id: string | null
  event_id: string | null
  ticket_quantity: number | null
  ticket_price: number | null
  total_amount: number | null
  booking_date: string | null
  status: string | null
  attendee_names: string[] | null
  contact_phone: string | null
  contact_email: string | null
  confirmation_code: string | null
  payment_status: string | null
  payment_method: string | null
  payment_reference: string | null
  qr_code: string | null
  check_in_time: string | null
  notes: string | null
  created_at: string | null
  updated_at: string | null
}

export interface ClubsBooking {
  id: string
  user_id: string | null
  club_id: string | null
  zone_id: string | null
  booking_date: string | null
  visit_time: string | null
  guest_count: number | null
  total_amount: number | null
  booking_type: string | null
  status: string | null
  special_requests: string | null
  contact_phone: string | null
  contact_email: string | null
  confirmation_code: string | null
  payment_status: string | null
  payment_method: string | null
  notes: string | null
  created_at: string | null
  updated_at: string | null
}

export interface Review {
  id: string
  user_id: string | null
  club_id: string | null
  rating: number | null
  comment: string | null
  is_verified: boolean | null
  created_at: string | null
  updated_at: string | null
}

export interface Bottle {
  id: string
  club_id: string | null
  event_id: string | null
  name: string
  category: string | null
  subcategory: string | null
  brand: string | null
  price: number
  volume_ml: number | null
  alcohol_content: number | null
  description: string | null
  image_url: string | null
  is_available: boolean | null
  is_featured: boolean | null
  created_at: string | null
  updated_at: string | null
}

export interface Category {
  id: string
  name: string
  description: string | null
  icon: string | null
  color: string | null
  is_active: boolean | null
  created_at: string | null
  updated_at: string | null
}
