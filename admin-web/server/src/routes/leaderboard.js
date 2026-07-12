import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';

const router = Router();

/**
 * Club rankings by live wallet time.
 * Auth: any signed-in Supabase user (member / staff / admin).
 */
router.get('/', async (req, res) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token.' });
  }

  const token = header.slice(7);
  const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token);
  if (authError || !authData.user) {
    return res.status(401).json({ error: authError?.message || 'Invalid session.' });
  }

  const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 100);

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('id, name, email, role, time_balance_seconds')
    .eq('is_banned', false)
    .order('time_balance_seconds', { ascending: false })
    .order('name', { ascending: true })
    .limit(limit);

  if (error) return res.status(500).json({ error: error.message });

  const viewerId = authData.user.id;
  const rankings = (data ?? []).map((row, index) => ({
    id: row.id,
    rank: index + 1,
    name: row.name?.trim() || row.email?.split('@')[0] || 'Guest',
    email: row.email,
    role: row.role,
    timeBalanceSeconds: row.time_balance_seconds ?? 0,
    isCurrentUser: row.id === viewerId,
  }));

  res.json({ rankings });
});

export default router;
