// delete-account — Compliance Edge Function (Apple 5.1.1(v) / Play account
// deletion requirement).
//
// FULL WIPE, in order:
//   1. Storage objects: every file under couple-media/<coupleId>/ (legacy
//      bucket). R2 objects are deleted by the same caller flow via the
//      media-url function's 'delete-prefix' action (kept separate because
//      R2 has no FK cascade).
//   2. DB rows: couple row (FK cascade clears channels → messages,
//      daily_answers, key_escrow), profile row (cascade clears devices,
//      reports, blocks), outbox rows live client-side only.
//   3. auth.users row (cascades auth identity data).
//
// Requires SUPABASE_SERVICE_ROLE_KEY (auto-injected into Edge Functions).
// The caller's JWT must be valid — a user can only delete THEMSELVES.
//
// Deploy: supabase functions deploy delete-account

import { createClient } from 'jsr:@supabase/supabase-js@2';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);

  // 1. Who is calling? (their JWT, forwarded by supabase_flutter)
  const authHeader = req.headers.get('Authorization') ?? '';
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
  } = await userClient.auth.getUser();
  if (!user) return json({ error: 'unauthorized' }, 401);
  const userId = user.id;

  // 2. Service-role client — the only actor allowed to hard-delete.
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const errors: string[] = [];

  try {
    // 3. Find the couple (either side).
    const { data: couple } = await admin
      .from('couples')
      .select('id, user_1, user_2')
      .or(`user_1.eq.${userId},user_2.eq.${userId}`)
      .maybeSingle();

    // 4. Storage wipe for the couple's media (legacy bucket).
    if (couple) {
      const { data: objects } = await admin.storage
        .from('couple-media')
        .list(couple.id, { limit: 1000, sortBy: { column: 'name' } });
      if (objects && objects.length > 0) {
        // list() returns folder entries too — recurse one level (images/videos/voice/files)
        for (const folder of objects) {
          const prefix = `${couple.id}/${folder.name}`;
          const { data: inner } = await admin.storage
            .from('couple-media')
            .list(prefix, { limit: 1000 });
          if (inner && inner.length > 0) {
            const paths = inner.map((o) => `${prefix}/${o.name}`);
            const { error } = await admin.storage
              .from('couple-media')
              .remove(paths);
            if (error) errors.push(`storage ${prefix}: ${error.message}`);
          }
        }
      }

      // 5. Delete the couple row — FK cascades clear channels, messages,
      //    daily_answers, key_escrow.
      const { error } = await admin
        .from('couples')
        .delete()
        .eq('id', couple.id);
      if (error) errors.push(`couple: ${error.message}`);
    }

    // 6. Delete the profile — cascades devices, reports, blocks.
    const { error } = await admin
      .from('profiles')
      .delete()
      .eq('id', userId);
    if (error) errors.push(`profile: ${error.message}`);

    // 7. Delete the auth user last (cascades auth identities/sessions).
    const { error: authError } = await admin.auth.deleteUser(userId);
    if (authError) errors.push(`auth user: ${authError.message}`);

    if (errors.length > 0) {
      return json({ error: 'partial_failure', details: errors }, 500);
    }
    return json({ ok: true, deleted: { userId, coupleId: couple?.id ?? null } });
  } catch (e) {
    return json({ error: 'exception', details: [String(e)] }, 500);
  }
});
