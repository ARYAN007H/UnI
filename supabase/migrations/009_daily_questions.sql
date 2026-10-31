-- ============================================
-- 009 — Daily question ritual (§7.4)
-- The question of the day is DERIVED client-side:
--   index = fnv1a(coupleId + '|' + UTC date) % count(questions ORDER BY id)
-- The server only stores the question bank and the answers.
-- ============================================

CREATE TABLE IF NOT EXISTS public.daily_questions (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  emoji TEXT NOT NULL DEFAULT '💭'
);

ALTER TABLE public.daily_questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read questions"
  ON public.daily_questions FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE TABLE IF NOT EXISTS public.daily_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
  question_id INTEGER NOT NULL REFERENCES public.daily_questions(id) ON DELETE CASCADE,
  answer_date DATE NOT NULL DEFAULT CURRENT_DATE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (couple_id, question_id, answer_date, user_id)
);

ALTER TABLE public.daily_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couple members can read answers"
  ON public.daily_answers FOR SELECT
  USING (
    couple_id IN (
      SELECT id FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

CREATE POLICY "Users can insert own answers"
  ON public.daily_answers FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND couple_id IN (
      SELECT id FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

CREATE POLICY "Users can update own answers"
  ON public.daily_answers FOR UPDATE
  USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_daily_answers_lookup
  ON public.daily_answers(couple_id, answer_date DESC);

CREATE TRIGGER trg_daily_answers_updated_at
  BEFORE UPDATE ON public.daily_answers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
