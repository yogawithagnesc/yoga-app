// Vercel serverless function for complete user account deletion.
// Deletes both the profile (via RPC in the client) AND the auth.users record
// via the Supabase Admin API. This ensures the email/password combination
// becomes completely unusable for login.
//
// The client calls this with the Supabase access token in the Authorization header.
// We verify the token, then delete the auth user record via the Admin API.
//
// Required Vercel env var:
//   SUPABASE_SERVICE_ROLE_KEY — the admin API key (secret, never expose to client)

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

// Verify the Supabase JWT and return { userId } or null.
async function verifyCaller(accessToken) {
  if (!accessToken) return null;

  try {
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
    });
    if (!userRes.ok) return null;
    const user = await userRes.json();
    if (!user || !user.id) return null;
    return { userId: user.id };
  } catch (e) {
    console.error('verifyCaller error:', e);
    return null;
  }
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceRoleKey) {
    res.status(500).json({
      error: 'Server not configured for account deletion',
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

  try {
    // Delete the user via Supabase Admin API
    const deleteRes = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${caller.userId}`,
      {
        method: 'DELETE',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      }
    );

    if (!deleteRes.ok) {
      const detail = await deleteRes.text();
      res.status(deleteRes.status).json({
        error: 'Failed to delete user account',
        detail,
      });
      return;
    }

    res.status(200).json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Deletion failed', detail: String(e) });
  }
};
