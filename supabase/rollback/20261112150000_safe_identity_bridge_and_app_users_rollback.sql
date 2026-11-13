-- =============================================================================
-- Migration Rollback: 20261112150000_safe_identity_bridge_and_app_users_rollback.sql
-- Description: Non-Destructive Rollback for Go Backend Identity Bridge
--
-- BUSINESS DATA PRESERVATION GUARANTEE:
-- 1. NO tables are dropped with CASCADE. Zero business data loss.
-- 2. Preserves all Go-created users and records into archive tables:
--    - 'public.app_users_rollback_backup'
--    - 'public.profiles_go_archive'
--    - 'public.app_sessions_rollback_backup'
-- 3. Safely restores 'profiles.id REFERENCES auth.users(id)' on legacy Supabase users.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Step 1: Snapshot and Archive All Go Backend Identity Data
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_users_rollback_backup AS 
SELECT * FROM public.app_users;

CREATE TABLE IF NOT EXISTS public.profiles_go_archive AS 
SELECT * FROM public.profiles WHERE origin = 'go_backend';

CREATE TABLE IF NOT EXISTS public.app_sessions_rollback_backup AS 
SELECT * FROM public.app_sessions;

-- -----------------------------------------------------------------------------
-- Step 2: Drop Go Synchronization Triggers
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_sync_app_user_to_profile ON public.app_users;
DROP FUNCTION IF EXISTS public.sync_app_user_to_profile();

DROP TRIGGER IF EXISTS trg_sync_profile_to_app_user ON public.profiles;
DROP FUNCTION IF EXISTS public.sync_profile_to_app_user();

DROP TRIGGER IF EXISTS trg_sync_auth_user_delete ON auth.users;
DROP FUNCTION IF EXISTS public.sync_auth_user_delete_to_app_user();

-- -----------------------------------------------------------------------------
-- Step 3: Re-establish Original Constraint on 'public.profiles'
-- -----------------------------------------------------------------------------
-- 3.1 Drop Go foreign key constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_app_users_fk;

-- 3.2 Remove Go-created users from profiles (they are preserved in profiles_go_archive)
DELETE FROM public.profiles WHERE origin = 'go_backend';

-- 3.3 Restore original foreign key pointing to auth.users(id)
-- Since all remaining profiles have origin = 'supabase_auth', all IDs exist in auth.users!
ALTER TABLE public.profiles 
    ADD CONSTRAINT profiles_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 3.4 Clean up origin column and check constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_origin_check;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS origin;

-- -----------------------------------------------------------------------------
-- Step 4: Safely Retire Auxiliary Tables
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS public.app_pending_registrations;
DROP TABLE IF EXISTS public.app_otp_challenges;
DROP TABLE IF EXISTS public.app_sessions;
DROP TABLE IF EXISTS public.app_users;

COMMIT;
