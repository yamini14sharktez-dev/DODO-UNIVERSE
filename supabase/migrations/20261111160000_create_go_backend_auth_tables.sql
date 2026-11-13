-- =============================================================================
-- Migration: 20261111160000_create_go_backend_auth_tables.sql
-- Description: Core Schema for Go Backend Authentication & Sessions
--
-- IMPORTANT ARCHITECTURAL NOTICE:
-- This migration is prepared for REVIEW ONLY per Phase 3 requirements.
-- DO NOT EXECUTE OR APPLY AUTOMATICALLY TO REMOTE DATABASE.
--
-- Compatibility & Identity Bridge Note:
-- The existing legacy 'public.profiles' table has a foreign key constraint:
--   FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- During the transition period:
-- 1. 'app_users' acts as the authoritative Go identity store.
-- 2. Go microservices query and update 'app_users' directly.
-- 3. Existing 'profiles' rows can be mapped by matching phone/email to app_users.id.
-- 4. When legacy Supabase Auth is fully deprecated in Phase 8, the profiles foreign key
--    will be updated to reference app_users(id) ON DELETE CASCADE.
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. Application Users Table (Authoritative User Identity)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL UNIQUE,
    phone_confirmed_at TIMESTAMPTZ,
    email TEXT,
    email_confirmed_at TIMESTAMPTZ,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'customer', 'provider', 'admin')),
    is_registration_complete BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Case-insensitive unique index on email (when present)
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_email_unique 
    ON public.app_users (LOWER(email)) 
    WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_app_users_phone ON public.app_users (phone);

-- -----------------------------------------------------------------------------
-- 2. Pending Registrations Table (Two-Step Multi-Device Verification)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_pending_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    mobile_number TEXT NOT NULL,
    email TEXT,
    full_name TEXT NOT NULL,
    registration_token_hash TEXT NOT NULL,
    is_mobile_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_pending_reg_mobile 
    ON public.app_pending_registrations (mobile_number);

CREATE INDEX IF NOT EXISTS idx_app_pending_reg_token_hash 
    ON public.app_pending_registrations (registration_token_hash);

-- -----------------------------------------------------------------------------
-- 3. Isolated OTP Challenges Table (Independent Purpose & Attempts Tracking)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_otp_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purpose TEXT NOT NULL CHECK (purpose IN ('mobile_registration', 'email_registration', 'login')),
    destination TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    reference_id UUID,
    failed_attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 5,
    is_consumed BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_otp_challenges_lookup 
    ON public.app_otp_challenges (destination, purpose, is_consumed, created_at DESC);

-- -----------------------------------------------------------------------------
-- 4. Application Sessions Table (Refresh Token Rotation & Revocation)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_token_hash ON public.app_sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_app_sessions_user_id ON public.app_sessions (user_id);

-- -----------------------------------------------------------------------------
-- 5. Development Test Numbers Table (Safeguarded Multi-Number Testing)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dev_auth_test_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mobile_number TEXT NOT NULL UNIQUE,
    test_otp TEXT,
    test_otp_hash TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

