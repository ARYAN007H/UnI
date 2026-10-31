-- ============================================
-- 008 — Realtime consolidation + local-first support (§7.3)
-- One realtime stream per couple requires couple_id on messages.
-- Also fixes latent bug: 001's type CHECK rejected 'plan' messages.
-- ============================================

-- 1. Widen the message type constraint (001 omitted 'plan')
DO $$
DECLARE constraint_name text;
BEGIN
  SELECT conname INTO constraint_name
  FROM pg_constraint
  WHERE conrelid = 'public.messages'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%type%';
  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.messages DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

ALTER TABLE public.messages ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text', 'image', 'video', 'voice', 'file', 'system', 'plan'));

-- 2. couple_id on messages (server-derived, client value is ignored)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS couple_id UUID REFERENCES public.couples(id) ON DELETE CASCADE;

UPDATE public.messages m
SET couple_id = c.couple_id
FROM public.channels c
WHERE m.channel_id = c.id AND m.couple_id IS NULL;

ALTER TABLE public.messages ALTER COLUMN couple_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_couple_created ON public.messages(couple_id, created_at DESC);

-- Server always derives couple_id from the channel; a mismatched client
-- value can never pollute another couple's realtime stream.
CREATE OR REPLACE FUNCTION public.set_message_couple_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT couple_id INTO NEW.couple_id FROM public.channels WHERE id = NEW.channel_id;
  IF NEW.couple_id IS NULL THEN
    RAISE EXCEPTION 'channel % does not exist', NEW.channel_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_messages_couple_id ON public.messages;
CREATE TRIGGER trg_messages_couple_id
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.set_message_couple_id();

-- 3. Realtime publication safety net (001 already added messages)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;
  END IF;
END $$;
