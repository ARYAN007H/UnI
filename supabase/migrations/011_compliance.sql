-- ============================================
-- 011 — Compliance: UGC report/block (store 1.2 triad) 
-- Apple Guideline 1.2 + Play UGC policy require report/block/filter even
-- for a 2-user app. Reports are write-only to clients (reviewed by the
-- developer via the service role / Supabase dashboard).
-- ============================================

CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,            -- 'harassment' | 'ncii' | 'minor' | 'spam' | 'other'
  details TEXT,
  status TEXT NOT NULL DEFAULT 'open',  -- 'open' | 'reviewed' | 'actioned'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Insert own reports; NO client SELECT (privacy of reports; review via dashboard)
CREATE POLICY "Users can file reports"
  ON public.reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid() AND reported_user_id <> auth.uid());

CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own blocks"
  ON public.blocks FOR ALL
  USING (blocker_id = auth.uid())
  WITH CHECK (blocker_id = auth.uid());

-- Messages: a blocked sender cannot message their blocker. The sender's
-- partner (the other couple member) must not have blocked the sender.
DROP POLICY IF EXISTS "Couple members can insert messages" ON public.messages;
CREATE POLICY "Couple members can insert messages"
  ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND channel_id IN (
      SELECT c.id FROM public.channels c
      JOIN public.couples cp ON c.couple_id = cp.id
      WHERE cp.user_1 = auth.uid() OR cp.user_2 = auth.uid()
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      JOIN public.channels c2 ON c2.id = channel_id
      JOIN public.couples cp2 ON cp2.id = c2.couple_id
      WHERE (b.blocker_id = cp2.user_1 AND b.blocked_id = auth.uid())
         OR (b.blocker_id = cp2.user_2 AND b.blocked_id = auth.uid())
    )
  );

-- Devices table (migration 006) cleanup is FK-cascaded on profile deletion.
