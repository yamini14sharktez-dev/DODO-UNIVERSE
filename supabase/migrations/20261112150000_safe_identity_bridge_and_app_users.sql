-- =============================================================================
-- Migration: 20261112150000_safe_identity_bridge_and_app_users.sql
-- Description: Production-Hardened Identity Bridge & Go Backend Schema
-- Architecture: Go Microservices (Auth/Logic) + Supabase PostgreSQL (Storage)
--
-- SAFETY & COMPATIBILITY GUARANTEES:
-- 1. NO placeholder or invented phone/email data. Nullable fields remain NULL.
-- 2. Phone Uniqueness: Enforced on the canonical last 10 digits across all formats.
-- 3. Loop-Free Sync: Triple-guarded synchronization (session-scoped config,
--    IS DISTINCT FROM change detection, and pg_trigger_depth guard).
-- 4. 100% UUID preservation for all existing auth.users and profiles.
-- 5. Safe Deletions: Cascading delete trigger from auth.users with error shielding.
-- 6. Zero Business Data Loss: Preserves all tables, constraints, and audit data.
-- 7. 100% Idempotent: Can safely be re-run or resumed if interrupted.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Step 1: Ensure Required Extensions
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- Step 2: Track Account Origin on 'public.profiles' (Rollback Enabler)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS origin TEXT NOT NULL DEFAULT 'supabase_auth';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_origin_check'
    ) THEN
        ALTER TABLE public.profiles 
            ADD CONSTRAINT profiles_origin_check 
            CHECK (origin IN ('supabase_auth', 'go_backend'));
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Step 3: Create Authoritative 'public.app_users' Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT,                                 -- Nullable for legacy email users
    phone_confirmed_at TIMESTAMPTZ,             -- Null unless genuinely confirmed
    email TEXT,                                 -- Nullable for mobile-only users
    email_confirmed_at TIMESTAMPTZ,             -- Null unless genuinely confirmed
    full_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'customer', 'provider', 'admin')),
    is_registration_complete BOOLEAN NOT NULL DEFAULT FALSE,
    origin TEXT NOT NULL DEFAULT 'go_backend' CHECK (origin IN ('supabase_auth', 'go_backend')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- Canonical 10-digit uniqueness index: prevents duplicates across different formats
-- (e.g., '9876543210', '+919876543210', '09876543210')
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_phone_10digits_unique 
    ON public.app_users (RIGHT(regexp_replace(phone, '\D', '', 'g'), 10)) 
    WHERE phone IS NOT NULL AND length(regexp_replace(phone, '\D', '', 'g')) >= 10;

-- Case-insensitive unique index on normalized email
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_email_unique 
    ON public.app_users (LOWER(TRIM(email))) 
    WHERE email IS NOT NULL AND TRIM(email) != '';

CREATE INDEX IF NOT EXISTS idx_app_users_created_at ON public.app_users (created_at DESC);

-- -----------------------------------------------------------------------------
-- Step 4: Seed / Backfill Existing Users (Strict Authenticity, Zero Invention)
-- -----------------------------------------------------------------------------
INSERT INTO public.app_users (
    id,
    phone,
    phone_confirmed_at,
    email,
    email_confirmed_at,
    full_name,
    role,
    is_registration_complete,
    origin,
    created_at,
    updated_at
)
SELECT
    COALESCE(p.id, u.id) AS id,
    u.phone AS phone,
    u.phone_confirmed_at AS phone_confirmed_at,
    u.email AS email,
    u.email_confirmed_at AS email_confirmed_at,
    COALESCE(NULLIF(p.full_name, ''), NULLIF(u.raw_user_meta_data->>'full_name', ''), 'DODO User') AS full_name,
    'user' AS role,
    -- Authentic confirmation only: requires genuine confirmation of available channels
    (COALESCE(p.is_registration_complete, FALSE)
     AND (u.phone IS NULL OR u.phone_confirmed_at IS NOT NULL)
     AND (u.email IS NULL OR u.email_confirmed_at IS NOT NULL)) AS is_registration_complete,
    'supabase_auth' AS origin,
    COALESCE(p.created_at, u.created_at, pg_catalog.now()) AS created_at,
    COALESCE(p.updated_at, u.updated_at, pg_catalog.now()) AS updated_at
FROM public.profiles p
FULL OUTER JOIN auth.users u ON u.id = p.id
ON CONFLICT (id) DO UPDATE SET
    phone = EXCLUDED.phone,
    phone_confirmed_at = EXCLUDED.phone_confirmed_at,
    email = EXCLUDED.email,
    email_confirmed_at = EXCLUDED.email_confirmed_at,
    full_name = EXCLUDED.full_name,
    is_registration_complete = EXCLUDED.is_registration_complete,
    updated_at = EXCLUDED.updated_at;

-- Ensure missing profile rows are backfilled for any orphan auth.users
INSERT INTO public.profiles (
    id,
    full_name,
    is_registration_complete,
    origin,
    created_at,
    updated_at
)
SELECT
    a.id,
    a.full_name,
    a.is_registration_complete,
    a.origin,
    a.created_at,
    a.updated_at
FROM public.app_users a
ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    is_registration_complete = EXCLUDED.is_registration_complete,
    origin = EXCLUDED.origin,
    updated_at = EXCLUDED.updated_at;

-- -----------------------------------------------------------------------------
-- Step 5: Transfer Foreign Key Constraint on 'public.profiles'
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    constraint_rec RECORD;
BEGIN
    FOR constraint_rec IN 
        SELECT conname 
        FROM pg_constraint 
        WHERE conrelid = 'public.profiles'::regclass 
          AND contype = 'f' 
          AND confrelid = 'auth.users'::regclass
    LOOP
        EXECUTE 'ALTER TABLE public.profiles DROP CONSTRAINT ' || quote_ident(constraint_rec.conname);
    END LOOP;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'public.profiles'::regclass 
          AND conname = 'profiles_app_users_fk'
    ) THEN
        ALTER TABLE public.profiles 
            ADD CONSTRAINT profiles_app_users_fk 
            FOREIGN KEY (id) REFERENCES public.app_users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Step 6: Robust Multi-Guarded Synchronization Triggers
