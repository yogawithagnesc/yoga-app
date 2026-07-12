// Vercel serverless function (Node, no build step).
// Creates a Mux Direct Upload URL for an authenticated teacher/studio.
//
// The client POSTs with the caller's Supabase access token in the
// Authorization header. We verify the token, confirm the user's role is
// teacher or studio, then ask Mux for a one-time direct-upload URL. The
// browser PUTs the file bytes straight to that URL — the Mux secret never
// touches the client.
//
// Required Vercel env vars:
//   MUX_TOKEN_ID, MUX_TOKEN_SECRET   — Mux API access token (Video)
//   SUPABASE_URL (optional)          — defaults to the project URL below
//   SUPABASE_ANON_KEY (optional)     — defaults to the publishable key below

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://vuodmnhebsjmwdeazdtc.supabase.co';
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY || 'sb_publishable_Xkhwx_hNFyRGNp0Njqne3g_qD9VdFHy';

async function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  return await new Promise((resolve) => {
    let raw = '';
    req.on('data', (c) => { raw += c; });
    req.on('end', () => {
      try { resolve(raw ? JSON.parse(raw) : {}); }
      catch { resolve({}); }
    });
  });
}

// Verify the Supabase JWT and return { userId, role } or null.
async function verifyCaller(accessToken) {
  if (!accessToken) return null;

  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
    },
  });
  if (!userRes.ok) return null;
  const user = await userRes.json();
  if (!user || !user.id) return null;

  // Read the caller's own profile role (RLS permits self-read).
  const profRes = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?id=eq.${user.id}&select=role`,
    {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
    }
  );
  if (!profRes.ok) return null;
  const rows = await profRes.json();
  const role = rows && rows[0] ? rows[0].role : null;
  return { userId: user.id, role };
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const tokenId = process.env.MUX_TOKEN_ID;
  const tokenSecret = process.env.MUX_TOKEN_SECRET;
  if (!tokenId || !tokenSecret) {
    res.status(500).json({
      error: 'Mux is not configured. Set MUX_TOKEN_ID and MUX_TOKEN_SECRET in Vercel.',
    });
    return;
  }

  const auth = req.headers.authorization || '';
  const accessToken = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  const caller = await verifyCaller(accessToken);
  if (!caller) {
    res.status(401).json({ error: 'Not authenticated' });
    return;
  }
  if (caller.role !== 'teacher' && caller.role !== 'studio') {
    res.status(403).json({ error: 'Only teachers or studios can upload videos' });
    return;
  }

  const body = await readJsonBody(req);
  const corsOrigin =
    (req.headers.origin && String(req.headers.origin)) || '*';

  try {
    const muxRes = await fetch('https://api.mux.com/video/v1/uploads', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization:
          'Basic ' + Buffer.from(`${tokenId}:${tokenSecret}`).toString('base64'),
      },
      body: JSON.stringify({
        cors_origin: corsOrigin,
        new_asset_settings: {
          playback_policy: ['public'],
          video_quality: body.videoQuality || 'basic',
        },
      }),
    });

    const data = await muxRes.json();
    if (!muxRes.ok) {
      res.status(502).json({
        error: 'Mux upload creation failed',
        detail: data && data.error ? data.error : data,
      });
      return;
    }

    res.status(200).json({
      uploadId: data.data.id,
      url: data.data.url,
    });
  } catch (e) {
    res.status(500).json({ error: 'Upload creation threw', detail: String(e) });
  }
};
