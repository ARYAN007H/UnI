-- 012: Seed default channels for couples (fixes "channel <NULL> does not exist")
--
-- Root cause: the rewritten pairing flow stopped creating default channels,
-- so messages.failed to insert (trigger set_message_couple_id resolves
-- channel_id -> couple_id and raised 'channel <NULL> does not exist') and
-- realtime subscriptions had no channel to bind to (RealtimeCloseEvent 1002).
--
-- 1) Backfill: one 'general' channel for every couple that has none.
INSERT INTO public.channels (couple_id, name, icon, description, position, is_default)
SELECT c.id, 'general', '💬', 'Your conversation', 0, true
FROM public.couples c
WHERE NOT EXISTS (
  SELECT 1 FROM public.channels ch WHERE ch.couple_id = c.id AND ch.name = 'general'
);

-- 2) Future-proof: auto-seed at the DB level whenever a couple is created,
--    regardless of which client forgot to.
CREATE OR REPLACE FUNCTION public.seed_default_channel()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.channels (couple_id, name, icon, description, position, is_default)
  VALUES (NEW.id, 'general', '💬', 'Your conversation', 0, true)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_couples_seed_channel ON public.couples;
CREATE TRIGGER trg_couples_seed_channel
  AFTER INSERT ON public.couples
  FOR EACH ROW EXECUTE FUNCTION public.seed_default_channel();

-- 3) OPTIONAL cleanup of orphan invites (no partner ever joined).
--    Uncomment to run:
-- DELETE FROM public.couples WHERE user_2 IS NULL;