-- -----------------------------------------------------------------------------

-- 6.1 Sync from app_users -> profiles
CREATE OR REPLACE FUNCTION public.sync_app_user_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Layer 1: Session-variable loop guard
    IF current_setting('dodo.sync_in_progress', true) = 'true' THEN
        RETURN NEW;
    END IF;

    -- Layer 2: Global trigger depth guard
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Set transaction-local sync flag
    PERFORM set_config('dodo.sync_in_progress', 'true', true);

    INSERT INTO public.profiles (
        id,
        full_name,
        is_registration_complete,
        origin,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.full_name,
        NEW.is_registration_complete,
        NEW.origin,
        NEW.created_at,
        NEW.updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        is_registration_complete = EXCLUDED.is_registration_complete,
        origin = EXCLUDED.origin,
        updated_at = EXCLUDED.updated_at;

    PERFORM set_config('dodo.sync_in_progress', 'false', true);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_app_user_to_profile ON public.app_users;
CREATE TRIGGER trg_sync_app_user_to_profile
    AFTER INSERT OR UPDATE ON public.app_users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_app_user_to_profile();

-- 6.2 Sync from profiles -> app_users (protects legacy writes to profiles)
CREATE OR REPLACE FUNCTION public.sync_profile_to_app_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Layer 1: Session-variable loop guard
    IF current_setting('dodo.sync_in_progress', true) = 'true' THEN
        RETURN NEW;
    END IF;

    -- Layer 2: Global trigger depth guard
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Set transaction-local sync flag
    PERFORM set_config('dodo.sync_in_progress', 'true', true);

    UPDATE public.app_users
    SET full_name = NEW.full_name,
        is_registration_complete = NEW.is_registration_complete,
        updated_at = NEW.updated_at
    WHERE id = NEW.id;

    PERFORM set_config('dodo.sync_in_progress', 'false', true);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_to_app_user ON public.profiles;
CREATE TRIGGER trg_sync_profile_to_app_user
    AFTER UPDATE OF full_name, is_registration_complete ON public.profiles
    FOR EACH ROW
    WHEN (
        OLD.full_name IS DISTINCT FROM NEW.full_name OR
        OLD.is_registration_complete IS DISTINCT FROM NEW.is_registration_complete
    )
    EXECUTE FUNCTION public.sync_profile_to_app_user();

-- 6.3 Safe auth.users deletion cascade with error shielding
CREATE OR REPLACE FUNCTION public.sync_auth_user_delete_to_app_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Shielded deletion: never aborts an auth.users deletion in Supabase Studio
    BEGIN
        DELETE FROM public.app_users WHERE id = OLD.id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Cascade delete from auth.users to app_users failed for user %: %', OLD.id, SQLERRM;
    END;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_auth_user_delete ON auth.users;
CREATE TRIGGER trg_sync_auth_user_delete
    AFTER DELETE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_auth_user_delete_to_app_user();

-- -----------------------------------------------------------------------------
-- Step 7: Create Remaining Go Backend Tables (Idempotent)
-- -----------------------------------------------------------------------------

-- 7.1 Pending Registrations
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    verified_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_pending_reg_mobile 
    ON public.app_pending_registrations (mobile_number);

CREATE INDEX IF NOT EXISTS idx_app_pending_reg_token_hash 
    ON public.app_pending_registrations (registration_token_hash);

-- 7.2 Isolated OTP Challenges Table
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    verified_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_otp_challenges_lookup 
    ON public.app_otp_challenges (destination, purpose, is_consumed, created_at DESC);

-- 7.3 Sessions Table (Refresh Token Rotation)
CREATE TABLE IF NOT EXISTS public.app_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_token_hash ON public.app_sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_app_sessions_user_id ON public.app_sessions (user_id);

-- 7.4 Development Test Numbers Table (Ensures Presence & Integrity)
CREATE TABLE IF NOT EXISTS public.dev_auth_test_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mobile_number TEXT NOT NULL UNIQUE,
    test_otp_hash TEXT NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

-- -----------------------------------------------------------------------------
-- Step 8: Row-Level Security & Grants
-- -----------------------------------------------------------------------------
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_pending_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_otp_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_sessions ENABLE ROW LEVEL SECURITY;

-- Block anonymous/public direct HTTP access (PostgREST)
REVOKE ALL ON TABLE public.app_users FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.app_pending_registrations FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.app_otp_challenges FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.app_sessions FROM PUBLIC, anon;

-- Keep authenticated SELECT on profiles for client read compatibility
GRANT SELECT ON TABLE public.profiles TO authenticated;

COMMIT;
