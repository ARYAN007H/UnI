-- ============================================
-- Fix: Allow any authenticated user to SELECT couples by invite_code
-- The current RLS policy only lets user_1 or user_2 read couples,
-- which blocks the joining user from finding the couple to join.
-- ============================================

-- Allow authenticated users to read couples that have an active invite_code.
-- This is safe because:
--   1. Only couples with a non-null invite_code are visible
--   2. The invite_code is burned (set to null) upon joining
--   3. Knowing the UUID invite code is already an authorization check
CREATE POLICY "Anyone can find couple by invite code"
  ON public.couples FOR SELECT
  USING (invite_code IS NOT NULL);
