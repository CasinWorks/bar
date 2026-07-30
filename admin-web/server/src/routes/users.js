import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin, requireAdminOnly } from '../middleware/auth.js';
import { isSuperAdminEmail } from '../lib/superAdmin.js';

const router = Router();

const ACTIVE_SESSION_PHASES = ['inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry'];

async function attachActiveSessionTime(users) {
  if (!users?.length) return users;

  const ids = users.map((u) => u.id);
  const { data: sessions, error } = await supabaseAdmin
    .from('club_sessions')
    .select('member_id, remaining_seconds, phase')
    .in('member_id', ids)
    .in('phase', ACTIVE_SESSION_PHASES);

  if (error) throw error;

  const activeByMember = new Map();
  for (const session of sessions ?? []) {
    const prev = activeByMember.get(session.member_id) ?? 0;
    activeByMember.set(session.member_id, prev + (session.remaining_seconds ?? 0));
  }

  return users.map((user) => {
    const wallet = user.time_balance_seconds ?? 0;
    const active = activeByMember.get(user.id) ?? 0;
    return {
      ...user,
      active_session_seconds: active,
      total_load_seconds: wallet + active,
    };
  });
}

router.get('/', requireAdmin, async (req, res) => {
  const { search, role, banned, whitelisted, loadable } = req.query;
  let query = supabaseAdmin
    .from('profiles')
    .select('id, name, email, role, time_balance_seconds, is_banned, is_whitelisted, ban_reason, phone, branch, created_at')
    .order('created_at', { ascending: false })
    .limit(200);

  if (loadable === 'true') {
    // Cash desk: anyone not banned (includes founder / admin for demos)
    query = query.eq('is_banned', false);
  } else if (role) {
    query = query.eq('role', role);
  }
  if (banned === 'true') query = query.eq('is_banned', true);
  if (whitelisted === 'true') query = query.eq('is_whitelisted', true);
  if (search) {
    query = query.or(`name.ilike.%${search}%,email.ilike.%${search}%`);
  }

  const { data, error } = await query;
  if (error) return res.status(500).json({ error: error.message });

  try {
    const users = await attachActiveSessionTime(data);
    res.json({ users });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/:id', requireAdmin, requireAdminOnly, async (req, res) => {
  const { id } = req.params;

  const { data: existing } = await supabaseAdmin
    .from('profiles')
    .select('id, email, role')
    .eq('id', id)
    .single();

  if (existing && isSuperAdminEmail(existing.email)) {
    return res.status(403).json({ error: 'This account is protected and cannot be modified.' });
  }

  const allowed = ['role', 'is_banned', 'is_whitelisted', 'ban_reason', 'admin_notes', 'branch', 'name'];
  const patch = {};
  for (const key of allowed) {
    if (req.body[key] !== undefined) patch[key] = req.body[key];
  }

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .update(patch)
    .eq('id', id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ user: data });
});

function randomTempPassword() {
  const chunk = Math.random().toString(36).slice(2, 8);
  return `Tiger-${chunk}!9`;
}

/** Admin sets a temporary password so the member can sign in again. */
router.post('/:id/reset-password', requireAdmin, requireAdminOnly, async (req, res) => {
  const { id } = req.params;

  const { data: existing, error: lookupError } = await supabaseAdmin
    .from('profiles')
    .select('id, email, name, role')
    .eq('id', id)
    .single();

  if (lookupError || !existing) {
    return res.status(404).json({ error: 'Member not found.' });
  }
  if (isSuperAdminEmail(existing.email)) {
    return res.status(403).json({ error: 'This account is protected and cannot be modified.' });
  }

  const requested = typeof req.body?.password === 'string' ? req.body.password.trim() : '';
  const tempPassword = requested.length >= 8 ? requested : randomTempPassword();

  const { error } = await supabaseAdmin.auth.admin.updateUserById(id, {
    password: tempPassword,
  });

  if (error) return res.status(500).json({ error: error.message });

  res.json({
    ok: true,
    userId: id,
    email: existing.email,
    name: existing.name,
    tempPassword,
  });
});

router.get('/:id/sessions', requireAdmin, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('club_sessions')
    .select('*')
    .eq('member_id', req.params.id)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ sessions: data });
});

export default router;
