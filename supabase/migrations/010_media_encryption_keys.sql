-- ============================================
-- 010 — Media encryption key exchange + escrow (§7.5)
-- Device keypairs: each device publishes an X25519 public key on its own
-- profile row; the couple's media key is derived locally via ECDH + HKDF
-- and never touches the server in plaintext.
-- Escrow: the couple key encrypted under a user-held recovery code is
-- stored here so a lost phone can restore media access.
-- ============================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS media_public_key TEXT;

CREATE TABLE IF NOT EXISTS public.key_escrow (
  couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'recovery',
  blob TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (couple_id, user_id, kind)
);

ALTER TABLE public.key_escrow ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couple members can read escrow"
  ON public.key_escrow FOR SELECT
  USING (
    couple_id IN (
      SELECT id FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

CREATE POLICY "Users can write own escrow"
  ON public.key_escrow FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND couple_id IN (
      SELECT id FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

CREATE POLICY "Users can update own escrow"
  ON public.key_escrow FOR UPDATE
  USING (user_id = auth.uid());

CREATE TRIGGER trg_key_escrow_updated_at
  BEFORE UPDATE ON public.key_escrow
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
