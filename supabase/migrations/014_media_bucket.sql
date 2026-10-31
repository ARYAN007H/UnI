-- 014: Create the couple-media storage bucket + member-scoped access policies.
-- (Buckets live in the storage schema and are NOT created by table migrations —
-- this must run once per project. Idempotent.)
INSERT INTO storage.buckets (id, name, public)
VALUES ('couple-media', 'couple-media', false)
ON CONFLICT (id) DO NOTHING;

-- Path contract from §7.2: {coupleId}/{type}/{uuid}.{ext} — the first folder
-- segment must be a couple the caller belongs to.
DROP POLICY IF EXISTS "couple media read" ON storage.objects;
DROP POLICY IF EXISTS "couple media insert" ON storage.objects;
DROP POLICY IF EXISTS "couple media delete" ON storage.objects;

CREATE POLICY "couple media read" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'couple-media' AND (storage.foldername(name))[1] IN (
  SELECT c.id::text FROM public.couples c
  WHERE c.user_1 = auth.uid() OR c.user_2 = auth.uid()));

CREATE POLICY "couple media insert" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'couple-media' AND (storage.foldername(name))[1] IN (
  SELECT c.id::text FROM public.couples c
  WHERE c.user_1 = auth.uid() OR c.user_2 = auth.uid()));

CREATE POLICY "couple media delete" ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'couple-media' AND (storage.foldername(name))[1] IN (
  SELECT c.id::text FROM public.couples c
  WHERE c.user_1 = auth.uid() OR c.user_2 = auth.uid()));
