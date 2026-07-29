import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';
import { resolveLoad, ENTRY_PACKAGES } from '../lib/timePricing.js';

const router = Router();

const LOADS_EMBED_SELECT =
  '*, recipient:profiles!member_id(name, email, role), ' +
  'loader:profiles!loaded_by(name, email, role), ' +
  'voider:profiles!voided_by(name)';

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

async function fetchActivePackagesCatalog() {
  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .select(
      'id, slug, name, price_peso, duration_minutes, included_drinks, target_guest, tagline, popular, sort_order, active',
    )
    .eq('active', true)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  if (error || !data?.length) return ENTRY_PACKAGES;
  return data;
}

router.get('/packages', requireAdmin, async (_req, res) => {
  const packages = await fetchActivePackagesCatalog();
  res.json({ packages });
});

router.get('/', requireAdmin, async (req, res) => {
  const { data, error } = await fetchTimeLoads();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ loads: data });
});

router.post('/', requireAdmin, async (req, res) => {
  const {
    recipientId,
    packageSlug,
    amountPeso,
    billCount,
    quantity,
    paymentMethod,
    notes,
  } = req.body;

  if (!recipientId) {
    return res.status(400).json({ error: 'Select an account.' });
  }

  const catalog = await fetchActivePackagesCatalog();
  const resolved = resolveLoad({
    packageSlug,
    amountPeso,
    billCount,
    quantity,
    paymentMethod: paymentMethod || 'cash',
    catalog,
  });

  if (resolved.error) {
    return res.status(400).json({ error: resolved.error });
  }

  let data;
  let error;
  const rpc = await supabaseAdmin.rpc('admin_load_package', {
    p_member_id: recipientId,
    p_package_slug: resolved.pkg.slug,
    p_payment_method: paymentMethod || 'cash',
    p_notes: notes || null,
    p_admin_id: req.profile.id,
    p_quantity: resolved.count,
  });

  if (rpc.error?.message?.includes('admin_load_package')) {
    const legacy = await supabaseAdmin.rpc('admin_load_time', {
      p_member_id: recipientId,
      p_seconds: resolved.seconds,
      p_amount_peso: resolved.totalPeso,
      p_payment_method: paymentMethod || 'cash',
      p_notes: notes || `package:${resolved.pkg.slug}`,
      p_admin_id: req.profile.id,
    });
    data = legacy.data;
    error = legacy.error;
  } else {
    data = rpc.data;
    error = rpc.error;
  }

  if (error) return res.status(400).json({ error: error.message });
  res.json({
    load: data,
    packageSlug: resolved.pkg.slug,
    packageName: resolved.pkg.name,
    totalPeso: resolved.totalPeso,
    totalMinutes: resolved.totalMinutes,
    drinks: resolved.drinks,
    billCount: resolved.count,
  });
});

router.post('/bonus', requireAdmin, async (req, res) => {
  const { recipientId, ruleSlug, minutes, notes } = req.body;
  if (!recipientId || !ruleSlug) {
    return res.status(400).json({ error: 'Recipient and bonus rule required.' });
  }

  const { data, error } = await supabaseAdmin.rpc('admin_award_bonus_time', {
    p_member_id: recipientId,
    p_rule_slug: ruleSlug,
    p_minutes: minutes ?? null,
    p_notes: notes || null,
    p_admin_id: req.profile.id,
  });

  if (error?.message?.includes('admin_award_bonus_time')) {
    return res.status(503).json({
      error: 'Bonus awards require migration 020_time_packages_economy.sql.',
    });
  }
  if (error) return res.status(400).json({ error: error.message });
  res.json({ award: data });
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
