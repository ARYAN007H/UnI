-- 013: Align messages schema with the client model + add batch_mark_read RPC
--
-- Fixes two runtime failures observed on device:
--  1) PGRST204 "Could not find the 'latitude' column of 'messages'" — the app
--     inserts media metadata + geo columns that migrations never created.
--  2) PGRST202 "Could not find the function public.batch_mark_read" — the
--     read-receipt RPC the client calls was never defined.

-- 1) Missing message columns
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_thumbnail_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_duration_ms integer;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_size_bytes bigint;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS longitude double precision;

-- 2) Read receipts RPC (membership-guarded, self-reads only)
CREATE OR REPLACE FUNCTION public.batch_mark_read(p_channel_id uuid, p_user_id uuid)
RETURNS integer AS $$
DECLARE
  updated integer;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'can only mark own reads';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.channels c
    JOIN public.couples cp ON cp.id = c.couple_id
    WHERE c.id = p_channel_id
      AND (cp.user_1 = auth.uid() OR cp.user_2 = auth.uid())
  ) THEN
    RAISE EXCEPTION 'not a member of this channel';
  END IF;

  UPDATE public.messages
  SET read_by = array_append(read_by, p_user_id)
  WHERE channel_id = p_channel_id
    AND sender_id <> p_user_id
    AND NOT (p_user_id = ANY(read_by));

  GET DIAGNOSTICS updated = ROW_COUNT;
  RETURN updated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.batch_mark_read(uuid, uuid) TO authenticated;
