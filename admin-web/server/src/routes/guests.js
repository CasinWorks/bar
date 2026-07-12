import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

router.get('/event/:eventId', requireAdmin, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('guest_list_entries')
    .select('*')
    .eq('event_id', req.params.eventId)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ guests: data });
});

router.post('/', requireAdmin, async (req, res) => {
  const { eventId, name, email, phone, plusOnes, memberId, notes, status } = req.body;
  if (!eventId || !name) {
    return res.status(400).json({ error: 'Event and guest name required.' });
  }

  const { data, error } = await supabaseAdmin
    .from('guest_list_entries')
    .insert({
      event_id: eventId,
      name,
      email: email || null,
      phone: phone || null,
      plus_ones: Number(plusOnes) || 0,
      member_id: memberId || null,
      notes: notes || null,
      status: status || 'invited',
      added_by: req.profile.id,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ guest: data });
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const allowed = ['name', 'email', 'phone', 'plus_ones', 'status', 'notes', 'member_id'];
  const patch = {};
  for (const key of allowed) {
    if (req.body[key] !== undefined) patch[key] = req.body[key];
  }

  const { data, error } = await supabaseAdmin
    .from('guest_list_entries')
    .update(patch)
    .eq('id', req.params.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ guest: data });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { error } = await supabaseAdmin.from('guest_list_entries').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

export default router;
