-- ============================================
-- Email Verification Tracking
-- ============================================
-- Adds deferred email verification columns to profiles.
-- Users can sign up and use the app immediately;
-- verification is enforced after a 24-hour grace period.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ;
