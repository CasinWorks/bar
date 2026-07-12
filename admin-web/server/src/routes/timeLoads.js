import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';
import { resolveLoad, CASH_PACKAGES } from '../lib/timePricing.js';
import { isSuperAdminEmail } from '../lib/superAdmin.js';

const router = Router();

const LOADS_EMBED_SELECT =
  '*, recipient:profiles!member_id(name, email, role), ' +
  'loader:profiles!loaded_by(name, email, role), ' +
  'voider:profiles!voided_by(name)';

function hideSuperAdminLoads(loads) {
  return (loads ?? []).filter(
    (row) =>
      !isSuperAdminEmail(row.recipient?.email) &&
      !isSuperAdminEmail(row.member?.email),
  );
}

async function fetchTimeLoads() {
  const { data, error } = await supabaseAdmin
    .from('time_loads')
    .select(LOADS_EMBED_SELECT)
    .order('created_at', { ascending: false })
    .limit(100);

  if (!error) return { data, error: null };

  const relationshipError =
    error.code === 'PGRST200' || error.message?.includes('relationship');

  if (!relationshipError) return { data: null, error };

  // Fallback: plain rows + manual profile lookup (schema cache / FK hint issues).
  const { data: rows, error: rowError } = await supabaseAdmin
    .from('time_loads')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100);

  if (rowError) return { data: null, error: rowError };
  if (!rows.length) return { data: [], error: null };

  const profileIds = [
    ...new Set(
      rows.flatMap((row) => [row.member_id, row.loaded_by, row.voided_by].filter(Boolean)),
    ),
  ];

  const { data: profiles } = await supabaseAdmin
    .from('profiles')
    .select('id, name, email, role')
    .in('id', profileIds);

  const byId = Object.fromEntries((profiles ?? []).map((p) => [p.id, p]));

  return {
    data: rows.map((row) => ({
      ...row,
      recipient: byId[row.member_id] ?? null,
      loader: byId[row.loaded_by] ?? null,
      voider: row.voided_by ? byId[row.voided_by] ?? null : null,
    })),
    error: null,
  };
}

router.get('/packages', requireAdmin, (_req, res) => {
  res.json({ packages: CASH_PACKAGES });
});

router.get('/', requireAdmin, async (req, res) => {
  const { data, error } = await fetchTimeLoads();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ loads: hideSuperAdminLoads(data) });
});

router.post('/', requireAdmin, async (req, res) => {
  const { recipientId, amountPeso, billCount, paymentMethod, notes } = req.body;

  if (!recipientId) {
    return res.status(400).json({ error: 'Select an account.' });
  }

  const resolved = resolveLoad({
    amountPeso,
    billCount,
    paymentMethod: paymentMethod || 'cash',
  });

  if (resolved.error) {
    return res.status(400).json({ error: resolved.error });
  }

  const { data, error } = await supabaseAdmin.rpc('admin_load_time', {
    p_member_id: recipientId,
    p_seconds: resolved.seconds,
    p_amount_peso: resolved.totalPeso,
    p_payment_method: paymentMethod || 'cash',
    p_notes: notes || null,
    p_admin_id: req.profile.id,
  });

  if (error) return res.status(400).json({ error: error.message });
  res.json({
    load: data,
    totalPeso: resolved.totalPeso,
    totalMinutes: resolved.totalMinutes,
    billCount: resolved.count,
  });
});

router.post('/:id/void', requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  if (!reason?.trim()) {
    return res.status(400).json({ error: 'A reason is required to void a load.' });
  }

  const { data, error } = await supabaseAdmin.rpc('admin_void_time_load', {
    p_load_id: id,
    p_reason: reason.trim(),
    p_admin_id: req.profile.id,
  });

  if (error?.message?.includes('admin_void_time_load')) {
    return res.status(503).json({
      error: 'Void not available yet. Run supabase/migrations/010_void_time_loads.sql in Supabase.',
    });
  }
  if (error) return res.status(400).json({ error: error.message });
  res.json({ load: data });
});

export default router;
