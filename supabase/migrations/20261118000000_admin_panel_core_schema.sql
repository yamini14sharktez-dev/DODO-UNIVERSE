-- =============================================================================
-- Migration: 20261118000000_admin_panel_core_schema.sql
-- Description: Core Schema for DODO Universe Admin Panel & Management Engine
-- Scope: Admin Panel ONLY (No customer/vendor UI dependencies)
-- =============================================================================

BEGIN;

-- Ensure extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. Admin Users & Roles (RBAC: Super Admin, Operations Admin, Finance Admin)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'admin_role_enum') THEN
        CREATE TYPE admin_role_enum AS ENUM ('super_admin', 'operations_admin', 'finance_admin');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role admin_role_enum NOT NULL DEFAULT 'operations_admin',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    failed_login_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_admin_users_email ON public.admin_users (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_admin_users_phone ON public.admin_users (phone);

-- Admin Sessions for JWT Refresh Token Management
CREATE TABLE IF NOT EXISTS public.admin_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON public.admin_sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin ON public.admin_sessions (admin_id);

-- -----------------------------------------------------------------------------
-- 2. Immutable Audit Logs (Action Trail for All Administrative Writes)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    admin_name TEXT NOT NULL,
    admin_role TEXT NOT NULL,
    action TEXT NOT NULL,             -- 'CREATE', 'UPDATE', 'DELETE', 'APPROVE', 'REJECT', 'SUSPEND', 'ACTIVATE'
    entity_type TEXT NOT NULL,        -- 'user', 'vendor_application', 'category', 'form', 'listing', 'order', 'setting'
    entity_id TEXT NOT NULL,
    old_values JSONB,
    new_values JSONB,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_filter 
    ON public.audit_logs (entity_type, action, created_at DESC);

-- -----------------------------------------------------------------------------
-- 3. Services & Categories (Unlimited Hierarchical Nesting via parent_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES public.service_categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    icon_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0,
    category_type TEXT NOT NULL DEFAULT 'container' 
        CHECK (category_type IN ('container', 'product_category', 'bookable_service', 'hybrid')),
    allow_listings BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_service_categories_parent 
    ON public.service_categories (parent_id, sort_order ASC);

-- -----------------------------------------------------------------------------
-- 4. Dynamic Form Definitions (Service-Specific Form Builder with Versioning)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.form_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES public.service_categories(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    version INT NOT NULL DEFAULT 1,
    schema JSONB NOT NULL DEFAULT '{"fields": []}'::jsonb,
    created_by UUID REFERENCES public.admin_users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    CONSTRAINT uq_category_form_version UNIQUE (category_id, version)
);

CREATE INDEX IF NOT EXISTS idx_form_definitions_cat 
    ON public.form_definitions (category_id, status);

-- -----------------------------------------------------------------------------
-- 5. Vendor Applications (Review, Document Verification, and Approval)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vendor_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.service_categories(id),
    business_name TEXT NOT NULL,
    business_type TEXT,
    status TEXT NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'under_review', 'approved', 'rejected', 'info_requested')),
    submitted_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    documents JSONB NOT NULL DEFAULT '[]'::jsonb,
    rejection_reason TEXT,
    info_request_notes TEXT,
    reviewed_by UUID REFERENCES public.admin_users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_vendor_applications_status 
    ON public.vendor_applications (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vendor_applications_user 
    ON public.vendor_applications (user_id);

-- -----------------------------------------------------------------------------
-- 6. Products & Listings Configuration (Approval, Units, Transport)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.service_categories(id),
    title TEXT NOT NULL,
    description TEXT,
    listing_type TEXT NOT NULL 
        CHECK (listing_type IN ('product_only', 'bookable_service', 'product_transportation', 'custom_quote')),
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    pricing_unit TEXT NOT NULL, -- e.g. 'piece', 'ton', 'sq_ft', 'hour'
    min_order_quantity NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
    has_transportation BOOLEAN NOT NULL DEFAULT FALSE,
    transportation_fee NUMERIC(12, 2) DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    approval_status TEXT NOT NULL DEFAULT 'pending' 
        CHECK (approval_status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_product_listings_status 
    ON public.product_listings (approval_status, is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_listings_vendor 
    ON public.product_listings (vendor_id);

-- -----------------------------------------------------------------------------
-- 7. Orders & Bookings (Status, Quantities, Pricing, Disputes)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.app_users(id),
    vendor_id UUID NOT NULL REFERENCES public.app_users(id),
    listing_id UUID REFERENCES public.product_listings(id),
    status TEXT NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'vendor_accepted', 'in_progress', 'completed', 'cancelled', 'disputed')),
    total_amount NUMERIC(12, 2) NOT NULL,
    commission_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    order_details JSONB NOT NULL DEFAULT '{}'::jsonb,
    dispute_reason TEXT,
    dispute_resolution TEXT,
    resolved_by UUID REFERENCES public.admin_users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON public.orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_vendor ON public.orders (vendor_id);

-- -----------------------------------------------------------------------------
-- 8. Requests & Quotations (RFQs and Vendor Bids)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.quotation_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.app_users(id),
    category_id UUID REFERENCES public.service_categories(id),
    title TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'responded', 'closed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_quotation_requests_status 
    ON public.quotation_requests (status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.quotation_requests(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES public.app_users(id),
    offered_price NUMERIC(12, 2) NOT NULL,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_quotations_request ON public.quotations (request_id);

-- -----------------------------------------------------------------------------
-- 9. Payments & Commission (Ledger & Rules)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id),
    payer_id UUID REFERENCES public.app_users(id),
    amount NUMERIC(12, 2) NOT NULL,
    payment_type TEXT NOT NULL CHECK (payment_type IN ('order_payment', 'vendor_payout', 'refund')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'successful', 'failed')),
    reference_number TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_payment_records_type_status 
    ON public.payment_records (payment_type, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.service_categories(id) ON DELETE CASCADE,
    commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
    fixed_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- -----------------------------------------------------------------------------
-- 10. Notifications & Platform Announcements
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_role TEXT NOT NULL DEFAULT 'all' CHECK (target_role IN ('all', 'customers', 'vendors', 'admins')),
    is_broadcast BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES public.admin_users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- -----------------------------------------------------------------------------
-- 11. Reviews & Reports Moderation
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.platform_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id),
    author_id UUID NOT NULL REFERENCES public.app_users(id),
    target_id UUID NOT NULL REFERENCES public.app_users(id), -- user or vendor
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('published', 'flagged', 'hidden')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE TABLE IF NOT EXISTS public.platform_complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complainant_id UUID NOT NULL REFERENCES public.app_users(id),
    order_id UUID REFERENCES public.orders(id),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_investigation', 'resolved', 'dismissed')),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES public.admin_users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- -----------------------------------------------------------------------------
-- 12. System Settings (Platform-wide Administrative Configuration)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_by UUID REFERENCES public.admin_users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Initialize essential default platform settings if not present
INSERT INTO public.system_settings (key, value, description)
VALUES 
    ('platform_maintenance_mode', '{"enabled": false, "message": "Scheduled maintenance in progress"}'::jsonb, 'Maintenance mode toggle'),
    ('default_commission_rate', '{"percent": 10.0, "fixed_fee": 0.0}'::jsonb, 'Global default platform commission rate'),
    ('allowed_upload_formats', '{"images": ["jpg", "jpeg", "png", "webp"], "documents": ["pdf", "doc", "docx"]}'::jsonb, 'Permitted document and image file extensions')
ON CONFLICT (key) DO NOTHING;

COMMIT;
