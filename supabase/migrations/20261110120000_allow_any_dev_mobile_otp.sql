-- =============================================================================
-- Migration: 20261110120000_allow_any_dev_mobile_otp.sql
-- Description: Update public.dev_verify_mobile_otp to:
--              1. Support common development OTP '123456' for any valid Indian mobile number.
--              2. Enforce database-level Indian E.164 mobile format (+91[6-9][0-9]{9}).
--              3. Grant EXECUTE to service_role while revoking from PUBLIC, anon, authenticated.
-- Security: Preserves SECURITY DEFINER, search_path = '', least-privilege permissions,
--           brute-force lockout (5 attempts / 15 minutes), and custom test numbers.
-- =============================================================================

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
    -- 1. Database-level validation for Indian E.164 mobile format (+91[6-9][0-9]{9})
    IF p_mobile IS NULL OR p_mobile !~ '^\+91[6-9][0-9]{9}$' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'invalid_mobile',
            'message', 'Invalid Indian mobile number format. Expected +91 followed by 10 digits starting with 6-9.'
        );
    END IF;

    -- 2. Lookup existing test number record
    SELECT * INTO v_record
    FROM public.dev_auth_test_numbers
    WHERE mobile_number = p_mobile
    FOR UPDATE;

    IF NOT FOUND THEN
        -- Allow ANY valid 10-digit Indian mobile number in development by initializing
        -- an entry with the common fixed development OTP '123456'.
        INSERT INTO public.dev_auth_test_numbers (
            mobile_number,
            test_otp_hash,
            is_enabled,
            description
        )
        VALUES (
            p_mobile,
            extensions.crypt('123456', extensions.gen_salt('bf', 10)),
            true,
            'Auto-registered Development Test Mobile'
        )
        ON CONFLICT (mobile_number) DO NOTHING
        RETURNING * INTO v_record;

        -- If a concurrent insert occurred, re-select for update
        IF v_record.id IS NULL THEN
            SELECT * INTO v_record
            FROM public.dev_auth_test_numbers
            WHERE mobile_number = p_mobile
            FOR UPDATE;
        END IF;
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

    -- 3. Verify bcrypt hash
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

-- Ensure least-privilege security:
-- 1. Revoke all privileges from PUBLIC, anon, authenticated
REVOKE ALL ON FUNCTION public.dev_verify_mobile_otp(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- 2. Explicitly grant execute privilege to service_role (used by Edge Function)
GRANT EXECUTE ON FUNCTION public.dev_verify_mobile_otp(TEXT, TEXT) TO service_role;
