// Vercel serverless function (Node, no build step).
// Polls a Mux Direct Upload until its asset is ready, then returns the
// playback ID + duration the client stores in the `videos` table.
//
// GET /api/mux-upload-status?uploadId=<id>
//   → { state, assetId, playbackId, duration }
//
// state is one of:
//   'waiting'      — upload not yet linked to an asset
//   'preparing'    — asset exists but Mux is still processing
//   'ready'        — playbackId + duration available
//   'errored'      — upload or asset failed
//
// Auth: same Bearer token as mux-create-upload (reused verifier). We only
// gate on a valid teacher/studio session; the upload id itself is an opaque
// Mux handle the client already holds.

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://vuodmnhebsjmwdeazdtc.supabase.co';
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY || 'sb_publishable_Xkhwx_hNFyRGNp0Njqne3g_qD9VdFHy';

async function verifyCaller(accessToken) {
  if (!accessToken) return null;
  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` },
  });
  if (!userRes.ok) return null;
  const user = await userRes.json();
  if (!user || !user.id) return null;
  const profRes = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?id=eq.${user.id}&select=role`,
    { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` } }
  );
  if (!profRes.ok) return null;
  const rows = await profRes.json();
  return { userId: user.id, role: rows && rows[0] ? rows[0].role : null };
}

function muxAuthHeader() {
  return (
    'Basic ' +
    Buffer.from(
      `${process.env.MUX_TOKEN_ID}:${process.env.MUX_TOKEN_SECRET}`
    ).toString('base64')
  );
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  if (!process.env.MUX_TOKEN_ID || !process.env.MUX_TOKEN_SECRET) {
    res.status(500).json({ error: 'Mux is not configured.' });
    return;
  }

  const auth = req.headers.authorization || '';
  const accessToken = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  const caller = await verifyCaller(accessToken);
  if (!caller) { res.status(401).json({ error: 'Not authenticated' }); return; }
  if (caller.role !== 'teacher' && caller.role !== 'studio') {
    res.status(403).json({ error: 'Only teachers or studios can upload videos' });
    return;
  }

  const uploadId = (req.query && req.query.uploadId) || '';
  if (!uploadId) { res.status(400).json({ error: 'uploadId required' }); return; }

  try {
    // 1. Look up the upload to find its linked asset.
    const upRes = await fetch(
      `https://api.mux.com/video/v1/uploads/${encodeURIComponent(uploadId)}`,
      { headers: { Authorization: muxAuthHeader() } }
    );
    const upData = await upRes.json();
    if (!upRes.ok) {
      res.status(502).json({ error: 'Mux upload lookup failed', detail: upData });
      return;
    }

    const up = upData.data;
    if (up.status === 'errored' || up.error) {
      res.status(200).json({ state: 'errored', detail: up.error || 'upload errored' });
      return;
    }
    if (!up.asset_id) {
      res.status(200).json({ state: 'waiting' });
      return;
    }

    // 2. Look up the asset for readiness + playback id + duration.
    const asRes = await fetch(
      `https://api.mux.com/video/v1/assets/${encodeURIComponent(up.asset_id)}`,
      { headers: { Authorization: muxAuthHeader() } }
    );
    const asData = await asRes.json();
    if (!asRes.ok) {
      res.status(502).json({ error: 'Mux asset lookup failed', detail: asData });
      return;
    }

    const asset = asData.data;
    if (asset.status === 'errored') {
      res.status(200).json({ state: 'errored', assetId: up.asset_id });
      return;
    }
    if (asset.status !== 'ready') {
      res.status(200).json({ state: 'preparing', assetId: up.asset_id });
      return;
    }

    const playback =
      asset.playback_ids && asset.playback_ids.length
        ? asset.playback_ids[0].id
        : null;
    res.status(200).json({
      state: 'ready',
      assetId: up.asset_id,
      playbackId: playback,
      duration: asset.duration ? Math.round(asset.duration) : null,
    });
  } catch (e) {
    res.status(500).json({ error: 'Status check threw', detail: String(e) });
  }
};
