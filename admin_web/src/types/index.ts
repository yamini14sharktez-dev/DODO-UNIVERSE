export type AdminRole = 'super_admin' | 'operations_admin' | 'finance_admin';

export interface AdminUser {
  id: string;
  email: string;
  phone: string;
  full_name: string;
  role: AdminRole;
  is_active: boolean;
  last_login_at?: string;
  created_at: string;
  updated_at: string;
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

export interface AdminAuthResponse {
  admin: AdminUser;
  tokens: AuthTokens;
}

export interface AuditLog {
  id: string;
  admin_id?: string;
  admin_name: string;
  admin_role: string;
  action: string;
  entity_type: string;
  entity_id: string;
  old_values?: any;
  new_values?: any;
  ip_address?: string;
  created_at: string;
}

export interface DashboardMetrics {
  total_people: number;
  active_vendors: number;
  pending_vendor_applications: number;
  total_services: number;
  total_categories: number;
  total_listings: number;
  total_orders: number;
  pending_orders: number;
  completed_orders: number;
  cancelled_orders: number;
  pending_quote_requests: number;
  total_payment_volume: number;
  recent_activity: AuditLog[];
}

export interface Person {
  id: string;
  phone: string;
  phone_confirmed_at?: string;
  email?: string;
  email_confirmed_at?: string;
  full_name: string;
  role: string;
  is_registration_complete: boolean;
  created_at: string;
  updated_at: string;
}

export interface VendorApplication {
  id: string;
  user_id: string;
  user_full_name?: string;
  user_phone?: string;
  user_email?: string;
  category_id?: string;
  category_name?: string;
  business_name: string;
  business_type?: string;
  status: 'pending' | 'under_review' | 'approved' | 'rejected' | 'info_requested';
  submitted_data: Record<string, any>;
  documents: Array<{ name: string; url: string; type: string }>;
  rejection_reason?: string;
  info_request_notes?: string;
  reviewed_by?: string;
  reviewed_at?: string;
  created_at: string;
  updated_at: string;
}

export interface ServiceCategory {
  id: string;
  parent_id?: string;
  name: string;
  slug: string;
  description?: string;
  icon_url?: string;
  is_active: boolean;
  sort_order: number;
  category_type: 'container' | 'product_category' | 'bookable_service' | 'hybrid';
  allow_listings: boolean;
  children?: ServiceCategory[];
  created_at: string;
  updated_at: string;
}

export interface FormField {
  id: string;
  type: 'text' | 'number' | 'phone' | 'email' | 'dropdown' | 'radio' | 'checkbox' | 'date' | 'document_upload' | 'image_upload';
  label: string;
  placeholder?: string;
  required: boolean;
  options?: string[];
  validation_regex?: string;
  min?: number;
  max?: number;
  help_text?: string;
}

export interface FormDefinition {
  id?: string;
  category_id: string;
  title: string;
  description?: string;
  status: 'draft' | 'published' | 'archived';
  version: number;
  schema: {
    fields: FormField[];
  };
  created_by?: string;
  created_at?: string;
  updated_at?: string;
}

export interface ProductListing {
  id: string;
  vendor_id: string;
  vendor_name?: string;
  category_id: string;
  category_name?: string;
  title: string;
  description?: string;
  listing_type: 'product_only' | 'bookable_service' | 'product_transportation' | 'custom_quote';
  unit_price: number;
  pricing_unit: string;
  min_order_quantity: number;
  has_transportation: boolean;
  transportation_fee: number;
  is_active: boolean;
  approval_status: 'pending' | 'approved' | 'rejected';
  created_at: string;
  updated_at: string;
}

export interface AdminOrder {
  id: string;
  customer_id: string;
  customer_name?: string;
  customer_phone?: string;
  vendor_id: string;
  vendor_name?: string;
  vendor_phone?: string;
  listing_id?: string;
  listing_title?: string;
  status: 'pending' | 'vendor_accepted' | 'in_progress' | 'completed' | 'cancelled' | 'disputed';
  total_amount: number;
  commission_amount: number;
  order_details: Record<string, any>;
  dispute_reason?: string;
  dispute_resolution?: string;
  resolved_by?: string;
  resolved_at?: string;
  created_at: string;
  updated_at: string;
}

export interface QuotationRequest {
  id: string;
  customer_id: string;
  customer_name?: string;
  category_id?: string;
  category_name?: string;
  title: string;
  details: Record<string, any>;
  status: 'open' | 'responded' | 'closed' | 'cancelled';
  quotations?: Array<{
    id: string;
    vendor_id: string;
    vendor_name: string;
    offered_price: number;
    notes?: string;
    status: string;
    created_at: string;
  }>;
  created_at: string;
  updated_at: string;
}

export interface PaymentRecord {
  id: string;
  order_id?: string;
  payer_id?: string;
  payer_name?: string;
  amount: number;
  payment_type: 'order_payment' | 'vendor_payout' | 'refund';
  status: 'pending' | 'successful' | 'failed';
  reference_number?: string;
  notes?: string;
  created_at: string;
}

export interface CommissionRule {
  id: string;
  category_id?: string;
  category_name?: string;
  commission_percent: number;
  fixed_fee: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}
