import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAdmin } from '../middleware/auth.js';
import { ENTRY_PACKAGES } from '../lib/timePricing.js';

const router = Router();

const PACKAGE_COLUMNS =
  'id, slug, name, price_peso, duration_minutes, included_drinks, target_guest, tagline, popular, sort_order, active, created_at, updated_at';

function slugify(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

function parseOptionalInt(value, { allowNull = true } = {}) {
  if (value === undefined) return { skip: true };
  if (value === null || value === '') {
    return allowNull ? { value: null } : { error: 'Value cannot be empty.' };
  }
  const n = Number(value);
  if (!Number.isFinite(n) || !Number.isInteger(n)) {
    return { error: 'Must be a whole number.' };
  }
  return { value: n };
}

function validatePackageInput(body, { partial = false } = {}) {
  const errors = [];
  const patch = {};

  if (!partial || body.slug !== undefined) {
    const slug = slugify(body.slug ?? body.name);
    if (!slug) errors.push('Slug is required.');
    else patch.slug = slug;
  }

  if (!partial || body.name !== undefined) {
    const name = String(body.name || '').trim();
    if (!name) errors.push('Name is required.');
    else patch.name = name;
  }

  if (!partial || body.pricePeso !== undefined || body.price_peso !== undefined) {
    const raw = body.pricePeso ?? body.price_peso;
    const parsed = parseOptionalInt(raw, { allowNull: false });
    if (parsed.skip) errors.push('Price is required.');
    else if (parsed.error) errors.push(`Price: ${parsed.error}`);
    else if (parsed.value < 0) errors.push('Price must be >= 0.');
    else patch.price_peso = parsed.value;
  }

  if (
    !partial ||
    body.durationMinutes !== undefined ||
    body.duration_minutes !== undefined
  ) {
    const raw = body.durationMinutes ?? body.duration_minutes;
    const parsed = parseOptionalInt(raw, { allowNull: true });
    if (parsed.error) errors.push(`Duration: ${parsed.error}`);
    else if (parsed.value != null && parsed.value <= 0) {
      errors.push('Duration must be > 0 minutes (or empty for until closing).');
    } else if (!parsed.skip) {
      patch.duration_minutes = parsed.value;
    }
  }

  if (
    !partial ||
    body.includedDrinks !== undefined ||
    body.included_drinks !== undefined
  ) {
    const raw = body.includedDrinks ?? body.included_drinks;
    const parsed = parseOptionalInt(raw, { allowNull: true });
    if (parsed.error) errors.push(`Included drinks: ${parsed.error}`);
    else if (parsed.value != null && parsed.value < 0) {
      errors.push('Included drinks must be >= 0 (or empty for unlimited).');
    } else if (!parsed.skip) {
      patch.included_drinks = parsed.value;
    }
  }

  if (!partial || body.targetGuest !== undefined || body.target_guest !== undefined) {
    const raw = body.targetGuest ?? body.target_guest;
    if (raw !== undefined) {
      patch.target_guest = raw == null || raw === '' ? null : String(raw).trim();
    }
  }

  if (!partial || body.tagline !== undefined) {
    if (body.tagline !== undefined) {
      patch.tagline =
        body.tagline == null || body.tagline === ''
          ? null
          : String(body.tagline).trim();
    }
  }

  if (!partial || body.popular !== undefined) {
    if (body.popular !== undefined) patch.popular = Boolean(body.popular);
  }

  if (!partial || body.active !== undefined) {
    if (body.active !== undefined) patch.active = Boolean(body.active);
  }

  if (!partial || body.sortOrder !== undefined || body.sort_order !== undefined) {
    const raw = body.sortOrder ?? body.sort_order;
    const parsed = parseOptionalInt(raw, { allowNull: false });
    if (parsed.skip && !partial) patch.sort_order = 0;
    else if (parsed.error) errors.push(`Sort order: ${parsed.error}`);
    else if (!parsed.skip) {
      if (parsed.value < 0) errors.push('Sort order must be >= 0.');
      else patch.sort_order = parsed.value;
    }
  }

  return { errors, patch };
}

function fallbackPackages() {
  return ENTRY_PACKAGES.map((p, index) => ({
    id: `fallback-${p.slug}`,
    slug: p.slug,
    name: p.name,
    price_peso: p.peso,
    duration_minutes: p.minutes,
    included_drinks: p.drinks,
    target_guest: p.target,
    tagline: null,
    popular: Boolean(p.popular),
    sort_order: index + 1,
    active: true,
    created_at: null,
    updated_at: null,
  }));
}

/** Active packages for cash desk / Flutter-shaped clients. */
router.get('/active', requireAdmin, async (_req, res) => {
  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .select(PACKAGE_COLUMNS)
    .eq('active', true)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  if (error) {
    return res.json({ packages: fallbackPackages(), source: 'fallback' });
  }
  if (!data?.length) {
    return res.json({ packages: fallbackPackages(), source: 'fallback' });
  }
  res.json({ packages: data, source: 'database' });
});

/** Full catalog including inactive (admin editor). */
router.get('/', requireAdmin, async (_req, res) => {
  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .select(PACKAGE_COLUMNS)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ packages: data ?? [] });
});

router.post('/', requireAdmin, async (req, res) => {
  const { errors, patch } = validatePackageInput(req.body, { partial: false });
  if (errors.length) return res.status(400).json({ error: errors.join(' ') });

  if (patch.sort_order === undefined) {
    const { data: maxRow } = await supabaseAdmin
      .from('time_packages')
      .select('sort_order')
      .order('sort_order', { ascending: false })
      .limit(1)
      .maybeSingle();
    patch.sort_order = (maxRow?.sort_order ?? 0) + 1;
  }
  if (patch.active === undefined) patch.active = true;
  if (patch.popular === undefined) patch.popular = false;

  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .insert(patch)
    .select(PACKAGE_COLUMNS)
    .single();

  if (error) {
    if (error.code === '23505') {
      return res.status(400).json({ error: 'A package with that slug already exists.' });
    }
    return res.status(500).json({ error: error.message });
  }
  res.json({ package: data });
});

router.post('/reorder', requireAdmin, async (req, res) => {
  const orderedIds = Array.isArray(req.body?.orderedIds) ? req.body.orderedIds : null;
  if (!orderedIds?.length) {
    return res.status(400).json({ error: 'orderedIds array is required.' });
  }

  const updates = orderedIds.map((id, index) =>
    supabaseAdmin
      .from('time_packages')
      .update({ sort_order: index + 1 })
      .eq('id', id),
  );

  const results = await Promise.all(updates);
  const failed = results.find((r) => r.error);
  if (failed?.error) {
    return res.status(500).json({ error: failed.error.message });
  }

  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .select(PACKAGE_COLUMNS)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ packages: data ?? [] });
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const { errors, patch } = validatePackageInput(req.body, { partial: true });
  if (errors.length) return res.status(400).json({ error: errors.join(' ') });
  if (Object.keys(patch).length === 0) {
    return res.status(400).json({ error: 'No fields to update.' });
  }

  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .update(patch)
    .eq('id', req.params.id)
    .select(PACKAGE_COLUMNS)
    .single();

  if (error) {
    if (error.code === '23505') {
      return res.status(400).json({ error: 'A package with that slug already exists.' });
    }
    return res.status(500).json({ error: error.message });
  }
  res.json({ package: data });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  // Soft-delete: deactivate so historical loads keep a resolvable slug.
  const { data, error } = await supabaseAdmin
    .from('time_packages')
    .update({ active: false })
    .eq('id', req.params.id)
    .select(PACKAGE_COLUMNS)
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ package: data, ok: true });
});

export default router;
