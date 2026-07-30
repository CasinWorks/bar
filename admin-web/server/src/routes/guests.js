import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';

const router = Router();

const UNLINKED_WARNING =
  'No app account matches this email yet, so member_id is empty. The guest is door-list only until they register (or you re-link) with this exact email — then the event peers to their account automatically.';

function normalizeEmail(value) {
  const trimmed = String(value ?? '').trim().toLowerCase();
  return trimmed || null;
}

/// Finds the profile behind a guest email. The mobile app only surfaces events
/// through event_guests.member_id, so an unresolved email means an invisible
/// invite — the caller must surface that instead of silently succeeding.
async function resolveMemberIdByEmail(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) return null;

  // Escape ILIKE wildcards so "a_b@x.com" does not match "axb@x.com".
  const escaped = normalized.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_');

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('id, email')
    .ilike('email', escaped)
    .limit(5);

  if (error) throw error;
  const matches = (data || []).filter((row) => normalizeEmail(row.email) === normalized);
  if (matches.length !== 1) return null;
  return matches[0].id;
}

/// After member_id is set, ask Postgres to mirror guest_list → event_guests
/// and peer any other pending invite rows for that account.
async function peerLinkedMember(memberId) {
  if (!memberId) return;
  const { error } = await supabaseAdmin.rpc('link_event_guest_rows_for_member', {
    p_member_id: memberId,
  });
  // Older DBs without migration 036 still get member_id on guest_list_entries;
  // the 028 trigger (if present) mirrors from there. Don't fail the admin write.
  if (error && !/function .*link_event_guest_rows_for_member/i.test(error.message || '')) {
    throw error;
  }
}

async function memberAlreadyOnList(eventId, memberId, excludeEntryId = null) {
  if (!eventId || !memberId) return false;
  let query = supabaseAdmin
    .from('guest_list_entries')
    .select('id')
    .eq('event_id', eventId)
    .eq('member_id', memberId);
  if (excludeEntryId) query = query.neq('id', excludeEntryId);

  const { data, error } = await query.limit(1);
  if (error) throw error;
  return (data || []).length > 0;
}

router.get('/event/:eventId', requireAdmin, async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('guest_list_entries')
    .select('*')
    .eq('event_id', req.params.eventId)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: error.message });

  const guests = data || [];
  res.json({
    guests,
    unlinkedCount: guests.filter((g) => !g.member_id).length,
  });
});

router.post('/', requireAdmin, async (req, res) => {
  const { eventId, name, email, phone, plusOnes, memberId, notes, status } = req.body;
  if (!eventId || !name) {
    return res.status(400).json({ error: 'Event and guest name required.' });
  }

  let resolvedMemberId = memberId || null;
  let warning = null;

  try {
    if (!resolvedMemberId) {
      resolvedMemberId = await resolveMemberIdByEmail(email);
    }
    if (resolvedMemberId && (await memberAlreadyOnList(eventId, resolvedMemberId))) {
      return res.status(409).json({
        error: 'That app member is already on this event guest list.',
      });
    }
    if (!resolvedMemberId) warning = UNLINKED_WARNING;
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }

  const { data, error } = await supabaseAdmin
    .from('guest_list_entries')
    .insert({
      event_id: eventId,
      name,
      email: normalizeEmail(email) || email || null,
      phone: phone || null,
      plus_ones: Number(plusOnes) || 0,
      member_id: resolvedMemberId,
      notes: notes || null,
      status: status || 'invited',
      added_by: req.profile.id,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });

  try {
    await peerLinkedMember(resolvedMemberId);
  } catch (e) {
    return res.status(500).json({ error: e.message, guest: data, warning });
  }

  res.json({ guest: data, warning });
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const allowed = ['name', 'email', 'phone', 'plus_ones', 'status', 'notes', 'member_id'];
  const patch = {};
  for (const key of allowed) {
    if (req.body[key] !== undefined) patch[key] = req.body[key];
  }

  const { data: current, error: currentError } = await supabaseAdmin
    .from('guest_list_entries')
    .select('id, event_id, email, member_id')
    .eq('id', req.params.id)
    .single();
  if (currentError) return res.status(404).json({ error: currentError.message });

  let warning = null;
  let resolvedMemberId = null;
  try {
    // Re-resolve whenever the guest is still unlinked, or the email changed.
    const emailChanged =
      patch.email !== undefined && normalizeEmail(patch.email) !== normalizeEmail(current.email);
    if (patch.email !== undefined) {
      patch.email = normalizeEmail(patch.email) || patch.email || null;
    }
    if (patch.member_id === undefined && (!current.member_id || emailChanged)) {
      const resolved = await resolveMemberIdByEmail(patch.email ?? current.email);
      if (resolved && !(await memberAlreadyOnList(current.event_id, resolved, current.id))) {
        patch.member_id = resolved;
        resolvedMemberId = resolved;
      }
    } else if (patch.member_id) {
      resolvedMemberId = patch.member_id;
    }
    const nextMemberId =
      patch.member_id !== undefined ? patch.member_id : current.member_id;
    if (!nextMemberId) warning = UNLINKED_WARNING;
    else resolvedMemberId = nextMemberId;
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }

  const { data, error } = await supabaseAdmin
    .from('guest_list_entries')
    .update(patch)
    .eq('id', req.params.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });

  try {
    await peerLinkedMember(resolvedMemberId || data?.member_id);
  } catch (e) {
    return res.status(500).json({ error: e.message, guest: data, warning });
  }

  res.json({ guest: data, warning });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { error } = await supabaseAdmin.from('guest_list_entries').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

export default router;
