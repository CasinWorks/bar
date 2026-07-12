import { supabaseAsUser, supabaseAdmin } from '../lib/supabase.js';

export async function requireAdmin(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token.' });
  }

  const token = header.slice(7);

  // Prefer service-role auth lookup — more reliable on Vercel serverless.
  let user = null;
  const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token);
  if (!authError && authData.user) {
    user = authData.user;
  } else {
    const client = supabaseAsUser(token);
    const fallback = await client.auth.getUser(token);
    if (fallback.error || !fallback.data.user) {
      return res.status(401).json({
        error: authError?.message || fallback.error?.message || 'Invalid or expired session.',
      });
    }
    user = fallback.data.user;
  }

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('id, name, email, role, is_banned')
    .eq('id', user.id)
    .single();

  if (profileError || !profile) {
    return res.status(403).json({ error: profileError?.message || 'Profile not found.' });
  }

  if (!['admin', 'hr'].includes(profile.role)) {
    return res.status(403).json({
      error: `Admin or HR access required (current role: ${profile.role}).`,
    });
  }

  if (profile.is_banned) {
    return res.status(403).json({ error: 'Your account is suspended.' });
  }

  req.user = user;
  req.profile = profile;
  req.token = token;
  next();
}

export function requireAdminOnly(req, res, next) {
  if (req.profile.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required.' });
  }
  next();
}
