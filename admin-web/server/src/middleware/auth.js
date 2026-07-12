import { supabaseAsUser, supabaseAdmin } from '../lib/supabase.js';

export async function requireAdmin(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token.' });
  }

  const token = header.slice(7);
  const client = supabaseAsUser(token);
  const { data: authData, error: authError } = await client.auth.getUser(token);

  if (authError || !authData.user) {
    return res.status(401).json({ error: 'Invalid or expired session.' });
  }

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('id, name, email, role, is_banned')
    .eq('id', authData.user.id)
    .single();

  if (profileError || !profile) {
    return res.status(403).json({ error: 'Profile not found.' });
  }

  if (!['admin', 'hr'].includes(profile.role)) {
    return res.status(403).json({ error: 'Admin or HR access required.' });
  }

  if (profile.is_banned) {
    return res.status(403).json({ error: 'Your account is suspended.' });
  }

  req.user = authData.user;
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
