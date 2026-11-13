-- =============================================================================
-- Migration: 20261109120000_create_dev_auth_tables.sql
-- Description: Development-only test tables, pending registration storage,
--              atomic verification functions, and profile completion enforcement.
-- Security: Least privilege, no public/anon access, server-side RLS enforcement.
-- =============================================================================

-- 1. Ensure cryptographic hashing extension is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Add trusted registration completion status to public.profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_registration_complete BOOLEAN NOT NULL DEFAULT false;

-- Restrict column-level UPDATE on profiles: authenticated users can update full_name,
-- but CANNOT update is_registration_complete (only service_role / server logic can).
REVOKE ALL ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT UPDATE (full_name) ON public.profiles TO authenticated;

-- Update RLS policies: users can view their own profile (to read authoritative registration status)
-- and can only update their profile once registration is complete.
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING ( (SELECT auth.uid()) = id );

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING ( (SELECT auth.uid()) = id AND is_registration_complete = true )
    WITH CHECK ( (SELECT auth.uid()) = id AND is_registration_complete = true );

-- 3. Development test numbers configuration table
CREATE TABLE IF NOT EXISTS public.dev_auth_test_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mobile_number TEXT NOT NULL UNIQUE,
    test_otp_hash TEXT NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    failed_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    CONSTRAINT valid_indian_e164 CHECK (mobile_number ~ '^\+91[6-9][0-9]{9}$')
);

-- Deny all access to public, anon, and authenticated users
REVOKE ALL ON TABLE public.dev_auth_test_numbers FROM PUBLIC, anon, authenticated;
ALTER TABLE public.dev_auth_test_numbers ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS set_dev_auth_test_numbers_updated_at ON public.dev_auth_test_numbers;
CREATE TRIGGER set_dev_auth_test_numbers_updated_at
    BEFORE UPDATE ON public.dev_auth_test_numbers
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- 4. Development pending registration & email OTP storage table
CREATE TABLE IF NOT EXISTS public.dev_auth_pending_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    mobile_number TEXT NOT NULL,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    registration_token_hash TEXT NOT NULL,
    email_otp_hash TEXT NOT NULL,
    failed_attempts INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (pg_catalog.now() + interval '15 minutes'),
    is_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_dev_pending_reg_token ON public.dev_auth_pending_registrations (registration_token_hash);
CREATE INDEX IF NOT EXISTS idx_dev_pending_reg_email ON public.dev_auth_pending_registrations (email);

-- Deny all access to public, anon, and authenticated users
REVOKE ALL ON TABLE public.dev_auth_pending_registrations FROM PUBLIC, anon, authenticated;
ALTER TABLE public.dev_auth_pending_registrations ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS set_dev_auth_pending_registrations_updated_at ON public.dev_auth_pending_registrations;
CREATE TRIGGER set_dev_auth_pending_registrations_updated_at
    BEFORE UPDATE ON public.dev_auth_pending_registrations
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- 5. Atomic Server-Side Verification Functions (Executable only by service_role)

