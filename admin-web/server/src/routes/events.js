import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

router.get('/', requireAdmin, async (req, res) => {
  const { from, to } = req.query;
  let query = supabaseAdmin
    .from('club_events')
    .select('*')
    .order('starts_at', { ascending: true });

  if (from) query = query.gte('starts_at', from);
  if (to) query = query.lte('starts_at', to);

  const { data, error } = await query;
  if (error) return res.status(500).json({ error: error.message });
  res.json({ events: data });
});

router.post('/', requireAdmin, async (req, res) => {
  const { title, description, branch, startsAt, endsAt, capacity, vipOnly, status } = req.body;
  if (!title || !startsAt) {
    return res.status(400).json({ error: 'Title and start time required.' });
  }

  const { data, error } = await supabaseAdmin
    .from('club_events')
    .insert({
      title,
      description: description || null,
      branch: branch || 'The Blind Tiger — BGC',
      starts_at: startsAt,
      ends_at: endsAt || null,
      capacity: capacity ? Number(capacity) : null,
      vip_only: Boolean(vipOnly),
      status: status || 'scheduled',
      created_by: req.profile.id,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ event: data });
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const patch = {};
  const map = {
    title: 'title',
    description: 'description',
    branch: 'branch',
    startsAt: 'starts_at',
    endsAt: 'ends_at',
    capacity: 'capacity',
    vipOnly: 'vip_only',
    status: 'status',
  };
  for (const [k, col] of Object.entries(map)) {
    if (req.body[k] !== undefined) patch[col] = req.body[k];
  }

  const { data, error } = await supabaseAdmin
    .from('club_events')
    .update(patch)
    .eq('id', req.params.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ event: data });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { error } = await supabaseAdmin.from('club_events').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

export default router;
