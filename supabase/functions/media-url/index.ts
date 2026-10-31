// media-url — §7.2 Edge Function
// Mints presigned PUT/GET URLs for the PRIVATE R2 couple-media bucket.
// The device uploads/downloads directly to/from R2; bytes never pass
// through Supabase and nothing is publicly fetchable.
//
// Required env (Dashboard → Edge Functions → Secrets):
//   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
//
// Deploy: supabase functions deploy media-url

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { AwsClient } from 'https://esm.sh/aws4fetch@1.0.20';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req: Request) => {
  // 1. Authenticate the caller (their JWT, forwarded by supabase_flutter).
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return json({ error: 'unauthorized' }, 401);

  // 2. Parse + validate the request.
  let body: { action?: string; path?: string; contentType?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const { action, path } = body;
  const validActions = ['upload', 'download', 'delete-prefix'];
  if (
    !action || !validActions.includes(action) ||
    !path ||
    path.includes('..') ||
    path.startsWith('/')
  ) {
    return json({ error: 'bad request' }, 400);
  }

  // 3. Authorization: the first path segment is the coupleId; the caller
  //    must be a member of that couple (RLS-style check in the function,
  //    because R2 presigned URLs bypass Postgres entirely).
  const coupleId = path.split('/')[0];
  const { data: couple } = await supabase
    .from('couples')
    .select('id, user_1, user_2')
    .eq('id', coupleId)
    .maybeSingle();
  if (!couple || (couple.user_1 !== user.id && couple.user_2 !== user.id)) {
    return json({ error: 'forbidden' }, 403);
  }

  // 4. Presign via aws4fetch (SigV4 query signing).
  const accountId = Deno.env.get('R2_ACCOUNT_ID');
  const bucket = Deno.env.get('R2_BUCKET');
  const accessKeyId = Deno.env.get('R2_ACCESS_KEY_ID');
  const secretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY');
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) {
    return json({ error: 'r2_not_configured' }, 500);
  }

  const r2 = new AwsClient({ accessKeyId, secretAccessKey });
  const endpoint = `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${path}`;

  // Account-deletion path: wipe every object under the couple prefix.
  // (R2 has no FK cascade — the delete-account flow calls this explicitly.)
  if (action === 'delete-prefix') {
    if (path !== coupleId) return json({ error: 'prefix must be coupleId' }, 400);
    const listUrl = new URL(
      `https://${accountId}.r2.cloudflarestorage.com/${bucket}`,
    );
    listUrl.searchParams.set('list-type', '2');
    listUrl.searchParams.set('prefix', `${coupleId}/`);
    const listRes = await r2.fetch(listUrl.toString());
    if (!listRes.ok) return json({ error: 'r2 list failed' }, 500);
    const xml = await listRes.text();
    const keys = [...xml.matchAll(/<Key>([^<]+)<\/Key>/g)].map((m) => m[1]);

    let deleted = 0;
    for (const key of keys) {
      const res = await r2.fetch(
        `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`,
        { method: 'DELETE' },
      );
      if (res.ok || res.status === 404) deleted++;
    }
    return json({ ok: true, deleted });
  }

  let method: 'PUT' | 'GET';
  const url = new URL(endpoint);
  if (action === 'upload') {
    method = 'PUT';
    url.searchParams.set('X-Amz-Expires', '900'); // 15 min to start the PUT
  } else {
    method = 'GET';
    url.searchParams.set('X-Amz-Expires', '3600'); // 1 h to fetch
  }

  const signed = await r2.sign(
    new Request(url, {
      method,
      headers: action === 'upload' && body.contentType
        ? { 'Content-Type': body.contentType }
        : undefined,
    }),
    { aws: { signQuery: true } },
  );

  return json({
    path,
    [action === 'upload' ? 'uploadUrl' : 'downloadUrl']: signed.url,
  });
});