-- Atomic mobile OTP check with brute-force lockout
CREATE OR REPLACE FUNCTION public.dev_verify_mobile_otp(
    p_mobile TEXT,
    p_otp TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_record public.dev_auth_test_numbers%ROWTYPE;
BEGIN
    SELECT * INTO v_record
    FROM public.dev_auth_test_numbers
    WHERE mobile_number = p_mobile
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_found');
    END IF;

    IF NOT v_record.is_enabled THEN
        RETURN jsonb_build_object('success', false, 'error', 'disabled');
    END IF;

    IF v_record.locked_until IS NOT NULL AND v_record.locked_until > pg_catalog.now() THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'locked',
            'locked_until', v_record.locked_until
        );
    END IF;

    -- Verify bcrypt hash
    IF v_record.test_otp_hash = extensions.crypt(p_otp, v_record.test_otp_hash) THEN
        UPDATE public.dev_auth_test_numbers
        SET failed_attempts = 0, locked_until = NULL, updated_at = pg_catalog.now()
        WHERE id = v_record.id;

        RETURN jsonb_build_object('success', true);
    ELSE
        IF v_record.failed_attempts + 1 >= 5 THEN
            UPDATE public.dev_auth_test_numbers
            SET failed_attempts = v_record.failed_attempts + 1,
                locked_until = pg_catalog.now() + interval '15 minutes',
                updated_at = pg_catalog.now()
            WHERE id = v_record.id;

            RETURN jsonb_build_object('success', false, 'error', 'locked');
        ELSE
            UPDATE public.dev_auth_test_numbers
            SET failed_attempts = v_record.failed_attempts + 1,
                updated_at = pg_catalog.now()
            WHERE id = v_record.id;

            RETURN jsonb_build_object(
                'success', false,
                'error', 'invalid_otp',
                'attempts_remaining', 5 - (v_record.failed_attempts + 1)
            );
        END IF;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.dev_verify_mobile_otp(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- Atomic pending registration creator
CREATE OR REPLACE FUNCTION public.dev_create_pending_registration(
    p_auth_user_id UUID,
    p_mobile TEXT,
    p_email TEXT,
    p_full_name TEXT,
    p_token_hash TEXT,
    p_email_otp TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Invalidate any prior pending registration for this mobile or email
    DELETE FROM public.dev_auth_pending_registrations
    WHERE mobile_number = p_mobile OR LOWER(email) = LOWER(p_email);

    INSERT INTO public.dev_auth_pending_registrations (
        auth_user_id,
        mobile_number,
        email,
        full_name,
        registration_token_hash,
        email_otp_hash,
        expires_at
    )
    VALUES (
        p_auth_user_id,
        p_mobile,
        p_email,
        p_full_name,
        p_token_hash,
        extensions.crypt(p_email_otp, extensions.gen_salt('bf', 10)),
        pg_catalog.now() + interval '15 minutes'
    );

    RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.dev_create_pending_registration(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- Atomic email OTP verification & registration completion
CREATE OR REPLACE FUNCTION public.dev_verify_email_otp(
    p_token_hash TEXT,
    p_email TEXT,
    p_otp TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_pending public.dev_auth_pending_registrations%ROWTYPE;
BEGIN
    SELECT * INTO v_pending
    FROM public.dev_auth_pending_registrations
    WHERE registration_token_hash = p_token_hash
      AND LOWER(email) = LOWER(p_email)
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_found');
    END IF;

    IF v_pending.expires_at < pg_catalog.now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'expired');
    END IF;

    -- Scenario B Idempotency: If already verified within 15 minutes, allow retrying magic-link issuance
    IF v_pending.is_verified THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_verified', true,
            'auth_user_id', v_pending.auth_user_id,
            'mobile_number', v_pending.mobile_number,
            'email', v_pending.email
        );
    END IF;

    -- If already exceeded 5 attempts, ensure registration is purged and reject
    IF v_pending.failed_attempts >= 5 THEN
        DELETE FROM public.dev_auth_pending_registrations WHERE id = v_pending.id;
        RETURN jsonb_build_object('success', false, 'error', 'max_attempts_exceeded');
    END IF;

    IF v_pending.email_otp_hash = extensions.crypt(p_otp, v_pending.email_otp_hash) THEN
        -- Mark pending registration verified
        UPDATE public.dev_auth_pending_registrations
        SET is_verified = true, updated_at = pg_catalog.now()
        WHERE id = v_pending.id;

        -- Atomically complete profile registration status in public.profiles
        UPDATE public.profiles
        SET is_registration_complete = true, updated_at = pg_catalog.now()
        WHERE id = v_pending.auth_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'auth_user_id', v_pending.auth_user_id,
            'mobile_number', v_pending.mobile_number,
            'email', v_pending.email
        );
    ELSE
        IF v_pending.failed_attempts + 1 >= 5 THEN
            -- Invalidate pending registration permanently
            DELETE FROM public.dev_auth_pending_registrations
            WHERE id = v_pending.id;

            RETURN jsonb_build_object(
                'success', false,
                'error', 'max_attempts_exceeded',
                'message', 'Maximum verification attempts exceeded. Registration session invalidated.'
            );
        ELSE
            UPDATE public.dev_auth_pending_registrations
            SET failed_attempts = v_pending.failed_attempts + 1, updated_at = pg_catalog.now()
            WHERE id = v_pending.id;

            RETURN jsonb_build_object(
                'success', false,
                'error', 'invalid_otp',
                'attempts_remaining', 5 - (v_pending.failed_attempts + 1)
            );
        END IF;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.dev_verify_email_otp(TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- 6. Seed confirmed test number: +919392518488 with OTP 654321
-- NOTE: The first requested number '630280360' contains only 9 digits.
-- In accordance with project instructions, it is left UNSEEDED until its 10-digit value is confirmed.
INSERT INTO public.dev_auth_test_numbers (mobile_number, test_otp_hash, description)
VALUES (
    '+919392518488',
    extensions.crypt('654321', extensions.gen_salt('bf', 10)),
    'Confirmed Development Test Mobile'
)
ON CONFLICT (mobile_number) DO NOTHING;
