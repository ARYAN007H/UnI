-- ============================================
-- Couple Chat V1 — Initial Schema Migration
-- ============================================

-- Profiles (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  status_text TEXT DEFAULT '',
  is_online BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Couples (exactly 2 users)
CREATE TABLE IF NOT EXISTS public.couples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_1 UUID NOT NULL REFERENCES public.profiles(id),
  user_2 UUID REFERENCES public.profiles(id),
  paired_at TIMESTAMPTZ DEFAULT now(),
  anniversary_date DATE,
  couple_name TEXT,
  invite_code TEXT UNIQUE,
  UNIQUE(user_1, user_2)
);

-- Channels (Discord-style)
CREATE TABLE IF NOT EXISTS public.channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  icon TEXT DEFAULT '💬',
  description TEXT DEFAULT '',
  position INTEGER DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id),
  content TEXT,
  type TEXT DEFAULT 'text' CHECK (type IN ('text', 'image', 'video', 'voice', 'file', 'system')),
  media_url TEXT,
  reply_to UUID REFERENCES public.messages(id),
  is_edited BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  read_by UUID[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_messages_channel_created ON public.messages(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_channels_couple ON public.channels(couple_id);
CREATE INDEX IF NOT EXISTS idx_couples_invite_code ON public.couples(invite_code) WHERE invite_code IS NOT NULL;

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Profiles: read own + partner, update own
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can read partner profile"
  ON public.profiles FOR SELECT
  USING (
    id IN (
      SELECT CASE WHEN user_1 = auth.uid() THEN user_2 ELSE user_1 END
      FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Couples: members can read, creator can insert
CREATE POLICY "Couple members can read"
  ON public.couples FOR SELECT
  USING (user_1 = auth.uid() OR user_2 = auth.uid());

CREATE POLICY "Authenticated users can create couple"
  ON public.couples FOR INSERT
  WITH CHECK (user_1 = auth.uid());

CREATE POLICY "Partner can join couple"
  ON public.couples FOR UPDATE
  USING (invite_code IS NOT NULL)
  WITH CHECK (user_2 = auth.uid());

-- Channels: couple members only
CREATE POLICY "Couple members can read channels"
  ON public.channels FOR SELECT
  USING (
    couple_id IN (
      SELECT id FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

CREATE POLICY "Couple members can create channels"
  ON public.channels FOR INSERT
  WITH CHECK (
    couple_id IN (
      SELECT id FROM public.couples
      WHERE user_1 = auth.uid() OR user_2 = auth.uid()
    )
  );

-- Messages: couple members only
CREATE POLICY "Couple members can read messages"
  ON public.messages FOR SELECT
  USING (
    channel_id IN (
      SELECT c.id FROM public.channels c
      JOIN public.couples cp ON c.couple_id = cp.id
      WHERE cp.user_1 = auth.uid() OR cp.user_2 = auth.uid()
    )
  );

CREATE POLICY "Couple members can insert messages"
  ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND
    channel_id IN (
      SELECT c.id FROM public.channels c
      JOIN public.couples cp ON c.couple_id = cp.id
      WHERE cp.user_1 = auth.uid() OR cp.user_2 = auth.uid()
    )
  );

CREATE POLICY "Users can update own messages"
  ON public.messages FOR UPDATE
  USING (sender_id = auth.uid());

-- ============================================
-- REALTIME
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_messages_updated_at
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
