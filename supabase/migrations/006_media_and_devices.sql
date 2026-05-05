-- ============================================
-- Migration 006: Media Storage & Device Tokens
-- ============================================

-- 1. Add 'plan' to allowed message types
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_type_check;
ALTER TABLE public.messages ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text', 'image', 'video', 'voice', 'file', 'system', 'plan'));

-- 2. Add media metadata columns
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS media_thumbnail_url TEXT,
  ADD COLUMN IF NOT EXISTS media_duration_ms INTEGER,
  ADD COLUMN IF NOT EXISTS media_size_bytes BIGINT;

-- 3. Device tokens for push notifications
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  device_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_devices_user ON public.devices(user_id);

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own devices"
  ON public.devices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
  ON public.devices FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices"
  ON public.devices FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
  ON public.devices FOR DELETE
  USING (auth.uid() = user_id);

CREATE TRIGGER trg_devices_updated_at
  BEFORE UPDATE ON public.devices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 4. Supabase Storage bucket for couple media
-- NOTE: Run this in the Supabase Dashboard SQL Editor or via the Storage API:
--
-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES (
--   'couple-media',
--   'couple-media',
--   false,
--   52428800,  -- 50MB limit
--   ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','audio/aac','audio/mp4','audio/mpeg','audio/ogg']
-- );
--
-- Storage RLS policies (run in Dashboard):
--
-- CREATE POLICY "Couple members can upload media"
--   ON storage.objects FOR INSERT
--   WITH CHECK (
--     bucket_id = 'couple-media' AND
--     auth.uid() IS NOT NULL AND
--     (storage.foldername(name))[1] IN (
--       SELECT id::text FROM public.couples
--       WHERE user_1 = auth.uid() OR user_2 = auth.uid()
--     )
--   );
--
-- CREATE POLICY "Couple members can view media"
--   ON storage.objects FOR SELECT
--   USING (
--     bucket_id = 'couple-media' AND
--     (storage.foldername(name))[1] IN (
--       SELECT id::text FROM public.couples
--       WHERE user_1 = auth.uid() OR user_2 = auth.uid()
--     )
--   );
--
-- CREATE POLICY "Couple members can delete own media"
--   ON storage.objects FOR DELETE
--   USING (
--     bucket_id = 'couple-media' AND
--     auth.uid() IS NOT NULL AND
--     (storage.foldername(name))[1] IN (
--       SELECT id::text FROM public.couples
--       WHERE user_1 = auth.uid() OR user_2 = auth.uid()
--     )
--   );

-- 5. Function: batch mark messages as read (replaces N+1 loop)
CREATE OR REPLACE FUNCTION public.batch_mark_read(p_channel_id UUID, p_user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.messages
  SET read_by = array_append(read_by, p_user_id),
      updated_at = now()
  WHERE channel_id = p_channel_id
    AND NOT (read_by @> ARRAY[p_user_id]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
